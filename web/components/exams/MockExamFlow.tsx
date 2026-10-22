"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Undo2, Check, CheckCircle2, ChevronDown, ChevronLeft, Clock, EyeOff, Layers, Loader2, MinusCircle, Play, Send, Timer, X, XCircle } from "lucide-react";

import {
  EXAM_DURATIONS,
  answerText,
  choiceOrder,
  examFraction,
  examGradeLabel,
  examPasses,
  examQuestionCount,
  examResult,
  pickingSeed,
  type ExamPaper,
  type ExamPaperResult,
  type LessonTone,
  type QuizQuestion,
} from "@micabo/core";

import { ExamLessonChoice, LessonChecklist } from "@/components/exams/ExamEditSheet";
import { KeywordText, plainKeywordText } from "@/components/lesson/KeywordText";
import { LessonPrimaryButton, LessonSecondaryButton } from "@/components/lesson/LessonButtons";
import { QuestionCard, type QuizAnswer } from "@/components/lesson/QuestionCard";
import { Mika } from "@/components/mika/Mika";
import { addExamMissedCards, finishExamPaper } from "@/lib/actions/exam-paper";
import { useI18n } from "@/lib/i18n/client";
import { requestPaywall } from "@/lib/paywall";

/**
 * **Un examen blanc, du début à la fin** : on choisit les leçons et la durée, Mika écrit la
 * copie, on compose contre la montre sans savoir si l'on a juste, puis on rend : la note dans
 * le barème du pays, leçon par leçon, et le corrigé de chaque question. Jumeau de
 * `MockExamFlow.swift`.
 */
