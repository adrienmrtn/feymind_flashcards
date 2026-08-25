/**
 * La matière d'un cours, et ce qu'elle change à la façon de l'écrire.
 *
 * Une fiche de philosophie sans auteurs ni œuvres n'est pas une fiche de philosophie, et
 * une fiche d'économie qui donne une seule vision d'un débat est fausse par omission. Le
 * prompt général ne peut pas porter ces exigences : elles se contredisent d'une matière à
 * l'autre, et les empiler toutes ferait un prompt que le modèle survole.
 *
 * La matière est donc détectée, puis une seule consigne est ajoutée. La détection est faite
 * ici plutôt que dans l'application pour une raison simple : à l'import, personne ne connaît
 * encore la matière — c'est le modèle qui la trouve. On la devine donc sur le texte, et
 * quand l'application la connaît déjà (elle regénère une fiche, elle écrit des cartes), elle
 * l'envoie et c'est elle qui gagne.
 */

export type Discipline =
  | "philosophy"
  | "economics"
  | "law"
  | "medicine"
  | "history"
  | "mathematics"
  | "physics"
  | "biology"
  | "literature"
  | "language"
  | "computing"
  | "general";

/**
 * Mots qui trahissent une matière.
 *
 * Ils sont écrits sans accent et en minuscules : la comparaison se fait sur un texte replié,
 * sinon « théorie » et « theorie » ne seraient pas le même mot. Un seul mot ne suffit pas à
 * décider, c'est le nombre d'occurrences distinctes qui compte : « marché » apparaît dans un
 * cours d'histoire, mais pas avec « inflation » et « keynes ».
 */
const KEYWORDS: Record<Exclude<Discipline, "general">, string[]> = {
  philosophy: [
    "philosophie",
    "philosophique",
    "kant",
    "descartes",
    "nietzsche",
    "platon",
    "aristote",
    "spinoza",
    "hegel",
    "sartre",
    "metaphysique",
    "epistemologie",
    "conscience",
    "libre arbitre",
    "morale",
    "ontologie",
  ],
  economics: [
    "economie",
    "economique",
    "inflation",
    "keynes",
    "smith",
    "ricardo",
    "marche du travail",
    "offre et demande",
    "pib",
    "chomage",
    "monnaie",
    "banque centrale",
    "croissance economique",
    "consommation",
    "elasticite",
    "sciences economiques",
    "ses",
  ],
  law: [
    "droit",
    "juridique",
    "constitution",
    "jurisprudence",
    "code civil",
    "code penal",
    "article l",
    "alinea",
    "contrat",
    "responsabilite civile",
    "cassation",
    "conseil constitutionnel",
    "legislateur",
    "arret",
    "tribunal",
  ],
  medicine: [
    "anatomie",
    "physiologie",
    "pathologie",
    "clinique",
    "symptome",
    "diagnostic",
    "traitement",
    "posologie",
    "muscle",
    "arteres",
    "nerf",
    "cellule",
    "syndrome",
    "patient",
    "pharmacologie",
    "semiologie",
  ],
  history: [
    "histoire",
    "siecle",
    "revolution",
    "guerre",
    "traite de",
    "empire",
    "republique",
    "regime",
    "chronologie",
    "moyen age",
    "antiquite",
    "colonisation",
    "geopolitique",
  ],
  mathematics: [
    "mathematiques",
    "theoreme",
    "demonstration",
    "derivee",
    "integrale",
    "equation",
    "fonction affine",
    "matrice",
    "probabilite",
    "suite",
    "limite",
    "vecteur",
    "polynome",
  ],
  physics: [
    "physique",
    "chimie",
    "force",
    "energie cinetique",
    "mole",
    "reaction chimique",
    "atome",
    "electron",
    "circuit",
    "tension",
    "acceleration",
    "thermodynamique",
    "onde",
  ],
  biology: [
    "svt",
    "biologie",
    "genetique",
    "adn",
    "chromosome",
    "photosynthese",
    "ecosysteme",
    "mitose",
    "enzyme",
    "espece",
    "evolution",
    "geologie",
  ],
  literature: [
    "litterature",
    "francais",
    "roman",
    "poesie",
    "theatre",
    "registre",
    "figure de style",
    "narrateur",
    "commentaire de texte",
    "dissertation",
    "auteur",
    "recit",
  ],
  language: [
    "vocabulaire",
    "conjugaison",
    "grammaire",
    "declinaison",
    "verbe irregulier",
    "traduction",
    "anglais",
    "espagnol",
    "allemand",
    "italien",
    "prononciation",
  ],
  computing: [
    "informatique",
    "algorithme",
    "programmation",
    "boucle",
    "variable",
    "fonction python",
    "base de donnees",
    "compilateur",
    "complexite",
    "reseau",
  ],
};

