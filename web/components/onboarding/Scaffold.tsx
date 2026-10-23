"use client";

import { useCallback, useEffect, useRef } from "react";
import type { Route } from "next";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

import { useI18n } from "@/lib/i18n/client";
import { prefetchStep } from "@/lib/onboarding/prefetch";
import { useOnboarding } from "@/lib/onboarding/store";
import { nextPath, previousPath, type OnboardingPath, type StepContext } from "@/lib/onboarding/steps";

/**
 * Ce que l'ordre des écrans a besoin de savoir des réponses : le pays, et la filière.
 * L'écran de l'année ne se pose qu'à certains pays, et il faut le savoir pour avancer.
 */
export function useStepContext(): StepContext {
  const { answers } = useOnboarding();
  return { country: answers.country, trackId: answers.trackId };
}

/** Le temps de voir sa réponse cochée avant que l'écran ne parte. Assez pour le lire, pas plus. */
const AUTO_ADVANCE_MS = 180;

function prefersReducedMotion(): boolean {
  try {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  } catch {
    return false;
  }
}

/**
 * **Avancer d'un écran**, sans que l'écran ait à savoir lequel suit.
 *
 * `context` porte la réponse qu'on vient de donner : `set` n'a pas encore rendu, et l'écran de
 * l'année dépend justement de la filière qu'on vient de toucher. `auto` laisse le temps de voir
 * la coche - un écran qui part à l'instant du toucher donne l'impression d'avoir raté son appui.
 * Un double appui ne fait pas sauter deux écrans.
 */
export function useAdvance() {
  const router = useRouter();
  const pathname = usePathname();
  const base = useStepContext();
  const leaving = useRef(false);
  const timer = useRef(0);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  return useCallback(
    (options: { context?: StepContext; href?: OnboardingPath; auto?: boolean } = {}) => {
      if (leaving.current) return;
      leaving.current = true;
      const target = options.href ?? nextPath(pathname, { ...base, ...options.context });
      const go = () => router.push(target as Route);
      if (options.auto && !prefersReducedMotion()) timer.current = window.setTimeout(go, AUTO_ADVANCE_MS);
      else go();
    },
    [base, pathname, router],
  );
}

/**
 * La charpente d'un écran de parcours, **dans la carte**.
 *
 * Un titre centré, une phrase dessous quand il en faut une, la réponse, puis le retour à gauche
 * et le bouton à droite. C'est le geste d'un formulaire posé au milieu de la page, et il ne
 * change pas d'un écran à l'autre. La réponse défile **dans** la carte quand elle est longue
 * (vingt-cinq pays), avec un fondu en haut et en bas : la carte, elle, ne bouge jamais.
 */
export function Scaffold({
  title,
  lead,
  children,
  footer,
  center = false,
  width = "narrow",
}: {
  title: React.ReactNode;
  /** La phrase sous le titre. */
  lead?: React.ReactNode;
  children: React.ReactNode;
  footer: React.ReactNode;
  /** Centre le contenu dans la carte, quand il est court. */
  center?: boolean;
  width?: "narrow" | "wide";
}) {
  const pathname = usePathname();
  const router = useRouter();
  const { t } = useI18n();
  const context = useStepContext();
  const back = previousPath(pathname, context);

  // Le parcours entier est préchargé par l'habillage ; l'écran suivant l'est ici aussi, au cas
  // où la réponse vient de changer la suite (l'année, selon le pays).
  useEffect(() => {
    prefetchStep(router, nextPath(pathname, context));
  }, [context, pathname, router]);

  const column = width === "wide" ? "mx-auto w-full max-w-[560px]" : "mx-auto w-full max-w-[460px]";

  return (
    <div className="flex min-h-0 flex-1 flex-col px-5 pb-5 pt-5 sm:px-10 sm:pb-7 sm:pt-6">
      <div className="step-part shrink-0 text-center">
        <h1 className="mx-auto max-w-[24ch] text-balance text-[23px] font-extrabold leading-[1.15] tracking-tight-title text-ink sm:text-[27px]">
          {title}
        </h1>
        {lead ? (
          <p className="mx-auto mt-2 max-w-[42ch] text-balance text-[14.5px] leading-relaxed text-ink-secondary sm:text-[15px]">
            {lead}
          </p>
        ) : null}
      </div>

      <div
        className={`step-part step-scroll -mx-2 mt-5 min-h-0 flex-1 overflow-y-auto overscroll-contain px-2 py-2 ${center ? "flex flex-col" : ""}`}
        style={{ animationDelay: "35ms" }}
      >
        <div className={`${column} ${center ? "my-auto" : ""}`}>{children}</div>
      </div>

      <div className="step-part flex shrink-0 items-center justify-between gap-3 pt-4" style={{ animationDelay: "70ms" }}>
        {back ? (
          <Link
            href={back as Route}
            className="pressable inline-flex min-h-11 shrink-0 items-center gap-1.5 rounded-pill pe-2 text-[15px] font-semibold text-ink-tertiary transition-colors duration-hover hover:text-ink"
          >
            <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4 rtl:-scale-x-100">
              <path d="M12 4l-6 6 6 6" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            {t("common.back")}
          </Link>
        ) : (
          <span />
        )}
        <div className="min-w-0 shrink">{footer}</div>
      </div>
    </div>
  );
}