export function MockExamFlow({
  title,
  examId,
  lessons,
  preselected,
  country,
  onClose,
}: {
  title: string;
  examId: string | null;
  lessons: (ExamLessonChoice & { tone: LessonTone })[];
  preselected: string[];
  country: string | null;
  onClose: () => void;
}) {
  const { t, locale } = useI18n();
  const router = useRouter();
  type Phase = { kind: "setup" } | { kind: "writing" } | { kind: "failed"; message: string } | { kind: "run"; paper: ExamPaper } | { kind: "result"; paper: ExamPaper; answers: Record<string, QuizAnswer>; result: ExamPaperResult };
  const [phase, setPhase] = useState<Phase>({ kind: "setup" });
  const [selected, setSelected] = useState<Set<string>>(() => new Set(preselected.length > 0 ? preselected : lessons.slice(0, 1).map((lesson) => lesson.id)));
  const [minutes, setMinutes] = useState<number>(30);
  const tone = lessons.find((lesson) => selected.has(lesson.id))?.tone ?? "blue";

  function toggle(id: string) {
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function begin() {
    setPhase({ kind: "writing" });
    try {
      const response = await fetch("/api/lesson/exam", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title, examId, lessonIds: lessons.map((lesson) => lesson.id).filter((id) => selected.has(id)), minutes }),
      });
      const outcome = (await response.json()) as { status: string; paper?: ExamPaper; message?: string; code?: string };
      if (outcome.status === "ok" && outcome.paper && outcome.paper.items.length > 0) {
        setPhase({ kind: "run", paper: outcome.paper });
        return;
      }
      if (outcome.code === "pro_required" || outcome.code === "daily_limit") {
        setPhase({ kind: "setup" });
        requestPaywall();
        return;
      }
      setPhase({ kind: "failed", message: outcome.message ?? t("lesson.exam.failed") });
    } catch {
      setPhase({ kind: "failed", message: t("lesson.exam.failed") });
    }
  }

  async function submit(paper: ExamPaper, answers: Record<string, QuizAnswer>, seconds: number) {
    const local = examResult(paper, answers, seconds);
    setPhase({ kind: "result", paper, answers, result: local });
    const outcome = await finishExamPaper(
      paper.id,
      Object.entries(answers).map(([id, answer]) => ({ id, right: answer.right, picked: answer.picked })),
      seconds,
    );
    if (outcome.status === "ok" && outcome.result) setPhase({ kind: "result", paper, answers, result: outcome.result });
    router.refresh();
  }

  return (
    <div className="fixed inset-0 z-50 flex flex-col overflow-y-auto bg-canvas" role="dialog" aria-modal="true">
      {phase.kind === "setup" ? (
        <div className="mx-auto flex w-full max-w-[640px] flex-1 flex-col">
          <div className="flex px-3 pt-2">
            <button type="button" onClick={onClose} aria-label={t("lesson.circle.close")} className="pressable flex size-10 items-center justify-center rounded-full text-ink hover:bg-surface-muted">
              <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
            </button>
          </div>
          <div className="flex flex-1 flex-col gap-6 px-4 pb-5">
            <div className="flex items-center gap-3.5">
              <div className="flex min-w-0 flex-1 flex-col gap-1.5">
                <h2 className="line-clamp-2 text-[32px] font-extrabold leading-tight tracking-tight-title text-ink">{title}</h2>
                <p className="text-[16px] font-medium text-ink-secondary">{t("lesson.exam.setupBody")}</p>
              </div>
              <Mika mood="think" size={84} label="" />
            </div>
            <div className="flex flex-col gap-3">
              <p className="text-[15px] font-extrabold text-ink-secondary">{t("lesson.exam.duration")}</p>
              <div className="grid grid-cols-4 gap-2.5">
                {EXAM_DURATIONS.map((value) => {
                  const on = minutes === value;
                  return (
                    <button
                      key={value}
                      type="button"
                      aria-pressed={on}
                      onClick={() => setMinutes(value)}
                      className={`pressable flex flex-col items-center rounded-[18px] py-3.5 ${on ? "scale-[1.04] bg-accent-soft text-accent shadow-[inset_0_0_0_2px_var(--color-accent)]" : "bg-surface text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)]"}`}
                    >
                      <span className="numeral text-[24px] font-extrabold leading-none">{value}</span>
                      <span className="mt-0.5 text-[13px] font-bold">min</span>
                    </button>
                  );
                })}
              </div>
              <p className="text-[14px] font-semibold text-ink-secondary">{t("lesson.exam.questionCount", { count: examQuestionCount(minutes) })}</p>
            </div>
            <div className="flex flex-col gap-3">
              <p className="text-[15px] font-extrabold text-ink-secondary">{t("lesson.exam.lessons")}</p>
              <LessonChecklist lessons={lessons} selected={selected} onToggle={toggle} />
            </div>
            <ul className="flex flex-col gap-2.5 rounded-[20px] bg-surface-muted p-4">
              {[
                [Timer, "lesson.exam.rule.timer"],
                [EyeOff, "lesson.exam.rule.hidden"],
                [CheckCircle2, "lesson.exam.rule.grade"],
              ].map(([Icon, key]) => {
                const Rule = Icon as typeof Timer;
                return (
                  <li key={key as string} className="flex items-start gap-3 text-[15px] font-medium text-ink">
                    <Rule aria-hidden="true" className="mt-0.5 size-[18px] shrink-0 text-accent" strokeWidth={2.4} />
                    {t(key as string)}
                  </li>
                );
              })}
            </ul>
          </div>
          <div className="lesson-bottom-bar bg-canvas px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-2">
            <div className="mx-auto w-full max-w-[560px]">
              <LessonPrimaryButton onClick={() => void begin()} disabled={selected.size === 0} style={{ background: selected.size > 0 ? "var(--color-accent)" : undefined }}>
                <Play aria-hidden="true" className="size-5 fill-current" />
                {t("lesson.exam.begin")}
              </LessonPrimaryButton>
            </div>
          </div>
        </div>
      ) : phase.kind === "writing" ? (
        <div className="flex flex-1 flex-col items-center justify-center gap-5 px-8 text-center">
          <Mika mood="think" size={170} label="" />
          <p className="text-[20px] font-bold text-ink">{t("lesson.exam.writing")}</p>
          <p className="max-w-[420px] text-[16px] font-medium text-ink-secondary">{t("lesson.exam.writingSub")}</p>
          <Loader2 aria-hidden="true" className="size-6 animate-spin text-accent" />
        </div>
      ) : phase.kind === "failed" ? (
        <div className="flex flex-1 flex-col items-center justify-center gap-5 px-8 text-center">
          <Mika mood="sad" size={150} label="" />
          <p className="text-[20px] font-bold text-ink">{phase.message}</p>
          <div className="mt-4 flex w-full max-w-[420px] flex-col gap-3">
            <LessonPrimaryButton onClick={() => void begin()} style={{ background: "var(--color-accent)" }}>
              {t("lesson.practice.retry")}
            </LessonPrimaryButton>
            <LessonSecondaryButton onClick={() => setPhase({ kind: "setup" })}>{t("lesson.practice.back")}</LessonSecondaryButton>
          </div>
        </div>
      ) : phase.kind === "run" ? (
        <MockExamRun paper={phase.paper} tone={tone} onQuit={onClose} onSubmit={(answers, seconds) => void submit(phase.paper, answers, seconds)} />
      ) : (
        <MockExamResult paper={phase.paper} answers={phase.answers} result={phase.result} country={country} locale={locale} onClose={onClose} />
      )}
    </div>
  );
}

