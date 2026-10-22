"use client";

import { useCallback, useState } from "react";
import { useRouter } from "next/navigation";

import { fullQuiz, noteMissed, noteRight, randomSeed, type LessonProgress, type LessonTone, type QuizQuestion, type ThemeQuiz } from "@micabo/core";

import { QuizRun } from "@/components/lesson/QuizRun";
import { answerQuestion } from "@/lib/actions/lesson";
import { useI18n } from "@/lib/i18n/client";
import { lessonPath } from "@/lib/lesson/routes";
import { useLessonClock } from "@/lib/lesson/use-lesson-clock";

/**
 * **Le quiz de la barre** : dix questions sur toute la leçon, tirées de la réserve (les ratées
 * d'abord), relançable — chaque lancement change le tirage. Il ne coche rien ; une question
 * ratée devient tout de même une flashcard.
 */
export function LessonQuizScreen({
  lessonId,
  tone,
  quizzes,
  progress,
  seed: initialSeed,
}: {
  lessonId: string;
  tone: LessonTone;
  quizzes: (ThemeQuiz | null)[];
  progress: LessonProgress;
  /** La graine du mélange des propositions, tirée par la page (voir `QuizRun`). */
  seed: string;
}) {
  const { t } = useI18n();
  const router = useRouter();
  const [attempt, setAttempt] = useState(0);
  const [seed, setSeed] = useState<bigint>(() => BigInt(initialSeed));
  const [known, setKnown] = useState(progress);
  const [questions, setQuestions] = useState<QuizQuestion[]>(() => fullQuiz(lessonId, quizzes, progress, 0));
  useLessonClock(lessonId, "quiz");

  const answered = useCallback(
    (question: QuizQuestion, right: boolean) => {
      setKnown((current) => (right ? noteRight(current, question.id) : noteMissed(current, question.id)));
      void answerQuestion(lessonId, question, right);
    },
    [lessonId],
  );

  function again() {
    const next = attempt + 1;
    setAttempt(next);
    setSeed(randomSeed());
    setQuestions(fullQuiz(lessonId, quizzes, known, next));
  }

  return (
    <QuizRun
      key={attempt}
      questions={questions}
      tone={tone}
      seed={seed}
      onClose={() => router.push(lessonPath(lessonId))}
      onAnswer={answered}
      onDone={() => router.push(lessonPath(lessonId))}
      doneTitle={t("lesson.quiz.finish")}
      onMore={questions.length > 0 ? again : undefined}
    />
  );
}