/** Ce qu'une matière exige de la fiche, et que le prompt général ne peut pas porter. */
const BRIEFS: Record<Discipline, string> = {
  philosophy:
    `MATIÈRE : PHILOSOPHIE. Une notion de philosophie ne s'explique pas sans ceux qui l'ont pensée. **Nomme les auteurs, leurs œuvres et leurs thèses** dès que le document les mentionne, avec le titre exact de l'ouvrage. Quand une notion oppose deux positions, écris les deux et ce qui les sépare, dans un tableau si elles se comparent terme à terme. Distingue toujours la thèse, l'argument qui la soutient et l'exemple qui l'illustre : c'est cette distinction que l'épreuve évalue. Garde les distinctions conceptuelles du cours (en soi et pour soi, nécessaire et contingent) : ce sont elles qui font la copie.`,
  economics:
    `MATIÈRE : ÉCONOMIE. Une fiche d'économie qui donne une seule lecture d'un débat est fausse par omission. **Nomme les écoles et les auteurs** (classiques, keynésiens, néoclassiques, hétérodoxes) et, sur chaque question controversée, écris les visions qui s'opposent et le désaccord exact, pas une synthèse molle. Chaque mécanisme s'écrit comme un enchaînement de causes, et les chiffres du document sont repris avec leur unité et leur année. Rappelle en une ligne le prérequis de première quand une notion en dépend (offre et demande, élasticité, marché, facteurs de production) : le programme de terminale s'appuie dessus sans le redire.`,
  law:
    `MATIÈRE : DROIT. Un raisonnement juridique s'appuie sur un texte : **cite la source de chaque règle** telle que le document la donne, article, code, alinéa, et l'arrêt quand il y en a un. Distingue nettement le principe, ses conditions d'application et ses exceptions : c'est la structure d'une copie. Garde la hiérarchie des normes quand elle est en jeu (Constitution, traités, loi, règlement) et le vocabulaire exact, qui est technique et non synonyme du langage courant. Un tableau de comparaison dès que le cours oppose deux régimes, deux qualifications ou deux juridictions.`,
  medicine:
    `MATIÈRE : SANTÉ. Rien d'approximatif : **nomenclature exacte, valeurs seuils, unités systématiques**, et aucune valeur arrondie sans le dire. Une structure anatomique s'écrit avec sa situation, ses rapports et sa fonction. Un mécanisme physiologique s'écrit comme une chaîne, étape par étape. Signale explicitement les confusions classiques et les pièges de QCM, et privilégie les tableaux de comparaison : c'est comme ça que ces cours se révisent. N'invente jamais une posologie ni une valeur biologique.`,
  history:
    `MATIÈRE : HISTOIRE. Les dates, les lieux et les acteurs sont le contenu, pas l'habillage : **chaque fait porte sa date**, et les enchaînements sont écrits comme des causes et des conséquences, non comme une liste. Distingue le fait de son interprétation, et garde les notions du cours (les termes que l'épreuve attend) avec leur définition. Une frise ou un tableau chronologique dès que le document couvre plusieurs périodes.`,
  mathematics:
    `MATIÈRE : MATHÉMATIQUES. Un énoncé sans ses hypothèses est faux : **chaque théorème porte ses conditions d'application**. Les démonstrations du document sont conservées dans leurs étapes, pas résumées en conclusion. Les formules s'écrivent en LaTeX entre $…$, avec ce que désigne chaque symbole. Signale les erreurs classiques et les cas limites, et distingue ce qui est équivalence de ce qui est simple implication.`,
  physics:
    `MATIÈRE : PHYSIQUE-CHIMIE. Une grandeur sans unité ne veut rien dire : **unités partout**, et l'ordre de grandeur quand il éclaire. Chaque loi porte son domaine de validité. Les formules s'écrivent en LaTeX entre $…$ avec la signification de chaque symbole, et les valeurs numériques du document sont reprises telles quelles. Un schéma décrit en mots plutôt qu'un schéma inventé.`,
  biology:
    `MATIÈRE : SVT. Une notion de biologie s'écrit à son échelle : **dis toujours de quelle échelle tu parles** (molécule, cellule, organisme, écosystème) et ne les mélange pas dans une même phrase. Un mécanisme s'écrit comme une chaîne d'étapes, avec ce qui entre et ce qui sort. Garde la nomenclature exacte des structures et des molécules, et les chiffres du document avec leur unité.`,
  literature:
    `MATIÈRE : LETTRES. Une analyse littéraire sans texte n'est rien : **cite les passages** que le document donne, avec leur auteur et leur œuvre, et nomme les procédés avec leur terme exact (métaphore, anaphore, focalisation) en disant ce qu'ils produisent. Situe l'œuvre dans son mouvement et son siècle. Distingue le procédé, son effet et l'interprétation : c'est le plan d'un commentaire.`,
  language:
    `MATIÈRE : LANGUE VIVANTE. La fiche sert à produire de la langue, pas à en parler. **Garde chaque terme dans sa langue d'origine, suivi de sa traduction**, et signale le genre, le pluriel irrégulier et la construction quand ils comptent. Les règles s'écrivent avec un exemple complet, phrase entière. Signale les faux amis et les pièges de prononciation que le document mentionne.`,
  computing:
    `MATIÈRE : INFORMATIQUE. Un algorithme s'écrit avec ce qu'il prend, ce qu'il rend et son coût : **complexité annoncée** quand le document la donne. Les étapes ordonnées vont dans un bloc "steps", jamais dans un paragraphe. Garde les noms exacts des structures et des fonctions, et distingue ce qui est syntaxe d'un langage de ce qui est un principe général.`,
  general: "",
};

