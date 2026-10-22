"use client";

import { useCallback, useEffect, useState } from "react";
import { CheckCircle2, Flame, Sparkles, XCircle } from "lucide-react";

import { answerText, type LessonTone, type QuizQuestion } from "@micabo/core";

import { CircleTopBar } from "@/components/lesson/CircleTopBar";
import { KeywordText } from "@/components/lesson/KeywordText";
import { LessonPrimaryButton, LessonSecondaryButton } from "@/components/lesson/LessonButtons";
import { QuestionCard, type QuizAnswer } from "@/components/lesson/QuestionCard";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Un quiz** : une question par écran, quelle que soit sa forme, la barre qui se remplit, et
 * la réponse dans un panneau qui monte du bas, vert ou rouge, avec sa phrase d'explication.
 * Une série de bonnes réponses s'affiche ; à la fin, le score se remplit en cercle et Mika
 * réagit. Sert aux Checkpoints, au Quiz final et au quiz de la barre du bas. Jumeau de
 * `LessonQuizView`.
 *
 * Il n'y a pas de score minimum : une étape se coche quand toutes les questions sont
 * répondues. Chaque question ratée devient une flashcard à revoir demain (`onAnswer`).
 *
 * Au clavier : 1 à 4 choisissent une proposition, Entrée ou espace continuent.
 */
export function QuizRun({
  questions,
  tone,
  seed,
  onClose,
  onAnswer,
  onFinish,
  onDone,
  doneTitle,
  onMore,
}: {
  questions: QuizQuestion[];
  tone: LessonTone;
  /**
   * La graine du mélange des propositions : neuve à chaque ouverture, mais **tirée par la
   * page**, pas ici — tirée au rendu, elle différerait entre le serveur et le navigateur, et
   * les propositions changeraient de place à l'hydratation.
   */
  seed: bigint;
  onClose: () => void;
  onAnswer: (question: QuizQuestion, right: boolean) => void;
  /** Toutes répondues : le score, avant l'écran qui le montre. */
  onFinish?: (right: number, total: number) => void;
  /** Le bouton de l'écran de score ; sans lui, il ferme. */
  onDone?: () => void;
  doneTitle?: string;
  /** « Générer de nouvelles questions », quand l'entraînement le propose. */
  onMore?: () => void;
}) {
  const { t } = useI18n();
  const [index, setIndex] = useState(0);
  const [answer, setAnswer] = useState<QuizAnswer | null>(null);
  const [right, setRight] = useState(0);
  const [streak, setStreak] = useState(0);
  const [finished, setFinished] = useState(false);

  const question = questions[index] ?? null;
  const total = questions.length;
  const nextTitle = doneTitle ?? (onDone ? t("lesson.circle.next") : t("lesson.quiz.finish"));

  const record = useCallback(
    (result: QuizAnswer) => {
      if (!question || answer) return;
      setAnswer(result);
      if (result.right) {
        setRight((value) => value + 1);
        setStreak((value) => value + 1);
      } else {
        setStreak(0);
      }
      onAnswer(question, result.right);
    },
    [answer, onAnswer, question],
  );

  const next = useCallback(() => {
    if (!answer) return;
    if (index + 1 < total) {
      setIndex(index + 1);
      setAnswer(null);
    } else {
      onFinish?.(right, total);
      setFinished(true);
    }
  }, [answer, index, onFinish, right, total]);

  // Le clavier, et rien qui l'intercepte à moitié : espace ne doit pas faire défiler la page.
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (finished || !question) return;
      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;
      if (answer && (event.code === "Space" || event.key === "Enter")) {
        event.preventDefault();
        next();
        return;
      }
      if (answer) return;
      const digit = Number(event.key);
      if (digit >= 1 && digit <= 4 && (question.kind === "choice" || question.kind === "gap" || question.kind === "truefalse")) {
        const buttons = document.querySelectorAll<HTMLButtonElement>("[data-quiz-question] [role='group'] button");
        const button = buttons[digit - 1];
        if (button && !button.disabled) {
          event.preventDefault();
          button.click();
        }
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [answer, finished, next, question]);

  const done = () => (onDone ? onDone() : onClose());

  return (
    <div className="relative flex min-h-[calc(100svh-6rem)] flex-col">
      <CircleTopBar
        progress={total === 0 ? 0 : (index + (answer ? 1 : 0)) / total}
        tone={tone}
        label={total === 0 || finished ? null : `${Math.min(index + 1, total)} / ${total}`}
        onClose={onClose}
      />

      {total === 0 ? (
        <div className="flex flex-1 flex-col items-center justify-center gap-4 px-4 pb-4 text-center">
          <Mika mood="think" size={150} label="" />
          <p className="text-[20px] font-bold text-ink">{t("lesson.quiz.empty")}</p>
          <div className="mt-4 w-full max-w-[420px]">
            <LessonPrimaryButton onClick={done}>{nextTitle}</LessonPrimaryButton>
          </div>
        </div>
      ) : finished ? (
        <QuizScore right={right} total={total} tone={tone} doneTitle={nextTitle} onDone={done} onMore={onMore} />
      ) : question ? (
        <div key={index} className="notes-page-in mx-auto flex w-full max-w-[560px] flex-1 flex-col gap-3.5 px-1 pb-[220px] pt-4" data-quiz-question>
          {streak >= 3 ? (
            <span className="score-in inline-flex w-fit items-center gap-1.5 rounded-pill px-3 py-[7px] text-[14px] font-extrabold" style={{ background: "var(--color-tone-yellow-pale)", color: "var(--color-tone-yellow-ink)" }}>
              <Flame aria-hidden="true" className="size-4" strokeWidth={2.6} />
              {t("lesson.quiz.streak", { n: streak })}
            </span>
          ) : null}
          <QuestionCard question={question} tone={tone} answered={answer} shuffleSeed={seed + BigInt(index)} showsFeedback={false} onAnswer={record} />
        </div>
      ) : null}

      {answer && !finished && question ? <AnswerPanel question={question} right={answer.right} isLast={index + 1 === total} onNext={next} /> : null}
    </div>
  );
}

