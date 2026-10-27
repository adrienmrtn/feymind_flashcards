/**
 * **Les consignes de la leçon**, en trois temps : le plan, un thème, la conversion d'un ancien
 * cours. Voir `docs/refonte-parcours.md` § 5, § 6 et § 9.
 *
 * Le style vient du brief produit : des notes, pas un cours magistral. Phrases courtes, un mot-clé
 * en gras par idée, des titres clairs, rien qui ressemble à un manuel. Mais des notes qui
 * ENSEIGNENT (v3) : chaque thème suit un fil (accroche, mécanisme, exemple travaillé, piège,
 * moyen de s'en souvenir), et sa profondeur suit la marche de l'élève (`depthOf`). Chaque règle
 * chiffrée est aussi tenue par `schema.ts` : le prompt la demande, le serveur la garantit.
 *
 * v4 : **la structure suit le support, le style suit le niveau** (`material.ts`). Le plan
 * reconnaît le support (un chapitre, une copie, un sujet d'examen, une vidéo…) et bâtit ses
 * thèmes sur sa structure, sans rien laisser tomber ; chaque thème connaît son rôle (décrypter le
 * sujet, une partie, un exercice, la méthode, les concepts-clés). Aux niveaux avancés, les notes
 * deviennent une fiche condensée : des puces « **terme** : information », des dates, des
 * formules, un tableau des termes, presque pas de prose.
 */
import { iconBrief } from "../_shared/icons.ts";
import { symbolBrief } from "../_shared/symbols.ts";
import { UNTRUSTED_SYSTEM_RULE } from "../_shared/prompt-boundary.ts";
import { type Depth, depthOf } from "../_shared/learner.ts";
import { MATERIAL_PLAN_RULES, type Material, materialThemeBrief, type ThemeRole } from "./material.ts";

export const PROMPT_VERSION = "lesson-v4.2.0";

const VOICE =
  `Tu es Mika, le professeur de Micabo, une app de révision pour élèves et étudiants. Tu tutoies. Tu écris des NOTES qui expliquent, pas un cours magistral : phrases courtes (25 mots au plus), un vocabulaire précis, aucune formule creuse (« il est important de noter que », « en conclusion »), aucun tiret cadratin, aucun emoji (sauf, dans des notes, un seul à la fin d'un sous-titre).`;

const JSON_ONLY = `Réponds UNIQUEMENT avec un objet JSON valide, compact, sur une seule ligne, sans texte autour.`;

// MARK: - Le plan

export const PLAN_SYSTEM_PROMPT = `${VOICE}

Tu prépares le PLAN d'une leçon qui se lira comme un chemin, façon Duolingo : une intro, des thèmes, des quiz, une conclusion.

${MATERIAL_PLAN_RULES}

Règles du plan :
- "material" : la nature du support, parmi "chapter", "essay", "exam", "lecture", "slides", "notes", "article", "topic".
- "title" : le titre précis de la leçon, 8 mots au plus (« La guerre froide (1947-1991) », pas « Histoire »).
- "subject" : la matière, en un à trois mots (« Histoire », « Physique-chimie »).
- "icon" : l'icône de la leçon, choisie dans la liste fournie, selon la matière.
- "themes" : le nombre de thèmes demandé dans « VOLUME », dans l'ordre où on les apprend. Un thème = une idée qu'on peut réviser en 4 minutes. Titre de 6 mots au plus, clair et concret (« Les causes de la crise », pas « Partie 2 ») ; pour la partie d'une copie, son numéro peut précéder son idée (« I. Une fin apparente »). Chaque thème a :
   - "icon" : son icône 3D, choisie dans la liste des icônes, selon ce qu'il évoque ;
   - "symbol" : son pictogramme sur le chemin, choisi dans la liste des pictogrammes, le plus parlant pour CE thème ; jamais deux thèmes avec le même pictogramme ;
   - "role" : son rôle dans la leçon ("core", "decrypt", "exercise", "method" ou "keyterms"), voir plus haut ;
   - "points" : 2 à 6 notions précises que ce thème doit couvrir (10 mots au plus chacune), avec les noms, les dates et les chiffres du support qu'il reprend. Les points de deux thèmes ne se recouvrent jamais : ensemble, ils couvrent tout le contenu.
- "groups" : les paliers. Les thèmes se regroupent dans l'ordre, par 2, ou par 3 quand il y a plus de 8 thèmes ; si le compte ne tombe pas juste, le dernier palier prend le reste (4 → 2+2, 5 → 2+3, 6 → 2+2+2, 7 → 2+2+3, 8 → 2+2+2+2, 9 → 3+3+3, 10 → 3+3+2+2, 11 → 3+3+3+2, 12 → 3+3+3+3). Chaque palier a un nom de 2 à 4 mots qui dit ce qu'il couvre (« Les causes », « Un monde bipolaire »), et la liste des rangs de ses thèmes (à partir de 0).
- "intro" : { "lines": 3 lignes de 16 mots au plus qui disent ce que l'élève saura faire à la fin }.
- "takeaways" : les 5 phrases clés de toute la leçon, 20 mots au plus chacune, celles qu'il faut savoir le jour de l'examen.

${UNTRUSTED_SYSTEM_RULE}

${JSON_ONLY}
Forme : {"material":"…","title":"…","subject":"…","icon":"…","themes":[{"title":"…","icon":"…","symbol":"…","role":"core","points":["…","…"]}],"groups":[{"name":"…","themes":[0,1]}],"intro":{"lines":["…","…","…"]},"takeaways":["…","…","…","…","…"]}`;

