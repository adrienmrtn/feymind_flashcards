import type { Metadata } from "next";
import Link from "next/link";

import { entitlement, pricing } from "@micabo/core";

import { ArticleNote, ArticleSection, ArticleShell } from "@/components/pages/ArticleShell";
import { ANKI_PAGE, EXAM_PAGE, METHOD_PAGE } from "@/lib/site-pages";

export const metadata: Metadata = {
  title: ANKI_PAGE.title,
  description: ANKI_PAGE.description,
  alternates: { canonical: ANKI_PAGE.path },
  openGraph: {
    type: "article",
    url: ANKI_PAGE.path,
    title: ANKI_PAGE.title,
    description: ANKI_PAGE.description,
  },
};

/**
 * **La comparaison avec Anki, écrite honnêtement.**
 *
 * Une page de comparaison qui gagne sur toutes les lignes ne se croit pas, et elle ne
 * convertit pas : le lecteur connaît Anki mieux que nous, il sait ce qu&apos;il y trouve, et une
 * ligne fausse discrédite les vraies. Trois lignes vont donc à Anki, dont la plus importante —
 * il est gratuit.
 *
 * Ce n'est pas de la modestie : Micabo partage l'algorithme d'Anki. Prétendre le contraire
 * serait facilement démenti par n'importe qui compare deux intervalles.
 */

interface Row {
  criterion: string;
  micabo: React.ReactNode;
  anki: React.ReactNode;
  /** Qui l'emporte sur cette ligne. `null` : c'est la même chose. */
  edge: "micabo" | "anki" | null;
}

export default function AnkiComparisonPage() {
  const rows: Row[] = [
    {
      criterion: "L'algorithme",
      micabo: "SM-2, avec les réglages par défaut d'Anki.",
      anki: "SM-2 historiquement, FSRS aujourd'hui, et les deux se règlent.",
      edge: "anki",
    },
    {
      criterion: "Écrire les cartes",
      micabo:
        "Le cours devient une fiche, la fiche devient des cartes. Tu relis et tu corriges.",
      anki: "À toi. C'est là que passe l'essentiel du temps.",
      edge: "micabo",
    },
    {
      criterion: "Une date d'examen",
      micabo: "Le paquet se replanifie autour du jour J, et rien ne repart au-delà.",
      anki: "Pas de notion de date butoir. On avance le paquet à la main.",
      edge: "micabo",
    },
    {
      criterion: "Le prix",
      micabo: `Un cours gratuit, ${entitlement.FREE_TIER.cardsPerSession} cartes par session. Au-delà, ${pricing.YEARLY.price.toFixed(2).replace(".", ",")} € par an.`,
      anki: "Gratuit et open source, sauf l'app iPhone.",
      edge: "anki",
    },
    {
      criterion: "Les plateformes",
      micabo: "iPhone et navigateur, le même compte des deux côtés.",
      anki: "Ordinateur, Android, iPhone, navigateur.",
      edge: "anki",
    },
    {
      criterion: "Les paquets tout faits",
      micabo: "Aucun catalogue. Tes cours, et ceux que tes amis partagent.",
      anki: "Des milliers de paquets publics, de qualité inégale.",
      edge: "anki",
    },
    {
      criterion: "Les cours de tes camarades",
      micabo: "Un cours partagé se reprend en un geste, et devient le tien.",
      anki: "Un fichier à s'envoyer.",
      edge: "micabo",
    },
    {
      criterion: "La mise en route",
      micabo: "Un document déposé, une fiche à lire, une session le soir même.",
      anki: "Des réglages à comprendre avant la première carte.",
      edge: "micabo",
    },
  ];

  return (
    <ArticleShell
      page={ANKI_PAGE}
      eyebrow="Comparaison"
      title="Micabo ou Anki : ce qui change vraiment"
      lead={
        <>
          <p>
            Anki est un très bon logiciel. Il est gratuit, ouvert, il a vingt ans de recul et une
            communauté qui a tout documenté. Si tu t&apos;en sers déjà et que ça te va, tu
            n&apos;as aucune raison d&apos;en changer.
          </p>
          <p>
            La différence n&apos;est pas dans la planification —{" "}
            <strong className="font-semibold text-ink">c&apos;est le même SM-2</strong>. Elle est
            avant, dans le temps qu&apos;il faut pour avoir des cartes, et après, dans ce qui
            arrive quand une date d&apos;examen tombe.
          </p>
        </>
      }
    >
      <ArticleSection id="tableau" title="Ligne par ligne" wide>
        <p className="max-w-reading">
          Trois lignes vont à Anki, dont la plus importante pour beaucoup de gens : il ne coûte
          rien.
        </p>

        <ComparisonTable rows={rows} />
      </ArticleSection>

      <ArticleSection id="le-vrai-cout" title="Le coût d'Anki n'est pas son prix">
        <p>
          Un paquet Anki utile pour un cours de fac, c&apos;est deux à quatre heures de saisie
          par chapitre : découper, formuler une question par idée, ne pas empiler cinq éléments
          sur une carte. Ce travail est instructif — le nier serait malhonnête — mais c&apos;est
          le travail qui fait qu&apos;on ouvre Anki en septembre et plus en novembre.
        </p>
        <p>
          Micabo prend cette étape. Le cours devient une fiche remise dans l&apos;ordre, puis des
          cartes tirées de cette fiche. Tu relis, tu corriges ce qui est faux, tu supprimes ce qui
          ne sert pas. Ça reste ton travail, mais il commence à la relecture au lieu de commencer
          à la page blanche.
        </p>
        <ArticleNote>
          Le revers est réel : une carte générée peut être mal formulée ou tirée d&apos;un scan
          mal lu. C&apos;est pour ça que la fiche vient avant les cartes, et que Micabo ne définit
          pas un terme dont le document ne parle pas. Une fiche qui se trompe ne ressemble pas à
          une erreur.
        </ArticleNote>
      </ArticleSection>

      <ArticleSection id="la-date" title="Ce qu'Anki ne fait pas : la date">
        <p>
          C&apos;est la vraie différence de mécanique. La répétition espacée place chaque carte au
          dernier moment utile, sans fin. Elle ne sait pas qu&apos;il y a un partiel le 14 : une
          carte notée «&nbsp;facile&nbsp;» repart à trois semaines et ne revient pas avant
          l&apos;épreuve.
        </p>
        <p>
          Dans Anki, on s&apos;en sort en avançant le paquet à la main, ou en révisant tout la
          veille. Dans Micabo, tu poses la date et le paquet se replanifie autour, avec un plafond
          qui empêche une carte de repartir au-delà du jour J.{" "}
          <Link href={EXAM_PAGE.path} className="underline-draw font-medium text-ink">
            Le mode examen
          </Link>{" "}
          détaille comment.
        </p>
      </ArticleSection>

      <ArticleSection id="choisir" title="Lequel prendre">
        <p>
          <strong className="font-semibold text-ink">Reste sur Anki</strong> si tu aimes régler ton
          planificateur, si tu veux FSRS, si tu es sur Android, ou si tu tiens à un outil gratuit
          et ouvert dont tu possèdes les fichiers.
        </p>
        <p>
          <strong className="font-semibold text-ink">Essaie Micabo</strong> si ce qui te bloque
          n&apos;est pas la révision mais la fabrication des cartes, ou si tes révisions sont
          organisées autour de dates d&apos;examen plutôt que d&apos;un flux continu.
        </p>
        <p>
          Et si tu hésites :{" "}
          <Link href={METHOD_PAGE.path} className="underline-draw font-medium text-ink">
            la méthode
          </Link>{" "}
          est la même dans les deux. C&apos;est elle qui fait le travail, pas le logiciel qui la
          porte.
        </p>
      </ArticleSection>
    </ArticleShell>
  );
}

