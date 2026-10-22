"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { CheckCircle2 } from "lucide-react";

import { finalQuestion, notesPages, pickingSeed, swipeDirection, type LessonTone, type QuizQuestion, type SheetBlock, type ThemeNotes, type ThemeStatus, type NotesPage } from "@micabo/core";

import { CircleTopBar } from "@/components/lesson/CircleTopBar";
import { KeywordText } from "@/components/lesson/KeywordText";
import { LessonPrimaryButton } from "@/components/lesson/LessonButtons";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { NoteBlockList, ThemeNotesView, ToneBox } from "@/components/lesson/NoteBlocks";
import { QuestionCard, type QuizAnswer } from "@/components/lesson/QuestionCard";
import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { Spinner } from "@/components/ui/spinner";
import { useI18n } from "@/lib/i18n/client";

export interface StepTheme {
  id: string;
  title: string;
  icon: string | null;
  notes: ThemeNotes | null;
  /** L'ancien format, pour un chapitre d'avant la refonte : déjà normalisé. */
  sheet: SheetBlock[];
  status: ThemeStatus;
  quiz: { questions: QuizQuestion[] } | null;
}

/**
 * **Une étape Notes, en écrans courts** : l'idée du thème, puis un écran par bloc, « À
 * retenir », et la question de fin. Les segments du haut se remplissent à mesure ; on avance
 * avec « Continuer », d'un glissé ou des flèches, on revient d'un glissé. L'étape se coche
 * quand on a répondu, bien ou mal. Jumeau de `NotesCircleView`.
 */
export function NotesCircle({
  theme,
  tone,
  onAnswer,
  onLeave,
  onDone,
}: {
  theme: StepTheme;
  tone: LessonTone;
  onAnswer: (question: QuizQuestion, right: boolean) => void;
  /** La croix : où on s'est arrêté, entre 0 et 1. */
  onLeave: (read: number) => void;
  onDone: () => void;
}) {
  const { t } = useI18n();
  const question = theme.quiz ? finalQuestion(theme.quiz) : null;
  const pages = useMemo(() => notesPages(theme.notes, question !== null), [theme.notes, question]);
  const [page, setPage] = useState(0);
  const [furthest, setFurthest] = useState(0);
  const [answer, setAnswer] = useState<QuizAnswer | null>(null);
  const [forward, setForward] = useState(true);
  const current: NotesPage = pages[page] ?? { type: "question" };
  const isLast = page === pages.length - 1;
  const waiting = current.type === "question" && answer === null;

  const next = useCallback(() => {
    if (page + 1 >= pages.length) return;
    setForward(true);
    setPage(page + 1);
    setFurthest((value) => Math.max(value, page + 1));
  }, [page, pages.length]);

  const back = useCallback(() => {
    if (page === 0) return;
    setForward(false);
    setPage(page - 1);
  }, [page]);

  // Le glissé vers l'avant fait ce que fait « Continuer », sauf finir l'étape.
  const advanceIfAllowed = useCallback(() => {
    if (current.type === "question" && answer === null) return;
    next();
  }, [answer, current.type, next]);

  const start = useRef<{ x: number; y: number; at: number } | null>(null);
  function pointerDown(event: React.PointerEvent) {
    if (event.pointerType === "mouse") return;
    start.current = { x: event.clientX, y: event.clientY, at: performance.now() };
  }
  function pointerUp(event: React.PointerEvent) {
    const origin = start.current;
    start.current = null;
    if (!origin) return;
    const dx = event.clientX - origin.x;
    const dy = event.clientY - origin.y;
    const seconds = Math.max(0.05, (performance.now() - origin.at) / 1000);
    const rtl = getComputedStyle(event.currentTarget).direction === "rtl";
    // La position prédite : où le geste, lancé à cette vitesse, serait arrivé un quart de seconde plus tard.
    const predicted = { width: dx + (dx / seconds) * 0.25, height: dy };
    const direction = swipeDirection({ width: dx, height: dy }, predicted, rtl);
    if (direction === "forward") advanceIfAllowed();
    else if (direction === "back") back();
  }

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;
      if (event.key === "ArrowRight") advanceIfAllowed();
      else if (event.key === "ArrowLeft") back();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [advanceIfAllowed, back]);

  function answered(result: QuizAnswer) {
    if (!question) return;
    setAnswer(result);
    onAnswer(question, result.right);
  }

  function leave() {
    const read = (furthest + 1) / Math.max(1, pages.length);
    onLeave(read * (answer === null ? 0.9 : 1));
  }

  if (theme.status === "pending" && !theme.notes && theme.sheet.length === 0) {
    return <WritingTheme tone={tone} onClose={() => onLeave(0)} label={t("lesson.notes.writing")} />;
  }

  return (
    <div className="flex min-h-[calc(100svh-6rem)] flex-col">
      <CircleTopBar tone={tone} segments={{ count: pages.length, page }} onClose={leave} onBack={page > 0 ? back : null} />

      <div className="flex-1 touch-pan-y overflow-x-clip" onPointerDown={pointerDown} onPointerUp={pointerUp} onPointerCancel={() => (start.current = null)}>
        <div key={page} className="notes-page-in mx-auto w-full max-w-[560px] px-1 pb-8" style={{ ["--from" as string]: forward ? "40px" : "-40px" }}>
          <NotesPageView page={current} theme={theme} tone={tone} question={question} answer={answer} onAnswer={answered} />
        </div>
      </div>

      <div className="lesson-bottom-bar -mx-4 bg-canvas px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-2 lg:-mx-10 lg:px-10" data-print="hide">
        <div className="mx-auto flex w-full max-w-[560px] flex-col items-center gap-2">
          {waiting ? <p className="text-[14px] font-bold text-ink-secondary">{t("lesson.notes.answerToFinish")}</p> : null}
          <LessonPrimaryButton disabled={waiting} onClick={() => (isLast ? onDone() : next())}>
            {isLast ? t("lesson.notes.finishStep") : t("lesson.quiz.continue")}
          </LessonPrimaryButton>
        </div>
      </div>
    </div>
  );
}

