/**
 * Les ancres de la vitrine, nommées une fois.
 *
 * La barre de navigation et les sections doivent porter **exactement** les mêmes
 * identifiants : une ancre qui ne trouve pas sa cible ne fait rien, sans erreur et sans
 * rien afficher, et c'est la panne la plus facile à ne pas voir.
 *
 * Ce sont aussi les intitulés que Google lit pour proposer des liens vers une partie de la
 * page. Il ne les prend pas parce qu'on les déclare, mais parce qu'un titre de section
 * répond à une question : d'où des noms qui disent le sujet, pas la position.
 *
 * La vitrine se lit dans l'ordre du produit : ce qu'on dépose et la leçon qui en sort (le
 * héros), les trois étapes, ce qu'il y a dans une leçon, les applis, le prix, les questions.
 * Les apps iPhone et Android sont publiques, et le prix est écrit : la page les annonce.
 */
export const LANDING_SECTIONS = {
  how: "comment-ca-marche",
  lesson: "la-lecon",
  apps: "applis",
  pricing: "prix",
  questions: "questions",
} as const;

/**
 * La barre de la vitrine : la clé de catalogue de chaque lien, et son libellé français pour
 * les tests. Les applis n'y sont pas : la section est courte, et le pied de page la porte.
 */
export const LANDING_NAV = [
  { href: `#${LANDING_SECTIONS.how}`, key: "site.how", label: "Comment ça marche" },
  { href: `#${LANDING_SECTIONS.lesson}`, key: "landing.navLesson", label: "La leçon" },
  { href: `#${LANDING_SECTIONS.pricing}`, key: "landing.navPricing", label: "Prix" },
  { href: `#${LANDING_SECTIONS.questions}`, key: "site.questions", label: "Questions" },
] as const;
