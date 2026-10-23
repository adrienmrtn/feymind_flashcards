"use client";

import { useEffect, useState } from "react";
import { Check, CheckCircle2, X, XCircle } from "lucide-react";

import { CLOZE_GAP, LESSON_TONES, answerText, choiceOrder, matchRightOrder, normalizeClozeGap, orderPool, type LessonTone, type QuizQuestion } from "@micabo/core";

import { KeywordText, plainKeywordText } from "@/components/lesson/KeywordText";
import { LessonPrimaryButton } from "@/components/lesson/LessonButtons";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

/** Ce que l'élève a répondu à une question. */
export interface QuizAnswer {
  right: boolean;
  /** Pour un QCM, un vrai/faux ou une phrase à trou : le rang choisi, dans l'ordre affiché. */
  picked: number | null;
}

/**
 * **Une question, quelle que soit sa forme** : QCM, vrai/faux, phrase à trou, remise en ordre,
 * association. Jumeau de `QuestionCard.swift`.
 *
 * Les propositions se mélangent à l'affichage, selon `shuffleSeed` : une question qui revient
 * ne présente pas sa bonne réponse au même rang. La même graine redonne le même ordre.
 */
export function QuestionCard({
  question,
  tone,
  answered,
  shuffleSeed = 0n,
  showsFeedback = true,
  reveals = true,
  onAnswer,
}: {
  question: QuizQuestion;
  tone: LessonTone;
  answered: QuizAnswer | null;
  shuffleSeed?: bigint;
  /** Faux dans un quiz : le retour passe dans le panneau du bas. */
  showsFeedback?: boolean;
  /** Faux dans un examen blanc : la réponse choisie se surligne, sans dire si elle est juste. */
  reveals?: boolean;
  onAnswer: (answer: QuizAnswer) => void;
}) {
  const { t } = useI18n();
  const ink = `var(--color-tone-${tone}-ink)`;
  return (
    <div className="flex flex-col gap-[18px]">
      <p className="text-[13px] font-extrabold uppercase tracking-[1.2px]" style={{ color: ink }}>
        {t(`lesson.question.kind.${question.kind}`)}
      </p>

      {question.kind === "gap" ? (
        <GapSentence question={question} tone={tone} answered={reveals ? answered : null} />
      ) : (
        <p className="text-[22px] font-extrabold leading-snug text-ink">
          <KeywordText text={question.prompt} />
        </p>
      )}

      {question.kind === "choice" || question.kind === "gap" ? (
        <ChoiceList question={question} answered={answered} seed={shuffleSeed} compact={question.kind === "gap"} reveals={reveals} onAnswer={onAnswer} />
      ) : question.kind === "truefalse" ? (
        <TrueFalseButtons question={question} answered={answered} reveals={reveals} onAnswer={onAnswer} />
      ) : question.kind === "order" ? (
        <OrderBuilder question={question} tone={tone} answered={answered} seed={shuffleSeed} reveals={reveals} onAnswer={onAnswer} />
      ) : (
        <MatchBoard question={question} answered={answered} seed={shuffleSeed} reveals={reveals} onAnswer={onAnswer} />
      )}

      {showsFeedback && reveals && answered ? <QuestionFeedback question={question} right={answered.right} /> : null}
    </div>
  );
}

/** Juste ou faux, Mika réagit, et la phrase qui explique. */
export function QuestionFeedback({ question, right }: { question: QuizQuestion; right: boolean }) {
  const { t } = useI18n();
  return (
    <div className={`panel-rise flex items-center gap-3 rounded-[18px] p-3.5 ${right ? "bg-correct-soft" : "bg-wrong-soft"}`} role="status">
      <Mika mood={right ? "happy" : "sad"} size={64} label="" />
      <div className="flex min-w-0 flex-col gap-1">
        <p className={`text-[18px] font-extrabold ${right ? "text-correct-ink" : "text-wrong-ink"}`}>{right ? t("lesson.question.right") : t("lesson.question.wrong")}</p>
        {!right && (question.kind === "order" || question.kind === "match") ? (
          <p className="text-[15px] font-bold text-ink">
            <KeywordText text={answerText(question)} tints={false} />
          </p>
        ) : null}
        {question.why ? (
          <p className="text-[15px] font-medium leading-snug text-ink">
            <KeywordText text={question.why} />
          </p>
        ) : null}
      </div>
    </div>
  );
}

// MARK: - QCM et phrase à trou

