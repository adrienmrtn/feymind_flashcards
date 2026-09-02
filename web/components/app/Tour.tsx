"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { usePathname, useSearchParams } from "next/navigation";

import { Float } from "@/components/app/Float";
import { markTourSeen, skipTour } from "@/lib/actions/tour";
import { isOfferClaimed } from "@/lib/discount";
import {
  isPaywallDismissed,
  isPaywallPending,
  shouldOpenPaywall,
} from "@/lib/onboarding/persist";
import { bubblePlacement, holeAround, type Rect } from "@/lib/tour/place";
import { TOUR_RECHECK_EVENT } from "@/lib/tour/signal";
import { stepsForWidth, tourFor, type Tour, type TourStep } from "@/lib/tour/steps";
import { shouldOpenTour } from "@/lib/tour/state";

/**
 * **La visite guidée du web.**
 *
 * Chaque page se présente une fois, au premier passage, une zone après
 * l'autre. Elle attend son tour derrière le paywall et le cadeau, et elle ne
 * revient jamais : ce que le compte a vu est écrit dans `profiles`.
 *
 * Deux façons de montrer, décidées par la visite elle-même :
 *
 * - `guided` pose un voile percé sur la zone. Le voile n'est pas de la
 *   décoration : sans lui, un clic au milieu d'une explication change de page
 *   et la visite s'interrompt là où elle était la plus utile.
 * - `hint` ne pose rien. C'est le mode de la session de révision, et le
 *   changement est entier : la bulle suit ce que fait l'étudiant au lieu de
 *   lui demander de cliquer « Suivant ». Retourner la carte fait passer à la
 *   bulle des notes, parce que c'est le geste qu'on voulait expliquer.
 *
 * Ce composant est monté **dans la charpente**, une fois. Une navigation
 * interne ne le remonte pas : il garde donc en mémoire les pages déjà
 * présentées pendant la session, sans attendre que le serveur relise la
 * colonne à chaque clic.
 */
export function TourHost({
  isPaid,
  seen,
  skipped,
}: {
  isPaid: boolean;
  seen: readonly string[];
  skipped: boolean;
}) {
  const pathname = usePathname();
  const params = useSearchParams();
  const debug = params.get("debug") === "visite";
  const inSession = params.get("go") === "1";

  const tour = useMemo(() => tourFor({ pathname, inSession }), [inSession, pathname]);

  // Le serveur ne relit pas la colonne à chaque navigation interne : la liste
  // se complète donc ici, et le rechargement suivant la retrouve en base.
  const [done, setDone] = useState<readonly string[]>(seen);
  const [openId, setOpenId] = useState<string | null>(null);
  const [recheck, setRecheck] = useState(0);

  useEffect(() => {
    function again() {
      setRecheck((count) => count + 1);
    }
    window.addEventListener(TOUR_RECHECK_EVENT, again);
    return () => window.removeEventListener(TOUR_RECHECK_EVENT, again);
  }, []);

  useEffect(() => {
    if (!tour) {
      setOpenId(null);
      return;
    }
    if (openId === tour.id) return;

    // Le paywall décide avant nous, avec ses propres entrées. On les relit
    // plutôt que de deviner : deux règles séparées finiraient par ne plus
    // être d'accord sur qui s'ouvre.
    const paywallWillOpen = shouldOpenPaywall({
      isPaid,
      force: params.get("offre") === "1",
      welcome: params.get("bienvenue") === "1",
      pending: isPaywallPending(),
      dismissed: isPaywallDismissed(),
      onHome: pathname === "/app",
      debug: params.get("debug") === "paywall",
    });

    if (
      !shouldOpenTour({
        isPaid,
        paywallDismissed: isPaywallDismissed(),
        paywallWillOpen,
        offerClaimed: isOfferClaimed(),
        skipped,
        seen: done,
        tourId: tour.id,
        debug,
      })
    ) {
      return;
    }

    setOpenId(tour.id);
  }, [debug, done, isPaid, openId, params, pathname, recheck, skipped, tour]);

  const finish = useCallback(
    (tourId: string) => {
      setDone((previous) => (previous.includes(tourId) ? previous : [...previous, tourId]));
      setOpenId(null);
      // Sans attente : la visite est finie à l'écran, la colonne rattrape.
      void markTourSeen(tourId);
    },
    [],
  );

  const skipAll = useCallback(
    (tourId: string) => {
      setOpenId(null);
      setDone((previous) => (previous.includes(tourId) ? previous : [...previous, tourId]));
      void skipTour();
    },
    [],
  );

  if (!tour || openId !== tour.id) return null;

  return (
    <TourRun
      key={tour.id}
      tour={tour}
      onFinish={() => finish(tour.id)}
      onSkipAll={() => skipAll(tour.id)}
    />
  );
}

