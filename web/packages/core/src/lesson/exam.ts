import { questionIsValid, readQuizQuestion, type QuizQuestion } from "./types";

/**
 * **L'examen blanc** : la copie, son résultat, et la note dans le barème du pays. Jumeau de
 * `Micabo/Models/ExamPaper.swift` et de `ExamGrade`.
 */

/** Les durées proposées, en minutes. */
export const EXAM_DURATIONS = [15, 30, 45, 60] as const;

/** Combien de questions pour une durée : une et demie par minute, entre six et trente. */
export function examQuestionCount(minutes: number): number {
  return Math.min(30, Math.max(6, Math.round(minutes / 1.5)));
}

export interface ExamPaperLesson {
  courseId: string;
  title: string;
  /** Les chapitres, dans l'ordre des thèmes : une question ratée devient une carte du bon thème. */
  chapterIds: string[];
}

export interface ExamPaperItem {
  question: QuizQuestion;
  /** Le rang de la leçon dans `lessons`. */
  lesson: number;
  /** Le rang du thème dans la leçon. */
  theme: number;
}

export interface ExamPaper {
  id: string;
  /** L'examen déclaré que la copie prépare, s'il y en a un. */
  examId: string | null;
  title: string;
  minutes: number;
  createdAt: string;
  lessons: ExamPaperLesson[];
  items: ExamPaperItem[];
}

export interface ExamLessonScore {
  title: string;
  correct: number;
  total: number;
}

/** Ce qu'il reste d'un examen blanc une fois rendu. */
export interface ExamPaperResult {
  id: string;
  examId: string | null;
  title: string;
  date: string;
  correct: number;
  total: number;
  /** Le temps passé, en secondes. */
  seconds: number;
  minutes: number;
  lessons: ExamLessonScore[];
}

