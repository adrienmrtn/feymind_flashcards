import type { Metadata } from "next";
import Link from "next/link";

import {
  CARDS_PER_MINUTE,
  DEFAULT_CONFIG,
  DEFAULT_DAILY_MINUTES,
  REPETITIONS_PER_CARD,
  REVIEW_RATINGS,
  REVIEW_RATING_LABELS,
  newCardSnapshot,
  newCardsPerDay,
  previewLabels,
} from "@micabo/core";

import { RetentionChart } from "@/components/landing/RetentionChart";
import { ArticleNote, ArticleSection, ArticleShell } from "@/components/pages/ArticleShell";
import { EXAM_PAGE, METHOD_PAGE } from "@/lib/site-pages";

export const metadata: Metadata = {
  title: METHOD_PAGE.title,
  description: METHOD_PAGE.description,
  alternates: { canonical: METHOD_PAGE.path },
  openGraph: {
    type: "article",
    url: METHOD_PAGE.path,
    title: METHOD_PAGE.title,
    description: METHOD_PAGE.description,
  },
};

/**
 * **La page de la méthode.**
 *
 * La vitrine en montre la courbe et passe à la suite. Ici on dit pourquoi la courbe a cette
 * forme, et surtout ce que le produit en fait : les paliers, les quatre boutons, le rythme
 * quotidien. Tous les nombres affichés sont **lus dans `@micabo/core`** au moment du rendu —
 * les mêmes valeurs que l'iPhone. Une page qui recopierait « 1 minute, 10 minutes » à la main
 * mentirait le jour où le planificateur change, et personne ne penserait à la relire.
 */
