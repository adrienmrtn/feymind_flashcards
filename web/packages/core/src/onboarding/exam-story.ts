/**
 * L'exemple d'examen du parcours : un cas **déjà décidé**, pas un calendrier à remplir.
 *
 * L'écran ne demande plus la date. Il montre ce que Micabo change — un examen posé, des
 * cours accrochés, la révision, la note — dans le **système de notation du pays** choisi
 * deux écrans plus tôt. En France c'est 17/20 ; ailleurs, l'équivalent « très bien » de
 * ce pays-là. Inventer 17/20 à un Allemand ou un A à un Français, c'est parler une langue
 * de notes qu'ils n'ont jamais eue.
 */

import {
  LANGUAGE_LABELS,
  countryFor,
  type ContentLanguage,
  type CountryCode,
} from "./countries";

export interface ExamGrade {
  /** La note, déjà formatée : `17/20`, `A`, `1,3`. */
  score: string;
  /** La mention d'usage dans ce système. */
  mention: string;
}

export interface ExamStory {
  examName: string;
  examKind: string;
  dateLabel: string;
  subject: string;
  courses: readonly string[];
  grade: ExamGrade;
}

interface ExamFrame {
  examKind: string;
  nameFor: (subject: string) => string;
  dateLabel: string;
  grade: ExamGrade;
}

const FRAMES: Record<CountryCode, ExamFrame> = {
  fr: frame("Baccalauréat", (subject) => `Bac de ${subject.toLowerCase()}`, "12 juin", {
    score: "17/20",
    mention: "Très bien",
  }),
  be: frame("CESS", (subject) => `CESS · ${subject}`, "12 juin", {
    score: "17/20",
    mention: "Très bien",
  }),
  ch: frame("Maturité", (subject) => `Maturité · ${subject}`, "12 juin", {
    score: "5,5",
    mention: "Très bien",
  }),
  lu: frame("Examen de fin d'études", (subject) => `Fin d'études · ${subject}`, "12 juin", {
    score: "48/60",
    mention: "Très bien",
  }),
  ma: frame("Baccalauréat", (subject) => `Bac de ${subject.toLowerCase()}`, "12 juin", {
    score: "17/20",
    mention: "Très bien",
  }),
  dz: frame("Baccalauréat", (subject) => `Bac de ${subject.toLowerCase()}`, "12 juin", {
    score: "17/20",
    mention: "Très bien",
  }),
  tn: frame("Baccalauréat", (subject) => `Bac de ${subject.toLowerCase()}`, "12 juin", {
    score: "17/20",
    mention: "Très bien",
  }),
  sn: frame("Baccalauréat", (subject) => `Bac de ${subject.toLowerCase()}`, "12 juin", {
    score: "17/20",
    mention: "Très bien",
  }),
  ci: frame("Baccalauréat", (subject) => `Bac de ${subject.toLowerCase()}`, "12 juin", {
    score: "17/20",
    mention: "Très bien",
  }),
  uk: frame("A-levels", (subject) => `A-level ${subject}`, "12 June", {
    score: "A",
    mention: "Distinction",
  }),
  us: frame("Finals", (subject) => `Final · ${subject}`, "June 12", {
    score: "A",
    mention: "Excellent",
  }),
  ca: frame("Examens finaux", (subject) => `Final · ${subject}`, "12 juin", {
    score: "85 %",
    mention: "Excellent",
  }),
  de: frame("Abitur", (subject) => `Abitur · ${subject}`, "12. Juni", {
    score: "1,3",
    mention: "Sehr gut",
  }),
  it: frame("Maturità", (subject) => `Maturità · ${subject}`, "12 giugno", {
    score: "8,5/10",
    mention: "Ottimo",
  }),
  es: frame("EvAU", (subject) => `EvAU · ${subject}`, "12 de junio", {
    score: "8,5/10",
    mention: "Notable alto",
  }),
  pt: frame("Exames nacionais", (subject) => `Exame · ${subject}`, "12 de junho", {
    score: "17/20",
    mention: "Muito bom",
  }),
  cz: frame("Maturita", (subject) => `Maturita · ${subject}`, "12. června", {
    score: "1",
    mention: "Výborně",
  }),
  nl: frame("Eindexamen", (subject) => `Eindexamen · ${subject}`, "12 juni", {
    score: "8,5",
    mention: "Uitstekend",
  }),
  gr: frame("Πανελλήνιες", (subject) => `${subject}`, "12 Ιουνίου", {
    score: "17/20",
    mention: "Άριστα",
  }),
  hu: frame("Érettségi", (subject) => `Érettségi · ${subject}`, "június 12.", {
    score: "5",
    mention: "Jeles",
  }),
  pl: frame("Matura", (subject) => `Matura · ${subject}`, "12 czerwca", {
    score: "5",
    mention: "Bardzo dobry",
  }),
  ro: frame("Bacalaureat", (subject) => `Bac · ${subject}`, "12 iunie", {
    score: "9",
    mention: "Foarte bine",
  }),
  se: frame("Nationellt prov", (subject) => `Nationellt prov · ${subject}`, "12 juni", {
    score: "A",
    mention: "Mycket väl godkänd",
  }),
  tr: frame("YKS", (subject) => `YKS · ${subject}`, "12 Haziran", {
    score: "85",
    mention: "Pek iyi",
  }),
  other: frame("Exam", (subject) => subject, "12 June", {
    score: "A",
    mention: "Excellent",
  }),
};

