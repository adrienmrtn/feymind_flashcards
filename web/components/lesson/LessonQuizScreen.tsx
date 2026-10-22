"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Sparkles } from "lucide-react";

import { fullQuiz, noteMissed, noteRight, randomSeed, type LessonProgress, type LessonTone, type QuizQuestion, type ThemeQuiz } from "@micabo/core";

import { LessonPrimaryButton, LessonSecondaryButton } from "@/components/lesson/LessonButtons";
import { QuizRun } from "@/components/lesson/QuizRun";
import { Mika } from "@/components/mika/Mika";
import { answerQuestion } from "@/lib/actions/lesson";
import { useI18n } from "@/lib/i18n/client";
import { lessonPath } from "@/lib/lesson/routes";
import { useLessonClock } from "@/lib/lesson/use-lesson-clock";
import { requestPaywall } from "@/lib/paywall";

/**
 * **Le quiz de la barre** : dix questions sur toute la leçon, tirées de la réserve (les ratées
 * d'abord), relançable — chaque lancement change le tirage. Il ne coche rien ; une question
 * ratée devient tout de même une flashcard. À la fin, « Générer de nouvelles questions » :
 * Mika en écrit dix, loin de celles déjà vues, et on les joue tout de suite (`writePractice`).
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
  void known;
  useLessonClock(lessonId, "quiz");

  const answered = useCallback(
    (question: QuizQuestion, right: boolean) => {
      setKnown((current) => (right ? noteRight(current, question.id) : noteMissed(current, question.id)));
      void answerQuestion(lessonId, question, right);
    },
    [lessonId],
  );

  const [practice, setPractice] = useState<"idle" | "writing" | "failed">("idle");
  const [fresh, setFresh] = useState<number | null>(null);

  useEffect(() => {
    if (fresh === null) return;
    const timer = window.setTimeout(() => setFresh(null), 2600);
    return () => window.clearTimeout(timer);
  }, [fresh]);

  async function more() {
    setPractice("writing");
    try {
      const response = await fetch("/api/lesson/practice", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ lessonId }) });
      const outcome = (await response.json()) as { status: string; questions?: QuizQuestion[]; code?: string };
      if (outcome.status === "ok" && outcome.questions && outcome.questions.length > 0) {
        setAttempt((current) => current + 1);
        setSeed(randomSeed());
        setQuestions(outcome.questions);
        setFresh(outcome.questions.length);
        setPractice("idle");
        router.refresh();
        return;
      }
      if (outcome.code === "pro_required" || outcome.code === "daily_limit" || outcome.code === "free_limit") {
        setPractice("idle");
        requestPaywall();
        return;
      }
      setPractice("failed");
    } catch {
      setPractice("failed");
    }
  }

  if (practice === "writing") {
    return (
      <div className="flex min-h-[70svh] flex-col items-center justify-center gap-5 px-8 text-center" role="status">
        <Mika mood="think" size={170} label="" />
        <p className="text-[20px] font-bold text-ink">{t("lesson.practice.writing")}</p>
        <p className="max-w-[420px] text-[16px] font-medium text-ink-secondary">{t("lesson.practice.writingSub")}</p>
        <Loader2 aria-hidden="true" className="size-6 animate-spin" style={{ color: `var(--color-tone-${tone}-vivid)` }} />
      </div>
    );
  }
  if (practice === "failed") {
    return (
      <div className="flex min-h-[70svh] flex-col items-center justify-center gap-5 px-8 text-center">
        <Mika mood="sad" size={150} label="" />
        <p className="text-[20px] font-bold text-ink">{t("lesson.practice.failed")}</p>
        <div className="mt-4 flex w-full max-w-[420px] flex-col gap-3">
          <LessonPrimaryButton onClick={() => void more()} style={{ background: `var(--color-tone-${tone}-vivid)` }}>
            {t("lesson.practice.retry")}
          </LessonPrimaryButton>
          <LessonSecondaryButton onClick={() => router.push(lessonPath(lessonId))}>{t("lesson.practice.back")}</LessonSecondaryButton>
        </div>
      </div>
    );
  }

  return (
    <>
      {fresh !== null ? (
        <div className="pointer-events-none fixed inset-x-0 top-4 z-30 flex justify-center" role="status">
          <span className="score-in flex items-center gap-2 rounded-pill bg-ink px-4 py-2 text-[14px] font-extrabold text-on-ink shadow-floating">
            <Sparkles aria-hidden="true" className="size-4" strokeWidth={2.6} />
            {t("lesson.practice.newBadge", { count: fresh })}
          </span>
        </div>
      ) : null}
      <QuizRun
        key={attempt}
        questions={questions}
        tone={tone}
        seed={seed}
        onClose={() => router.push(lessonPath(lessonId))}
        onAnswer={answered}
        onDone={() => router.push(lessonPath(lessonId))}
        doneTitle={t("lesson.quiz.finish")}
        onMore={() => void more()}
      />
    </>
  );
}