/** **Les propositions**, mélangées. La bonne passe au vert, une mauvaise au rouge. */
function ChoiceList({
  question,
  answered,
  seed,
  compact,
  reveals,
  onAnswer,
}: {
  question: QuizQuestion;
  answered: QuizAnswer | null;
  seed: bigint;
  compact: boolean;
  reveals: boolean;
  onAnswer: (answer: QuizAnswer) => void;
}) {
  const order = choiceOrder(question, seed);
  const isPicked = (shown: number) => answered?.picked === shown;

  function look(shown: number, original: number): { box: string; text: string; symbol: "check" | "cross" | "dot" | null } {
    if (!answered) return { box: "quiz-choice bg-surface", text: "text-ink", symbol: null };
    if (!reveals) {
      return isPicked(shown)
        ? { box: "bg-accent-soft shadow-[inset_0_0_0_2px_var(--color-accent)]", text: "text-accent", symbol: "dot" }
        : { box: "bg-surface shadow-[inset_0_0_0_2px_var(--color-stroke)]", text: "text-ink-secondary", symbol: null };
    }
    if (original === question.answer) return { box: "bg-correct", text: "text-on-ink", symbol: "check" };
    if (isPicked(shown)) return { box: "bg-wrong path-shake", text: "text-on-ink", symbol: "cross" };
    return { box: "bg-surface", text: "text-ink-tertiary", symbol: null };
  }

  return (
    <div className={compact ? "flex flex-wrap gap-2.5" : "flex flex-col gap-2.5"} role="group">
      {order.map((original, shown) => {
        const style = look(shown, original);
        return (
          <button
            key={shown}
            type="button"
            disabled={answered !== null}
            onClick={() => onAnswer({ right: original === question.answer, picked: shown })}
            className={`pressable flex items-center gap-3 rounded-[16px] text-left transition-colors duration-300 ${compact ? "px-4 py-3" : "w-full px-4 py-[15px]"} ${style.box} ${
              isPicked(shown) ? "scale-[1.02]" : ""
            }`}
          >
            <span className={`${compact ? "text-[18px]" : "flex-1 text-[17px]"} font-bold leading-snug ${style.text}`}>
              <KeywordText text={question.choices[original] ?? ""} tints={false} />
            </span>
            {style.symbol === "check" ? (
              <Check aria-hidden="true" className={`size-[18px] shrink-0 ${style.text}`} strokeWidth={3.4} />
            ) : style.symbol === "cross" ? (
              <X aria-hidden="true" className={`size-[18px] shrink-0 ${style.text}`} strokeWidth={3.4} />
            ) : style.symbol === "dot" ? (
              <span aria-hidden="true" className="size-3 shrink-0 rounded-full bg-accent" />
            ) : null}
          </button>
        );
      })}
    </div>
  );
}

/** **La phrase à trou** : le trou en pointillés tant qu'on n'a pas répondu, puis le bon mot, en vert, à sa place. */
function GapSentence({ question, tone, answered }: { question: QuizQuestion; tone: LessonTone; answered: QuizAnswer | null }) {
  // Le trou du serveur et des apps (« … »), ou celui d'une ancienne leçon du site (« ____ »).
  const parts = normalizeClozeGap(question.prompt).split(CLOZE_GAP);
  const word = question.choices[question.answer] ?? "";
  const filled = answered !== null;
  return (
    <p className="text-[22px] font-extrabold leading-snug text-ink">
      <KeywordText text={parts[0] ?? ""} />
      <span
        className={`mx-0.5 rounded-md px-1.5 transition-colors ${filled ? "bg-correct-soft text-correct-ink" : ""}`}
        style={filled ? undefined : { background: `var(--color-tone-${tone}-pale)`, color: `var(--color-tone-${tone}-ink)` }}
      >
        {filled ? plainKeywordText(word) : "________"}
      </span>
      {parts.length > 1 ? <KeywordText text={parts.slice(1).join(CLOZE_GAP)} /> : null}
    </p>
  );
}

// MARK: - Vrai ou faux

