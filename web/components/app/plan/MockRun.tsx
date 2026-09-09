"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";

import { mockScore, readinessGap } from "@micabo/core";

import { Button } from "@/components/ui/button";
import { finishMockSession, type MockAnswer } from "@/lib/actions/mocks";
import { useI18n } from "@/lib/i18n/client";

/**
 * **La passation d'un examen blanc.**
 *
 * L'écran le plus contraint du produit, et il doit l'être : c'est le seul endroit où l'on
 * mesure, donc le seul où l'on ne s'aide pas. Pas d'indice, pas de retour à la question
 * précédente, pas de notation à quatre boutons - deux réponses, su ou pas su, et on avance.
 * Un chronomètre court.
 *
 * Ce n'est **pas** une session de révision qui compterait double : rien n'est envoyé à la
 * répétition espacée. Un blanc mesure, il n'apprend pas ; mélanger les deux fausserait à la
 * fois le score et les échéances.
 */

export interface MockQuestion {
  id: string;
  front: string;
  back: string;
  courseTitle: string | null;
}

export function MockRun({
  sessionId,
  examName,
  examId,
  minutes,
  questions,
  masteryPercent,
}: {
  sessionId: string;
  examName: string;
  examId: string;
  minutes: number;
  questions: MockQuestion[];
  masteryPercent: number;
}) {
  const { t } = useI18n();
  const router = useRouter();

  const [index, setIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [answers, setAnswers] = useState<MockAnswer[]>([]);
  const [done, setDone] = useState(false);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);
  const [remaining, setRemaining] = useState(minutes * 60);

  const deadline = useRef(Date.now() + minutes * 60_000);
  const question = questions[index];

  const close = useCallback(
    async (final: MockAnswer[]) => {
      setSaving(true);
      setFailed(false);
      const result = await finishMockSession(sessionId, final);
      setSaving(false);
      if (result.status === "error") {
        setFailed(true);
        return;
      }
      setDone(true);
      router.refresh();
    },
    [router, sessionId],
  );

  // Le temps imparti est la contrainte de l'exercice : quand il tombe, la session se ferme
  // sur ce qui a été répondu. Ne pas fermer laisserait un score que rien ne borne.
  useEffect(() => {
    if (done) return;
    const timer = setInterval(() => {
      const left = Math.max(0, Math.round((deadline.current - Date.now()) / 1000));
      setRemaining(left);
      if (left === 0) {
        clearInterval(timer);
        void close(answers);
      }
    }, 1000);
    return () => clearInterval(timer);
  }, [answers, close, done]);

  const correct = answers.filter((answer) => answer.correct).length;

  const result = useMemo(
    () => ({
      id: sessionId,
      examId,
      questionCount: questions.length,
      correctCount: correct,
      finishedAt: new Date(),
    }),
    [correct, examId, questions.length, sessionId],
  );

  if (done || !question) {
    return (
      <MockDone
        score={mockScore(result)}
        correct={correct}
        total={questions.length}
        gap={readinessGap(masteryPercent, result)}
        masteryPercent={masteryPercent}
        examId={examId}
      />
    );
  }

  function answer(knew: boolean) {
    const next = [...answers, { card: question!.id, correct: knew }];
    setAnswers(next);
    setRevealed(false);

    if (index + 1 >= questions.length) {
      void close(next);
      return;
    }
    setIndex(index + 1);
  }

  return (
    <div className="mx-auto flex min-h-[70svh] w-full max-w-[640px] flex-col">
      <div className="flex items-center justify-between gap-4">
        <span className="min-w-0 truncate text-[13px] text-ink-secondary">{examName}</span>
        <span
          className={`numeral shrink-0 rounded-pill px-2.5 py-1 text-[13px] font-semibold ${
            remaining <= 60 ? "bg-negative-soft text-negative" : "bg-surface-muted text-ink"
          }`}
          role="timer"
          aria-live="off"
        >
          {clock(remaining)}
        </span>
      </div>

      <div className="mt-3 flex items-center gap-2">
        <span
          aria-hidden
          className="h-1 min-w-0 flex-1 overflow-hidden rounded-pill bg-surface-sunken"
        >
          <span
            className="block h-full rounded-pill bg-accent transition-all duration-menu"
            style={{ width: `${(index / questions.length) * 100}%` }}
          />
        </span>
        <span className="numeral shrink-0 text-[12.5px] text-ink-tertiary">
          {t("app.mock.progress", { index: index + 1, total: questions.length })}
        </span>
      </div>

      <div className="mt-8 flex min-h-0 flex-1 flex-col justify-center">
        {question.courseTitle ? (
          <p className="eyebrow mb-3 text-center text-ink-tertiary">{question.courseTitle}</p>
        ) : null}
        <p className="text-center text-[21px] font-semibold leading-snug text-ink">
          {question.front}
        </p>

        {revealed ? (
          <div className="mt-6 panel p-5">
            <p className="text-[16px] leading-relaxed text-ink-reading">{question.back}</p>
          </div>
        ) : null}
      </div>

      <div className="mt-8">
        {revealed ? (
          <div className="grid grid-cols-2 gap-2">
            <Button variant="outline" onClick={() => answer(false)} disabled={saving}>
              {t("app.mock.missed")}
            </Button>
            <Button onClick={() => answer(true)} disabled={saving}>
              {t("app.mock.knew")}
            </Button>
          </div>
        ) : (
          <Button className="w-full" onClick={() => setRevealed(true)}>
            {t("app.mock.reveal")}
          </Button>
        )}

        <p className="mt-3 text-center text-[12px] text-ink-tertiary">
          {t("app.mock.noHelp")}
        </p>

        {failed ? (
          <p className="mt-3 text-center text-[13px] text-negative" role="alert">
            {t("app.plan.verdict.failed")}
          </p>
        ) : null}
      </div>
    </div>
  );
}

