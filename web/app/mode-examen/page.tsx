import type { Metadata } from "next";
import Link from "next/link";

import { BASE_PASSES, CLOSING_DAYS, EXAM_INTENSITIES, EXAM_INTENSITY_LABELS } from "@micabo/core";

import { ExamMode } from "@/components/landing/ExamMode";
import { ArticleNote, ArticleSection, ArticleShell } from "@/components/pages/ArticleShell";
import { ANKI_PAGE, EXAM_PAGE, METHOD_PAGE } from "@/lib/site-pages";

export const metadata: Metadata = {
  title: EXAM_PAGE.title,
  description: EXAM_PAGE.description,
  alternates: { canonical: EXAM_PAGE.path },
  openGraph: {
    type: "article",
    url: EXAM_PAGE.path,
    title: EXAM_PAGE.title,
    description: EXAM_PAGE.description,
  },
};

/**
 * **La page du mode examen.**
 *
 * C'est la fonctionnalité qui n'existe pas ailleurs, et la seule dont l'argument tient en une
 * phrase : la répétition espacée ne connaît pas les dates. Le reste de la page explique ce
 * qu'on fait de cette phrase.
 *
 * L'histogramme est celui de la vitrine, et il est **calculé par `planExam`** — le port du
 * planificateur de l'app. Ce que la page montre est donc ce que le produit fera.
 */
export default function ExamModePage() {
  return (
    <ArticleShell
      page={EXAM_PAGE}
      eyebrow="Mode examen"
      title="Tu donnes la date. Micabo réorganise tout."
      lead={
        <>
          <p>
            La répétition espacée place chaque carte au dernier moment utile, indéfiniment. Elle
            ne sait pas qu&apos;il y a un partiel le 14. Une carte notée «&nbsp;facile&nbsp;»
            aujourd&apos;hui repart à trois semaines, même si l&apos;épreuve est dans dix jours —
            et elle ne reviendra pas avant.
          </p>
          <p>
            Le mode examen donne au planificateur ce qui lui manque :{" "}
            <strong className="font-semibold text-ink">une date butoir</strong>. Tu poses le jour
            J, il replanifie le paquet autour.
          </p>
        </>
      }
    >
      <ArticleSection id="le-probleme" title="Pourquoi un planning normal se fait piéger">
        <p>
          Un paquet de deux cents cartes en révision espacée est parfait pour un contrôle continu
          et mauvais pour une date fixe. Trois choses vont de travers : des cartes tombent{" "}
          <em>après</em> l&apos;examen, d&apos;autres n&apos;ont jamais été introduites, et les
          plus fragiles reviennent trop tôt pour être utiles le jour J.
        </p>
        <p>
          La réponse manuelle consiste à réviser tout le paquet la veille. C&apos;est exactement
          ce que la méthode évite : une session de trois cents cartes en une soirée ne laisse
          rien le lendemain, et on le sait avant de commencer.
        </p>
      </ArticleSection>

      <ArticleSection id="le-plafond" title="Aucune carte ne repart au-delà du jour J">
        <p>
          C&apos;est la règle qui fait tout tenir, et elle est plus radicale qu&apos;elle en a
          l&apos;air. Pendant un examen actif, l&apos;intervalle qu&apos;une carte reçoit est{" "}
          <strong className="font-semibold text-ink">plafonné à la date de l&apos;épreuve</strong>.
        </p>
        <p>
          Sans ce plafond, la première bonne réponse défait le plan : la carte s&apos;en va à
          trois semaines et sort du champ. Avec lui, elle revient une dernière fois avant le jour
          J. Les intervalles annoncés sous les boutons sont donc plus courts que d&apos;habitude,
          et la session le dit en haut de l&apos;écran — sinon on croirait le planificateur cassé.
        </p>
      </ArticleSection>

      <ArticleSection id="ce-que-ca-donne" title="Le plan, annoncé avant d'être appliqué" wide>
        <p className="max-w-reading">
          Micabo montre la projection <strong className="font-semibold text-ink">avant</strong> de
          déplacer quoi que ce soit : combien de cartes sont couvertes, combien de passages sont
          placés, sur combien de jours. Une replanification qu&apos;on découvre après coup est
          une replanification qu&apos;on annule.
        </p>
        <div className="mt-9">
          <ExamMode />
        </div>
        <p className="mt-6 max-w-reading">
          La charge se resserre vers la fin sans s&apos;empiler sur la veille : les derniers
          passages s&apos;étalent sur les {CLOSING_DAYS} derniers jours, décalés d&apos;une carte
          à l&apos;autre.
        </p>
      </ArticleSection>

      <ArticleSection id="intensite" title="Trois intensités, selon la note que tu veux">
        <p>
          Combien de fois chaque carte doit repasser avant l&apos;épreuve n&apos;est pas la même
          question pour «&nbsp;je veux valider&nbsp;» et pour «&nbsp;je veux le major&nbsp;». Tu
          poses la note visée, Micabo en déduit l&apos;intensité :
        </p>

        <dl className="not-prose mt-7 grid gap-3 sm:grid-cols-3">
          {EXAM_INTENSITIES.map((intensity) => (
            <div
              key={intensity}
              className="rounded-group border border-stroke bg-surface px-4 py-4"
            >
              <dt className="text-[13px] font-medium text-ink-secondary">
                {EXAM_INTENSITY_LABELS[intensity]}
              </dt>
              <dd className="mt-1">
                <span className="numeral text-[22px] font-bold text-ink">
                  {BASE_PASSES[intensity]}
                </span>
                <span className="ms-1.5 text-[13px] text-ink-tertiary">
                  passages par carte
                </span>
              </dd>
            </div>
          ))}
        </dl>

        <p className="mt-7">
          L&apos;échelle de notes suit ton pays de scolarisation : un 20 français, un 100
          québécois et un A-Level britannique ne se comparent pas, et un curseur qui vaudrait
          partout ne voudrait rien dire nulle part.
        </p>
      </ArticleSection>

      <ArticleSection id="plusieurs-examens" title="Plusieurs examens, plusieurs cours">
        <p>
          Un examen porte sur les cours que tu lui donnes, et un cours peut être dans plusieurs
          examens. Quand deux dates se disputent une même carte, c&apos;est{" "}
          <strong className="font-semibold text-ink">la plus proche</strong> qui plafonne : elle
          est la première contrainte, et respecter la seconde d&apos;abord raterait les deux.
        </p>
        <ArticleNote>
          Passé le jour J, l&apos;examen cesse de contraindre et le paquet revient à sa
          planification normale. Rien à désactiver : une date passée n&apos;est plus une date.
        </ArticleNote>
      </ArticleSection>

      <ArticleSection id="limites" title="Ce que le mode examen ne fait pas">
        <p>
          Il ne fabrique pas du temps. Déclarer un examen pour demain sur deux cents cartes
          neuves donne un plan honnête et intenable, et Micabo l&apos;affiche tel quel plutôt que
          de rassurer.
        </p>
        <p>
          Il ne remplace pas non plus la méthode :{" "}
          <Link href={METHOD_PAGE.path} className="underline-draw font-medium text-ink">
            le rappel actif et l&apos;espacement
          </Link>{" "}
          font le travail, le mode examen ne fait que leur donner une échéance. Si tu viens
          d&apos;Anki, la{" "}
          <Link href={ANKI_PAGE.path} className="underline-draw font-medium text-ink">
            comparaison
          </Link>{" "}
          dit précisément ce que ça change.
        </p>
      </ArticleSection>
    </ArticleShell>
  );
}