// MARK: - Composer

/** **La copie, contre la montre** : une question à la fois, la réponse choisie se surligne sans verdict, on revient en arrière, on change d'avis. À zéro, la copie se rend seule. */
function MockExamRun({ paper, tone, onQuit, onSubmit }: { paper: ExamPaper; tone: LessonTone; onQuit: () => void; onSubmit: (answers: Record<string, QuizAnswer>, seconds: number) => void }) {
  const { t } = useI18n();
  const [index, setIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, QuizAnswer>>({});
  const [resets, setResets] = useState<Record<string, number>>({});
  const [startedAt] = useState(() => Date.now());
  const [now, setNow] = useState(() => Date.now());
  const [confirm, setConfirm] = useState<"quit" | "submit" | null>(null);
  const submitted = useRef(false);
  const seed = useMemo(() => pickingSeed(paper.id.toUpperCase()), [paper.id]);

  const total = paper.minutes * 60;
  const elapsed = Math.min(total, Math.floor((now - startedAt) / 1000));
  const remaining = Math.max(0, total - elapsed);
  const item = paper.items[index]!;
  const answeredCount = paper.items.filter((entry) => answers[entry.question.id]).length;

  const submit = useCallback(() => {
    if (submitted.current) return;
    submitted.current = true;
    onSubmit(answers, Math.min(total, Math.floor((Date.now() - startedAt) / 1000)));
  }, [answers, onSubmit, startedAt, total]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      const current = Date.now();
      setNow(current);
      if (total - Math.floor((current - startedAt) / 1000) <= 0) submit();
    }, 1000);
    return () => window.clearInterval(timer);
  }, [startedAt, submit, total]);

  const go = (target: number) => {
    if (target >= 0 && target < paper.items.length) setIndex(target);
  };
  const answer = answers[item.question.id];
  const timerColor = remaining <= 60 ? "var(--color-wrong)" : remaining <= 300 ? "var(--color-caution-vivid)" : "var(--color-accent)";

  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-1 flex-col">
      <div className="flex items-center gap-3 px-3 pt-2">
        <button type="button" onClick={() => setConfirm("quit")} aria-label={t("lesson.exam.quit")} className="pressable flex size-10 items-center justify-center rounded-full text-ink hover:bg-surface-muted">
          <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
        </button>
        <span className="flex-1" />
        <span className="flex items-center gap-2 rounded-pill bg-surface px-3.5 py-2" style={{ boxShadow: `inset 0 0 0 1.5px color-mix(in srgb, ${timerColor} 50%, transparent)` }}>
          <Clock aria-hidden="true" className="size-[18px]" strokeWidth={2.6} style={{ color: timerColor }} />
          <span className={`numeral text-[19px] font-extrabold ${remaining <= 60 ? "text-wrong-ink" : "text-ink"}`}>
            {Math.floor(remaining / 60)}:{String(remaining % 60).padStart(2, "0")}
          </span>
        </span>
        <span className="flex-1" />
        <span className="numeral w-14 text-right text-[16px] font-extrabold text-ink-secondary">
          {answeredCount}/{paper.items.length}
        </span>
      </div>

      <ol className="flex gap-1.5 overflow-x-auto px-4 pt-3 [scrollbar-width:none]">
        {paper.items.map((entry, number) => {
          const done = Boolean(answers[entry.question.id]);
          return (
            <li key={entry.question.id}>
              <button
                type="button"
                onClick={() => go(number)}
                aria-current={number === index ? "step" : undefined}
                className={`numeral flex size-7 items-center justify-center rounded-full text-[12px] font-extrabold ${done ? "bg-accent text-on-ink" : "bg-surface text-ink-secondary"}`}
                style={{ boxShadow: number === index ? "inset 0 0 0 2px var(--color-ink)" : "inset 0 0 0 1px var(--color-stroke)" }}
              >
                {number + 1}
              </button>
            </li>
          );
        })}
      </ol>

      <div className="flex flex-1 flex-col gap-3.5 px-4 pb-6 pt-[18px]">
        <p className="text-[14px] font-extrabold text-ink-secondary">{t("lesson.exam.questionOf", { n: index + 1, total: paper.items.length })}</p>
        {paper.lessons.length > 1 && paper.lessons[item.lesson] ? (
          <span className="w-fit rounded-pill px-2.5 py-1 text-[13px] font-bold" style={{ background: `var(--color-tone-${tone}-pale)`, color: `var(--color-tone-${tone}-ink)` }}>
            {paper.lessons[item.lesson]!.title}
          </span>
        ) : null}
        <div key={`${item.question.id}#${resets[item.question.id] ?? 0}`} className="notes-page-in flex flex-col gap-4">
          {answer && (item.question.kind === "order" || item.question.kind === "match") ? (
            <p className="text-[22px] font-extrabold leading-snug text-ink">
              <KeywordText text={item.question.prompt} />
            </p>
          ) : (
            <QuestionCard
              question={item.question}
              tone={tone}
              answered={answer ?? null}
              shuffleSeed={seed}
              showsFeedback={false}
              reveals={false}
              onAnswer={(value) => setAnswers((current) => ({ ...current, [item.question.id]: value }))}
            />
          )}
          {answer ? (
            <div className="flex items-center gap-2.5 rounded-[16px] bg-accent-soft/60 p-3.5">
              <CheckCircle2 aria-hidden="true" className="size-5 text-accent" strokeWidth={2.4} />
              <span className="flex-1 text-[15px] font-bold text-accent">{t("lesson.exam.saved")}</span>
              <button
                type="button"
                onClick={() => {
                  setAnswers((current) => {
                    const next = { ...current };
                    delete next[item.question.id];
                    return next;
                  });
                  setResets((current) => ({ ...current, [item.question.id]: (current[item.question.id] ?? 0) + 1 }));
                }}
                className="pressable flex items-center gap-1.5 text-[14px] font-bold text-ink-secondary"
              >
                <Undo2 aria-hidden="true" className="size-4" strokeWidth={2.4} />
                {t("lesson.exam.change")}
              </button>
            </div>
          ) : null}
        </div>
      </div>

      <div className="lesson-bottom-bar flex gap-3 bg-canvas px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-2.5">
        <button
          type="button"
          onClick={() => go(index - 1)}
          disabled={index === 0}
          aria-label={t("lesson.exam.previous")}
          className="pressable flex size-[58px] shrink-0 items-center justify-center rounded-[18px] bg-surface text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)] disabled:opacity-40"
        >
          <ChevronLeft aria-hidden="true" className="size-5" strokeWidth={2.8} />
        </button>
        {index === paper.items.length - 1 ? (
          <LessonPrimaryButton onClick={() => (answeredCount < paper.items.length ? setConfirm("submit") : submit())} style={{ background: "var(--color-correct)" }}>
            <Send aria-hidden="true" className="size-[18px]" strokeWidth={2.4} />
            {t("lesson.exam.submit")}
          </LessonPrimaryButton>
        ) : (
          <LessonPrimaryButton onClick={() => go(index + 1)} style={{ background: answer ? "var(--color-accent)" : "var(--color-ink-secondary)" }}>
            {t(answer ? "lesson.exam.next" : "lesson.exam.skip")}
          </LessonPrimaryButton>
        )}
      </div>

      {confirm ? (
        <div className="fixed inset-0 z-[60] flex items-end justify-center bg-ink/40 p-4 sm:items-center" role="alertdialog" aria-modal="true" onClick={() => setConfirm(null)}>
          <div className="score-in flex w-full max-w-[420px] flex-col gap-3 rounded-[24px] bg-canvas p-5" onClick={(event) => event.stopPropagation()}>
            <p className="text-[17px] font-bold text-ink">{confirm === "quit" ? t("lesson.exam.quitConfirm") : t("lesson.exam.submitConfirm", { count: paper.items.length - answeredCount })}</p>
            <LessonPrimaryButton onClick={confirm === "quit" ? onQuit : submit} style={{ background: confirm === "quit" ? "var(--color-wrong)" : "var(--color-correct)" }}>
              {confirm === "quit" ? t("lesson.exam.quit") : t("lesson.exam.submit")}
            </LessonPrimaryButton>
            <LessonSecondaryButton onClick={() => setConfirm(null)}>{t("app.common.cancel")}</LessonSecondaryButton>
          </div>
        </div>
      ) : null}
    </div>
  );
}