const FALLBACK_COURSES: Record<ContentLanguage, readonly string[]> = {
  fr: ["Français", "Histoire", "Mathématiques"],
  en: ["English", "History", "Mathematics"],
  de: ["Deutsch", "Geschichte", "Mathematik"],
  it: ["Italiano", "Storia", "Matematica"],
  es: ["Lengua", "Historia", "Matemáticas"],
  pt: ["Português", "História", "Matemática"],
  cs: ["Čeština", "Dějepis", "Matematika"],
  nl: ["Nederlands", "Geschiedenis", "Wiskunde"],
  el: ["Νέα Ελληνικά", "Ιστορία", "Μαθηματικά"],
  hu: ["Magyar", "Történelem", "Matematika"],
  pl: ["Język polski", "Historia", "Matematyka"],
  ro: ["Limba română", "Istorie", "Matematică"],
  sv: ["Svenska", "Historia", "Matematik"],
  tr: ["Türkçe", "Tarih", "Matematik"],
};

function frame(
  examKind: string,
  nameFor: (subject: string) => string,
  dateLabel: string,
  grade: ExamGrade,
): ExamFrame {
  return { examKind, nameFor, dateLabel, grade };
}

function subjectFor(language: ContentLanguage, subjects: readonly string[]): string {
  const living = subjects.find((item) => isoOfLanguageSubject(item));
  if (living) return living;
  if (subjects[0]) return subjects[0];
  return LANGUAGE_LABELS[language];
}

function isoOfLanguageSubject(subject: string): boolean {
  return /anglais|espagnol|allemand|italien|portugais|japonais|chinois|arabe|russe|francais/i.test(
    subject.normalize("NFD").replace(/[\u0300-\u036f]/g, ""),
  );
}

function coursesFor(
  language: ContentLanguage,
  subjects: readonly string[],
  subject: string,
): string[] {
  const chosen = subjects.filter(Boolean).slice(0, 3);
  if (chosen.length >= 2) {
    return chosen.includes(subject) ? chosen : [subject, ...chosen].slice(0, 3);
  }
  const fallback = FALLBACK_COURSES[language] ?? FALLBACK_COURSES.fr;
  if (chosen.length === 1) return [chosen[0]!, fallback[1]!, fallback[2]!];
  return [...fallback];
}

/** L'exemple d'examen, calé sur le pays (et les matières déjà choisies). */
export function examStoryFor(
  countryCode: string | null | undefined,
  subjects: readonly string[] = [],
): ExamStory {
  const country = countryFor(countryCode);
  const frame = FRAMES[country.code] ?? FRAMES.other;
  const subject = subjectFor(country.language, subjects);
  return {
    examKind: frame.examKind,
    examName: frame.nameFor(subject),
    dateLabel: frame.dateLabel,
    subject,
    courses: coursesFor(country.language, subjects, subject),
    grade: frame.grade,
  };
}