/**
 * Une visite en cours.
 *
 * Remontée à chaque page (`key`), donc sans état à remettre à zéro : un index
 * qui survivrait d'une page à l'autre ouvrirait la troisième bulle d'un écran
 * qui n'en a que deux.
 */
function TourRun({
  tour,
  onFinish,
  onSkipAll,
}: {
  tour: Tour;
  onFinish: () => void;
  onSkipAll: () => void;
}) {
  const steps = useVisibleSteps(tour);
  const [index, setIndex] = useState(0);
  const [passed, setPassed] = useState<readonly string[]>([]);

  // En mode `hint`, la bulle montrée est la première dont la zone est à
  // l'écran : c'est la carte qui commande, pas un compteur.
  const guided = tour.mode === "guided";
  const step = guided ? steps[index] : null;

  const hintStep = useHintStep(guided ? null : steps, passed);
  const current = guided ? step : hintStep;

  const anchor = useAnchor(current?.anchor ?? null, guided);
  const frame = useVisibleFrame();
  const [node, setNode] = useState<HTMLDivElement | null>(null);
  // Plus haute que le contenu réel : une première pose trop basse coupe
  // « Suivant » le temps que le ResizeObserver rattrape.
  const [size, setSize] = useState({ width: 320, height: 240 });

  useEffect(() => {
    if (!node) return;
    const measure = () => {
      const rect = node.getBoundingClientRect();
      setSize({ width: rect.width, height: rect.height });
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(node);
    return () => observer.disconnect();
  }, [current?.anchor, node]);

  const next = useCallback(() => {
    if (index + 1 >= steps.length) {
      onFinish();
      return;
    }
    setIndex(index + 1);
  }, [index, onFinish, steps.length]);

  const dismissHint = useCallback(() => {
    if (!current) return;
    const seen = [...passed, current.anchor];
    setPassed(seen);
    if (steps.every((item) => seen.includes(item.anchor))) onFinish();
  }, [current, onFinish, passed, steps]);

  // Une zone de `hint` qui disparaît est une zone dont on a fini de parler :
  // retourner la carte fait sortir « Voir la réponse », et la bulle avec.
  useEffect(() => {
    if (guided || !current || anchor) return;
    const timer = window.setTimeout(dismissHint, 120);
    return () => window.clearTimeout(timer);
  }, [anchor, current, dismissHint, guided]);

  useEffect(() => {
    if (!guided) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        onFinish();
        return;
      }
      if (event.key === "ArrowRight") {
        event.preventDefault();
        next();
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [guided, next, onFinish]);

  // Toutes les zones d'une page peuvent manquer : un cours sans carte n'a pas
  // d'atelier. On ne marque alors rien comme vu, et la page se présentera le
  // jour où elle aura quelque chose à montrer.
  if (steps.length === 0) return null;
  if (!current) return null;
  if (guided && !anchor) return null;
  if (!anchor) return null;

  const place = bubblePlacement(anchor, size, frame);
  const hole = holeAround(anchor);

  return (
    <Float>
      <>
      {guided ? (
        <>
          {/* Le bloqueur est sous le trou : c'est lui qui avale les clics, y
              compris ceux qui tombent dans le trou. La zone est montrée, pas
              rendue cliquable. */}
          <div className="tour-veil fixed inset-0 z-50" aria-hidden />
          <div
            aria-hidden
            className="tour-hole pointer-events-none fixed z-[51]"
            style={{
              top: hole.top,
              left: hole.left,
              width: hole.width,
              height: hole.height,
            }}
          />
        </>
      ) : (
        <div
          aria-hidden
          className="tour-ring pointer-events-none fixed z-[51]"
          style={{
            top: hole.top,
            left: hole.left,
            width: hole.width,
            height: hole.height,
          }}
        />
      )}

      <div
        ref={setNode}
        role="dialog"
        aria-modal={guided || undefined}
        aria-labelledby="tour-title"
        aria-describedby="tour-body"
        className="tour-bubble fixed z-[52] max-h-[calc(100dvh-1.5rem)] w-[min(21rem,calc(100vw-1.5rem))] overflow-y-auto rounded-[20px] bg-surface p-5 shadow-[0_24px_70px_-18px_rgba(25,28,32,0.45)]"
        style={{ top: place.top, left: place.left }}
      >
        {guided ? (
          <div className="mb-2.5 flex items-start justify-between gap-3">
            <p className="numeral text-[11.5px] font-semibold uppercase tracking-[0.1em] text-ink-tertiary">
              {index + 1} / {steps.length}
            </p>
            <button
              type="button"
              onClick={onFinish}
              aria-label="Passer la visite de cette page"
              className="pressable -mr-1.5 -mt-1.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-ink-tertiary hover:bg-canvas"
            >
              <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4">
                <path
                  d="M5 5l10 10M15 5L5 15"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.9"
                  strokeLinecap="round"
                />
              </svg>
            </button>
          </div>
        ) : null}

        <h2 id="tour-title" className="text-[16px] font-semibold leading-snug text-ink">
          {current.title}
        </h2>
        <p id="tour-body" className="mt-1.5 text-[14px] leading-relaxed text-ink-secondary">
          {current.body}
        </p>

        <div className="mt-4 flex items-center justify-between gap-3">
          {guided ? (
            <button
              type="button"
              onClick={onSkipAll}
              className="pressable text-[13px] font-medium text-ink-tertiary underline-offset-2 hover:underline"
            >
              Passer la visite
            </button>
          ) : (
            <span />
          )}

          <button
            type="button"
            autoFocus
            onClick={guided ? next : dismissHint}
            className="pressable flex h-10 items-center justify-center rounded-button bg-accent px-4 text-[14px] font-semibold text-on-ink"
          >
            {guided ? (index + 1 >= steps.length ? "Terminer" : "Suivant") : "Compris"}
          </button>
        </div>
      </div>
      </>
    </Float>
  );
}

/**
 * La fenêtre vraiment visible : barre d'adresse, clavier, zoom.
 *
 * `innerHeight` compte ce qui est caché derrière le chrome du navigateur.
 * Une bulle calée dessus a son bouton hors de portée.
 */
function useVisibleFrame(): { width: number; height: number } {
  const [frame, setFrame] = useState(() => readVisibleFrame());

  useEffect(() => {
    function sync() {
      setFrame(readVisibleFrame());
    }
    sync();
    window.addEventListener("resize", sync);
    window.visualViewport?.addEventListener("resize", sync);
    window.visualViewport?.addEventListener("scroll", sync);
    return () => {
      window.removeEventListener("resize", sync);
      window.visualViewport?.removeEventListener("resize", sync);
      window.visualViewport?.removeEventListener("scroll", sync);
    };
  }, []);

  return frame;
}

function readVisibleFrame(): { width: number; height: number } {
  if (typeof window === "undefined") return { width: 1280, height: 800 };
  const view = window.visualViewport;
  return {
    width: view?.width ?? window.innerWidth,
    height: view?.height ?? window.innerHeight,
  };
}

/** Les bulles qui ont un sens sur cette largeur, recalculées si elle change. */
function useVisibleSteps(tour: Tour): readonly TourStep[] {
  const [width, setWidth] = useState(() =>
    typeof window === "undefined" ? 1280 : window.innerWidth,
  );

  useEffect(() => {
    function onResize() {
      setWidth(window.innerWidth);
    }
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  return useMemo(() => stepsForWidth(tour, width), [tour, width]);
}

/**
 * Le rectangle de la zone montrée, suivi tant qu'elle bouge.
 *
 * Une zone peut arriver après la page - un `Suspense` qui se résout, une carte
 * qui se déplie - donc la recherche insiste un peu au lieu de conclure du
 * premier coup. Elle insiste **en mode guidé seulement** : une bulle de
 * session qui attendrait une zone absente resterait collée à l'écran alors que
 * la carte a déjà tourné.
 */
function useAnchor(name: string | null, insist: boolean): Rect | null {
  const [rect, setRect] = useState<Rect | null>(null);

  useEffect(() => {
    setRect(null);
    if (!name) return;

    let frame = 0;
    let stop = false;
    const started = Date.now();
    const patience = insist ? 1200 : 0;
    let scrolled = false;

    function read() {
      if (stop) return;
      const node = document.querySelector<HTMLElement>(`[data-tour="${name}"]`);

      if (!node) {
        if (Date.now() - started < patience) {
          frame = window.requestAnimationFrame(read);
        } else {
          setRect(null);
        }
        return;
      }

      if (!scrolled) {
        scrolled = true;
        const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        node.scrollIntoView({ block: "center", behavior: still ? "auto" : "smooth" });
      }

      const box = node.getBoundingClientRect();
      setRect({ top: box.top, left: box.left, width: box.width, height: box.height });

      // Le défilement doux met quelques centaines de millisecondes : on relit
      // pendant ce temps-là, sinon le trou reste où la zone était.
      if (Date.now() - started < 900) frame = window.requestAnimationFrame(read);
    }

    read();

    const follow = () => {
      const node = document.querySelector<HTMLElement>(`[data-tour="${name}"]`);
      if (!node) {
        setRect(null);
        return;
      }
      const box = node.getBoundingClientRect();
      setRect({ top: box.top, left: box.left, width: box.width, height: box.height });
    };

    window.addEventListener("scroll", follow, { passive: true });
    window.addEventListener("resize", follow);

    return () => {
      stop = true;
      window.cancelAnimationFrame(frame);
      window.removeEventListener("scroll", follow);
      window.removeEventListener("resize", follow);
    };
  }, [insist, name]);

  return rect;
}

/**
 * En mode `hint`, la première bulle dont la zone est présente et pas encore
 * écartée.
 *
 * Relu par intervalle plutôt que par observateur de mutations : deux zones à
 * surveiller pendant une session de révision, où le DOM bouge à chaque carte
 * notée. Un observateur y serait réveillé des centaines de fois pour répondre
 * la même chose.
 */
function useHintStep(
  steps: readonly TourStep[] | null,
  passed: readonly string[],
): TourStep | null {
  const [found, setFound] = useState<TourStep | null>(null);

  useEffect(() => {
    if (!steps) {
      setFound(null);
      return;
    }

    const candidates = steps;

    function look() {
      const next =
        candidates.find(
          (step) =>
            !passed.includes(step.anchor) &&
            document.querySelector(`[data-tour="${step.anchor}"]`) !== null,
        ) ?? null;
      setFound(next);
    }

    look();
    const tick = window.setInterval(look, 300);
    return () => window.clearInterval(tick);
  }, [passed, steps]);

  return found;
}