// MARK: - Le résultat

/** **La copie rendue** : la note dans le barème du pays dans un anneau, la moyenne ou pas, chaque leçon avec sa barre, puis le corrigé. Les erreurs peuvent rejoindre les flashcards. */
function MockExamResult({
  paper,
  answers,
  result,
  country,
  locale,
  onClose,
}: {
  paper: ExamPaper;
  answers: Record<string, QuizAnswer>;
  result: ExamPaperResult;
  country: string | null;
  locale: string;
  onClose: () => void;
}) {
  const { t } = useI18n();
  const [shown, setShown] = useState(false);
  const [cardsAdded, setCardsAdded] = useState(false);
  const [corrections, setCorrections] = useState(false);
  const [adding, setAdding] = useState(false);
  const fraction = examFraction(result);
  const passes = examPasses(fraction);
  const missed = paper.items.filter((item) => answers[item.question.id]?.right !== true);
  const seed = useMemo(() => pickingSeed(paper.id.toUpperCase()), [paper.id]);

  useEffect(() => {
    const timer = window.setTimeout(() => setShown(true), 60);
    return () => window.clearTimeout(timer);
  }, []);

  const size = 220;
  const stroke = 18;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;

  async function addCards() {
    setAdding(true);
    const outcome = await addExamMissedCards(paper.id);
    setAdding(false);
    if (outcome.status === "ok") setCardsAdded(true);
  }

  return (
    <div className="score-in mx-auto flex w-full max-w-[640px] flex-col gap-6 px-4 pb-8">
      <div className="flex justify-end pt-2">
        <button type="button" onClick={onClose} aria-label={t("lesson.circle.close")} className="pressable flex size-10 items-center justify-center rounded-full text-ink hover:bg-surface-muted">
          <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
        </button>
      </div>

      <div className="relative mx-auto" style={{ width: size, height: size }}>
        <svg aria-hidden="true" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
          <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--color-track)" strokeWidth={stroke} />
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={passes ? "var(--color-correct)" : "var(--color-caution-vivid)"}
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={circumference * (1 - (shown ? fraction : 0))}
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
            className="score-ring"
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <p className="numeral text-[44px] font-extrabold leading-none text-ink">{examGradeLabel(fraction, country, locale)}</p>
          {examGradeLabel(fraction, country, locale) !== `${result.correct}/${result.total}` ? (
            <p className="numeral mt-1.5 text-[16px] font-bold text-ink-secondary">
              {result.correct}/{result.total}
            </p>
          ) : null}
        </div>
        <div className="absolute -right-9 bottom-0">
          <Mika mood={passes ? "celebrate" : "sad"} size={86} label="" />
        </div>
      </div>

      <div className="flex flex-col items-center gap-1.5 text-center">
        <h2 className="text-[28px] font-extrabold leading-tight tracking-tight-title text-ink">{t(passes ? "lesson.exam.passed" : "lesson.exam.notYet")}</h2>
        <p className="text-[15px] font-semibold text-ink-secondary">{t("lesson.exam.time", { used: Math.max(1, Math.ceil(result.seconds / 60)), total: result.minutes })}</p>
      </div>

      {result.lessons.length > 1 ? (
        <section className="flex flex-col gap-3.5 rounded-[22px] bg-surface p-[18px] shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
          <h3 className="text-[18px] font-extrabold text-ink">{t("lesson.exam.byLesson")}</h3>
          {result.lessons.map((score, index) => {
            const part = score.total === 0 ? 0 : score.correct / score.total;
            return (
              <div key={index} className="flex flex-col gap-1.5">
                <div className="flex items-center justify-between gap-3">
                  <span className="truncate text-[15px] font-bold text-ink">{score.title}</span>
                  <span className={`numeral text-[15px] font-extrabold ${examPasses(part) ? "text-correct-ink" : "text-wrong-ink"}`}>{examGradeLabel(part, country, locale)}</span>
                </div>
                <div className="h-2.5 overflow-hidden rounded-pill bg-track">
                  <div className="h-full rounded-pill transition-[width] duration-[900ms] ease-out" style={{ width: `${(shown ? part : 0) * 100}%`, background: examPasses(part) ? "var(--color-correct)" : "var(--color-caution-vivid)" }} />
                </div>
              </div>
            );
          })}
        </section>
      ) : null}

      {missed.length > 0 ? (
        <LessonPrimaryButton onClick={() => void addCards()} disabled={cardsAdded || adding} style={{ background: cardsAdded ? "var(--color-correct)" : "var(--color-accent)" }}>
          {cardsAdded ? <Check aria-hidden="true" className="size-5" strokeWidth={3} /> : <Layers aria-hidden="true" className="size-5" strokeWidth={2.4} />}
          {cardsAdded ? t("lesson.exam.cardsAdded") : t("lesson.exam.addCards", { count: missed.length })}
        </LessonPrimaryButton>
      ) : null}

      <section className="flex flex-col gap-3">
        <button type="button" onClick={() => setCorrections((value) => !value)} aria-expanded={corrections} className="pressable flex items-center justify-between py-1">
          <span className="text-[18px] font-extrabold text-ink">{t("lesson.exam.corrections")}</span>
          <ChevronDown aria-hidden="true" className={`size-5 text-ink-secondary transition-transform ${corrections ? "rotate-180" : ""}`} strokeWidth={2.6} />
        </button>
        {corrections
          ? paper.items.map((item, number) => <CorrectionRow key={item.question.id} number={number + 1} question={item.question} answer={answers[item.question.id] ?? null} seed={seed} />)
          : null}
      </section>

      <LessonSecondaryButton onClick={onClose}>{t("lesson.exam.done")}</LessonSecondaryButton>
    </div>
  );
}

