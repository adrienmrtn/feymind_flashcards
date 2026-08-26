/**
 * Le palier d'études, **tel qu'il se nomme là où l'étudiant étudie.**
 *
 * Porté depuis `Micabo/Features/Onboarding/EducationStage.swift`.
 *
 * « Prépa », « PASS » et « les attendus du bac » ne veulent rien dire hors de France, et un
 * Américain à qui on propose « Licence » ne se reconnaît dans aucune réponse. La question est donc
 * posée **après** le pays, et ses réponses sont celles du système scolaire choisi.
 *
 * Chaque palier porte deux clés qui ne servent pas à la même chose. Son `level` est le **registre
 * de rédaction** envoyé à l'Edge Function, volontairement grossier parce qu'un cégep québécois et
 * un lycée français demandent la même écriture. Son `tier` est la **marche sur une échelle
 * comparable d'un pays à l'autre**, qui sert à retrouver l'équivalent quand on change de pays — le
 * registre ne pouvait pas s'en charger, un lycéen et un collégien le partageant.
 */

import type { CountryCode } from "./countries";

/** Le registre de rédaction, et c'est la colonne `profiles.study_level`. */
export type StudyLevel = "lycee" | "prepa" | "licence" | "sante" | "master" | "concours" | "other";

/**
 * Le palier ramené à une échelle comparable d'un pays à l'autre.
 *
 * **L'ordre est celui de l'échelle**, du plus bas au plus haut. Les trois derniers n'en font pas
 * partie, et c'est volontaire : la santé, les concours et « autre » sont des voies, pas des
 * marches. Un étudiant en santé ne devient pas « undergraduate » parce que son pays d'accueil n'a
 * pas de filière santé nommée.
 */
export type EducationTier =
  | "lowerSecondary"
  | "upperSecondary"
  | "preUniversity"
  | "undergraduate"
  | "graduate"
  | "health"
  | "competitive"
  | "other";

/** Les marches de l'échelle, de la plus basse à la plus haute. */
export const TIER_LADDER: readonly EducationTier[] = [
  "lowerSecondary",
  "upperSecondary",
  "preUniversity",
  "undergraduate",
  "graduate",
];

export interface EducationStage {
  /** Stable et préfixé par le pays : `fr.prepa`, `us.college`. */
  id: string;
  title: string;
  emoji: string;
  level: StudyLevel;
  tier: EducationTier;
}

function stage(
  id: string,
  title: string,
  emoji: string,
  level: StudyLevel,
  tier: EducationTier,
): EducationStage {
  return { id, title, emoji, level, tier };
}

/**
 * L'échelle générique, en anglais, pour un pays dont on ne connaît pas le système.
 *
 * Délibérément courte : inventer des paliers pour un pays qu'on ne connaît pas produirait des
 * réponses fausses, et une réponse fausse est pire qu'une réponse large.
 */
const GENERIC_STAGES: EducationStage[] = [
  stage("generic.middle", "Middle school", "🎒", "lycee", "lowerSecondary"),
  stage("generic.high", "High school", "🏫", "lycee", "upperSecondary"),
  stage("generic.college", "College", "🎓", "licence", "undergraduate"),
  stage("generic.university", "University", "🔬", "master", "graduate"),
  stage("generic.other", "Other", "✨", "other", "other"),
];

/**
 * Les paliers proposés par pays. Chaque liste se termine par une sortie : un système scolaire ne
 * se résume jamais à cinq lignes, et un écran de question sans réponse possible se quitte en
 * quittant le site.
 */
/**
 * Les paliers des pays européens sont écrits **dans leur langue**, et pas traduits : un lycéen
 * polonais cherche « Liceum », pas « Lycée ». C'est la même règle que pour « A-Levels » ou
 * « Cégep », qui n'ont jamais eu de traduction non plus. Portés depuis `EducationStage.swift`.
 */