/**
 * Le bouton principal, **gris tant qu'on n'a pas répondu**, et **Entrée** pour l'appuyer.
 *
 * Il occupe sa place depuis le début, éteint : un bouton qui apparaît quand la réponse arrive
 * fait sauter la page au moment où le doigt s'approche. La touche Entrée l'appuie de partout -
 * sauf depuis un bouton ou un lien qui a le focus, qui ont déjà la leur.
 */
export function ContinueButton({
  label,
  enabled,
  href,
  onPress,
}: {
  label?: string;
  enabled: boolean;
  /**
   * L'écran suivant. **À ne pas donner** : par défaut, c'est celui que `STEPS` place après
   * celui-ci, pour cet étudiant-là.
   *
   * Chaque écran nommait sa suite en dur, ce qui revient à tenir l'ordre du parcours à
   * quatorze endroits. Le jour où quatre écrans se sont insérés après les matières, l'écran
   * des matières a continué d'appeler le chargement : quatre écrans existaient, s'ouvraient
   * au retour, et personne ne les voyait jamais à l'aller. L'ordre vit dans `STEPS`, et il
   * n'y a plus qu'un endroit où se tromper.
   */
  href?: OnboardingPath;
  /** Remplace la navigation : l'écran décide lui-même où aller (la session, l'offre). */
  onPress?: () => void;
}) {
  const { t } = useI18n();
  const advance = useAdvance();
  const text = label ?? t("common.continue");

  const press = useCallback(() => {
    if (!enabled) return;
    if (onPress) onPress();
    else advance({ href });
  }, [advance, enabled, href, onPress]);

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== "Enter" || event.isComposing || event.defaultPrevented) return;
      if (event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return;
      const target = event.target as HTMLElement | null;
      if (target?.closest("button, a, select, textarea, [role='button']")) return;
      event.preventDefault();
      press();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [press]);

  return (
    <button
      type="button"
      disabled={!enabled}
      onClick={press}
      className={`inline-flex h-[52px] max-w-full items-center justify-center gap-2 rounded-[16px] px-5 text-[15.5px] font-extrabold leading-tight transition-[background-color,color,box-shadow] duration-hover sm:h-14 sm:px-7 sm:text-[16px] ${
        enabled ? "lp-cta bg-accent text-on-ink" : "cursor-not-allowed bg-surface-muted text-ink-tertiary"
      }`}
    >
      <span className="truncate">{text}</span>
      <svg aria-hidden viewBox="0 0 20 20" className="lp-arrow h-[18px] w-[18px] shrink-0 rtl:-scale-x-100" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 10h11M11 5l5 5-5 5" />
      </svg>
    </button>
  );
}

/** La coche d'une réponse : un rond pour une seule réponse, un carré arrondi pour plusieurs. */
function Tick({ selected, multi }: { selected: boolean; multi: boolean }) {
  return (
    <span
      aria-hidden
      className={`flex h-[22px] w-[22px] shrink-0 items-center justify-center border-2 transition-colors duration-hover ${
        multi ? "rounded-[7px]" : "rounded-full"
      } ${selected ? "border-accent bg-accent" : "border-stroke-strong bg-surface"}`}
    >
      {selected ? (
        <svg viewBox="0 0 20 20" className="emoji-pop h-full w-full text-on-ink">
          <path d="M5 10.5l3.2 3.2L15 7" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      ) : null}
    </span>
  );
}

/**
 * Une réponse.
 *
 * L'emoji est posé **à même la ligne**, sans fond ni cadre : une pastille colorée par ligne fait
 * lire des pictogrammes au lieu des réponses. Il porte la classe `emoji`, sans quoi un drapeau se
 * dessine « FR » sur les systèmes dont la police de texte n'a pas les glyphes régionaux.
 *
 * `multi` dit au lecteur d'écran et à l'œil qu'on peut en cocher plusieurs : une case, pas un
 * rond.
 */
export function ChoiceRow({
  emoji,
  icon,
  title,
  detail,
  selected,
  onSelect,
  multi = false,
}: {
  emoji?: string;
  /** À la place de l'emoji : un drapeau dessiné, par exemple. */
  icon?: React.ReactNode;
  title: string;
  detail?: string;
  selected: boolean;
  onSelect: () => void;
  multi?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      className={`pressable flex min-h-[54px] w-full items-center gap-3.5 rounded-[16px] border-[1.5px] px-4 py-2.5 text-start transition-colors duration-hover ${
        selected ? "border-accent bg-accent-soft" : "border-stroke bg-surface hover:border-stroke-strong hover:bg-surface-muted/60"
      }`}
    >
      {icon ??
        (emoji ? (
          <span aria-hidden className="emoji w-7 shrink-0 text-center text-[22px] leading-none">
            {emoji}
          </span>
        ) : null)}
      <span className="min-w-0 flex-1">
        <span className={`block text-[15.5px] font-semibold leading-snug ${selected ? "text-accent" : "text-ink"}`}>{title}</span>
        {detail ? <span className="mt-0.5 block truncate text-[12.5px] font-medium text-ink-tertiary">{detail}</span> : null}
      </span>
      <Tick selected={selected} multi={multi} />
    </button>
  );
}

/** Un groupe de réponses, nommé par le titre de l'écran pour le lecteur d'écran. */
export function ChoiceGroup({
  label,
  multi = false,
  className = "",
  children,
}: {
  label: string;
  multi?: boolean;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div role="group" aria-label={label} data-multi={multi || undefined} className={className}>
      {children}
    </div>
  );
}
