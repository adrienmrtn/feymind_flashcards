"use client";

import { useEffect, useRef, useState } from "react";

import { useI18n } from "@/lib/i18n/client";

/**
 * **Les avis, un à la fois, et on les fait glisser.**
 *
 * Trois cartes côte à côte se lisent en diagonale, donc ne se lisent pas. Une seule, assez
 * grande pour qu'on la lise vraiment, posée sur un rail qu'on pousse.
 *
 * **Le rail est un débordement horizontal, et rien d'autre.** La première version reposait
 * sur `scroll-snap-type: mandatory` avec un `scrollLeft` réécrit à la main pendant le geste ;
 * les deux se battaient. L'accrochage obligatoire ramène le rail sur son point d'ancrage à
 * chaque écriture, si bien que le rail ne bougeait pas d'un pixel sous la souris - ce qui
 * marchait sous un test qui déplace le pointeur par sauts, et ne marchait pas sous une vraie
 * main qui le déplace en continu.
 *
 * L'accrochage est donc **proximity** et non **mandatory** : il range la carte quand on
 * relâche près d'un bord, sans jamais reprendre la main pendant le geste. Le doigt et le
 * pavé tactile passent directement par le défilement du système, avec son inertie et son
 * rebond. Reste la souris, qui ne fait pas ce geste : le glisser au bouton enfoncé lui est
 * réservé, et il ne fait que déplacer le défilement.
 */

const REVIEWS = ["review1", "review2", "review3", "review4"] as const;

const INTERVAL_MS = 5_200;

export function ReviewCarousel() {
  const { t } = useI18n();
  const rail = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);
  const [paused, setPaused] = useState(false);

  /** Aller à une carte. C'est le rail qui décide, pas l'état : c'est lui que le doigt pousse. */
  function goTo(position: number) {
    const node = rail.current;
    if (!node) return;
    node.scrollTo({ left: position * node.clientWidth, behavior: "smooth" });
  }

  // La pastille suit ce qu'on voit, y compris quand c'est le doigt qui a décidé.
  useEffect(() => {
    const node = rail.current;
    if (!node) return;
    function onScroll() {
      if (!node) return;
      setIndex(Math.round(node.scrollLeft / Math.max(1, node.clientWidth)));
    }
    node.addEventListener("scroll", onScroll, { passive: true });
    return () => node.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    if (paused) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const id = window.setInterval(() => {
      const node = rail.current;
      if (!node) return;
      const next =
        (Math.round(node.scrollLeft / Math.max(1, node.clientWidth)) + 1) % REVIEWS.length;
      node.scrollTo({ left: next * node.clientWidth, behavior: "smooth" });
    }, INTERVAL_MS);
    return () => window.clearInterval(id);
  }, [paused]);

  /**
   * Le glisser à la souris.
   *
   * Il n'écrit plus `scrollLeft` : il appelle `scrollBy` avec le déplacement du dernier
   * évènement. La différence compte, parce qu'un `scrollBy` passe par le défilement du
   * navigateur - celui-là même que l'accrochage respecte - là où une affectation directe se
   * fait corriger dans la foulée.
   */
  const drag = useRef<{ x: number; moved: number } | null>(null);

  function onPointerDown(event: React.PointerEvent) {
    if (event.pointerType !== "mouse" || event.button !== 0) return;
    const node = rail.current;
    if (!node) return;
    drag.current = { x: event.clientX, moved: 0 };
    node.setPointerCapture(event.pointerId);
  }

  function onPointerMove(event: React.PointerEvent) {
    const node = rail.current;
    if (!node || !drag.current) return;
    const step = drag.current.x - event.clientX;
    drag.current = { x: event.clientX, moved: drag.current.moved + step };
    node.scrollBy({ left: step });
    // Sans ça, le navigateur commence à sélectionner le texte de la citation dès le
    // deuxième pixel, et le rail se traîne derrière un surlignage bleu.
    event.preventDefault();
  }

  function endDrag(event: React.PointerEvent) {
    const node = rail.current;
    if (!node || !drag.current) return;
    const { moved } = drag.current;
    drag.current = null;
    if (node.hasPointerCapture(event.pointerId)) node.releasePointerCapture(event.pointerId);

    // Le lâcher se range sur le **geste**, pas sur la position : pousser d'un cinquième de
    // carte veut dire « la suivante », alors qu'un arrondi ramènerait à celle qu'on quitte.
    const width = Math.max(1, node.clientWidth);
    const from = Math.round((node.scrollLeft - moved) / width);
    const step = Math.abs(moved) > width * 0.2 ? Math.sign(moved) : 0;
    goTo(Math.min(REVIEWS.length - 1, Math.max(0, from + step)));
  }

  return (
    <div
      aria-roledescription="carousel"
      aria-label={t("onboarding.reviewsAria")}
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocusCapture={() => setPaused(true)}
      onBlurCapture={() => setPaused(false)}
      onTouchStart={() => setPaused(true)}
    >
      <div
        ref={rail}
        className="slider-rail flex cursor-grab snap-x snap-proximity overflow-x-auto overscroll-x-contain active:cursor-grabbing"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
      >
        {REVIEWS.map((review) => (
          <figure
            key={review}
            className="flex min-h-[188px] w-full shrink-0 snap-center select-none flex-col justify-center rounded-group bg-surface-muted px-6 py-7 text-center sm:px-10"
          >
            <span className="mx-auto inline-flex items-center rounded-pill bg-accent-soft px-3 py-1 text-[12.5px] font-semibold text-accent">
              {t(`onboarding.${review}Gain`)}
            </span>
            <blockquote className="mt-4 text-balance text-[17px] leading-relaxed text-ink sm:text-[18px]">
              {t(`onboarding.${review}Text`)}
            </blockquote>
            <figcaption className="mt-4 text-[13px] text-ink-tertiary">
              {t(`onboarding.${review}Name`)} · {t(`onboarding.${review}Detail`)}
            </figcaption>
          </figure>
        ))}
      </div>

      <div className="mt-5 flex justify-center gap-2">
        {REVIEWS.map((review, position) => (
          <button
            key={review}
            type="button"
            onClick={() => goTo(position)}
            aria-label={t("onboarding.reviewsGo", { n: position + 1 })}
            aria-current={position === index}
            className={`pressable h-2 rounded-pill transition-all duration-hover ${
              position === index ? "w-6 bg-ink" : "w-2 bg-stroke-strong hover:bg-ink-tertiary"
            }`}
          />
        ))}
      </div>
    </div>
  );
}
