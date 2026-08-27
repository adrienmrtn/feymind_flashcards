/**
 * L'emoji d'un cours, porté depuis `CourseEmoji` dans
 * `Micabo/DesignSystem/Components/MicaboCover.swift`.
 *
 * **Une matière, un emoji.** La table servait autrefois le même dessin à six matières
 * voisines : quatre matières de santé pour un stéthoscope, dix langues pour une bouche qui
 * parle. Sur l'écran des matières, où une quarantaine de pastilles s'enroulent en sept familles,
 * un emoji répété n'accroche plus rien - il fait relire les libellés un par un, ce qui est
 * exactement le travail qu'il devait éviter.
 *
 * **L'ordre de la table est sa règle** : la première correspondance gagne, donc une entrée large
 * ne passe jamais avant une entrée précise. « Code de la route » contient « code », et sortait un
 * ordinateur portable. Les mots les plus généraux - « langue », « genie », « arts » - ferment donc
 * la liste, derrière les matières qu'ils englobent.
 *
 * Il vit dans le noyau partagé parce que le web en a besoin **deux fois** : sur l'écran des
 * matières du parcours d'accueil, et sur chaque cours importé. Deux tables tenues en parallèle
 * finiraient par donner à une matière un emoji que ses cours n'ont pas.
 */

export const FALLBACK_EMOJI = "📘";

/** Sans accents et en minuscules, comme le `folding` de Swift. */
function fold(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

/** Ordonné : la première correspondance gagne, du plus spécifique au plus large. */
const TABLE: readonly [string, readonly string[]][] = [
  // Langues vivantes : un drapeau se reconnaît sans lire, et c'est justement à ça que sert un
  // emoji sur une pastille.
  ["🇫🇷", ["francais"]],
  ["🇬🇧", ["anglais", "english"]],
  ["🇪🇸", ["espagnol"]],
  ["🇩🇪", ["allemand"]],
  ["🇮🇹", ["italien"]],
  ["🇵🇹", ["portugais"]],
  ["🇯🇵", ["japonais"]],
  ["🇨🇳", ["chinois", "mandarin"]],
  ["🇷🇺", ["russe"]],
  ["🇸🇦", ["arabe"]],
  // Les langues anciennes n'ont pas de drapeau : l'amphore dit l'antiquité mieux que le drapeau
  // d'un pays qui n'existait pas.
  ["🏺", ["latin", "grec"]],

  // Sciences
  ["🧪", ["chimie", "molecul", "reaction"]],
  ["🧬", ["biolog", "genet", "cellul", "svt", "adn"]],
  ["🌿", ["botan", "ecolog", "plante", "photosynth", "environnement"]],
  ["🔭", ["astronom", "astrophys", "cosmolog"]],
  ["🪨", ["geolog", "mineral", "tectoniq"]],
  ["📊", ["statistique", "probabilit", "econometr"]],
  ["📐", ["math", "geometr", "algebr", "analyse", "trigonom"]],
  ["⚛️", ["physique", "quantique", "thermodynam", "optique"]],

  // Santé
  ["🫀", ["anatomie", "physiolog", "cardio"]],
  ["💊", ["pharmac", "posolog"]],
  ["🥗", ["nutrition", "dietet"]],
  ["🦴", ["kinesi", "osteo", "orthoped", "rhumatolog"]],
  ["🏥", ["infirm", "soins", "hospital"]],
  ["🩺", ["medecine", "sante", "clinique", "semiolog"]],

  // Technique
  ["🧩", ["algorithm", "complexite", "structures de donnees"]],
  ["🌐", ["reseau", "internet", "protocole"]],
  ["🔌", ["electron", "electricite", "circuit"]],
  ["⚙️", ["mecanique", "cinematique", "statique"]],
  ["💻", ["informat", "programm", "logiciel", "donnees", "python", "java"]],
  ["🏢", ["architecture", "urbanis"]],
  ["🏗️", ["genie civil", "materiaux", "construction", "beton", "ingenier", "genie"]],

  // Sciences humaines
  ["🏛️", ["histoire", "antiquite", "revolution", "guerre", "civilisation"]],
  ["🗳️", ["sciences politiques", "science politique", "institution", "electoral"]],
  ["👥", ["sociolog", "anthropolog", "demograph"]],
  ["🤔", ["philo", "epistemolog", "metaphysiq", "ethique"]],
  ["🧠", ["psycho", "cognit", "neuro"]],
  ["🗺️", ["geograph", "territoire", "climat"]],
  ["🌍", ["geopolit", "international", "europe"]],

  // Droit et économie
  ["⚖️", ["droit", "juridique", "constitution", "penal", "civil"]],
  ["🧾", ["comptab", "bilan", "fiscal"]],
  ["📈", ["finance", "boursier", "investissement"]],
  ["📣", ["marketing", "communication", "publicite"]],
  ["🧑‍💼", ["management", "gestion", "ressources humaines", "entrepreneur"]],
  ["💰", ["economie", "monetaire", "commerce"]],

  // Et le reste
  ["🚗", ["code de la route", "permis", "conduite"]],
  ["🏃", ["sport", "staps", "athletisme", "entrainement physique"]],
  ["🎬", ["cinema", "audiovisuel", "montage"]],
  ["🎵", ["musique", "solfege", "harmonie"]],
  ["🎭", ["theatre"]],
  ["💃", ["danse"]],
  ["📷", ["photographie", "photo"]],
  ["📰", ["journalisme"]],
  ["🎒", ["pedagogie", "education"]],
  ["🌾", ["agronomie", "agriculture"]],
  ["✈️", ["aeronautique", "aviation"]],
  ["🎨", ["arts", "dessin", "design", "peinture"]],
  ["📖", ["litterature", "poesie", "roman"]],
  ["💡", ["culture generale", "actualite"]],
  // Le filet de sécurité des langues : il attrape « LV2 », « vocabulaire », « thème
  // grammatical » - tout ce qui parle de langue sans nommer laquelle.
  //
  // Le radical est `grammat` et non `grammaire` : c'est le port de cette table qui a montré que
  // l'exemple donné par le commentaire d'origine ne passait pas, et que le test iOS qui le
  // vérifie échouait. Corrigé des deux côtés dans la même journée.
  ["🗣️", ["langue", "vocabulaire", "grammat", "conjugaison"]],
];

export function deriveEmoji(subject: string | null | undefined, title: string): string {
  const haystack = fold([subject ?? "", title].join(" "));

  for (const [emoji, keywords] of TABLE) {
    if (keywords.some((keyword) => haystack.includes(keyword))) return emoji;
  }
  return FALLBACK_EMOJI;
}

/**
 * L'emoji retenu pour un cours : celui que le modèle a proposé s'il en vaut un, sinon celui que
 * la table déduit. Le livre générique et le crayon ne comptent pas comme des propositions.
 */
export function resolveEmoji(
  proposed: string | null | undefined,
  subject: string | null | undefined,
  title: string,
): string {
  const clean = proposed?.trim();
  if (clean && clean !== FALLBACK_EMOJI && clean !== "📝") return clean;
  return deriveEmoji(subject, title);
}