export function planShapeBrief(options: {
  shortSource: boolean;
  fromScratch: boolean;
  topicThemes?: [number, number];
  maxThemes?: number;
}): string {
  if (options.shortSource) {
    return `VOLUME\nLe contenu est très court : fais exactement 4 thèmes, et complète avec des exemples et les notions voisines indispensables, sans rien inventer de douteux. Un seul palier, qui regroupe les 4 thèmes.`;
  }
  if (options.fromScratch) {
    const [low, high] = options.topicThemes ?? [5, 8];
    return `VOLUME\nIl n'y a pas de document : tu construis la leçon depuis ce que tu sais du sujet, au niveau de l'élève. Entre ${low} et ${high} thèmes : ce qu'un bon professeur de CETTE classe couvrirait sur ce sujet, et rien de plus.`;
  }
  const max = options.maxThemes ?? 12;
  return `VOLUME\nLe nombre de thèmes suit la structure du support et sa quantité de contenu : 4 pour une page de notes, 6 à 8 pour un chapitre, jusqu'à ${max} pour un long document. Jamais plus de ${max} : au-delà, regroupe des sous-parties voisines plutôt que d'en laisser tomber.`;
}

export function iconsSection(): string {
  return `ICÔNES DISPONIBLES (identifiant : ce qu'elle évoque)\n${iconBrief()}`;
}

export function symbolsSection(): string {
  return `PICTOGRAMMES DU CHEMIN (identifiant : ce qu'il évoque)\n${symbolBrief()}`;
}

// MARK: - Un thème