/** Replie un texte pour la comparaison : sans accents, en minuscules. */
function fold(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

/**
 * La matière du document.
 *
 * La matière déclarée par l'application passe devant : quand elle existe, elle a été trouvée
 * par le modèle sur ce même document, ou corrigée à la main, et vaut mieux que des mots
 * comptés. Sinon on compte, sur le début du document et sur son titre, et il faut au moins
 * deux mots distincts pour décider : un seul rangerait un cours d'histoire en économie parce
 * qu'il parle de marchés.
 */
export function detectDiscipline(
  text: string,
  hintTitle?: string,
  declaredSubject?: string,
): Discipline {
  const declared = fromSubject(declaredSubject);
  if (declared !== "general") return declared;

  // Le début suffit, et coûte bien moins cher : un cours annonce sa matière dès ses
  // premières lignes, et compter sur soixante mille caractères ne changerait pas le verdict.
  const haystack = fold(`${hintTitle ?? ""} ${text.slice(0, 6_000)}`);

  let best: Discipline = "general";
  let bestScore = 1;

  for (const [discipline, keywords] of Object.entries(KEYWORDS)) {
    const score = keywords.filter((keyword) => haystack.includes(keyword)).length;
    if (score > bestScore) {
      best = discipline as Discipline;
      bestScore = score;
    }
  }

  return best;
}

/** La matière telle que l'application la connaît déjà, quand elle la connaît. */
function fromSubject(subject?: string): Discipline {
  const folded = fold(subject ?? "").trim();
  if (folded.length < 3) return "general";

  for (const [discipline, keywords] of Object.entries(KEYWORDS)) {
    if (keywords.some((keyword) => folded.includes(keyword))) {
      return discipline as Discipline;
    }
  }
  return "general";
}

export function disciplineBrief(discipline: Discipline): string {
  return BRIEFS[discipline];
}