export default function MethodPage() {
  const steps = DEFAULT_CONFIG.learningStepsMinutes;
  const perDay = newCardsPerDay(DEFAULT_DAILY_MINUTES);
  const seenPerDay = Math.round(DEFAULT_DAILY_MINUTES * CARDS_PER_MINUTE);

  return (
    <ArticleShell
      page={METHOD_PAGE}
      eyebrow="La méthode"
      title="Relire ne suffit pas. Se souvenir, oui."
      lead={
        <>
          <p>
            Une page relue quatre fois donne une impression de maîtrise qui ne survit pas à la
            copie double. C&apos;est la reconnaissance qui progresse — «&nbsp;oui, j&apos;ai déjà
            vu ça&nbsp;» — et la reconnaissance n&apos;est pas ce qu&apos;un examen demande.
          </p>
          <p>
            Ce qui tient, c&apos;est ce qu&apos;on a dû{" "}
            <strong className="font-semibold text-ink">retrouver de mémoire</strong>, et ce qui
            revient <strong className="font-semibold text-ink">juste avant qu&apos;on l&apos;oublie</strong>
            . Deux idées anciennes, mesurées depuis plus d&apos;un siècle, et deux idées
            pénibles à appliquer à la main. C&apos;est tout le travail de Micabo.
          </p>
        </>
      }
    >
      <ArticleSection id="rappel-actif" title="Le rappel actif : la question avant la réponse">
        <p>
          Se tester est plus efficace que relire, même quand on se trompe. L&apos;effort de
          récupération est ce qui renforce la trace : une réponse qu&apos;on cherche pendant
          trois secondes vaut mieux qu&apos;une réponse qu&apos;on lit en une.
        </p>
        <p>
          C&apos;est aussi pour ça qu&apos;une flashcard porte{" "}
          <strong className="font-semibold text-ink">une seule chose à retrouver</strong>. Une
          carte qui demande cinq éléments d&apos;un coup ne se note pas : on en retrouve trois,
          et il n&apos;existe pas de bouton pour «&nbsp;trois cinquièmes&nbsp;».
        </p>
      </ArticleSection>

      <ArticleSection
        id="courbe-oubli"
        title="L'espacement : revenir au dernier moment utile"
        wide
      >
        <p className="max-w-reading">
          Sans révision, ce qu&apos;on retient d&apos;un cours tombe à presque rien en un mois.
          Chaque rappel remet le compteur à cent — et la descente qui suit est{" "}
          <strong className="font-semibold text-ink">plus lente que la précédente</strong>. Réviser
          au bon moment ne demande donc pas plus de temps : ça en demande moins, à mesure que la
          mémoire se stabilise.
        </p>
        <div className="mt-9">
          <RetentionChart />
        </div>
        <p className="mt-6 max-w-reading">
          L&apos;intérêt n&apos;est pas la forme de chaque courbe, c&apos;est{" "}
          <strong className="font-semibold text-ink">l&apos;endroit où elles se séparent</strong> :
          la première révision. Ce que la répétition espacée automatise, c&apos;est le choix de
          cet instant, carte par carte.
        </p>
      </ArticleSection>

      <ArticleSection id="planificateur" title="Ce que Micabo calcule à chaque note">
        <p>
          Micabo planifie en <strong className="font-semibold text-ink">SM-2</strong>, la règle
          d&apos;Anki dans ses réglages par défaut. Une carte neuve passe par des paliers courts
          — {steps.map((minutes) => `${minutes} min`).join(", puis ")} — avant de sortir en
          jours. Ensuite, chaque note multiplie l&apos;intervalle par une facilité propre à la
          carte, qui part de {DEFAULT_CONFIG.startingEase.toFixed(1).replace(".", ",")} et bouge
          selon tes réponses.
        </p>
        <p>
          Quatre boutons, pas deux : «&nbsp;je sais&nbsp;/&nbsp;je ne sais pas&nbsp;» ne
          distingue pas la carte retrouvée avec peine de celle qui est venue seule, et c&apos;est
          justement cet écart qui décide de la date suivante. Voici ce que les quatre boutons
          annoncent sur une carte neuve :
        </p>

        <NewCardIntervals />

        <p>
          L&apos;intervalle est écrit sur le bouton{" "}
          <strong className="font-semibold text-ink">avant</strong> qu&apos;on appuie. Un
          planificateur qui décide dans son coin se fait vite désobéir : on note «&nbsp;facile&nbsp;»
          pour aller plus vite, la carte repart à trois semaines, et on la redécouvre le jour de
          l&apos;épreuve.
        </p>
      </ArticleSection>

      <ArticleSection id="rythme" title="Le rythme : des minutes, pas un quota de cartes">
        <p>
          Le réglage que Micabo demande est un temps par jour, pas un nombre de cartes. À{" "}
          {DEFAULT_DAILY_MINUTES} minutes — le défaut — on voit environ {seenPerDay} cartes,
          et le produit n&apos;en introduit que{" "}
          <strong className="font-semibold text-ink">{perDay} neuves</strong>.
        </p>
        <p>
          L&apos;écart entre les deux est le cœur du réglage : une carte neuve ne coûte pas un
          passage, elle en coûte environ {REPETITIONS_PER_CARD} avant d&apos;être acquise.
          Introduire cinquante cartes aujourd&apos;hui parce qu&apos;on a le temps, c&apos;est se
          poser une dette de sessions pour les trois semaines suivantes — et c&apos;est comme ça
          qu&apos;on abandonne un paquet.
        </p>
        <ArticleNote>
          Le plafond du jour ne bloque pas les révisions dues : celles-là passent toutes. Il ne
          rationne que l&apos;<em>introduction</em> de nouvelles cartes. Une journée manquée ne
          crée donc pas de trou, elle décale.
        </ArticleNote>
      </ArticleSection>

      <ArticleSection id="fiche-avant-cartes" title="La fiche d'abord, les cartes ensuite">
        <p>
          Une flashcard suppose qu&apos;on a déjà compris. Se tester sur une notion qu&apos;on
          n&apos;a pas lue, c&apos;est apprendre une réponse par cœur sans savoir de quoi elle
          parle — la carte tombera juste, et l&apos;examen non.
        </p>
        <p>
          C&apos;est pourquoi Micabo écrit d&apos;abord{" "}
          <strong className="font-semibold text-ink">la fiche</strong> à partir de ton document :
          le cours remis dans l&apos;ordre, les passages qui comptent marqués. Les cartes sont
          tirées de cette fiche, pas du document brut. Tu lis, puis tu te testes.
        </p>
        <p>
          Micabo ne définit jamais un terme dont le document ne parle pas. Quand le contexte ne
          tranche pas, le mot douteux n&apos;apparaît pas dans la fiche : une définition
          inventée est parfaitement crédible, et c&apos;est ce qui la rend dangereuse.
        </p>
      </ArticleSection>

      <ArticleSection id="limites" title="Ce que la méthode ne fait pas">
        <p>
          La répétition espacée place les révisions. Elle ne comprend pas à ta place, elle ne
          rédige pas une dissertation, et elle ne rattrape pas un chapitre commencé la veille —
          il n&apos;y a pas d&apos;espacement possible sur une nuit.
        </p>
        <p>
          Elle ignore aussi les dates, par construction : SM-2 ne sait pas qu&apos;un examen a
          lieu dans trois semaines. C&apos;est exactement ce que le{" "}
          <Link href={EXAM_PAGE.path} className="underline-draw font-medium text-ink">
            mode examen
          </Link>{" "}
          vient corriger.
        </p>
      </ArticleSection>
    </ArticleShell>
  );
}

/**
 * Les quatre intervalles d'une carte neuve, calculés par le planificateur partagé.
 *
 * `DETERMINISTIC_CONFIG` est celle que `previewLabels` prend par défaut : le brouillage
 * aléatoire des intervalles est coupé, sans quoi la page afficherait « 3 j » un jour et
 * « 4 j » le lendemain sans que rien n'ait changé.
 */
function NewCardIntervals() {
  const labels = previewLabels(newCardSnapshot());

  return (
    <dl className="not-prose mt-7 grid grid-cols-2 gap-3 sm:grid-cols-4">
      {REVIEW_RATINGS.map((rating) => (
        <div
          key={rating}
          className="rounded-group border border-stroke bg-surface px-4 py-3.5 text-center"
        >
          <dt className="text-[13px] font-medium text-ink-secondary">
            {REVIEW_RATING_LABELS[rating]}
          </dt>
          <dd className="numeral mt-1 text-[19px] font-bold text-ink">{labels[rating]}</dd>
        </div>
      ))}
    </dl>
  );
}
