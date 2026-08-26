import { RawPage } from "@/components/demo/RawPage";

import { StartButton } from "./StartButton";

/**
 * L'accroche : une phrase, le produit, et le bouton qui ouvre le parcours.
 * La landing montre. « Commencer » n'explique plus rien : il ouvre le premier écran.
 */
export function Hero() {
  return (
    <section className="mx-auto max-w-page px-screen pt-14 sm:pt-20">
      <div className="grid items-center gap-12 lg:grid-cols-[1.05fr_0.95fr] lg:gap-16">
        <div>
          <p className="eyebrow text-accent">Flashcards qui restent</p>
          <h1 className="mt-3 text-[40px] font-bold leading-[1.06] tracking-display text-ink sm:text-[56px]">
            Ton cours devient une fiche. Puis des cartes. Puis ça reste.
          </h1>

          <p className="mt-6 max-w-[44ch] text-[17px] leading-relaxed text-ink-secondary">
            Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo
            écrit la fiche, en tire les cartes, et les fait revenir juste avant que
            tu oublies.
          </p>

          <div className="mt-9 flex flex-wrap items-center gap-4">
            <StartButton />
            <p className="text-[13.5px] text-ink-tertiary">Gratuit pour un cours.</p>
          </div>
        </div>

        <div className="relative mx-auto w-full max-w-[400px]">
          <RawPage className="rotate-[-1.2deg]" />
          <p className="mt-5 text-center text-[13px] text-ink-tertiary">
            Un chapitre de SVT, tel qu&apos;on le reçoit.
          </p>
        </div>
      </div>
    </section>
  );
}