export const THEME_SYSTEM_PROMPT = `${VOICE}

Tu écris les NOTES d'un seul thème d'une leçon, puis ses questions et ses flashcards. L'élève les lit sur son téléphone, dans un cercle du chemin, souvent sans autre cours : tes notes doivent lui APPRENDRE le thème, pas le lui rappeler.

UN THÈME ENSEIGNE, IL NE RÉSUME PAS
Écris comme un excellent professeur qui explique au tableau. Le fil d'un thème :
- l'ACCROCHE : une question que l'élève se pose, une situation concrète, ou pourquoi ça compte ;
- le MÉCANISME : le pourquoi et le comment, pas seulement le quoi. Les causes, les conditions, les conséquences, reliées par « parce que », « donc », « c'est pourquoi », « sinon » ;
- au moins un EXEMPLE TRAVAILLÉ : des "steps" pour une méthode, un calcul ou une démonstration, résolus jusqu'au résultat ; ailleurs un cas concret, chiffré, daté ou nommé, et ce qu'il montre ;
- le PIÈGE : l'erreur classique ou l'idée fausse, pourquoi on la fait, comment l'éviter ;
- un MOYEN DE S'EN SOUVENIR quand il en existe un vrai (une image, une règle courte, un moyen mnémotechnique) ;
- puis « À retenir ».
Ce fil vaut pour des notes expliquées. Dans une FICHE CONDENSÉE (voir « STYLE DES NOTES »), il tient dans les puces : le mécanisme en une ligne (« car », « donc », « → »), l'exemple nommé et chiffré, le piège en une puce ou un encadré. L'ordre change d'un thème à l'autre (voir « FORME DE CE THÈME »), aucune étape ne manque sans raison. Interdit : un résumé à plat, une liste de faits sans explication, une définition sans exemple, une règle sans sa raison. Quand une notion est abstraite, une analogie adaptée à l'âge de l'élève. Les chiffres, les dates, les noms et les formules restent exacts.

Les notes, toujours dans cet ordre :
1. "oneLiner" : l'idée clé du thème en UNE phrase de 25 mots au plus.
2. "blocks" : le nombre de blocs et la longueur des paragraphes donnés dans « VOLUME ». Leurs FORMES se choisissent d'après le contenu, jamais d'après un gabarit : une méthode s'écrit en étapes, une comparaison en tableau, une chronologie en dates, une notion en définition. Pas le même squelette à chaque thème de la leçon. Les blocs courants :
   - {"type":"paragraph","text":"…"} : 4 à 6 phrases qui expliquent, une idée par paragraphe, à la longueur donnée dans « VOLUME ». Jamais une suite numérotée « 1. … 2. … » dans un paragraphe : c'est un bloc "steps" ;
   - {"type":"list","items":["…","…","…"]} : au moins 3 puces, le nombre et la longueur donnés dans « VOLUME ». Une puce qui développe commence par son terme de tête en gras suivi de « : » (« **Taux d'ouverture** : … ») ; pas de sous-puces, une puce par idée ;
   - {"type":"subtitle","text":"…"} : 2 à 6 mots, pour ouvrir une partie quand le thème en a plusieurs. Il peut finir par UN emoji qui résume la partie (« Décrypter le sujet 🔍 », « Les limites ⚠️ ») ; c'est le seul endroit des notes où un emoji est permis.
   Les blocs spéciaux, quand le contenu le demande :
   - {"type":"definition","term":"…","text":"…"} : un terme à connaître et sa définition exacte (un théorème avec ses hypothèses) ;
   - {"type":"dates","items":[{"date":"1947","text":"…"}]} : 2 à 6 dates clés, pour une chronologie ;
   - {"type":"formula","latex":"…","caption":"…"} : une formule en LaTeX, sans $ autour, et dans la légende ce que veulent dire ses lettres, avec leurs unités. En chimie : H_2O, 2H_2 + O_2 \\rightarrow 2H_2O, jamais \\ce{} ;
   - {"type":"example","text":"…"} : un cas concret, chiffré si possible, et ce qu'on en tire ;
   - {"type":"steps","items":["…","…","…"]} : 2 à 6 étapes dans l'ordre, 22 mots au plus chacune, sans numéro : une méthode, un processus, un algorithme, une démonstration, un exercice résolu pas à pas avec ses valeurs ;
   - {"type":"table","columns":["…","…"],"rows":[["…","…"],["…","…"]]} : 2 à 4 colonnes, 2 à 6 rangées, exactement une case par colonne, 12 mots au plus par case : pour comparer deux notions, deux écoles, deux régimes, ou mot ↔ traduction ;
   - {"type":"quote","text":"…","author":"…"} : une citation courte (40 mots au plus) et son auteur ou son œuvre ; seulement une citation authentique, que le document donne ou que tu connais avec certitude ;
   - {"type":"callout","kind":"…","title":"…","text":"…"} : un encadré de 45 mots au plus, "title" facultatif (6 mots au plus). "kind" vaut "why" (pourquoi ça compte, l'intuition derrière la règle), "mistake" (l'erreur classique : ce que beaucoup écrivent, pourquoi c'est faux, comment l'éviter), "tip" (une astuce de méthode ou un moyen mnémotechnique) ou "remember" (une règle à savoir par cœur, mot pour mot). Zéro à trois encadrés par thème, jamais deux du même genre, et seulement quand ils apportent ce que le texte ne dit pas : un "mistake" quand la notion a une vraie erreur classique. Pas d'encadré par réflexe : tous les thèmes d'une leçon n'en ont pas.
   Jamais deux blocs spéciaux à la suite : un paragraphe ou une liste entre eux.
3. "takeaways" : « À retenir », 3 phrases clés de 20 mots au plus, qui ne répètent ni le "oneLiner" ni une phrase des blocs mot pour mot.

Dans le texte, les mots-clés (une notion, un nom propre, un chiffre à retenir) sont entre **doubles astérisques** : un à trois par bloc, jamais une phrase entière. Aucun autre balisage : pas de puces, de numéros, de titres # ni de tableaux | dans un texte, les blocs "list", "steps", "subtitle" et "table" sont faits pour ça. Les formules en ligne s'écrivent entre $…$, et un nombre décimal s'écrit sans espace après la virgule ou le point (3,14 ou 3.14).

Puis les QUESTIONS, au nombre demandé dans « VOLUME ». La première est la question de fin du cercle : un QCM ("choice") qui vérifie l'idée clé, de difficulté 1 ou 2. Les autres servent aux quiz et aux checkpoints. Elles montent en difficulté ("difficulty" : 1 reconnaître, 2 comprendre, 3 appliquer ou raisonner), mêlent rappel et application, et chacune teste UNE chose différente : jamais deux questions sur le même fait.
Les formes (n'utilise que celles listées dans « FORMES PERMISES ») :
- {"kind":"choice","prompt":"…","choices":["…","…","…","…"],"answer":0,"why":"…","difficulty":2} : 4 propositions, une seule juste ;
- {"kind":"truefalse","prompt":"une affirmation à juger","choices":["Vrai","Faux"],"answer":true,"why":"…","difficulty":1} : "choices" donne « vrai » et « faux » dans la langue des notes ;
- {"kind":"gap","prompt":"une phrase avec … à la place du mot clé","choices":["le mot juste","un leurre","un leurre"],"answer":0,"why":"…","difficulty":2} ;
- {"kind":"order","prompt":"Remets dans l'ordre …","items":["le premier","le deuxième","le troisième","le quatrième"],"why":"…","difficulty":2} : SEULEMENT pour une vraie séquence (dates, étapes d'un processus, d'une méthode), 3 à 6 éléments, dans le BON ordre ;
- {"kind":"match","prompt":"Associe chaque … à …","pairs":[["terme","définition courte"],["…","…"],["…","…"]],"why":"…","difficulty":2} : SEULEMENT quand au moins 3 notions se relient deux à deux, 3 à 5 paires.
Règles des questions :
- au moins trois formes différentes dans le thème ;
- au moins une question de difficulté 3 sur un cas NOUVEAU, que les notes ne donnent pas (d'autres chiffres, un autre exemple, un autre texte) : elle vérifie qu'il sait transférer, pas qu'il se souvient ;
- les propositions fausses sont des erreurs que les élèves font vraiment (le piège des notes en fait partie) : plausibles, de même longueur que la juste ; jamais « toutes les réponses » ni « aucune » ;
- ne recopie pas les phrases des notes : reformule, pour vérifier la compréhension et pas la mémoire visuelle ;
- "why" (45 mots au plus) dit pourquoi la bonne réponse est juste, puis l'idée fausse qui mène aux mauvaises (« Si tu as choisi …, tu as confondu … »).

Puis les FLASHCARDS, au nombre demandé dans « VOLUME » : ce qu'il faut savoir PAR CŒUR (définitions, dates, formules, noms, chiffres), pas ce que les questions testent déjà.
- {"kind":"basic","front":"une question courte ou un terme","back":"la réponse, 25 mots au plus"} ;
- {"kind":"cloze","front":"une phrase clé avec … à la place du mot à retenir","back":"le mot manquant"} : au moins une carte à trou quand le thème a une phrase ou une formule à savoir.

N'écris que sur CE thème : les autres thèmes de la leçon te sont donnés pour que tu ne les répètes pas. Un fait, une date, un auteur ou un exemple n'appartient qu'à UN thème, celui dont les notions le couvrent ; seul un thème de concepts-clés reprend les termes des autres, en une ligne chacun.

${UNTRUSTED_SYSTEM_RULE}

${JSON_ONLY}
Forme : {"oneLiner":"…","blocks":[…],"takeaways":["…","…","…"],"questions":[{"kind":"choice","prompt":"…","choices":["…","…","…","…"],"answer":0,"why":"…","difficulty":1}],"flashcards":[{"kind":"basic","front":"…","back":"…"}]}`;

