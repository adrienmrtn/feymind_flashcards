/**
 * **La nature du support, et ce qu'elle change au plan et aux notes.**
 *
 * Un chapitre en trois parties, une dissertation, un sujet d'examen et la transcription d'une
 * vidéo YouTube ne se révisent pas de la même façon. Avec un seul gabarit, ils donnaient la même
 * leçon : quatre à huit thèmes découpés à l'aveugle, le même squelette de notes. Le plan
 * reconnaît donc le support (`material`) et construit ses thèmes sur SA structure ; chaque thème
 * reçoit un rôle (`role`) : décrypter le sujet, une partie, un exercice, la méthode de l'épreuve,
 * les concepts-clés.
 *
 * **Le chemin jusqu'aux thèmes.** Les apps déjà publiées ne renvoient au thème que ce qu'elles
 * connaissaient (le titre, les thèmes, les notions, la matière, la source et le texte de
 * référence). Le texte de référence (`contextText`) est rendu par le plan et renvoyé tel quel à
 * chaque thème : la nature du support et les rôles y voyagent, en tête, sur deux lignes lisibles
 * (`materialHeader`). Le thème les relit (`readMaterialHeader`) ; sans elles (une leçon d'avant,
 * une leçon sans document), il les devine (`guessMaterial`, `guessRole`). Les autres lecteurs de
 * ce texte (Mika, l'explication d'un passage, l'examen blanc) sont des modèles : deux lignes qui
 * disent la nature du support ne les gênent pas, elles les aident.
 *
 * Tout est pur et testé (`material.test.ts`).
 */
import type { NoteRegister } from "../_shared/learner.ts";

/**
 * Les natures de support. `chapter` un cours rédigé avec ses parties ; `essay` une dissertation,
 * une copie, un corrigé rédigé ; `exam` un sujet d'examen, des annales, une feuille d'exercices ;
 * `lecture` la transcription d'un cours oral, d'une vidéo, d'un podcast ; `slides` des
 * diapositives ; `notes` des notes personnelles ; `article` un article ou un extrait d'ouvrage ;
 * `topic` aucun document, un sujet tapé.
 */
export type Material = "chapter" | "essay" | "exam" | "lecture" | "slides" | "notes" | "article" | "topic";

export const MATERIALS: readonly Material[] = ["chapter", "essay", "exam", "lecture", "slides", "notes", "article", "topic"];

/**
 * Le rôle d'un thème dans la leçon. `decrypt` décrypte le sujet et la problématique ; `exercise`
 * reprend un exercice d'un sujet ; `method` donne la méthode de l'épreuve ; `keyterms` rassemble
 * les concepts-clés ; `core` tout le reste (une partie, une notion).
 */
export type ThemeRole = "core" | "decrypt" | "exercise" | "method" | "keyterms";

export const THEME_ROLES: readonly ThemeRole[] = ["core", "decrypt", "exercise", "method", "keyterms"];

export type { NoteRegister };

