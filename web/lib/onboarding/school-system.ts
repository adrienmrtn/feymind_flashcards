import { resolveStage, type CountryCode, type EducationStage, type EducationTier, type StudyLevel } from "@micabo/core";

/**
 * **La filière et l'année, pour les pays décrits en détail** : le jumeau de `SchoolSystem.swift`.
 *
 * « Lycée » ne dit pas ce qu'un élève étudie : un élève de terminale STMG et un élève de
 * terminale générale ne partagent ni leurs matières ni leur épreuve, et un collégien de 4e ne
 * s'écrit pas comme un lycéen. L'iPhone pose donc deux questions là où il connaît le système -
 * la filière, puis l'année - et envoie les deux à `generate-lesson` (`track`, `year`), qui
 * règle le registre, le volume et les exemples dessus (`supabase/functions/_shared/learner.ts`).
 *
 * Quatre pays, comme l'app : France, Turquie, Allemagne, Espagne. Ailleurs, on garde le palier
 * large (`stagesFor`), qui ne prétend rien savoir de plus que le niveau.
 *
 * **Les libellés sont ceux du pays, et ne se traduisent pas** : « 12. sınıf » est le nom de la
 * classe d'un lycéen turc, quelle que soit la langue dans laquelle il lit le site. Les
 * identifiants sont ceux de l'iPhone, à la lettre : ils voyagent dans le cookie `micabo.learner`.
 */

export interface SchoolYear {
  id: string;
  title: string;
}

export interface SchoolTrack {
  id: string;
  title: string;
  emoji: string;
  /** Le registre (`profiles.study_level`). */
  level: StudyLevel;
  /** La marche, celle qui règle l'écriture. */
  tier: EducationTier;
  years: SchoolYear[];
}

function track(
  id: string,
  title: string,
  emoji: string,
  level: StudyLevel,
  tier: EducationTier,
  years: [string, string][],
): SchoolTrack {
  return { id, title, emoji, level, tier, years: years.map(([yearId, yearTitle]) => ({ id: yearId, title: yearTitle })) };
}

const range = (from: number, to: number) => Array.from({ length: to - from + 1 }, (_, index) => from + index);

const trLise = (prefix: string): [string, string][] => [
  [`${prefix}.9`, "9. sınıf"],
  [`${prefix}.10`, "10. sınıf"],
  [`${prefix}.11`, "11. sınıf"],
  [`${prefix}.12`, "12. sınıf"],
];

