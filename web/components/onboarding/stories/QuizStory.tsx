"use client";

import { useState } from "react";

import type { QuizQuestion } from "@micabo/core";

import { QuestionCard, type QuizAnswer } from "@/components/lesson/QuestionCard";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Une question du quiz**, la vraie : on répond, elle dit si c'est juste et pourquoi. Puis
 * elle se repose. Rien n'est enregistré : c'est la démonstration.
 */
export function QuizStory() {
  const { t } = useI18n();
  const [answered, setAnswered] = useState<QuizAnswer | null>(null);
  const [round, setRound] = useState(0);
  const question: QuizQuestion = {
    id: `demo:${round}`,
    kind: "choice",
    prompt: t("demo.card2Front"),
    choices: [t("demo.card2c1"), t("demo.card2c2"), t("demo.card2c3")],
    answer: 0,
    why: t("demo.card2Back"),
    matches: [],
    difficulty: 1,
  };

  return (
    <div className="w-full max-w-[340px] text-start">
      <div key={round} className="notes-page-in">
        <QuestionCard question={question} tone="blue" answered={answered} shuffleSeed={0n} showsFeedback reveals onAnswer={setAnswered} />
      </div>
      {answered ? (
        <button
          type="button"
          onClick={() => {
            setAnswered(null);
            setRound((value) => value + 1);
          }}
          className="pressable mt-3 w-full rounded-pill bg-surface-muted py-2 text-[13.5px] font-extrabold text-ink"
        >
          {t("onboarding.quizAgain")}
        </button>
      ) : null}
    </div>
  );
}