const STAGES: Record<CountryCode, EducationStage[]> = {
  de: [
    stage("de.mittelstufe", "Mittelstufe", "🎒", "lycee", "lowerSecondary"),
    stage("de.abitur", "Gymnasium, Abitur", "🏫", "lycee", "upperSecondary"),
    stage("de.bachelor", "Bachelor", "🎓", "licence", "undergraduate"),
    stage("de.medizin", "Medizin", "🩺", "sante", "health"),
    stage("de.master", "Master", "🔬", "master", "graduate"),
    stage("de.other", "Sonstiges", "✨", "other", "other"),
  ],
  it: [
    stage("it.medie", "Scuola media", "🎒", "lycee", "lowerSecondary"),
    stage("it.liceo", "Liceo, maturità", "🏫", "lycee", "upperSecondary"),
    stage("it.triennale", "Laurea triennale", "🎓", "licence", "undergraduate"),
    stage("it.medicina", "Medicina", "🩺", "sante", "health"),
    stage("it.magistrale", "Laurea magistrale", "🔬", "master", "graduate"),
    stage("it.other", "Altro", "✨", "other", "other"),
  ],
  es: [
    stage("es.eso", "ESO", "🎒", "lycee", "lowerSecondary"),
    stage("es.bachillerato", "Bachillerato", "🏫", "lycee", "upperSecondary"),
    stage("es.grado", "Grado", "🎓", "licence", "undergraduate"),
    stage("es.medicina", "Medicina", "🩺", "sante", "health"),
    stage("es.master", "Máster", "🔬", "master", "graduate"),
    stage("es.other", "Otro", "✨", "other", "other"),
  ],
  pt: [
    stage("pt.basico", "Ensino básico", "🎒", "lycee", "lowerSecondary"),
    stage("pt.secundario", "Ensino secundário", "🏫", "lycee", "upperSecondary"),
    stage("pt.licenciatura", "Licenciatura", "🎓", "licence", "undergraduate"),
    stage("pt.medicina", "Medicina", "🩺", "sante", "health"),
    stage("pt.mestrado", "Mestrado", "🔬", "master", "graduate"),
    stage("pt.other", "Outro", "✨", "other", "other"),
  ],
  cz: [
    stage("cz.zakladni", "Základní škola", "🎒", "lycee", "lowerSecondary"),
    stage("cz.maturita", "Gymnázium, maturita", "🏫", "lycee", "upperSecondary"),
    stage("cz.bakalar", "Bakalářské studium", "🎓", "licence", "undergraduate"),
    stage("cz.medicina", "Medicína", "🩺", "sante", "health"),
    stage("cz.magistr", "Magisterské studium", "🔬", "master", "graduate"),
    stage("cz.other", "Jiné", "✨", "other", "other"),
  ],
  nl: [
    stage("nl.onderbouw", "Onderbouw", "🎒", "lycee", "lowerSecondary"),
    stage("nl.eindexamen", "Havo, vwo", "🏫", "lycee", "upperSecondary"),
    stage("nl.bachelor", "Bachelor", "🎓", "licence", "undergraduate"),
    stage("nl.geneeskunde", "Geneeskunde", "🩺", "sante", "health"),
    stage("nl.master", "Master", "🔬", "master", "graduate"),
    stage("nl.other", "Anders", "✨", "other", "other"),
  ],
  gr: [
    stage("gr.gymnasio", "Γυμνάσιο", "🎒", "lycee", "lowerSecondary"),
    stage("gr.lykeio", "Λύκειο, Πανελλήνιες", "🏫", "lycee", "upperSecondary"),
    stage("gr.ptychio", "Πτυχίο", "🎓", "licence", "undergraduate"),
    stage("gr.iatriki", "Ιατρική", "🩺", "sante", "health"),
    stage("gr.metaptychiako", "Μεταπτυχιακό", "🔬", "master", "graduate"),
    stage("gr.other", "Άλλο", "✨", "other", "other"),
  ],
  hu: [
    stage("hu.altalanos", "Általános iskola", "🎒", "lycee", "lowerSecondary"),
    stage("hu.erettsegi", "Gimnázium, érettségi", "🏫", "lycee", "upperSecondary"),
    stage("hu.alapkepzes", "Alapképzés", "🎓", "licence", "undergraduate"),
    stage("hu.orvosi", "Orvostudomány", "🩺", "sante", "health"),
    stage("hu.mesterkepzes", "Mesterképzés", "🔬", "master", "graduate"),
    stage("hu.other", "Egyéb", "✨", "other", "other"),
  ],
  pl: [
    stage("pl.podstawowa", "Szkoła podstawowa", "🎒", "lycee", "lowerSecondary"),
    stage("pl.matura", "Liceum, matura", "🏫", "lycee", "upperSecondary"),
    stage("pl.licencjat", "Licencjat", "🎓", "licence", "undergraduate"),
    stage("pl.medycyna", "Medycyna", "🩺", "sante", "health"),
    stage("pl.magister", "Studia magisterskie", "🔬", "master", "graduate"),
    stage("pl.other", "Inne", "✨", "other", "other"),
  ],
  ro: [
    stage("ro.gimnaziu", "Gimnaziu", "🎒", "lycee", "lowerSecondary"),
    stage("ro.bacalaureat", "Liceu, bacalaureat", "🏫", "lycee", "upperSecondary"),
    stage("ro.licenta", "Licență", "🎓", "licence", "undergraduate"),
    stage("ro.medicina", "Medicină", "🩺", "sante", "health"),
    stage("ro.master", "Master", "🔬", "master", "graduate"),
    stage("ro.other", "Altele", "✨", "other", "other"),
  ],
  se: [
    stage("se.grundskola", "Grundskola", "🎒", "lycee", "lowerSecondary"),
    stage("se.gymnasium", "Gymnasium", "🏫", "lycee", "upperSecondary"),
    stage("se.kandidat", "Kandidatexamen", "🎓", "licence", "undergraduate"),
    stage("se.lakarprogrammet", "Läkarprogrammet", "🩺", "sante", "health"),
    stage("se.master", "Masterexamen", "🔬", "master", "graduate"),
    stage("se.other", "Annat", "✨", "other", "other"),
  ],
  tr: [
    stage("tr.ortaokul", "Ortaokul", "🎒", "lycee", "lowerSecondary"),
    stage("tr.lise", "Lise, YKS", "🏫", "lycee", "upperSecondary"),
    stage("tr.lisans", "Lisans", "🎓", "licence", "undergraduate"),
    stage("tr.tip", "Tıp", "🩺", "sante", "health"),
    stage("tr.yukseklisans", "Yüksek lisans", "🔬", "master", "graduate"),
    stage("tr.other", "Diğer", "✨", "other", "other"),
  ],
  fr: [
    stage("fr.lycee", "Lycée", "🎒", "lycee", "upperSecondary"),
    stage("fr.prepa", "Prépa", "📐", "prepa", "preUniversity"),
    stage("fr.licence", "Licence", "🎓", "licence", "undergraduate"),
    stage("fr.sante", "PASS, santé", "🩺", "sante", "health"),
    stage("fr.master", "Master", "🔬", "master", "graduate"),
    stage("fr.concours", "Concours", "🏁", "concours", "competitive"),
    stage("fr.other", "Autre", "✨", "other", "other"),
  ],
  be: [
    stage("be.secondaire", "Secondaire", "🎒", "lycee", "upperSecondary"),
    stage("be.bachelier", "Bachelier", "🎓", "licence", "undergraduate"),
    stage("be.medecine", "Médecine, santé", "🩺", "sante", "health"),
    stage("be.master", "Master", "🔬", "master", "graduate"),
    stage("be.concours", "Examen d'entrée", "🏁", "concours", "competitive"),
    stage("be.other", "Autre", "✨", "other", "other"),
  ],
  ch: [
    stage("ch.gymnase", "Gymnase, maturité", "🎒", "lycee", "upperSecondary"),
    stage("ch.bachelor", "Bachelor", "🎓", "licence", "undergraduate"),
    stage("ch.medecine", "Médecine, santé", "🩺", "sante", "health"),
    stage("ch.master", "Master", "🔬", "master", "graduate"),
    stage("ch.other", "Autre", "✨", "other", "other"),
  ],
  ca: [
    // « Baccalauréat » désigne ici un diplôme universitaire, pas l'examen de fin de secondaire :
    // proposer les deux sens dans la même liste serait un piège.
    stage("ca.secondaire", "Secondaire", "🎒", "lycee", "upperSecondary"),
    stage("ca.cegep", "Cégep", "📐", "lycee", "preUniversity"),
    stage("ca.bac", "Baccalauréat", "🎓", "licence", "undergraduate"),
    stage("ca.medecine", "Médecine, santé", "🩺", "sante", "health"),
    stage("ca.maitrise", "Maîtrise", "🔬", "master", "graduate"),
    stage("ca.other", "Autre", "✨", "other", "other"),
  ],
  lu: [
    stage("lu.secondaire", "Secondaire", "🎒", "lycee", "upperSecondary"),
    stage("lu.bachelor", "Bachelor", "🎓", "licence", "undergraduate"),
    stage("lu.master", "Master", "🔬", "master", "graduate"),
    stage("lu.other", "Autre", "✨", "other", "other"),
  ],
  ma: [
    stage("ma.lycee", "Lycée, bac", "🎒", "lycee", "upperSecondary"),
    stage("ma.prepa", "Prépa", "📐", "prepa", "preUniversity"),
    stage("ma.licence", "Licence", "🎓", "licence", "undergraduate"),
    stage("ma.medecine", "Médecine, santé", "🩺", "sante", "health"),
    stage("ma.master", "Master", "🔬", "master", "graduate"),
    stage("ma.concours", "Concours", "🏁", "concours", "competitive"),
    stage("ma.other", "Autre", "✨", "other", "other"),
  ],
  dz: [
    stage("dz.lycee", "Lycée, bac", "🎒", "lycee", "upperSecondary"),
    stage("dz.licence", "Licence", "🎓", "licence", "undergraduate"),
    stage("dz.medecine", "Médecine, santé", "🩺", "sante", "health"),
    stage("dz.master", "Master", "🔬", "master", "graduate"),
    stage("dz.other", "Autre", "✨", "other", "other"),
  ],
  tn: [
    stage("tn.lycee", "Lycée, bac", "🎒", "lycee", "upperSecondary"),
    stage("tn.licence", "Licence", "🎓", "licence", "undergraduate"),
    stage("tn.medecine", "Médecine, santé", "🩺", "sante", "health"),
    stage("tn.mastere", "Mastère", "🔬", "master", "graduate"),
    stage("tn.other", "Autre", "✨", "other", "other"),
  ],
  sn: [
    stage("sn.lycee", "Lycée, bac", "🎒", "lycee", "upperSecondary"),
    stage("sn.licence", "Licence", "🎓", "licence", "undergraduate"),
    stage("sn.medecine", "Médecine, santé", "🩺", "sante", "health"),
    stage("sn.master", "Master", "🔬", "master", "graduate"),
    stage("sn.concours", "Grandes écoles", "🏁", "concours", "competitive"),
    stage("sn.other", "Autre", "✨", "other", "other"),
  ],
  ci: [
    stage("ci.lycee", "Lycée, bac", "🎒", "lycee", "upperSecondary"),
    stage("ci.licence", "Licence", "🎓", "licence", "undergraduate"),
    stage("ci.medecine", "Médecine, santé", "🩺", "sante", "health"),
    stage("ci.master", "Master", "🔬", "master", "graduate"),
    stage("ci.concours", "Grandes écoles", "🏁", "concours", "competitive"),
    stage("ci.other", "Autre", "✨", "other", "other"),
  ],
  uk: [
    stage("uk.gcse", "GCSE", "🎒", "lycee", "lowerSecondary"),
    stage("uk.alevels", "A-Levels", "📐", "lycee", "upperSecondary"),
    stage("uk.undergraduate", "Undergraduate", "🎓", "licence", "undergraduate"),
    stage("uk.medicine", "Medicine", "🩺", "sante", "health"),
    stage("uk.postgraduate", "Postgraduate", "🔬", "master", "graduate"),
    stage("uk.other", "Other", "✨", "other", "other"),
  ],
  us: [
    stage("us.middle", "Middle school", "🎒", "lycee", "lowerSecondary"),
    stage("us.high", "High school", "🏫", "lycee", "upperSecondary"),
    stage("us.college", "College", "🎓", "licence", "undergraduate"),
    stage("us.premed", "Pre-med, MCAT", "🩺", "sante", "health"),
    stage("us.graduate", "Graduate school", "🔬", "master", "graduate"),
    stage("us.other", "Other", "✨", "other", "other"),
  ],
  other: GENERIC_STAGES,
};