/** Deux grands boutons côte à côte, dans l'ordre « vrai, faux » : on ne mélange pas ce que tout le monde attend à sa place. */
function TrueFalseButtons({
  question,
  answered,
  reveals,
  onAnswer,
}: {
  question: QuizQuestion;
  answered: QuizAnswer | null;
  reveals: boolean;
  onAnswer: (answer: QuizAnswer) => void;
}) {
  function look(index: number): { box: string; text: string } {
    if (!answered) return { box: "quiz-choice bg-surface", text: index === 0 ? "text-correct-ink" : "text-wrong-ink" };
    if (!reveals) {
      return answered.picked === index
        ? { box: "bg-accent-soft shadow-[inset_0_0_0_2px_var(--color-accent)]", text: "text-accent" }
        : { box: "bg-surface", text: "text-ink-tertiary" };
    }
    if (index === question.answer) return { box: "bg-correct", text: "text-on-ink" };
    if (answered.picked === index) return { box: "bg-wrong path-shake", text: "text-on-ink" };
    return { box: "bg-surface", text: "text-ink-tertiary" };
  }
  return (
    <div className="grid grid-cols-2 gap-3" role="group">
      {question.choices.slice(0, 2).map((label, index) => {
        const style = look(index);
        const Icon = index === 0 ? CheckCircle2 : XCircle;
        return (
          <button
            key={index}
            type="button"
            disabled={answered !== null}
            onClick={() => onAnswer({ right: index === question.answer, picked: index })}
            className={`pressable flex flex-col items-center gap-2.5 rounded-[22px] py-[26px] transition-colors duration-300 ${style.box} ${style.text}`}
          >
            <Icon aria-hidden="true" className="size-9" strokeWidth={2.4} />
            <span className="text-[19px] font-extrabold">
              <KeywordText text={label} tints={false} />
            </span>
          </button>
        );
      })}
    </div>
  );
}

// MARK: - Remettre dans l'ordre

/**
 * **Remettre dans l'ordre** : on touche les éléments dans l'ordre voulu ; ils montent dans la
 * réponse, numérotés. Un appui sur un élément placé le renvoie. « Valider » quand tout est
 * placé ; on voit ensuite chaque place, juste ou fausse.
 */
function OrderBuilder({
  question,
  tone,
  answered,
  seed,
  reveals,
  onAnswer,
}: {
  question: QuizQuestion;
  tone: LessonTone;
  answered: QuizAnswer | null;
  seed: bigint;
  reveals: boolean;
  onAnswer: (answer: QuizAnswer) => void;
}) {
  const { t } = useI18n();
  const pool = orderPool(question, seed);
  const [placed, setPlaced] = useState<number[]>([]);
  const identity = question.choices.map((_, index) => index);

  // Relue après coup, la question montre l'ordre juste.
  useEffect(() => {
    if (answered && reveals && placed.length === 0) setPlaced(identity);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- à l'ouverture seulement.
  }, [answered]);

  const vivid = `var(--color-tone-${tone}-vivid)`;
  function verdict(position: number, item: number): "right" | "wrong" | null {
    if (!answered || !reveals) return null;
    return item === position ? "right" : "wrong";
  }

  return (
    <div className="flex flex-col gap-4">
      <ol className="flex flex-col gap-2">
        {placed.map((item, position) => {
          const state = verdict(position, item);
          const ring = state === "right" ? "var(--color-correct)" : state === "wrong" ? "var(--color-wrong)" : answered && !reveals ? "var(--color-accent)" : "var(--color-stroke)";
          return (
            <li key={item}>
              <button
                type="button"
                disabled={answered !== null}
                onClick={() => setPlaced((current) => current.filter((value) => value !== item))}
                className="pressable flex w-full items-center gap-3 rounded-[16px] bg-surface p-3 text-left"
                style={{ boxShadow: `inset 0 0 0 2px ${ring}` }}
              >
                <span
                  className="numeral flex size-[30px] shrink-0 items-center justify-center rounded-full text-[17px] font-extrabold text-on-ink"
                  style={{ background: state === "right" ? "var(--color-correct)" : state === "wrong" ? "var(--color-wrong)" : vivid }}
                >
                  {position + 1}
                </span>
                <span className="text-[17px] font-bold leading-snug text-ink">
                  <KeywordText text={question.choices[item] ?? ""} tints={false} />
                </span>
              </button>
            </li>
          );
        })}
        {Array.from({ length: Math.max(0, question.choices.length - placed.length) }, (_, offset) => {
          const slot = placed.length + offset;
          return (
            <li key={`slot-${slot}`} className="flex h-[54px] items-center rounded-[16px] border-2 border-dashed border-stroke pl-[22px]">
              <span className="numeral text-[17px] font-extrabold text-ink-tertiary">{slot + 1}</span>
            </li>
          );
        })}
      </ol>

      {answered === null ? (
        <>
          <div className="flex flex-wrap gap-2.5">
            {pool
              .filter((item) => !placed.includes(item))
              .map((item) => (
                <button
                  key={item}
                  type="button"
                  onClick={() => setPlaced((current) => [...current, item])}
                  className="pressable rounded-[14px] bg-surface px-3.5 py-[11px] text-left text-[16px] font-bold text-ink shadow-[inset_0_0_0_2px_var(--color-stroke)]"
                >
                  <KeywordText text={question.choices[item] ?? ""} tints={false} />
                </button>
              ))}
          </div>
          <LessonPrimaryButton
            disabled={placed.length !== question.choices.length}
            onClick={() => onAnswer({ right: placed.every((item, position) => item === position), picked: null })}
          >
            {t("lesson.question.check")}
          </LessonPrimaryButton>
        </>
      ) : null}
    </div>
  );
}