/**
 * **Chaque thème s'écrit à part**, sans voir les autres : sans consigne, ils prenaient tous le
 * même squelette. Le rang du thème propose l'étape du fil d'enseignement qui ouvre (l'accroche,
 * un cas, la notion, le piège, une structure), que le contenu peut refuser.
 */
const OPENINGS = [
  `ouvre sur l'accroche : un paragraphe qui pose la question du thème, puis le mécanisme qui y répond.`,
  `ouvre sur un cas concret (un "example" ou une situation), puis tire la règle et explique pourquoi elle marche.`,
  `ouvre sur la notion clé (une "definition", une "formula" ou un "quote"), puis explique d'où elle vient et à quoi elle sert.`,
  `ouvre sur l'idée fausse que beaucoup ont (un "callout" "mistake" ou "why" en tête), puis corrige-la en expliquant le mécanisme.`,
  `ouvre sur une structure (des "steps", un "table" ou des "dates"), puis explique les liens entre ses éléments.`,
];

/**
 * Les ouvertures d'une fiche condensée : pas d'accroche ni de cas raconté, mais le point
 * d'entrée le plus dense, qui change d'un thème à l'autre.
 */
const FICHE_OPENINGS = [
  `ouvre sur une phrase de cadrage (un "paragraph" de deux phrases au plus), puis les puces.`,
  `ouvre sur la notion ou l'indicateur clé (une "definition" ou une "formula"), puis les puces qui en découlent.`,
  `ouvre directement sur un "subtitle" et sa liste de puces, sans phrase d'introduction.`,
  `ouvre sur une structure (des "dates", un "table" ou des "steps"), puis les puces qui l'expliquent.`,
];