export function stagesFor(country: CountryCode): EducationStage[] {
  return STAGES[country] ?? GENERIC_STAGES;
}

/** La marche qu'un registre désigne quand on n'a que lui. */
const CANONICAL_TIER: Record<StudyLevel, EducationTier> = {
  lycee: "upperSecondary",
  prepa: "preUniversity",
  licence: "undergraduate",
  sante: "health",
  master: "graduate",
  concours: "competitive",
  other: "other",
};

/**
 * Le palier de ce pays qui correspond à une réponse déjà donnée.
 *
 * C'est ce qui permet de changer de pays sans redemander où l'on en est, et l'ordre des tentatives
 * va du plus précis au plus grossier :
 *
 * 1. **l'identifiant**, quand la réponse vient du même pays ;
 * 2. **le palier exact** : un lycéen français devient high schooler américain, un étudiant en
 *    santé retrouve la filière santé locale ;
 * 3. **la marche la plus proche**, en montant à égalité de distance : un élève de prépa n'a pas
 *    d'équivalent britannique, et « Undergraduate » le sert mieux qu'une question reposée ;
 * 4. **le registre de rédaction**, seule chose que le cloud transporte.
 *
 * Rien ne correspond, on rend `null` et l'écran redemande : transformer un étudiant en santé en
 * « undergraduate » parce que son pays n'a pas de filière nommée serait une réponse fausse écrite à
 * sa place.
 */
