/**
 * Les ancres de la vitrine, nommées une fois.
 *
 * La barre de navigation et les sections doivent porter **exactement** les mêmes
 * identifiants : une ancre qui ne trouve pas sa cible ne fait rien, sans erreur et sans
 * rien afficher, et c'est la panne la plus facile à ne pas voir.
 *
 * Ce sont aussi les intitulés que Google lit pour proposer des liens vers une partie de la
 * page. Il ne les prend pas parce qu'on les déclare, mais parce qu'un titre de section
 * répond à une question — d'où des noms qui disent le sujet, pas la position.
 */
export const LANDING_SECTIONS = {
  cards: "cartes",
  method: "methode",
  exam: "mode-examen",
  questions: "questions",
} as const;

export const LANDING_NAV = [
  { href: `#${LANDING_SECTIONS.method}`, label: "La méthode" },
  { href: `#${LANDING_SECTIONS.exam}`, label: "Mode examen" },
  { href: `#${LANDING_SECTIONS.questions}`, label: "Questions" },
] as const;