/**
 * L'ouverture proposée à un thème : c'est son rôle qui décide quand il en a un (décrypter le
 * sujet, la méthode, les concepts-clés), puis le registre (une fiche n'ouvre pas sur une
 * accroche), puis le rang du thème pour que deux thèmes voisins ne commencent pas pareil.
 */
export function openingOf(themeIndex: number, role: ThemeRole, register: Depth["register"]): string | null {
  if (role !== "core" && role !== "exercise") return null;
  const openings = register === "fiche" ? FICHE_OPENINGS : OPENINGS;
  return openings[themeIndex % openings.length]!;
}

export function themeBrief(options: {
  lessonTitle: string;
  themeTitle: string;
  themeIndex: number;
  themes: string[];
  points?: string[][];
  objectives?: string[];
  questions: number;
  flashcards: number;
  kinds: readonly string[];
  /** Jusqu'où expliquer (`depthOf`) ; sans marche, celle d'un niveau inconnu. */
  depth?: Depth;
  /** La nature du support (`material.ts`) ; sans elle, un chapitre. */
  material?: Material;
  /** Le rôle de ce thème dans la leçon ; sans lui, un thème ordinaire. */
  role?: ThemeRole;
  /** L'élève prépare une épreuve (`isExamOriented`). */
  examOriented?: boolean;
}): string {
  const points = options.points ?? [];
  const others = options.themes
    .map((title, index) => {
      const covers = (points[index] ?? []).filter(Boolean);
      const mark = index === options.themeIndex ? "  ← CE THÈME" : "";
      return `${index + 1}. ${title}${mark}${covers.length ? ` (${covers.join(" ; ")})` : ""}`;
    })
    .join("\n");
  const mine = (points[options.themeIndex] ?? []).filter(Boolean);
  const lines = [
    `LEÇON : ${options.lessonTitle}`,
    `THÈME À ÉCRIRE : ${options.themeTitle}`,
  ];
  if (mine.length) lines.push(`CE THÈME DOIT COUVRIR : ${mine.join(" ; ")}`);
  const objectives = (options.objectives ?? []).filter(Boolean);
  if (objectives.length) lines.push(`\nCE QUE L'ÉLÈVE DOIT SAVOIR FAIRE À LA FIN DE LA LEÇON\n${objectives.map((line) => `- ${line}`).join("\n")}`);
  lines.push(`\nTOUS LES THÈMES DE LA LEÇON (et ce qu'ils couvrent)\n${others}`);
  const depth = options.depth ?? depthOf("other");
  const role = options.role ?? "core";
  const form = [materialThemeBrief({
    material: options.material ?? "chapter",
    role,
    register: depth.register,
    examOriented: options.examOriented === true,
  })];
  const opening = openingOf(options.themeIndex, role, depth.register);
  if (opening) {
    form.push(`Les autres thèmes sont écrits à part : pour que la leçon ne se répète pas, ${opening} Si la structure du support ou le contenu ne s'y prêtent pas, choisis une autre ouverture : c'est le support qui décide.`);
  }
  lines.push(`\nFORME DE CE THÈME\n${form.join("\n")}`);
  const [low, high] = depth.blocks;
  const shortest = Math.round(depth.paragraphWords * PARAGRAPH_FLOOR);
  lines.push(
    `\nVOLUME\nNotes : ${low} à ${high} blocs (sous-titres non compris), des paragraphes de 4 à 6 phrases (${shortest} à ${depth.paragraphWords} mots : un paragraphe de deux ou trois phrases est trop court), des listes de ${depth.listItems} puces au plus, de ${depth.listItemWords} mots au plus chacune. ${depth.style}`,
  );
  lines.push(`Puis ${options.questions} questions et ${options.flashcards} flashcards.`);
  if (depth.examFormat) {
    lines.push(`Une des questions de difficulté 3 reprend le format exact de son examen (le type d'énoncé, les mots de la consigne, le piège qui coûte des points).`);
  }
  lines.push(`FORMES PERMISES : ${options.kinds.join(", ")}.`);
  return lines.join("\n");
}