/**
 * **La réponse, dans un panneau qui monte du bas** : vert et « Bonne réponse ! », ou rouge et
 * « Pas tout à fait », la phrase qui explique, et « Continuer » dans la même couleur.
 */
function AnswerPanel({ question, right, isLast, onNext }: { question: QuizQuestion; right: boolean; isLast: boolean; onNext: () => void }) {
  const { t } = useI18n();
  const Icon = right ? CheckCircle2 : XCircle;
  return (
    <div
      className={`panel-rise lesson-bottom-bar -mx-4 mt-auto px-4 pb-[max(0.875rem,env(safe-area-inset-bottom))] pt-5 lg:-mx-10 lg:px-10 ${right ? "bg-correct-soft" : "bg-wrong-soft"}`}
      style={{ boxShadow: `inset 0 2px 0 color-mix(in srgb, ${right ? "var(--color-correct)" : "var(--color-wrong)"} 35%, transparent)` }}
      role="status"
    >
      <div className="mx-auto flex w-full max-w-[560px] flex-col gap-3.5">
        <div className="flex items-center gap-3">
          <Icon aria-hidden="true" className={`size-8 shrink-0 ${right ? "text-correct" : "text-wrong"}`} strokeWidth={2.4} />
          <p className={`flex-1 text-[21px] font-extrabold ${right ? "text-correct-ink" : "text-wrong-ink"}`}>{right ? t("lesson.question.right") : t("lesson.question.wrong")}</p>
          <Mika mood={right ? "happy" : "sad"} size={52} label="" />
        </div>
        {!right && (question.kind === "order" || question.kind === "match" || question.kind === "gap") ? (
          <p className="text-[16px] font-bold leading-snug text-ink">
            <KeywordText text={answerText(question)} tints={false} />
          </p>
        ) : null}
        {question.why ? (
          <p className="text-[16px] font-medium leading-snug text-ink">
            <KeywordText text={question.why} />
          </p>
        ) : null}
        <button
          type="button"
          onClick={onNext}
          className="pressable w-full rounded-[18px] py-4 text-[18px] font-extrabold text-on-ink"
          style={{ background: right ? "var(--color-correct)" : "var(--color-wrong)", boxShadow: `0 4px 0 color-mix(in srgb, ${right ? "var(--color-correct)" : "var(--color-wrong)"} 60%, transparent)` }}
        >
          {isLast ? t("lesson.quiz.seeScore") : t("lesson.quiz.continue")}
        </button>
      </div>
    </div>
  );
}

/** **Le score** : un anneau qui se remplit jusqu'au résultat, Mika qui réagit, et ce qui vient ensuite. */
export function QuizScore({
  right,
  total,
  tone,
  doneTitle,
  onDone,
  onMore,
}: {
  right: number;
  total: number;
  tone: LessonTone;
  doneTitle: string;
  onDone: () => void;
  onMore?: () => void;
}) {
  const { t } = useI18n();
  const ratio = right / Math.max(1, total);
  const [shown, setShown] = useState(0);
  useEffect(() => {
    const timer = window.setTimeout(() => setShown(ratio), 50);
    return () => window.clearTimeout(timer);
  }, [ratio]);

  const size = 170;
  const stroke = 14;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const message = ratio >= 0.8 ? t("lesson.quiz.great") : ratio >= 0.5 ? t("lesson.quiz.good") : t("lesson.quiz.keepGoing");

  return (
    <div className="score-in flex flex-1 flex-col items-center justify-center gap-[18px] px-4 pb-4 text-center">
      <Mika mood={ratio >= 0.8 ? "celebrate" : ratio >= 0.5 ? "happy" : "think"} size={130} label="" />
      <div className="relative" style={{ width: size, height: size }}>
        <svg aria-hidden="true" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
          <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--color-track)" strokeWidth={stroke} />
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={ratio >= 0.5 ? `var(--color-tone-${tone}-vivid)` : "var(--color-wrong)"}
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={circumference * (1 - shown)}
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
            className="score-ring"
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <p className="numeral text-[40px] font-extrabold leading-none" style={{ color: `var(--color-tone-${tone}-ink)` }}>
            {right} / {total}
          </p>
          <p className="numeral mt-1 text-[16px] font-bold text-ink-secondary">{Math.round(ratio * 100)} %</p>
        </div>
      </div>
      <p className="text-[20px] font-bold text-ink">{message}</p>
      {right < total ? <p className="max-w-[360px] text-[15px] font-medium text-ink-secondary">{t("lesson.quiz.missedBecomeCards")}</p> : null}
      <div className="mt-4 flex w-full max-w-[420px] flex-col gap-3">
        <LessonPrimaryButton onClick={onDone}>{doneTitle}</LessonPrimaryButton>
        {onMore ? (
          <LessonSecondaryButton onClick={onMore}>
            <Sparkles aria-hidden="true" className="size-[18px]" strokeWidth={2.4} />
            {t("lesson.practice.more")}
          </LessonSecondaryButton>
        ) : null}
      </div>
    </div>
  );
}
