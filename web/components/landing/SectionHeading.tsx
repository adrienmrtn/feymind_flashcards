"use client";

import type { Route } from "next";
import Link from "next/link";

import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";

/**
 * **L'en-tête d'une section de la vitrine** : une pastille, un titre, une phrase, et parfois
 * le lien vers la page qui développe le sujet.
 *
 * Ces liens ne sont pas décoratifs : une page que rien ne cite depuis l'accueil est une page
 * que Google explore en dernier. Les trois éléments montent l'un après l'autre.
 */
export function SectionHeading({
  eyebrow,
  title,
  note,
  more,
  align = "center",
}: {
  eyebrow: string;
  title: string;
  note?: string;
  more?: { href: Route; label: string };
  align?: "center" | "left";
}) {
  const { t } = useI18n();
  const centered = align === "center";
  return (
    <div className={centered ? "mx-auto max-w-[44rem] text-center" : "max-w-[34rem]"}>
      <Reveal>
        <p className="inline-flex items-center rounded-pill bg-accent-soft px-3 py-1 text-[12.5px] font-extrabold text-accent">
          {t(eyebrow)}
        </p>
      </Reveal>
      <Reveal delay={1}>
        <h2 className="mt-4 text-balance text-[32px] font-extrabold leading-[1.06] tracking-display text-ink sm:text-[44px]">
          {t(title)}
        </h2>
      </Reveal>
      {note ? (
        <Reveal delay={2}>
          <p className={`mt-4 text-[16.5px] leading-relaxed text-ink-secondary sm:text-[17.5px] ${centered ? "mx-auto max-w-[56ch]" : "max-w-[52ch]"}`}>
            {t(note)}
          </p>
        </Reveal>
      ) : null}
      {more ? (
        <Reveal delay={3}>
          <p className="mt-4">
            <Link href={more.href} className="underline-draw text-[14.5px] font-bold text-ink">
              {t(more.label)}
            </Link>
          </p>
        </Reveal>
      ) : null}
    </div>
  );
}