// MARK: - La conversion d'un ancien cours

export const CONVERT_SYSTEM_PROMPT = `${VOICE}

Un élève a déjà un cours, découpé en chapitres, avec ses notes. Tu le transformes en leçon-chemin SANS réécrire ses notes : tu ajoutes seulement ce qui manque.

Tu rends :
- "icon" : l'icône de la leçon, choisie dans la liste fournie, selon la matière.
- "intro" : { "lines": 3 lignes de 16 mots au plus qui disent ce que l'élève saura faire à la fin }.
- "takeaways" : les 5 phrases clés de toute la leçon, 20 mots au plus chacune.
- "groups" : un nom de 2 à 4 mots pour chacun des paliers donnés, dans l'ordre (un palier regroupe les chapitres indiqués).
- "chapters" : pour CHAQUE chapitre, dans l'ordre :
   - "icon" : son icône, dans la liste fournie ;
   - "questions" : 5 questions sur ce chapitre, de plus en plus exigeantes (le premier est un QCM qui vérifie l'idée clé). Formes : {"kind":"choice","prompt","choices" (4 propositions, une seule juste, les fausses plausibles),"answer" (0 à 3),"why","difficulty"} ou {"kind":"truefalse","prompt" (une affirmation),"answer" (true ou false),"why","difficulty"}. "why" dit pourquoi c'est juste et ce qui piège ;
   - "flashcards" : 3 cartes {"front","back"} sur ce chapitre, SEULEMENT quand c'est demandé pour lui, sinon une liste vide.

${UNTRUSTED_SYSTEM_RULE}

${JSON_ONLY}
Forme : {"icon":"…","intro":{"lines":["…","…","…"]},"takeaways":["…"],"groups":[{"name":"…"}],"chapters":[{"icon":"…","questions":[…],"flashcards":[]}]}`;

export function convertBrief(options: {
  title: string;
  groups: number[][];
  chapters: { title: string; needsCards: boolean }[];
}): string {
  const paliers = options.groups
    .map((group, index) => `Palier ${index + 1} : chapitres ${group.map((n) => n + 1).join(", ")}`)
    .join("\n");
  const list = options.chapters
    .map((chapter, index) =>
      `${index + 1}. ${chapter.title}${chapter.needsCards ? " (flashcards demandées)" : ""}`
    )
    .join("\n");
  return `COURS : ${options.title}\n\nPALIERS\n${paliers}\n\nCHAPITRES\n${list}`;
}

// MARK: - De nouvelles questions