// MARK: - Associer

/**
 * **Associer** : un terme à gauche, puis sa définition à droite. Chaque paire prend sa
 * couleur. Quand tout est associé, la réponse tombe : chaque paire juste en vert, chaque fausse
 * en rouge, et le corrigé dans le retour.
 */
function MatchBoard({
  question,
  answered,
  seed,
  reveals,
  onAnswer,
}: {
  question: QuizQuestion;
  answered: QuizAnswer | null;
  seed: bigint;
  reveals: boolean;
  onAnswer: (answer: QuizAnswer) => void;
}) {
  const rightOrder = matchRightOrder(question, seed);
  const [pairs, setPairs] = useState<Map<number, number>>(() => new Map());
  const [selectedLeft, setSelectedLeft] = useState<number | null>(null);

  useEffect(() => {
    if (answered && reveals && pairs.size === 0) setPairs(new Map(question.choices.map((_, index) => [index, index])));
    // eslint-disable-next-line react-hooks/exhaustive-deps -- à l'ouverture seulement.
  }, [answered]);

  const colorOf = (left: number): string | null =>
    pairs.has(left) || selectedLeft === left ? `var(--color-tone-${LESSON_TONES[left % LESSON_TONES.length]}-vivid)` : null;
  const verdictOf = (left: number): boolean | null => (answered && reveals && pairs.has(left) ? pairs.get(left) === left : null);

  function pickLeft(left: number) {
    if (answered) return;
    if (pairs.has(left)) {
      setPairs((current) => {
        const next = new Map(current);
        next.delete(left);
        return next;
      });
    }
    setSelectedLeft((current) => (current === left ? null : left));
  }

  function pickRight(right: number) {
    if (answered || selectedLeft === null) return;
    const next = new Map(pairs);
    for (const [left, value] of next) if (value === right) next.delete(left);
    next.set(selectedLeft, right);
    setPairs(next);
    setSelectedLeft(null);
    if (next.size === question.choices.length) {
      const allRight = [...next].every(([left, value]) => left === value);
      window.setTimeout(() => onAnswer({ right: allRight, picked: null }), 250);
    }
  }

  function tile(text: string, color: string | null, selected: boolean, verdict: boolean | null, onClick: () => void, key: string) {
    const fill = verdict === true ? "var(--color-correct-soft)" : verdict === false ? "var(--color-wrong-soft)" : color ? `color-mix(in srgb, ${color} 16%, transparent)` : "var(--color-surface)";
    const stroke = verdict === true ? "var(--color-correct)" : verdict === false ? "var(--color-wrong)" : (color ?? "var(--color-stroke)");
    return (
      <button
        key={key}
        type="button"
        disabled={answered !== null}
        aria-pressed={selected}
        onClick={onClick}
        className={`pressable flex min-h-12 w-full items-center justify-center rounded-[14px] px-2.5 py-2 text-center text-[15px] font-bold leading-snug text-ink transition-[transform,background-color] ${selected ? "scale-[1.03]" : ""}`}
        style={{ background: fill, boxShadow: `inset 0 0 0 ${selected ? 3 : 2}px ${stroke}` }}
      >
        <KeywordText text={text} tints={false} />
      </button>
    );
  }

  return (
    <div className="grid grid-cols-2 items-start gap-2.5">
      <div className="flex flex-col gap-2.5">
        {question.choices.map((text, left) => tile(text, colorOf(left), selectedLeft === left, verdictOf(left), () => pickLeft(left), `l${left}`))}
      </div>
      <div className="flex flex-col gap-2.5">
        {rightOrder.map((right) => {
          const owner = [...pairs].find(([, value]) => value === right)?.[0];
          return tile(question.matches[right] ?? "", owner === undefined ? null : colorOf(owner), false, owner === undefined ? null : verdictOf(owner), () => pickRight(right), `r${right}`);
        })}
      </div>
    </div>
  );
}
