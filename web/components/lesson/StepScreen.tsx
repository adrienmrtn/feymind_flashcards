"use client";

import { useCallback, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import type { Route } from "next";

import {
  averageQuizPercent,
  circleQuiz,
  markDone,
  noteMissed,
  noteRight,
  recordQuiz,
  totalSeconds,
  type LessonProgress,
  type LessonTone,
  type PathCircle,
  type QuizQuestion,
  type ThemeQuiz,
} from "@micabo/core";

import { ConclusionCircle } from "@/components/lesson/ConclusionCircle";
import { IntroCircle } from "@/components/lesson/IntroCircle";
import { LessonFinished } from "@/components/lesson/LessonFinished";
import { NotesCircle, type StepTheme } from "@/components/lesson/NotesCircle";
import { QuizRun } from "@/components/lesson/QuizRun";
import { answerQuestion, completeCircle, recordQuizScore, setInCircle } from "@/lib/actions/lesson";
import { useI18n } from "@/lib/i18n/client";
import { flashcardsPath, lessonPath, LESSONS_PATH } from "@/lib/lesson/routes";
import { useLessonClock } from "@/lib/lesson/use-lesson-clock";

/**
 * **Une étape ouverte**, en plein écran : l'Intro, des Notes, un Checkpoint ou le Quiz final
 * (puis « À retenir », puis « Leçon terminée »). Chacune se termine par un bouton qui coche
 * l'étape et ramène au chemin. Jumeau de `LessonCircleScreen`.
 *
 * Tout ce qui se lit arrive de la page ; ce qui s'écrit part par les actions, au fil de l'eau,
 * sans faire attendre l'élève : la réponse s'affiche d'abord, le serveur suit. La progression
 * est aussi tenue ici, en copie, pour que le score moyen et le temps de l'écran de fin soient
 * justes sans relire la base.
 */
export interface StepScreenProps {
  lessonId: string;
  tone: LessonTone;
  circle: PathCircle;
  progress: LessonProgress;
  intro: { lines: string[]; minutes: number; themes: { title: string; icon: string | null }[] } | null;
  theme: StepTheme | null;
  /** Les quiz de chaque thème, pour tirer les questions d'un Checkpoint ou du Quiz final. */
  quizzes: (ThemeQuiz | null)[];
  takeaways: string[];
  /** La graine du mélange des propositions, tirée par la page (voir `QuizRun`). */
  seed: string;
}

export function StepScreen(props: StepScreenProps) {
  const { t } = useI18n();
  const router = useRouter();
  const { circle, lessonId } = props;
  const [progress, setProgress] = useState(props.progress);
  const [phase, setPhase] = useState<"step" | "conclusion" | "finished">("step");
  const [pending, startTransition] = useTransition();
  const clock = useLessonClock(lessonId, circle.activity);
  // Le tirage, figé à l'ouverture : une question ratée change l'ordre du prochain tirage, pas celui du quiz en cours.
  const [questions] = useState<QuizQuestion[]>(() => (circle.kind.type === "quiz" || circle.kind.type === "final" ? circleQuiz(lessonId, circle, props.quizzes, props.progress) : []));

  const backToPath = useCallback(
    (done?: string) => {
      router.push((done ? `${lessonPath(lessonId)}?fait=${encodeURIComponent(done)}` : lessonPath(lessonId)) as Route);
    },
    [lessonId, router],
  );

  const answered = useCallback(
    (question: QuizQuestion, right: boolean) => {
      setProgress((current) => (right ? noteRight(current, question.id) : noteMissed(current, question.id)));
      void answerQuestion(lessonId, question, right);
    },
    [lessonId],
  );

  const quizFinished = useCallback(
    (right: number, total: number) => {
      setProgress((current) => recordQuiz(current, circle.id, right, total));
      void recordQuizScore(lessonId, circle.id, right, total);
    },
    [circle.id, lessonId],
  );

  /** Coche l'étape, puis le chemin (ou, pour le Quiz final, l'écran de fin). */
  function finish() {
    const isFinal = circle.kind.type === "final";
    startTransition(async () => {
      const result = await completeCircle(lessonId, circle.id, isFinal);
      if (result.status === "ok" && result.progress) setProgress(result.progress);
      else setProgress((current) => ({ ...markDone(current, circle.id), finishedAt: isFinal && !current.finishedAt ? new Date().toISOString() : current.finishedAt }));
      if (isFinal) setPhase("finished");
      else backToPath(circle.id);
    });
  }

  function leaveNotes(read: number) {
    void setInCircle(lessonId, read);
    backToPath();
  }

  if (phase === "finished") {
    const seconds = totalSeconds(progress) + clock.elapsed();
    return (
      <LessonFinished
        tone={props.tone}
        averagePercent={averageQuizPercent(progress)}
        minutes={Math.round(seconds / 60)}
        onCards={() => router.push(`${flashcardsPath(lessonId)}?reviser=1` as Route)}
        onBack={() => router.push(LESSONS_PATH)}
      />
    );
  }

  if (phase === "conclusion") {
    return (
      <ConclusionCircle
        takeaways={props.takeaways}
        averagePercent={averageQuizPercent(progress)}
        tone={props.tone}
        pending={pending}
        onClose={() => backToPath()}
        onDone={finish}
      />
    );
  }

  switch (circle.kind.type) {
    case "intro":
      return <IntroCircle lines={props.intro?.lines ?? []} minutes={props.intro?.minutes ?? 0} themes={props.intro?.themes ?? []} tone={props.tone} onClose={() => backToPath()} onDone={finish} />;
    case "notes":
      if (!props.theme) return null;
      return <NotesCircle theme={props.theme} tone={props.tone} onAnswer={answered} onLeave={leaveNotes} onDone={finish} />;
    case "quiz":
      return (
        <QuizRun
          questions={questions}
          tone={props.tone}
          seed={BigInt(props.seed)}
          onClose={() => backToPath()}
          onAnswer={answered}
          onFinish={quizFinished}
          onDone={finish}
          doneTitle={t("lesson.circle.next")}
        />
      );
    case "final":
      return (
        <QuizRun
          questions={questions}
          tone={props.tone}
          seed={BigInt(props.seed)}
          onClose={() => backToPath()}
          onAnswer={answered}
          onFinish={quizFinished}
          onDone={() => setPhase("conclusion")}
          doneTitle={t("lesson.circle.next")}
        />
      );
  }
}