/** Replie un texte pour la comparaison : sans accents, en minuscules. */
function fold(value: string): string {
  return value.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

/** Les noms qu'un modèle donne parfois à un support, ramenés aux huit de la leçon. */
const MATERIAL_ALIASES = new Map<string, Material>([
  ["course", "chapter"],
  ["cours", "chapter"],
  ["chapitre", "chapter"],
  ["lesson", "chapter"],
  ["textbook", "chapter"],
  ["manuel", "chapter"],
  ["dissertation", "essay"],
  ["copie", "essay"],
  ["corrige", "essay"],
  ["commentaire", "essay"],
  ["paper", "essay"],
  ["exams", "exam"],
  ["examen", "exam"],
  ["sujet", "exam"],
  ["annales", "exam"],
  ["exercises", "exam"],
  ["exercices", "exam"],
  ["pastpaper", "exam"],
  ["test", "exam"],
  ["video", "lecture"],
  ["youtube", "lecture"],
  ["transcript", "lecture"],
  ["transcription", "lecture"],
  ["audio", "lecture"],
  ["podcast", "lecture"],
  ["oral", "lecture"],
  ["slide", "slides"],
  ["diapositives", "slides"],
  ["diaporama", "slides"],
  ["presentation", "slides"],
  ["note", "notes"],
  ["personalnotes", "notes"],
  ["book", "article"],
  ["livre", "article"],
  ["extrait", "article"],
  ["excerpt", "article"],
  ["texte", "article"],
  ["sujetlibre", "topic"],
  ["none", "topic"],
]);

/** Une nature de support lue telle que le modèle l'écrit ; `null` quand on ne la reconnaît pas. */
export function readMaterial(raw: unknown): Material | null {
  if (typeof raw !== "string") return null;
  const key = fold(raw).replace(/[^a-z]/g, "");
  if (!key) return null;
  if ((MATERIALS as readonly string[]).includes(key)) return key as Material;
  return MATERIAL_ALIASES.get(key) ?? null;
}

const ROLE_ALIASES = new Map<string, ThemeRole>([
  ["part", "core"],
  ["partie", "core"],
  ["notion", "core"],
  ["context", "core"],
  ["subject", "decrypt"],
  ["sujet", "decrypt"],
  ["problematique", "decrypt"],
  ["intro", "decrypt"],
  ["exercice", "exercise"],
  ["question", "exercise"],
  ["methode", "method"],
  ["methodology", "method"],
  ["tips", "method"],
  ["glossary", "keyterms"],
  ["glossaire", "keyterms"],
  ["concepts", "keyterms"],
  ["terms", "keyterms"],
  ["vocabulary", "keyterms"],
  ["vocabulaire", "keyterms"],
]);

/** Le rôle d'un thème tel que le modèle l'écrit ; un rôle inconnu est `core`. */
export function readRole(raw: unknown): ThemeRole {
  if (typeof raw !== "string") return "core";
  const key = fold(raw).replace(/[^a-z]/g, "");
  if ((THEME_ROLES as readonly string[]).includes(key)) return key as ThemeRole;
  return ROLE_ALIASES.get(key) ?? "core";
}

/** Les sources orales : leur texte est une transcription, quoi que le modèle en dise. */
const ORAL_SOURCES = new Set(["youtube", "audio"]);

/**
 * **La nature du support devinée sur le texte**, quand le modèle ne l'a pas donnée (une
 * réponse sans le champ, une leçon d'avant). Prudente : un sujet d'examen et une dissertation
 * ont des marques qui ne trompent pas ; tout le reste est un chapitre, la lecture la plus sûre.
 */
export function guessMaterial(text: string, source?: string): Material {
  const origin = (source ?? "").trim().toLowerCase();
  if (origin === "topic") return "topic";
  if (ORAL_SOURCES.has(origin)) return "lecture";
  if (!text.trim()) return "topic";
  const haystack = fold(text.slice(0, 8_000));
  const examMarks = [
    /\bexercices?\s*(?:n[°o]\s*)?\d/,
    /\bexercises?\s*\d/,
    /\(\s*\d+(?:[.,]5)?\s*(?:points?|pts)\s*\)/,
    /\bbareme\b/,
    /\bduree\s*(?:de l'epreuve)?\s*:?\s*\d+\s*h/,
    /\bcalculatrice\b/,
    /\bsujet\s+(?:n[°o]\s*)?\d/,
    /\bdocuments?\s+autorises?\b/,
  ].filter((mark) => mark.test(haystack)).length;
  if (examMarks >= 2) return "exam";
  const essayMarks = [
    /\bproblematique\b/,
    /\bdissertation\b/,
    /\bcopie\b/,
    /\bannonce du plan\b/,
    /\btransition\b/,
    /^\s*(?:partie\s+)?(?:i|ii|iii)\s*[.)\-–—:]/m,
    /\bouverture\b/,
  ].filter((mark) => mark.test(haystack)).length;
  if (essayMarks >= 3) return "essay";
  return "chapter";
}

/**
 * **Le rôle d'un thème deviné sur son titre**, pour une leçon dont le plan n'a pas transmis les
 * rôles (une leçon d'avant, une leçon sans document).
 */
export function guessRole(title: string, material: Material): ThemeRole {
  const key = fold(title);
  if (/\bmethod|\bconseils?\b|\brepere?s? pour la copie|\bpieges? de l'epreuve/.test(key)) return "method";
  if (/concepts?[- ]cles?|notions?[- ]cles?|\bkey terms\b|\blexique\b|\bglossaire\b|\bvocabulaire\b/.test(key)) return "keyterms";
  if ((material === "essay" || material === "exam") && /\bdecrypt|\bproblematique\b|\bcomprendre le sujet\b/.test(key)) return "decrypt";
  if (material === "exam" && /\bexercices?\b|\bexercises?\b/.test(key)) return "exercise";
  return "core";
}

/**
 * Le rôle `method` n'a sa place que dans une leçon tournée vers l'épreuve : un support d'examen
 * ou une copie, ou un élève qui prépare un examen. Ailleurs, le thème garde sa place et devient
 * un thème ordinaire.
 */
export function allowedRole(role: ThemeRole, material: Material, examOriented: boolean): ThemeRole {
  if (role === "method" && !examOriented && material !== "essay" && material !== "exam") return "core";
  // Un sujet de dissertation tapé tel quel se décrypte aussi ; un cours, une vidéo, non.
  if (role === "decrypt" && material !== "essay" && material !== "exam" && material !== "topic") return "core";
  if (role === "exercise" && material !== "exam") return "core";
  return role;
}

// MARK: - Le chemin jusqu'aux thèmes

const HEADER_MATERIAL = "NATURE DU SUPPORT : ";
const HEADER_ROLES = "RÔLES DES THÈMES : ";
const HEADER = /^NATURE DU SUPPORT : ([a-z]+)[^\n]*\n(?:R[ÔO]LES DES TH[ÈE]MES : ([a-z ,]*)\n)?\n?/;

/**
 * Les deux lignes qui ouvrent le texte de référence. Pas de `*` ni de `_` : l'app iOS les retire
 * de certains textes, et la ligne doit revenir intacte.
 */
export function materialHeader(material: Material, roles: readonly ThemeRole[]): string {
  return `${HEADER_MATERIAL}${material}\n${HEADER_ROLES}${roles.join(" ")}\n\n`;
}

/**
 * Le texte de référence renvoyé par l'app, séparé de ses deux lignes d'en-tête. Sans en-tête,
 * le texte revient tel quel et la nature reste à deviner.
 */
export function readMaterialHeader(context: string): { material?: Material; roles?: ThemeRole[]; text: string } {
  const match = HEADER.exec(context);
  if (!match) return { text: context };
  const material = readMaterial(match[1]);
  const roles = (match[2] ?? "").split(/[\s,]+/).filter(Boolean).map(readRole);
  const text = context.slice(match[0].length);
  const out: { material?: Material; roles?: ThemeRole[]; text: string } = { text };
  if (material) out.material = material;
  if (roles.length) out.roles = roles;
  return out;
}

// MARK: - Le plan

/**
 * **Reconnaître le support, et construire le plan sur sa structure.** C'est la partie fixe du
 * prompt du plan : elle va dans le prompt système, qui se met en cache.
 */
export const MATERIAL_PLAN_RULES = `D'ABORD, RECONNAIS LE SUPPORT ("material"), PUIS CONSTRUIS LE PLAN SUR SA STRUCTURE. Deux supports différents donnent deux plans différents : jamais le même gabarit.
- "chapter" : un chapitre ou un cours rédigé, avec ses parties. Les thèmes suivent ses parties et sous-parties, dans son ordre, sous des titres proches des siens. Ne redécoupe pas arbitrairement et ne fusionne jamais deux parties distinctes : une partie trop longue se partage en deux thèmes qui se suivent, deux sous-parties très courtes d'une même partie peuvent faire un thème.
- "essay" : une dissertation, une copie, un corrigé rédigé, un commentaire. Dans l'ordre : un thème "decrypt" (les mots-clés du sujet définis, la problématique, l'annonce du plan) ; un thème de repères s'il y en a (définition chiffrée, indicateur, chronologie) ; UN thème par partie du plan (I, II, III), titré comme la partie (« I. Une fin apparente ») ; un thème "method" (« Méthode pour la copie ») ; un thème "keyterms" (« Concepts-clés »).
- "exam" : un sujet d'examen, des annales, une feuille d'exercices, un QCM. Un thème "exercise" par exercice ou par notion testée, dans l'ordre du sujet (ce qu'il faut savoir, la méthode, la réponse attendue) ; puis un thème "method" (« Méthode et pièges de l'épreuve »).
- "lecture" : la transcription d'une vidéo, d'un cours oral, d'un podcast. Suis la progression de l'exposé, mais en notions propres : sans les digressions, les répétitions, les apartés ni les formules d'oral ; ce qui est dit en plusieurs fois se regroupe. Un thème est une notion, jamais une tranche de minutes.
- "slides" : des diapositives. Une diapositive n'est pas un thème : regroupe-les par notion, dans l'ordre de la présentation.
- "notes" : des notes personnelles, souvent en vrac. Remets-les dans l'ordre logique : définitions, mécanismes, applications.
- "article" : un article, un extrait d'ouvrage, un texte à étudier. Le contexte et l'enjeu, la thèse, chaque argument avec ses preuves, puis les limites ou les critiques.
- "topic" : aucun document, un sujet tapé. L'ordre canonique du programme de CETTE classe sur ce sujet. Quand le sujet tapé est un sujet de dissertation (une question à traiter), construis-le comme "essay" : "decrypt", une partie par thème, "method", "keyterms".
Chaque thème porte un "role" : "decrypt" (décrypter le sujet, pour "essay", "exam" ou un sujet de dissertation tapé), "exercise" (un exercice du sujet, pour "exam"), "method" (la méthode de l'épreuve), "keyterms" (les concepts-clés, en dernier) ou "core" (tout le reste). "method" seulement pour "essay" et "exam", ou quand « ORIENTATION EXAMEN » le permet. "keyterms" seulement quand la leçon a au moins six termes à maîtriser.
COUVERTURE : presque tout ce que dit le support doit se retrouver dans un thème : chaque partie, chaque auteur, chaque date, chaque chiffre, chaque exemple. Condense, n'omets pas. Les "points" d'un thème nomment ce qu'il reprend du support.`;

/**
 * La partie variable : ce qu'on sait déjà du support (la source, une première lecture du
 * texte), le registre des notes et l'orientation vers l'épreuve.
 */
export function planMaterialBrief(options: {
  guess: Material;
  fromScratch: boolean;
  register: NoteRegister;
  examOriented: boolean;
}): string {
  const lines = ["LE SUPPORT ET LA FORME DE LA LEÇON"];
  if (options.fromScratch) {
    lines.push(`Il n'y a pas de document : "material" vaut "topic".`);
  } else if (options.guess === "lecture") {
    lines.push(`Le texte est la transcription d'une vidéo ou d'un enregistrement : "material" vaut "lecture".`);
  } else {
    lines.push(`Première lecture du texte : "${options.guess}". Corrige-la si le document dit autre chose (ses titres, sa consigne, sa mise en page).`);
  }
  lines.push(`FORMAT DES NOTES : ${REGISTER_NAMES[options.register]}.`);
  lines.push(
    options.examOriented
      ? `ORIENTATION EXAMEN : oui. L'élève prépare une épreuve : un thème "method" final est permis même pour un cours, quand le support donne de la méthode ou que l'épreuve en demande une précise.`
      : `ORIENTATION EXAMEN : non. Pas de thème "method", sauf pour un support "essay" ou "exam".`,
  );
  return lines.join("\n");
}

const REGISTER_NAMES: Record<NoteRegister, string> = {
  fiche: "fiche condensée de niveau avancé (des puces denses, chaque ligne porte une information)",
  explained: "notes structurées et expliquées (des paragraphes courts, des puces, un exemple travaillé)",
  guided: "notes guidées pas à pas (des mots simples, une idée par bloc, des exemples de la vie courante)",
};

// MARK: - Un thème

/** Ce que la nature du support change à l'écriture d'un thème ordinaire (`core`). */
const MATERIAL_THEME: Record<Material, string> = {
  chapter: `Le support est un CHAPITRE DE COURS. Ce thème reprend sa partie : suis son ordre et ses intitulés, garde ses définitions, ses exemples et ses chiffres.`,
  essay: `Le support est une DISSERTATION ou une COPIE. Ce thème est une étape de son raisonnement : chaque argument garde son auteur, son année, son exemple et son chiffre ; la dernière puce tire la conclusion de la partie (« **Ainsi** : … »).`,
  exam: `Le support est un SUJET D'EXAMEN. Ce thème donne ce que l'épreuve teste sur cette notion : ce qu'il faut savoir, la méthode, la réponse attendue, le piège qui coûte des points.`,
  lecture: `Le support est la TRANSCRIPTION d'un exposé oral. Remets au propre ce que dit l'orateur : sans hésitations, digressions ni répétitions ; garde ses exemples, ses chiffres et ses noms, corrige les mots mal transcrits quand le sens est certain.`,
  slides: `Le support est un jeu de DIAPOSITIVES, elliptique. Rétablis les liens entre les puces (pourquoi, donc, à condition que) sans rien inventer au-delà de ce que les diapositives permettent d'affirmer.`,
  notes: `Le support est fait de NOTES PERSONNELLES. Remets-les en ordre, développe les abréviations quand leur sens est certain, et laisse de côté ce qui est illisible plutôt que de le deviner.`,
  article: `Le support est un ARTICLE ou un EXTRAIT D'OUVRAGE. Distingue la thèse de l'auteur, ses arguments et ses preuves ; nomme l'auteur quand une idée est la sienne.`,
  topic: `Il n'y a pas de document : ce thème suit le programme de la classe de l'élève sur ce sujet.`,
};

/** Ce que le rôle du thème lui demande, quelle que soit la marche. */
const ROLE_THEME: Record<Exclude<ThemeRole, "core">, string> = {
  decrypt: `CE THÈME DÉCRYPTE LE SUJET. Une "list" dont chaque puce définit un mot-clé du sujet tel qu'il faut l'entendre ici (« **Ouverture commerciale** : … »), puis la problématique en une phrase (un "callout" "remember" ou une puce « **Problématique** : … »), puis l'annonce du plan, une puce par partie (« **I.** … »). Dis pourquoi la réponse n'est ni oui ni non quand c'est le cas.`,
  exercise: `CE THÈME REPREND UN EXERCICE DU SUJET. Ce que l'exercice teste (la notion, en une "definition" ou une puce), la méthode en "steps" résolus jusqu'au résultat, la réponse attendue telle qu'un correcteur la veut, et le piège qui coûte des points dans un "callout" "mistake".`,
  method: `CE THÈME DONNE LA MÉTHODE DE L'ÉPREUVE. Une ou deux "list" dont chaque puce commence par son repère : **Plan** ou **Schéma** (la structure attendue), **Citations** (les auteurs et les années à placer, tirés de la leçon), **Équilibre** (entre les parties ou les exercices), **Gestion du temps** (des minutes précises par étape), **Style** ou **Pièges** (ce qui fait perdre des points). Rien de vague : chaque puce se met en pratique telle quelle le jour de l'épreuve.`,
  keyterms: `CE THÈME RASSEMBLE LES CONCEPTS-CLÉS DE LA LEÇON. Un "table" à deux colonnes (Terme, Définition), une rangée par terme, et une "list" « **terme** : définition » pour ceux qui ne tiennent pas dans le tableau. Seulement des termes de la leçon, avec la définition exacte qu'attend l'épreuve ; pas de paragraphe.`,
};

/** Comment écrire selon le registre : une fiche dense, des notes expliquées, des notes guidées. */
const REGISTER_THEME: Record<NoteRegister, string> = {
  fiche: `STYLE DES NOTES : FICHE CONDENSÉE (niveau avancé). Presque tout s'écrit en "list" : chaque puce commence par **un terme de tête** suivi de « : », puis l'information, en une ou deux lignes : une définition exacte, un mécanisme en une ligne (« car », « donc », « → »), un auteur et son année (« **Rodrik (2024)** : … »), un chiffre avec son unité et son année, un exemple nommé. Une chronologie s'écrit en "dates" (l'année, puis le fait et son chiffre). Une formule ou un indicateur dans une "formula", avec ce que veut dire chaque lettre. Un "subtitle" ouvre chaque partie du thème. Un paragraphe au plus, de deux phrases, pour cadrer ; pas d'accroche ni d'analogie. Garde tout ce que le support dit sur ce thème : condense, ne supprime pas ; les noms, les dates et les chiffres restent exacts.`,
  explained: `STYLE DES NOTES : STRUCTURÉES ET EXPLIQUÉES. Des sous-titres, des paragraphes courts (deux ou trois phrases) qui expliquent le pourquoi, des "list" dont les puces commencent par **un terme de tête** suivi de « : », et un exemple travaillé. Le vocabulaire exact du programme, expliqué la première fois.`,
  guided: `STYLE DES NOTES : GUIDÉES. Une idée par bloc, des mots simples, des paragraphes courts qui expliquent, un exemple de la vie courante pour chaque notion, et une "list" courte pour ce qu'il faut retenir.`,
};

/**
 * **La consigne de forme d'un thème** : la nature du support, le rôle du thème dans la leçon,
 * puis le registre de la marche. Le rôle passe avant le registre : un thème de concepts-clés
 * reste un tableau, même pour un collégien.
 */
export function materialThemeBrief(options: {
  material: Material;
  role: ThemeRole;
  register: NoteRegister;
  examOriented: boolean;
}): string {
  const lines = [MATERIAL_THEME[options.material]];
  if (options.role !== "core") lines.push(ROLE_THEME[options.role]);
  lines.push(REGISTER_THEME[options.register]);
  if (options.examOriented && options.role !== "method" && options.material !== "essay" && options.material !== "exam") {
    lines.push(`L'élève prépare une épreuve : quand ce thème a un réflexe de méthode qui rapporte des points, un "callout" "tip" le donne en une ou deux phrases.`);
  }
  return lines.join("\n");
}

/**
 * Vrai quand la leçon se lit en vue d'une épreuve : un examen nommé, une marche de concours ou
 * de santé, la prépa, ou le stress de l'examen.
 */
export function isExamOriented(learner: { tier: string; exam?: string; worries?: readonly string[] }): boolean {
  if (learner.exam) return true;
  if (learner.tier === "competitive" || learner.tier === "health" || learner.tier === "preUniversity") return true;
  return (learner.worries ?? []).includes("examStress");
}