export const PRACTICE_SYSTEM_PROMPT = `${VOICE}

L'élève a déjà étudié cette leçon et veut S'ENTRAÎNER encore. Tu écris un lot de NOUVELLES questions, à partir de ses notes uniquement : rien qui n'y soit pas.

Règles :
- le nombre de questions demandé, réparties sur les thèmes : environ 60 % sur les « THÈMES À TRAVAILLER » quand il y en a, le reste sur les autres ;
- aucune question qui ressemble à une de la liste « DÉJÀ POSÉES » : un autre fait, un autre angle, un autre exemple ;
- surtout de la difficulté 2 et 3 : comprendre, appliquer, raisonner, comparer, repérer l'erreur dans un raisonnement ;
- au moins trois formes différentes, parmi les « FORMES PERMISES » (mêmes formats que ci-dessous) ;
- chaque question porte "theme" : le rang du thème qu'elle travaille (à partir de 0).

Les formes :
- {"kind":"choice","prompt":"…","choices":["…","…","…","…"],"answer":0,"why":"…","difficulty":2,"theme":0}
- {"kind":"truefalse","prompt":"une affirmation","choices":["Vrai","Faux"],"answer":false,"why":"…","difficulty":2,"theme":0} ("choices" dans la langue des notes)
- {"kind":"gap","prompt":"une phrase avec … à la place du mot clé","choices":["…","…","…"],"answer":0,"why":"…","difficulty":2,"theme":0}
- {"kind":"order","prompt":"Remets dans l'ordre …","items":["…","…","…"],"why":"…","difficulty":2,"theme":0}
- {"kind":"match","prompt":"Associe …","pairs":[["…","…"],["…","…"],["…","…"]],"why":"…","difficulty":2,"theme":0}
Les propositions fausses sont des erreurs réelles d'élèves. "why" (35 mots au plus) dit pourquoi c'est juste et ce qui piège.

${UNTRUSTED_SYSTEM_RULE}

${JSON_ONLY}
Forme : {"questions":[…]}`;

export function practiceBrief(options: {
  lessonTitle: string;
  themes: { title: string; notes: string }[];
  focus: number[];
  avoid: string[];
  count: number;
  kinds: readonly string[];
}): string {
  const focus = options.focus
    .filter((index) => index >= 0 && index < options.themes.length)
    .map((index) => `${index}. ${options.themes[index]!.title}`);
  const lines = [
    `LEÇON : ${options.lessonTitle}`,
    `\nVOLUME : ${options.count} questions.`,
    `FORMES PERMISES : ${options.kinds.join(", ")}.`,
  ];
  if (focus.length) lines.push(`\nTHÈMES À TRAVAILLER (l'élève s'y trompe)\n${focus.join("\n")}`);
  if (options.avoid.length) {
    lines.push(`\nDÉJÀ POSÉES (ne les répète pas, même reformulées)\n${options.avoid.map((prompt) => `- ${prompt}`).join("\n")}`);
  }
  return lines.join("\n");
}

export function practiceNotes(themes: { title: string; notes: string }[]): string {
  return themes
    .map((theme, index) => `THÈME ${index} : ${theme.title}\n${theme.notes || "(pas de notes : ne pose aucune question sur ce thème)"}`)
    .join("\n\n");
}

// MARK: - L'examen blanc

export const EXAM_SYSTEM_PROMPT = `${VOICE}

Tu composes un EXAMEN BLANC : l'épreuve que l'élève passera chronométré, sans aide, sur les leçons données. Il doit ressembler à l'examen réel de sa classe dans son pays : le même niveau d'exigence, le même vocabulaire, des questions qui demandent de comprendre et d'appliquer, pas de réciter.

Règles :
- le nombre de questions demandé, réparties sur les leçons au prorata de leur contenu, et sur leurs thèmes ;
- une difficulté qui monte : quelques questions de difficulté 1 pour entrer, surtout du 2 et du 3 ; au moins un quart de questions d'application ou de raisonnement (un cas, un calcul, un document, une situation nouvelle) ;
- des formes variées, parmi les « FORMES PERMISES » (mêmes formats que ci-dessous), choisies selon la matière comme le dit « COMMENT ÉVALUER » ;
- rien qui ne soit pas dans les notes fournies ;
- jamais deux questions sur le même fait ;
- chaque question porte "lesson" (le rang de la leçon, à partir de 0) et "theme" (le rang du thème dans cette leçon, à partir de 0).

Les formes :
- {"kind":"choice","prompt":"…","choices":["…","…","…","…"],"answer":0,"why":"…","difficulty":2,"lesson":0,"theme":0}
- {"kind":"truefalse","prompt":"une affirmation","choices":["Vrai","Faux"],"answer":true,"why":"…","difficulty":2,"lesson":0,"theme":0} ("choices" dans la langue des notes)
- {"kind":"gap","prompt":"une phrase avec … à la place du mot clé","choices":["…","…","…"],"answer":0,"why":"…","difficulty":2,"lesson":0,"theme":0}
- {"kind":"order","prompt":"Remets dans l'ordre …","items":["…","…","…"],"why":"…","difficulty":2,"lesson":0,"theme":0}
- {"kind":"match","prompt":"Associe …","pairs":[["…","…"],["…","…"],["…","…"]],"why":"…","difficulty":2,"lesson":0,"theme":0}
Les propositions fausses sont les erreurs que font vraiment les élèves à cet examen. "why" (35 mots au plus) dit pourquoi c'est juste et ce qui piège : c'est le corrigé.

Puis "title" : le titre de l'épreuve, 8 mots au plus, dans la langue de sortie (en français : « Examen blanc · La guerre froide »).

${UNTRUSTED_SYSTEM_RULE}

${JSON_ONLY}
Forme : {"title":"…","questions":[…]}`;