/** Le thème s'écrit encore : Mika y est. */
function WritingTheme({ tone, onClose, label }: { tone: LessonTone; onClose: () => void; label: string }) {
  return (
    <div className="flex min-h-[calc(100svh-6rem)] flex-col">
      <CircleTopBar tone={tone} onClose={onClose} />
      <div className="flex flex-1 flex-col items-center justify-center gap-3 text-center">
        <Spinner className="size-7 text-ink-secondary" />
        <p className="text-[17px] font-bold text-ink-secondary">{label}</p>
      </div>
    </div>
  );
}

/** **Le contenu d'un écran**, qui se remplit en arrivant : chaque élément glisse en place, un peu après le précédent. */
function NotesPageView({
  page,
  theme,
  tone,
  question,
  answer,
  onAnswer,
}: {
  page: NotesPage;
  theme: StepTheme;
  tone: LessonTone;
  question: QuizQuestion | null;
  answer: QuizAnswer | null;
  onAnswer: (answer: QuizAnswer) => void;
}) {
  const { t } = useI18n();
  const reveal = (order: number) => ({ className: "notes-reveal", style: { animationDelay: `${80 + order * 90}ms` } });

  switch (page.type) {
    case "opening":
      if (!theme.notes) return null;
      return (
        <div className="flex flex-col gap-[18px] pt-5">
          <div {...reveal(0)}>
            <MicaboIcon id={theme.icon} size={84} />
          </div>
          <h1 {...reveal(1)} className="notes-reveal text-[30px] font-extrabold leading-[1.1] tracking-tight-title text-ink">
            {theme.title}
          </h1>
          <div {...reveal(2)}>
            <ToneBox label={t("lesson.notes.oneLiner")} tone={tone}>
              <p className="text-[20px] font-bold leading-snug text-ink">
                <KeywordText text={theme.notes.oneLiner} />
              </p>
            </ToneBox>
          </div>
        </div>
      );

    case "blocks":
      if (!theme.notes) return null;
      return (
        <div className="pt-6">
          <NoteBlockList blocks={theme.notes.blocks.slice(page.start, page.end)} tone={tone} reveal />
        </div>
      );

    case "takeaways":
      if (!theme.notes) return null;
      return (
        <div className="flex flex-col gap-4 pt-4">
          <div {...reveal(0)}>
            <MicaboIcon id="etoile" size={72} />
          </div>
          <h2 {...reveal(1)} className="notes-reveal text-[28px] font-extrabold leading-tight tracking-tight-title text-ink">
            {t("lesson.notes.takeaways")}
          </h2>
          {theme.notes.takeaways.map((line, index) => (
            <div key={index} {...reveal(index + 2)} className="notes-reveal flex items-baseline gap-3 rounded-[18px] bg-surface p-4 shadow-floating">
              <CheckCircle2 aria-hidden="true" className="size-5 shrink-0 translate-y-[3px]" strokeWidth={2.6} style={{ color: `var(--color-tone-${tone}-vivid)` }} />
              <p className="text-[19px] font-semibold leading-snug text-ink">
                <KeywordText text={line} />
              </p>
            </div>
          ))}
        </div>
      );

    case "legacy":
      return (
        <div className="flex flex-col gap-5 pt-4">
          <div className="flex items-center gap-3.5">
            <MicaboIcon id={theme.icon} size={52} />
            <h1 className="text-[26px] font-bold leading-tight text-ink">{theme.title}</h1>
          </div>
          <ThemeBody theme={theme} tone={tone} />
        </div>
      );

    case "question":
      if (!question) return null;
      return (
        <div {...reveal(0)} className="notes-reveal pt-4">
          <QuestionCard question={question} tone={tone} answered={answer} shuffleSeed={pickingSeed(question.id, "notes")} onAnswer={onAnswer} />
        </div>
      );
  }
}

/** Les notes d'un thème : au format de la refonte, sinon la fiche d'un ancien chapitre, avec la même typographie. */
export function ThemeBody({ theme, tone }: { theme: Pick<StepTheme, "notes" | "sheet" | "title">; tone: LessonTone }) {
  const { t } = useI18n();
  if (theme.notes) return <ThemeNotesView notes={theme.notes} tone={tone} />;
  const blocks = legacyBlocks(theme.sheet, theme.title);
  if (blocks.length > 0) return <SheetBlocks blocks={blocks} />;
  return <p className="text-[17px] leading-[1.35] text-ink-secondary">{t("lesson.notes.empty")}</p>;
}

/** Les blocs d'un ancien chapitre, sans le titre qui l'ouvre : il est déjà en tête d'écran. */
export function legacyBlocks(sheet: readonly SheetBlock[], title: string): SheetBlock[] {
  const first = sheet[0];
  if (first && first.type === "heading" && first.text.trim().toLowerCase() === title.trim().toLowerCase()) return sheet.slice(1);
  return [...sheet];
}
