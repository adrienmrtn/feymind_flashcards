"use client";

import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";
import { SourceBadge, type SourceKind } from "./SourceBadge";

/**
 * **La bande sous le héros**, là où d'autres alignent des logos d'universités.
 *
 * On n'a pas de clients à afficher, et un mur de logos qu'on n'a pas se repère en une
 * seconde. Ce qu'on a, c'est la liste de ce que Mika sait lire : c'est la vraie question
 * qu'on se pose à cet endroit de la page.
 */
const FORMATS: { kind: SourceKind; key: string }[] = [
  { kind: "pdf", key: "landing.formatPdf" },
  { kind: "word", key: "landing.formatWord" },
  { kind: "photo", key: "landing.formatPhoto" },
  { kind: "youtube", key: "landing.formatYoutube" },
  { kind: "audio", key: "landing.formatAudio" },
  { kind: "text", key: "landing.formatText" },
];

export function FormatStrip() {
  const { t } = useI18n();
  return (
    <section aria-labelledby="formats" className="mx-auto mt-14 max-w-page px-screen sm:mt-16">
      <Reveal>
        <p id="formats" className="text-center text-[13.5px] font-bold text-ink-tertiary">
          {t("landing.formatsTitle")}
        </p>
      </Reveal>
      <ul className="mx-auto mt-5 flex max-w-[52rem] flex-wrap items-center justify-center gap-2.5 sm:gap-3">
        {FORMATS.map((format, index) => (
          <Reveal as="li" key={format.kind} delay={index}>
            <span className="inline-flex items-center gap-2.5 rounded-pill bg-surface/80 py-1.5 ps-1.5 pe-4 text-[14.5px] font-bold text-ink shadow-paper">
              <SourceBadge kind={format.kind} size={30} />
              {t(format.key)}
            </span>
          </Reveal>
        ))}
      </ul>
    </section>
  );
}