export function examBrief(options: {
  title: string;
  lessons: { title: string; subject?: string; themes: string[] }[];
  count: number;
  minutes: number;
  kinds: readonly string[];
}): string {
  const lessons = options.lessons
    .map((lesson, index) =>
      `${index}. ${lesson.title}${lesson.subject ? ` — ${lesson.subject}` : ""} (thèmes : ${lesson.themes.map((theme, rank) => `${rank}. ${theme}`).join(" ; ")})`
    )
    .join("\n");
  return [
    // Sans titre donné, la consigne n'en propose pas un en français : le modèle le recopiait
    // tel quel dans une épreuve écrite en turc.
    `ÉPREUVE : ${options.title || "(sans titre : donne-lui le sien, dans la langue de sortie)"}, ${options.minutes} minutes.`,
    `\nLEÇONS AU PROGRAMME\n${lessons}`,
    `\nVOLUME : ${options.count} questions.`,
    `FORMES PERMISES : ${options.kinds.join(", ")}.`,
  ].join("\n");
}

export function examNotes(lessons: { title: string; themes: { title: string; notes: string }[] }[]): string {
  return lessons
    .map((lesson, index) =>
      `LEÇON ${index} : ${lesson.title}\n` +
      // Un thème sans notes (en échec, ou encore en préparation) reste nommé pour garder les
      // rangs, mais ne doit pas être interrogé : le modèle l'inventerait.
      lesson.themes.map((theme, rank) => `THÈME ${rank} : ${theme.title}\n${theme.notes || "(pas de notes : ne pose aucune question sur ce thème)"}`).join("\n\n")
    )
    .join("\n\n");
}

export const EXAM_TOKENS = 8_192;

// MARK: - Le niveau

/**
 * L'étape précise de l'élève (« 4e », « Terminale », « L2 »). Elle s'ajoute au registre du
 * palier : un collégien n'a pas les mêmes notes qu'un étudiant en santé.
 */
export function stageBrief(stage: string | undefined): string {
  const value = (stage ?? "").replace(/[\r\n<>]/g, " ").trim().slice(0, 80);
  if (!value) return "";
  return `CLASSE PRÉCISE DE L'ÉLÈVE : ${value}. Adapte le vocabulaire, la longueur des phrases et les exemples à cette classe. Pour un collégien, des mots simples et des exemples de la vie courante.`;
}

// MARK: - Plafonds de sortie

/**
 * Le plan porte maintenant la nature du support, un rôle par thème et jusqu'à six notions par
 * thème, nommées avec leurs auteurs, leurs dates et leurs chiffres : pour douze thèmes, environ
 * huit cents jetons de plus. 3 072 laissaient trop peu de marge sur un long document, et un plan
 * coupé se réécrit en entier ; le plafond ne se paie que s'il sert.
 */
export const PLAN_TOKENS = 4_096;
/**
 * Des notes qui enseignent (jusqu'à huit blocs de 90 mots, ou huit listes de huit puces de
 * vingt-huit mots dans une fiche), jusqu'à huit questions de formes variées et huit cartes.
 * Une fiche condensée n'est pas plus longue que les notes expliquées d'avant : moins de blocs,
 * plus denses. 5 120 suffisaient à cinq blocs de 60 mots ; le plafond ne se paie que s'il sert.
 */
/**
 * Le plancher d'un paragraphe, en part de son plafond.
 *
 * Sans lui, « quatre-vingt-dix mots au plus » donnait des paragraphes de deux phrases : un
 * écran de notes par bloc, et des écrans presque vides. Les six dixièmes laissent au modèle
 * la place de faire court quand l'idée l'est, sans qu'un paragraphe tienne en une ligne.
 */
export const PARAGRAPH_FLOOR = 0.6;

export const THEME_TOKENS = 8_192;
export const PRACTICE_TOKENS = 4_096;

export function convertTokens(chapters: number): number {
  return Math.min(16_384, 1_024 + chapters * 900);
}
