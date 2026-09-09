"use client";

import { useEffect, useState } from "react";

import { useI18n } from "@/lib/i18n/client";

/**
 * **Les avis, un à la fois.**
 *
 * Trois cartes côte à côte se lisent en diagonale et ne se lisent donc pas. Une seule, assez
 * grande pour qu'on la lise vraiment, et qui passe à la suivante toute seule : l'écran ne
 * demande rien à ce moment du parcours, il donne une raison de continuer. Les pastilles
 * dessous disent combien il y en a et laissent revenir sur celle qu'on a ratée.
 *
 * Le défilement s'arrête dès que la souris entre ou que le clavier attrape une pastille -
 * lire une phrase qui s'échappe au milieu est la seule façon de rendre un avis agaçant - et
 * il ne démarre pas du tout pour qui a demandé moins d'animations à son système.
 */

const REVIEWS = ["review1", "review2", "review3", "review4"] as const;

const INTERVAL_MS = 5_200;

export function ReviewCarousel() {
  const { t } = useI18n();
  const [index, setIndex] = useState(0);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    if (paused) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const id = window.setInterval(() => {
      setIndex((current) => (current + 1) % REVIEWS.length);
    }, INTERVAL_MS);
    return () => window.clearInterval(id);
  }, [paused]);

  const key = REVIEWS[index]!;

  return (
    <div
      aria-roledescription="carousel"
      aria-label={t("onboarding.reviewsAria")}
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocusCapture={() => setPaused(true)}
      onBlurCapture={() => setPaused(false)}
    >
      {/* La hauteur est réservée : sans elle, une citation plus courte que la précédente fait
          remonter les pastilles au moment où le doigt s'en approche. */}
      <figure
        key={key}
        className="rise flex min-h-[196px] flex-col justify-center rounded-group bg-surface-muted px-6 py-7 text-center sm:px-10"
        aria-live="polite"
      >
        <span className="mx-auto inline-flex items-center rounded-pill bg-accent-soft px-3 py-1 text-[12.5px] font-semibold text-accent">
          {t(`onboarding.${key}Gain`)}
        </span>
        <blockquote className="mt-4 text-balance text-[17px] leading-relaxed text-ink sm:text-[18px]">
          {t(`onboarding.${key}Text`)}
        </blockquote>
        <figcaption className="mt-4 text-[13px] text-ink-tertiary">
          {t(`onboarding.${key}Name`)} · {t(`onboarding.${key}Detail`)}
        </figcaption>
      </figure>

      <div className="mt-5 flex justify-center gap-2">
        {REVIEWS.map((review, position) => (
          <button
            key={review}
            type="button"
            onClick={() => setIndex(position)}
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
