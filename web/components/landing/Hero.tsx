import { RawPage } from "@/components/demo/RawPage";

import { StartButton } from "./StartButton";

/**
 * L'accroche : **une phrase, et le produit tout de suite.**
 *
 * Une phrase, pas un titre suivi d'un paragraphe de sous-titre qui répète le titre. Et pas de
 * grand nombre avec sa petite étiquette, pas de dégradé, pas de bandeau sombre : c'est la réponse
 * que tout le monde donne, donc ce n'est pas une réponse.
 *
 * **Le bouton mène au parcours**, pas à une liste d'attente. La landing montre ; « Commencer »
 * ouvre le premier écran, et les suivants s'enchaînent un par un. La liste d'attente reste au
 * prix, pour ceux qui veulent être prévenus sans s'engager.
 */
export function Hero() {
  return (
    <section className="mx-auto max-w-page px-screen pt-12 sm:pt-16">
      <div className="grid items-center gap-14 lg:grid-cols-[1.05fr_0.95fr]">
        <div>
          <h1 className="text-[40px] font-bold leading-[1.08] tracking-display text-ink sm:text-[54px]">
            Ton cours devient une fiche. Puis des cartes. Puis ça reste.
          </h1>

          <p className="mt-6 max-w-[46ch] text-[17px] leading-relaxed text-ink-secondary">
            Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la
            fiche que tu relis, en tire les cartes qui te la font retenir, et les fait revenir
            juste avant que tu l&apos;oublies.
          </p>

          <div className="mt-9">
            <StartButton />
          </div>

          <p className="mt-7 flex flex-wrap items-center gap-x-5 gap-y-2 text-[13px] text-ink-tertiary">
            <span>PDF, photo, Word, YouTube</span>
            <span aria-hidden>·</span>
            <span>Répétition espacée</span>
            <span aria-hidden>·</span>
            <span>Mode examen</span>
          </p>
        </div>

        {/* Le point de départ, posé tout de suite. Le visiteur voit ce qu'il dépose avant de lire
            un argument, et la section suivante le transforme sous ses yeux — dans le même
            rectangle. */}
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