export function resolveStage(
  country: CountryCode,
  answer: { id?: string | null; tier?: EducationTier | null; level?: StudyLevel | null },
): EducationStage | null {
  const stages = stagesFor(country);

  if (answer.id) {
    const byId = stages.find((candidate) => candidate.id === answer.id);
    if (byId) return byId;
  }

  if (answer.tier) {
    const exact = stages.find((candidate) => candidate.tier === answer.tier);
    if (exact) return exact;
    const neighbour = nearestOnLadder(stages, answer.tier);
    if (neighbour) return neighbour;
  }

  if (!answer.level) return null;

  const matching = stages.filter((candidate) => candidate.level === answer.level);
  return (
    matching.find((candidate) => candidate.tier === CANONICAL_TIER[answer.level!]) ??
    matching[0] ??
    null
  );
}

/**
 * La marche la plus proche de celle demandée. À distance égale, **on monte** : un palier au-dessus
 * se rattrape en lisant, un palier en dessous se paye en fiches trop simples.
 */
function nearestOnLadder(
  stages: EducationStage[],
  tier: EducationTier,
): EducationStage | null {
  const target = TIER_LADDER.indexOf(tier);
  if (target < 0) return null;

  let best: { stage: EducationStage; distance: number; index: number } | null = null;

  for (const candidate of stages) {
    const index = TIER_LADDER.indexOf(candidate.tier);
    if (index < 0) continue;
    const distance = Math.abs(index - target);
    if (
      !best ||
      distance < best.distance ||
      (distance === best.distance && index > best.index)
    ) {
      best = { stage: candidate, distance, index };
    }
  }

  return best?.stage ?? null;
}
