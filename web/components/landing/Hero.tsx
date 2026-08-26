import { RawPage } from "@/components/demo/RawPage";
import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { DEMO_COURSE, TRANSFORMATION_SHEET } from "@/components/demo/demo-course";

import { StartButton } from "./StartButton";

/**
 * L'accroche : une phrase, et la transformation posée à côté d'elle.
 *
 * Les deux états — le polycopié brut, la fiche — sont **côte à côte et entiers**. La version
 * précédente les empilait dans un rectangle piloté au défilement, et ce rectangle se coupait au
 * milieu de l'écran : une fiche tronquée ne montre pas une transformation, elle montre un bug.
 */
export function Hero() {
  return (
    <section className="relative overflow-hidden">
      {/* Une seule lueur verte, très basse en opacité : elle donne de la profondeur au papier
          sans devenir le dégradé de bandeau que tout le monde pose. */}
      <div
        aria-hidden
        className="pointer-events-none absolute -top-40 left-1/2 h-[520px] w-[900px] -translate-x-1/2 rounded-full opacity-[0.18] blur-3xl"
        style={{ background: "radial-gradient(circle, var(--color-accent-vivid), transparent 65%)" }}
      />

      <div className="relative mx-auto max-w-page px-screen pt-16 text-center sm:pt-24">
        <p className="rise inline-flex items-center gap-2 rounded-pill bg-surface px-3.5 py-1.5 text-[12.5px] font-medium text-ink-secondary paper">
          <span className="h-1.5 w-1.5 rounded-full bg-accent-vivid" />
          Fiches et flashcards, à partir de tes cours
        </p>

        <h1
          className="rise mx-auto mt-7 max-w-[19ch] text-[44px] font-bold leading-[1.03] tracking-display text-ink sm:text-[76px]"
          style={{ animationDelay: "60ms" }}
        >
          Apprends tout,{" "}
          <span className="relative whitespace-nowrap text-accent">
            plus vite
            <svg
              aria-hidden
              viewBox="0 0 200 12"
              preserveAspectRatio="none"
              className="absolute -bottom-1.5 left-0 h-2.5 w-full text-accent-vivid"
            >
              <path
                d="M2 8c40-5 90-7 196-4"
                fill="none"
                stroke="currentColor"
                strokeWidth="4"
                strokeLinecap="round"
              />
            </svg>
          </span>
          .
        </h1>

        <p
          className="rise mx-auto mt-7 max-w-[52ch] text-[17px] leading-relaxed text-ink-secondary sm:text-[19px]"
          style={{ animationDelay: "120ms" }}
        >
          Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la
          fiche, en tire les cartes, et les fait revenir juste avant que tu oublies.
        </p>

        <div
          className="rise mt-9 flex flex-col items-center gap-3"
          style={{ animationDelay: "180ms" }}
        >
          <StartButton />
          <p className="text-[13px] text-ink-tertiary">Un cours gratuit. Sans carte bancaire.</p>
        </div>
      </div>

      {/* La transformation, en entier et sans défilement piloté : à gauche ce qu'on dépose, à
          droite ce qu'on relit. Deux objets complets valent mieux qu'un seul qu'on rogne. */}
      <div className="relative mx-auto mt-16 max-w-page px-screen">
        <div className="grid items-center gap-4 sm:grid-cols-[1fr_auto_1fr] sm:gap-6">
          <div className="mx-auto w-full max-w-[340px]">
            <p className="eyebrow mb-3 text-center text-ink-tertiary">Ton cours</p>
            <RawPage className="rotate-[-1.2deg]" />
          </div>

          <div className="mx-auto flex h-11 w-11 items-center justify-center rounded-full bg-ink text-on-ink">
            <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5 sm:hidden">
              <path
                d="M10 4v12M5 11l5 5 5-5"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <svg aria-hidden viewBox="0 0 20 20" className="hidden h-5 w-5 sm:block">
              <path
                d="M4 10h12M11 5l5 5-5 5"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </div>

          <div className="mx-auto w-full max-w-[340px]">
            <p className="eyebrow mb-3 text-center text-accent">Ta fiche</p>
            <div className="float paper max-h-[420px] overflow-hidden rounded-group bg-surface p-5">
              <SheetBlocks blocks={TRANSFORMATION_SHEET} tint={DEMO_COURSE.accent} />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
