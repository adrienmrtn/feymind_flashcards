"use client";

import { useEffect, useRef, useState } from "react";

import { useI18n } from "@/lib/i18n/client";

/**
 * **Les avis, un à la fois, et on les fait glisser.**
 *
 * Trois cartes côte à côte se lisent en diagonale, donc ne se lisent pas. Une seule, assez
 * grande pour qu'on la lise vraiment, posée sur un rail qu'on pousse au doigt comme partout
 * ailleurs sur un téléphone. Le rail est un simple débordement horizontal avec accrochage
 * natif : l'inertie, le rebond du bord et le sens de lecture sont ceux du système, et une
 * reconstruction au `pointermove` les refait toujours moins bien.
 *
 * La souris ne fait pas ce geste, elle : sur un ordinateur sans pavé tactile, un rail ne se
 * pousse pas. D'où le glisser au bouton enfoncé, qui ne fait que déplacer le défilement -
 * quelques lignes, et rien de ce que le tactile sait faire n'est perdu.
 *
 * Le défilement automatique s'arrête dès que la souris entre, qu'un doigt se pose ou que le
 * clavier attrape une pastille - lire une phrase qui s'échappe au milieu est la seule façon de
 * rendre un avis agaçant - et il ne démarre pas du tout pour qui a demandé moins d'animations.
 */

const REVIEWS = ["review1", "review2", "review3", "review4"] as const;

const INTERVAL_MS = 5_200;

export function ReviewCarousel() {
  const { t } = useI18n();
  const rail = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);
  const [paused, setPaused] = useState(false);

  /** Le rail décide, pas l'état : c'est lui que le doigt déplace. */
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
      const next = (Math.round(node.scrollLeft / Math.max(1, node.clientWidth)) + 1) % REVIEWS.length;
      node.scrollTo({ left: next * node.clientWidth, behavior: "smooth" });
    }, INTERVAL_MS);
    return () => window.clearInterval(id);
  }, [paused]);

  /** Le glisser à la souris : on suit le curseur, on ne calcule rien d'autre. */
  const drag = useRef<{ x: number; from: number } | null>(null);

  function onPointerDown(event: React.PointerEvent) {
    if (event.pointerType !== "mouse") return;
    const node = rail.current;
    if (!node) return;
    drag.current = { x: event.clientX, from: node.scrollLeft };
    node.setPointerCapture(event.pointerId);
    // **L'accrochage se coupe le temps du geste.** Il est déclaré « mandatory » : tant qu'il
    // tient, une position posée à la main est ramenée sur le point d'accroche le plus proche
    // dans la foulée, et le rail ne bouge pas d'un pixel sous la souris.
    node.style.scrollSnapType = "none";
  }

  function onPointerMove(event: React.PointerEvent) {
    const node = rail.current;
    if (!node || !drag.current) return;
    node.scrollLeft = drag.current.from - (event.clientX - drag.current.x);
  }

  /** Au-delà de ce cinquième de carte, le geste vaut « la suivante ». */
  const FLICK = 0.2;

  function endDrag(event: React.PointerEvent) {
    const node = rail.current;
    if (!node || !drag.current) return;
    const from = drag.current.from;
    drag.current = null;
    if (node.hasPointerCapture(event.pointerId)) node.releasePointerCapture(event.pointerId);
    node.style.scrollSnapType = "";

    // Le lâcher se range à la main : l'accrochage natif ne s'applique qu'au défilement du
    // système, pas à un `scrollLeft` qu'on a posé soi-même. Et il se range sur le geste, pas
    // sur la position : pousser d'un tiers de carte veut dire « la suivante », alors que
    // l'arrondi à la carte la plus proche ramènerait à celle qu'on quitte.
    const width = Math.max(1, node.clientWidth);
    const moved = (node.scrollLeft - from) / width;
    const start = Math.round(from / width);
    const step = Math.abs(moved) > FLICK ? Math.sign(moved) : 0;
    goTo(Math.min(REVIEWS.length - 1, Math.max(0, start + step)));
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
        className="slider-rail flex snap-x snap-mandatory overflow-x-auto overscroll-x-contain"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
      >
        {REVIEWS.map((review) => (
          <figure
            key={review}
            className="flex min-h-[188px] w-full shrink-0 snap-center flex-col justify-center rounded-group bg-surface-muted px-6 py-7 text-center select-none sm:px-10"
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