const SYSTEMS: Partial<Record<CountryCode, SchoolTrack[]>> = {
  fr: [
    track("fr.college", "Collège", "🎒", "lycee", "lowerSecondary", [
      ["fr.6e", "Sixième"],
      ["fr.5e", "Cinquième"],
      ["fr.4e", "Quatrième"],
      ["fr.3e", "Troisième"],
    ]),
    track("fr.lyceeGeneral", "Lycée général", "🏫", "lycee", "upperSecondary", [
      ["fr.seconde", "Seconde"],
      ["fr.premiere", "Première"],
      ["fr.terminale", "Terminale"],
    ]),
    track("fr.lyceeTechno", "Lycée technologique", "⚙️", "lycee", "upperSecondary", [
      ["fr.technoSeconde", "Seconde"],
      ["fr.technoPremiere", "Première"],
      ["fr.technoTerminale", "Terminale"],
    ]),
    track("fr.lyceePro", "Lycée professionnel", "🔧", "lycee", "upperSecondary", [
      ["fr.proSeconde", "Seconde pro"],
      ["fr.proPremiere", "Première pro"],
      ["fr.proTerminale", "Terminale pro"],
    ]),
    track("fr.prepa", "Prépa", "📐", "prepa", "preUniversity", [
      ["fr.prepa1", "Première année"],
      ["fr.prepa2", "Deuxième année"],
    ]),
    track("fr.sante", "Études de santé", "🩺", "sante", "health", [
      ["fr.pass", "PASS / L.AS"],
      ["fr.sante2", "Deuxième année"],
      ["fr.sante3", "Troisième année et plus"],
    ]),
    track("fr.universite", "Université", "🎓", "licence", "undergraduate", [
      ["fr.l1", "Licence 1"],
      ["fr.l2", "Licence 2"],
      ["fr.l3", "Licence 3"],
      ["fr.m1", "Master 1"],
      ["fr.m2", "Master 2"],
    ]),
  ],
  tr: [
    track("tr.ortaokul", "Ortaokul", "🎒", "lycee", "lowerSecondary", [
      ["tr.5", "5. sınıf"],
      ["tr.6", "6. sınıf"],
      ["tr.7", "7. sınıf"],
      ["tr.8", "8. sınıf"],
    ]),
    track("tr.anadolu", "Anadolu Lisesi", "🏫", "lycee", "upperSecondary", trLise("tr.anadolu")),
    track("tr.fen", "Fen Lisesi", "🔬", "lycee", "upperSecondary", trLise("tr.fen")),
    track("tr.meslek", "Meslek Lisesi", "🔧", "lycee", "upperSecondary", trLise("tr.meslek")),
    track("tr.imamhatip", "İmam Hatip Lisesi", "🕌", "lycee", "upperSecondary", trLise("tr.imamhatip")),
    track("tr.yks", "YKS hazırlık", "🏁", "concours", "competitive", [
      ["tr.tyt", "TYT"],
      ["tr.ayt", "AYT"],
    ]),
    track("tr.universite", "Üniversite", "🎓", "licence", "undergraduate", [
      ["tr.uni1", "1. sınıf"],
      ["tr.uni2", "2. sınıf"],
      ["tr.uni3", "3. sınıf"],
      ["tr.uni4", "4. sınıf"],
      ["tr.yukseklisans", "Yüksek lisans"],
    ]),
  ],
  de: [
    track(
      "de.mittelstufe",
      "Mittelstufe",
      "🎒",
      "lycee",
      "lowerSecondary",
      range(5, 10).map((grade) => [`de.klasse${grade}`, `${grade}. Klasse`]),
    ),
    track("de.gymnasium", "Gymnasium, Oberstufe", "🏫", "lycee", "upperSecondary", [
      ["de.klasse11", "11. Klasse"],
      ["de.klasse12", "12. Klasse"],
      ["de.klasse13", "13. Klasse, Abitur"],
    ]),
    track(
      "de.realschule",
      "Realschule",
      "📗",
      "lycee",
      "lowerSecondary",
      range(5, 10).map((grade) => [`de.real${grade}`, `${grade}. Klasse`]),
    ),
    track("de.berufsschule", "Berufsschule", "🔧", "lycee", "upperSecondary", [
      ["de.beruf1", "1. Lehrjahr"],
      ["de.beruf2", "2. Lehrjahr"],
      ["de.beruf3", "3. Lehrjahr"],
    ]),
    track("de.medizin", "Medizin", "🩺", "sante", "health", [
      ["de.vorklinik", "Vorklinik"],
      ["de.klinik", "Klinik"],
      ["de.pj", "Praktisches Jahr"],
    ]),
    track("de.universitaet", "Universität", "🎓", "licence", "undergraduate", [
      ["de.bachelor1", "Bachelor, 1. Jahr"],
      ["de.bachelor2", "Bachelor, 2. Jahr"],
      ["de.bachelor3", "Bachelor, 3. Jahr"],
      ["de.master", "Master"],
    ]),
  ],
  es: [
    track("es.eso", "ESO", "🎒", "lycee", "lowerSecondary", [
      ["es.eso1", "1º de ESO"],
      ["es.eso2", "2º de ESO"],
      ["es.eso3", "3º de ESO"],
      ["es.eso4", "4º de ESO"],
    ]),
    track("es.bachCiencias", "Bachillerato de Ciencias", "🔬", "lycee", "upperSecondary", [
      ["es.bachCiencias1", "1º de Bachillerato"],
      ["es.bachCiencias2", "2º de Bachillerato"],
    ]),
    track("es.bachHumanidades", "Bachillerato de Humanidades y CCSS", "📚", "lycee", "upperSecondary", [
      ["es.bachHum1", "1º de Bachillerato"],
      ["es.bachHum2", "2º de Bachillerato"],
    ]),
    track("es.bachArtes", "Bachillerato de Artes", "🎨", "lycee", "upperSecondary", [
      ["es.bachArtes1", "1º de Bachillerato"],
      ["es.bachArtes2", "2º de Bachillerato"],
    ]),
    track("es.fp", "Formación Profesional", "🔧", "lycee", "upperSecondary", [
      ["es.fpMedio", "Grado medio"],
      ["es.fpSuperior", "Grado superior"],
    ]),
    track("es.medicina", "Medicina", "🩺", "sante", "health", [
      ["es.medicina1", "Ciclo básico"],
      ["es.medicina2", "Ciclo clínico"],
      ["es.mir", "MIR"],
    ]),
    track("es.universidad", "Universidad", "🎓", "licence", "undergraduate", [
      ["es.grado1", "1º de grado"],
      ["es.grado2", "2º de grado"],
      ["es.grado3", "3º de grado"],
      ["es.grado4", "4º de grado"],
      ["es.master", "Máster"],
    ]),
  ],
};

/** Les filières d'un pays, ou rien quand on n'en connaît que les paliers larges. */
export function tracksFor(country: string | null | undefined): SchoolTrack[] {
  return (country ? SYSTEMS[country as CountryCode] : undefined) ?? [];
}

/** Vrai quand le pays est décrit assez finement pour demander la filière puis l'année. */
export function isDetailedCountry(country: string | null | undefined): boolean {
  return tracksFor(country).length > 0;
}

/** Une filière de ce pays-là, jamais d'un autre : « fr.prepa » ne vaut rien pour un Turc. */
export function trackById(id: string | null | undefined, country: string | null | undefined): SchoolTrack | null {
  if (!id) return null;
  return tracksFor(country).find((candidate) => candidate.id === id) ?? null;
}

export function yearById(id: string | null | undefined, track: SchoolTrack | null): SchoolYear | null {
  if (!id || !track) return null;
  return track.years.find((candidate) => candidate.id === id) ?? null;
}

/** Les années de master sont rangées dans la filière universitaire : leur marche est le master. */
const GRADUATE_YEARS = new Set(["fr.m1", "fr.m2", "de.master", "es.master", "tr.yukseklisans"]);

/** La marche d'une filière, corrigée par son année (`LessonAudience.tier(track:year:)`). */
export function trackTier(track: SchoolTrack, year: SchoolYear | null): EducationTier {
  if (year && GRADUATE_YEARS.has(year.id)) return "graduate";
  return track.tier;
}

/**
 * Le palier large qu'une filière désigne, dans les paliers du pays : c'est lui qui va dans
 * `study_level` et dans `schoolStage`, comme `country.resolvedStage(id: nil, tier:, level:)`.
 */
export function stageOfTrack(country: CountryCode, track: SchoolTrack): EducationStage | null {
  return resolveStage(country, { id: null, tier: track.tier, level: track.level });
}