/**
 * Le tableau, et un vrai `<table>`.
 *
 * Une grille de `div` se lit à l'œil et pas au lecteur d'écran : sans en-têtes de colonne, une
 * cellule est une phrase sans sujet. Sur mobile, chaque critère devient une carte empilée —
 * trois colonnes sur 360 px donneraient neuf caractères par ligne.
 */
function ComparisonTable({ rows }: { rows: Row[] }) {
  return (
    <>
      <div className="not-prose mt-8 hidden overflow-hidden rounded-group border border-stroke sm:block">
        <table className="w-full border-collapse text-left text-[14.5px]">
          <caption className="sr-only">
            Comparaison de Micabo et d&apos;Anki, critère par critère.
          </caption>
          <thead>
            <tr className="bg-surface-muted">
              <th scope="col" className="w-[22%] px-5 py-3.5 text-[12.5px] font-semibold text-ink">
                Critère
              </th>
              <th scope="col" className="px-5 py-3.5 text-[12.5px] font-semibold text-ink">
                Micabo
              </th>
              <th scope="col" className="px-5 py-3.5 text-[12.5px] font-semibold text-ink">
                Anki
              </th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.criterion} className="border-t border-hairline">
                <th
                  scope="row"
                  className="px-5 py-4 align-top text-[14px] font-medium text-ink"
                >
                  {row.criterion}
                </th>
                <Cell text={row.micabo} leading={row.edge === "micabo"} />
                <Cell text={row.anki} leading={row.edge === "anki"} />
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <ul className="not-prose mt-8 space-y-3 sm:hidden">
        {rows.map((row) => (
          <li key={row.criterion} className="rounded-group border border-stroke bg-surface p-5">
            <p className="text-[13px] font-semibold text-ink">{row.criterion}</p>
            <dl className="mt-3 space-y-2.5 text-[14px]">
              <div>
                <dt className="text-[12px] font-medium text-ink-tertiary">Micabo</dt>
                <dd className={row.edge === "micabo" ? "text-ink" : "text-ink-secondary"}>
                  {row.micabo}
                </dd>
              </div>
              <div>
                <dt className="text-[12px] font-medium text-ink-tertiary">Anki</dt>
                <dd className={row.edge === "anki" ? "text-ink" : "text-ink-secondary"}>
                  {row.anki}
                </dd>
              </div>
            </dl>
          </li>
        ))}
      </ul>
    </>
  );
}

/** La colonne qui l'emporte porte l'encre pleine. Pas de coche : rien ici n'est binaire. */
function Cell({ text, leading }: { text: React.ReactNode; leading: boolean }) {
  return (
    <td
      className={`px-5 py-4 align-top leading-relaxed ${
        leading ? "font-medium text-ink" : "text-ink-secondary"
      }`}
    >
      {text}
    </td>
  );
}
