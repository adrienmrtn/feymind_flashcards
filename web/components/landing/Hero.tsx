import { RawPage } from "@/components/demo/RawPage";
import { WaitlistForm } from "./WaitlistForm";

/**
 * L'accroche : **une phrase, et le produit tout de suite.**
 *
 * Une phrase, pas un titre suivi d'un paragraphe de sous-titre qui répète le titre. Et pas de
 * grand nombre avec sa petite étiquette, pas de dégradé, pas de bandeau sombre : c'est la réponse
 * que tout le monde donne, donc ce n'est pas une réponse.
 *
 * **Ce qui manque ici, et pourquoi.** Le plan prévoyait une zone de dépôt à la place du bouton :
 * on pose un PDF, la fiche s'écrit, et c'est le meilleur appel à l'action possible. Elle n'y est
 * pas, parce qu'elle ne peut pas encore mener quelque part — la génération demande le passage des
 * Edge Functions au jeton de l'utilisateur et le plafond d'usage, qui sont à l'étape 4. Une zone
 * de dépôt qui accepte un document et ne le lit pas serait précisément le genre de faux appel à
 * l'action que ce site s'interdit. Elle arrivera avec le parcours d'accueil, qui est ce qu'il y a
 * derrière.
 *
 * En attendant, l'appel à l'action est une liste d'attente, et elle **fonctionne pour de vrai**.
 */
export function Hero() {
  return (
    <section className="mx-auto max-w-page px-screen pt-20 sm:pt-28">
      <div className="grid items-center gap-14 lg:grid-cols-[1.05fr_0.95fr]">
        <div>
          <p className="eyebrow text-ink-tertiary">Micabo</p>

          <h1 className="mt-4 text-[40px] font-bold leading-[1.08] text-ink sm:text-[54px]">
            Ton cours devient une fiche. Puis des cartes. Puis ça reste.
          </h1>

          <p className="mt-6 max-w-[46ch] text-[17px] leading-relaxed text-ink-secondary">
            Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la
            fiche que tu relis, en tire les cartes qui te la font retenir, et les fait revenir
            juste avant que tu l&apos;oublies.
          </p>

          <div className="mt-9 max-w-[440px]">
            <WaitlistForm source="hero" />
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