export function examFraction(result: Pick<ExamPaperResult, "correct" | "total">): number {
  return result.total === 0 ? 0 : result.correct / result.total;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * La copie, lue depuis la réponse du serveur (stage `exam`) : les questions, chacune
 * rattachée à sa leçon et à son thème. `null` sans copie lisible.
 */
export function readExamResponse(
  raw: unknown,
  options: { paperId: string; examId: string | null; title: string; minutes: number; lessons: ExamPaperLesson[]; createdAt?: string },
): ExamPaper | null {
  if (!isRecord(raw) || !isRecord(raw.exam)) return null;
  const exam = raw.exam;
  const items: ExamPaperItem[] = [];
  (Array.isArray(exam.questions) ? exam.questions : []).forEach((entry, number) => {
    if (!isRecord(entry)) return;
    const question = readQuizQuestion({ ...entry, id: `${options.paperId}:${number}` });
    if (!question || !questionIsValid(question)) return;
    const lessonRaw = typeof entry.lesson === "number" ? Math.round(entry.lesson) : 0;
    const lesson = lessonRaw >= 0 && lessonRaw < options.lessons.length ? lessonRaw : 0;
    const chapterCount = options.lessons[lesson]?.chapterIds.length ?? 0;
    const themeRaw = typeof entry.theme === "number" ? Math.round(entry.theme) : 0;
    const theme = themeRaw >= 0 && themeRaw < chapterCount ? themeRaw : 0;
    items.push({ question, lesson, theme });
  });
  if (items.length === 0) return null;
  const title = typeof exam.title === "string" && exam.title.trim() ? exam.title.trim() : options.title;
  return {
    id: options.paperId,
    examId: options.examId,
    title,
    minutes: options.minutes,
    createdAt: options.createdAt ?? new Date().toISOString(),
    lessons: options.lessons,
    items,
  };
}

/** Une copie relue depuis ce qu'on en a gardé (`mock_sessions.questions`). */
export function readExamPaper(raw: unknown): ExamPaper | null {
  const source = typeof raw === "string" ? safeParse(raw) : raw;
  if (!isRecord(source) || typeof source.id !== "string" || !Array.isArray(source.items)) return null;
  const lessons: ExamPaperLesson[] = (Array.isArray(source.lessons) ? source.lessons : [])
    .filter(isRecord)
    .map((lesson) => ({
      courseId: typeof lesson.courseId === "string" ? lesson.courseId : "",
      title: typeof lesson.title === "string" ? lesson.title : "",
      chapterIds: Array.isArray(lesson.chapterIds) ? lesson.chapterIds.filter((id): id is string => typeof id === "string") : [],
    }));
  const items: ExamPaperItem[] = [];
  for (const entry of source.items) {
    if (!isRecord(entry)) continue;
    const question = readQuizQuestion(entry.question);
    if (!question) continue;
    items.push({
      question,
      lesson: typeof entry.lesson === "number" ? entry.lesson : 0,
      theme: typeof entry.theme === "number" ? entry.theme : 0,
    });
  }
  return {
    id: source.id,
    examId: typeof source.examId === "string" ? source.examId : null,
    title: typeof source.title === "string" ? source.title : "",
    minutes: typeof source.minutes === "number" ? source.minutes : 30,
    createdAt: typeof source.createdAt === "string" ? source.createdAt : new Date(0).toISOString(),
    lessons,
    items,
  };
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/**
 * Le résultat d'une copie, rendue avec ces réponses. Une question sans réponse est fausse :
 * c'est la règle d'un vrai examen.
 */
export function examResult(
  paper: ExamPaper,
  answers: Readonly<Record<string, { right: boolean }>>,
  seconds: number,
  date = new Date(),
): ExamPaperResult {
  const perLesson: ExamLessonScore[] = paper.lessons.map((lesson) => ({ title: lesson.title, correct: 0, total: 0 }));
  let correct = 0;
  for (const item of paper.items) {
    const right = answers[item.question.id]?.right === true;
    if (right) correct += 1;
    const score = perLesson[item.lesson];
    if (!score) continue;
    score.total += 1;
    if (right) score.correct += 1;
  }
  return {
    id: paper.id,
    examId: paper.examId,
    title: paper.title,
    date: date.toISOString(),
    correct,
    total: paper.items.length,
    seconds: Math.max(0, Math.round(seconds)),
    minutes: paper.minutes,
    lessons: perLesson.filter((score) => score.total > 0),
  };
}

// MARK: - La note

/** Vrai quand la copie a la moyenne. */
export function examPasses(fraction: number): boolean {
  return fraction >= 0.5;
}

function pick(value: number, steps: readonly [number, string][], fallback: string): string {
  return steps.find(([floor]) => value >= floor)?.[1] ?? fallback;
}

function number(amount: number, digits: number, locale: string): string {
  return new Intl.NumberFormat(locale, { minimumFractionDigits: 0, maximumFractionDigits: digits }).format(amount);
}

/**
 * **La note d'une copie, dans le barème du pays** : 13,5/20 en France, 2,3 en Allemagne, 4,5
 * en Suisse, B+ aux États-Unis. Le même pourcentage, dit comme l'élève le lit sur ses copies.
 * La moitié des points fait la moyenne partout.
 */
export function examGradeLabel(fraction: number, country: string | null | undefined, locale = "fr"): string {
  const value = Math.min(1, Math.max(0, Number.isFinite(fraction) ? fraction : 0));
  switch (country ?? "other") {
    case "fr":
    case "be":
    case "ma":
    case "dz":
    case "tn":
    case "sn":
    case "ci":
    case "pt":
    case "gr":
      return `${number(Math.round(value * 40) / 2, 1, locale)}/20`;
    case "it":
    case "es":
      return `${number(Math.round(value * 20) / 2, 1, locale)}/10`;
    case "lu":
      return `${Math.round(value * 60)}/60`;
    case "ca":
    case "tr":
      return `${Math.round(value * 100)} %`;
    case "ch":
      return number(Math.round((value * 5 + 1) * 2) / 2, 1, locale);
    case "nl":
      return number(Math.round((value * 9 + 1) * 10) / 10, 1, locale);
    case "ro":
      return number(Math.round(Math.max(1, value * 10) * 10) / 10, 1, locale);
    case "de":
      return pick(
        value,
        [
          [0.95, "1,0"],
          [0.9, "1,3"],
          [0.85, "1,7"],
          [0.8, "2,0"],
          [0.75, "2,3"],
          [0.7, "2,7"],
          [0.65, "3,0"],
          [0.6, "3,3"],
          [0.55, "3,7"],
          [0.5, "4,0"],
          [0.3, "5,0"],
        ],
        "6,0",
      );
    case "cz":
      return pick(value, [[0.9, "1"], [0.75, "2"], [0.6, "3"], [0.5, "4"]], "5");
    case "hu":
      return pick(value, [[0.9, "5"], [0.7, "4"], [0.5, "3"], [0.35, "2"]], "1");
    case "pl":
      return pick(value, [[0.98, "6"], [0.9, "5"], [0.7, "4"], [0.5, "3"], [0.3, "2"]], "1");
    case "se":
      return pick(value, [[0.9, "A"], [0.8, "B"], [0.7, "C"], [0.6, "D"], [0.5, "E"]], "F");
    case "uk":
      return pick(value, [[0.9, "A*"], [0.8, "A"], [0.7, "B"], [0.6, "C"], [0.5, "D"], [0.4, "E"]], "U");
    default:
      return pick(
        value,
        [
          [0.97, "A+"],
          [0.93, "A"],
          [0.9, "A-"],
          [0.87, "B+"],
          [0.83, "B"],
          [0.8, "B-"],
          [0.77, "C+"],
          [0.73, "C"],
          [0.7, "C-"],
          [0.6, "D"],
        ],
        "F",
      );
  }
}