/** Une question corrigée : ce qu'on a répondu, la bonne réponse, et pourquoi. */
function CorrectionRow({ number, question, answer, seed }: { number: number; question: QuizQuestion; answer: QuizAnswer | null; seed: bigint }) {
  const { t } = useI18n();
  const right = answer?.right === true;
  let picked: string | null = null;
  if (answer?.picked !== null && answer?.picked !== undefined) {
    const original = question.kind === "truefalse" ? answer.picked : choiceOrder(question, seed)[answer.picked];
    picked = original !== undefined ? (question.choices[original] ?? null) : null;
  }
  const Icon = answer === null ? MinusCircle : right ? CheckCircle2 : XCircle;
  return (
    <div className="notes-reveal flex flex-col gap-2.5 rounded-[18px] bg-surface p-3.5" style={{ boxShadow: `inset 0 0 0 1.5px ${right ? "color-mix(in srgb, var(--color-correct) 40%, transparent)" : "var(--color-stroke)"}` }}>
      <div className="flex items-start gap-2.5">
        <Icon aria-hidden="true" className={`mt-0.5 size-[22px] shrink-0 ${answer === null ? "text-ink-tertiary" : right ? "text-correct" : "text-wrong"}`} strokeWidth={2.4} />
        <p className="text-[16px] font-extrabold leading-snug text-ink">
          {number}. <KeywordText text={question.prompt} />
        </p>
      </div>
      {picked && !right ? <p className="text-[14.5px] font-semibold text-wrong-ink">{t("lesson.exam.yourAnswer", { answer: plainKeywordText(picked) })}</p> : null}
      {answer === null ? <p className="text-[14.5px] font-semibold text-ink-secondary">{t("lesson.exam.unanswered")}</p> : null}
      <p className="text-[14.5px] font-bold text-correct-ink">{t("lesson.exam.rightAnswer", { answer: plainKeywordText(answerText(question)) })}</p>
      {question.why ? (
        <p className="text-[14.5px] font-medium text-ink-secondary">
          <KeywordText text={question.why} />
        </p>
      ) : null}
    </div>
  );
}
