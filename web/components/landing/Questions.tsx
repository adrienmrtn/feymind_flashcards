import { entitlement, pricing } from "@micabo/core";

/**
 * Les questions, et de vraies questions.
 *
 * Six, pas quinze. Une foire aux questions qui répond à des questions que personne ne pose est un
 * bloc de texte pour le référencement, et ça se lit. Celles-ci sont celles qu'on se pose
 * réellement devant un outil qui lit ses cours : est-ce que c'est privé, est-ce que ça marche
 * dans ma langue, est-ce que ça invente.
 *
 * Le `<details>` du système plutôt qu'un accordéon fait main : il est accessible au clavier, il
 * se cherche avec la fonction de recherche du navigateur, et il fonctionne sans JavaScript.
 */

const QUESTIONS: { question: string; answer: React.ReactNode }[] = [
  {
    question: "Est-ce que mes cours sont privés ?",
    answer: (
      <>
        Oui, et par construction : le cloisonnement est dans la base, pas dans l&apos;application.
        Chaque requête est évaluée avec ton identité lue dans ton jeton, donc il n&apos;existe pas
        de requête qui puisse demander les cours de quelqu&apos;un d&apos;autre. Tu peux choisir de
        partager un cours - camarades de ton établissement, amis, ou personne - et le réglage se
        décide <strong className="font-semibold text-ink">au moment de l&apos;import</strong>, pas
        après coup.
      </>
    ),
  },
  {
    question: "Est-ce que Micabo invente des choses ?",
    answer: (
      <>
        C&apos;est le risque qu&apos;on prend le plus au sérieux, parce qu&apos;une fiche fausse ne
        ressemble pas à une erreur. Un mot mal lu par la reconnaissance de texte peut donner une
        définition parfaitement crédible et complètement fausse. Micabo ne définit donc jamais un
        terme dont il n&apos;est pas sûr : quand le contexte ne tranche pas, le mot douteux
        n&apos;apparaît simplement pas dans la fiche.
      </>
    ),
  },
  {
    question: "Ça marche en anglais ? Dans d'autres systèmes scolaires ?",
    answer: (
      <>
        Oui. Le pays de scolarisation décide à la fois du système de référence - un cégep
        québécois, un A-Level britannique et une prépa française ne demandent pas la même
        rédaction - et de la langue dans laquelle la fiche est écrite. Le site, lui, est en
        français pour l&apos;instant.
      </>
    ),
  },
  {
    question: "Qu'est-ce qui est gratuit ?",
    answer: (
      <>
        Un cours entier à importer, dont tu lis les{" "}
        {Math.round(entitlement.FREE_TIER.readableSheetRatio * 100)} % de la fiche, et{" "}
        {entitlement.FREE_TIER.cardsPerSession} cartes par session. Ce n&apos;est pas zéro
        volontairement : un paywall posé avant le premier import demande de payer pour un produit
        qu&apos;on n&apos;a pas vu tourner sur ses propres cours.
      </>
    ),
  },
  {
    question: "Que se passe-t-il à la fin de l'essai ?",
    answer: (
      <>
        Les {pricing.FREE_TRIAL_DAYS} jours d&apos;essai s&apos;arrêtent, et rien ne se prélève
        sans que tu l&apos;aies décidé. Tes cours et tes cartes restent : ce qui se referme,
        c&apos;est ce que Pro ouvrait, pas ce que tu as déjà écrit.
      </>
    ),
  },
  {
    question: "Et si j'utilise déjà Anki ?",
    answer: (
      <>
        La répétition espacée de Micabo <em>est</em> celle d&apos;Anki - SM-2, avec ses réglages
        par défaut, ses quatre boutons et ses paliers d&apos;apprentissage. Ce que Micabo ajoute
        est ce qu&apos;Anki ne fait pas : écrire la fiche et les cartes à partir de ton cours, et
        replanifier tout un paquet quand tu déclares la date d&apos;un examen.
      </>
    ),
  },
];

export function Questions() {
  return (
    <div className="paper mt-9 overflow-hidden rounded-group bg-surface">
      {QUESTIONS.map((item, index) => (
        <details
          key={item.question}
          className={`group px-6 py-1 ${index > 0 ? "border-t border-hairline" : ""}`}
        >
          <summary className="hover-row flex cursor-pointer list-none items-center justify-between gap-4 py-4 text-[15px] font-medium text-ink [&::-webkit-details-marker]:hidden">
            {item.question}
            <svg
              aria-hidden
              viewBox="0 0 16 16"
              className="h-4 w-4 shrink-0 text-ink-tertiary transition-transform duration-hover ease-out-strong group-open:rotate-45"
            >
              <path
                d="M8 3v10M3 8h10"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              />
            </svg>
          </summary>
          <p className="max-w-reading pb-5 text-[14.5px] leading-relaxed text-ink-secondary">
            {item.answer}
          </p>
        </details>
      ))}
    </div>
  );
}
