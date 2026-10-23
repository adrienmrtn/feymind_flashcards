import type { PathCircle } from "./path-layout";
import {
  CHECKPOINT_REVIEW_COUNT,
  CIRCLE_QUIZ_COUNT,
  FULL_QUIZ_COUNT,
  finalQuizCount,
  pickQuiz,
  pickingSeed,
  progressive,
} from "./picking";
import type { LessonProgress, QuizQuestion, ThemeQuiz } from "./types";

/**
 * **Ce qu'une étape pose comme questions**, depuis les thèmes et la progression. Jumeau de
 * la partie « questions » de `LessonSession.swift`.
 *
 * La graine reprend celle de l'app : l'identifiant de la leçon **en majuscules** (c'est ainsi
 * que Swift écrit un UUID), l'identifiant de l'étape, et le numéro de la tentative.
 */

/** Les questions des thèmes donnés, thème par thème (la première est celle de fin). */
export function themeQuestions(quizzes: readonly (ThemeQuiz | null)[], themes: readonly number[]): QuizQuestion[][] {
  return themes
    .map((index) => quizzes[index]?.questions ?? [])
    .filter((questions) => questions.length > 0);
}

function attemptOf(circle: PathCircle, progress: LessonProgress): number {
  return progress.quizScores[circle.id] === undefined ? 0 : 1 + progress.done.length;
}

function lessonSeed(lessonId: string, ...parts: string[]): bigint {
  return pickingSeed(lessonId.toUpperCase(), ...parts);
}

/**
 * **Les questions d'un Checkpoint ou du Quiz final**, du plus simple au plus exigeant.
 *
 * Un Checkpoint pose cinq questions sur son palier et deux sur les paliers d'avant : revenir
 * sur ce qu'on a vu plus tôt est ce qui le fait tenir. Le Quiz final reprend toute la leçon,
 * deux questions par thème.
 */
export function circleQuiz(
  lessonId: string,
  circle: PathCircle,
  quizzes: readonly (ThemeQuiz | null)[],
  progress: LessonProgress,
): QuizQuestion[] {
  const seed = lessonSeed(lessonId, circle.id, String(attemptOf(circle, progress)));
  switch (circle.kind.type) {
    case "quiz": {
      const current = pickQuiz(themeQuestions(quizzes, circle.kind.themes), progress.missed, CIRCLE_QUIZ_COUNT, seed);
      const earlier = Array.from({ length: Math.min(...circle.kind.themes) }, (_, index) => index);
      const review = pickQuiz(themeQuestions(quizzes, earlier), progress.missed, CHECKPOINT_REVIEW_COUNT, seed + 1n)
        .filter((question) => !current.some((picked) => picked.id === question.id));
      return progressive([...current, ...review]);
    }
    case "final":
      return progressive(
        pickQuiz(themeQuestions(quizzes, circle.kind.themes), progress.missed, finalQuizCount(circle.kind.themes.length), seed),
      );
    default:
      return [];
  }
}

/** Le quiz complet (la barre, l'examen blanc) : dix questions sur toute la leçon. */
export function fullQuiz(
  lessonId: string,
  quizzes: readonly (ThemeQuiz | null)[],
  progress: LessonProgress,
  attempt: number,
): QuizQuestion[] {
  const themes = quizzes.map((_, index) => index);
  return pickQuiz(
    themeQuestions(quizzes, themes),
    progress.missed,
    FULL_QUIZ_COUNT,
    lessonSeed(lessonId, "full", String(attempt)),
  );
}

/** Le thème d'une question, retrouvé par son identifiant (`<thème>:<rang>`). */
export function themeOfQuestion(questionId: string, themeIds: readonly string[]): number {
  const prefix = questionId.split(":")[0] ?? "";
  return themeIds.findIndex((id) => id.toLowerCase() === prefix.toLowerCase());
}

/** Ce qu'une étape attend encore avant de s'ouvrir. */
export type CircleReadiness = "ready" | "writing" | "failed";

export function circleReadiness(
  circle: PathCircle,
  statuses: readonly ("pending" | "ready" | "failed")[],
  quizzes: readonly (ThemeQuiz | null)[],
): CircleReadiness {
  const of = (index: number): CircleReadiness => {
    const status = statuses[index];
    return status === "pending" ? "writing" : status === "failed" ? "failed" : "ready";
  };
  switch (circle.kind.type) {
    case "notes":
      return of(circle.kind.theme);
    case "quiz":
    case "final": {
      const states = circle.kind.themes.map(of);
      if (states.includes("writing")) return "writing";
      // Sans questions du tout (une leçon convertie hors ligne), l'étape se passe d'un appui
      // plutôt que de bloquer le chemin.
      if (states.includes("failed") && themeQuestions(quizzes, circle.kind.themes).length === 0) return "failed";
      return "ready";
    }
    case "intro":
      return "ready";
  }
}