/**
 * Le résultat, et ce qu'il change.
 *
 * L'écart entre la maîtrise et le score est le chiffre qui vaut le déplacement : il dit si
 * réviser plus suffira, ou s'il faut réviser autrement.
 */
function MockDone({
  score,
  correct,
  total,
  gap,
  masteryPercent,
  examId,
}: {
  score: number;
  correct: number;
  total: number;
  gap: number;
  masteryPercent: number;
  examId: string;
}) {
  const { t } = useI18n();
  const tone = score >= 75 ? "text-positive" : score >= 50 ? "text-caution" : "text-negative";

  return (
    <div className="mx-auto w-full max-w-[560px] py-6">
      <p className="eyebrow text-center text-ink-tertiary">{t("app.mock.doneEyebrow")}</p>
      <p className={`numeral mt-3 text-center text-[56px] font-bold leading-none ${tone}`}>
        {score}
        <span className="text-[28px]"> %</span>
      </p>
      <p className="numeral mt-2 text-center text-[14px] text-ink-secondary">
        {t("app.mock.outOf", { correct, total })}
      </p>

      <div className="mt-7 panel p-5">
        <p className="section-title">{t("app.mock.gapTitle")}</p>
        <p className="mt-2 text-[14px] leading-relaxed text-ink-secondary">
          {gap >= 15
            ? t("app.mock.gapWide", { mastery: masteryPercent, score })
            : gap <= -10
              ? t("app.mock.gapNarrowBetter", { mastery: masteryPercent, score })
              : t("app.mock.gapClose", { mastery: masteryPercent, score })}
        </p>
      </div>

      <div className="mt-5 flex flex-wrap justify-center gap-2">
        <Button render={<Link href={`/app/plan/${examId}` as never} />}>
          {t("app.mock.seeExam")}
        </Button>
        <Button variant="outline" render={<Link href={"/app/plan" as never} />}>
          {t("app.plan.sheet.back")}
        </Button>
      </div>
    </div>
  );
}

function clock(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return `${minutes}:${`${rest}`.padStart(2, "0")}`;
}
