"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Check, Loader2, X } from "lucide-react";

import { GENERATION_STAGES, type GenerationStage, type LessonCreation } from "@micabo/core";

import { LessonPrimaryButton, LessonSecondaryButton } from "@/components/lesson/LessonButtons";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";
import { lessonPath } from "@/lib/lesson/routes";
import { firstCompletion, writeThemes } from "@/lib/lesson/theme-writer";
import { requestPaywall } from "@/lib/paywall";

/**
 * **Créer une leçon, après l'envoi** (`docs/refonte-parcours.md` § 4) : « As-tu un examen ? »,
 * « Quelle date ? » si oui, puis l'écran de génération, relié au vrai travail. La leçon
 * s'ouvre dès que son plan est là et que son premier thème est écrit ; les autres continuent
 * de s'écrire pendant qu'on lit l'Intro. Jumeau de `LessonCreationFlow`.
 *
 * L'identifiant de la leçon est gardé d'un essai à l'autre : le serveur réserve la leçon sous
 * cet identifiant (`begin_lesson`), et « Réessayer » avec un identifiant neuf la compterait
 * comme une seconde leçon.
 */
export function LessonCreationFlow({
  creation,
  hasSupports,
  onCancel,
  onCreated,
}: {
  creation: LessonCreation;
  hasSupports: boolean;
  onCancel: () => void;
  onCreated: () => void;
}) {
  const { t } = useI18n();
  const router = useRouter();
  const [step, setStep] = useState<"exam" | "date" | "generating">("exam");
  const [examDate, setExamDate] = useState(() => defaultExamDate());
  const [stage, setStage] = useState<GenerationStage | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [lessonId] = useState(() => crypto.randomUUID());
  const pending = useRef<string | null>(null);
  const alive = useRef(true);

  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);

  async function start(date: string | null) {
    pending.current = date;
    setFailure(null);
    setStage("reading");
    setStep("generating");

    let outcome: { status: string; lessonId?: string; themes?: number; message?: string; code?: string };
    try {
      const response = await fetch("/api/lesson/plan", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ lessonId, ...creation, examDate: date }),
      });
      outcome = (await response.json()) as typeof outcome;
    } catch {
      outcome = { status: "error", message: t("lesson.error.generic") };
    }
    if (!alive.current) return;
    if (outcome.status !== "ok" || !outcome.lessonId) {
      setFailure(outcome.message ?? t("lesson.error.generic"));
      if (outcome.code === "free_limit" || outcome.code === "import_pro") requestPaywall();
      return;
    }

    setStage("cutting");
    const indices = Array.from({ length: outcome.themes ?? 0 }, (_, index) => index);
    setStage("writing");
    // Les thèmes partent tous ; on attend le premier, puis la page du chemin prend la suite.
    void writeThemes(outcome.lessonId, indices);
    await firstCompletion(outcome.lessonId);
    if (!alive.current) return;
    setStage("questions");
    onCreated();
    router.push(lessonPath(outcome.lessonId));
  }

  const closeBar = (
    <div className="flex items-center px-3 pt-2">
      <button type="button" onClick={onCancel} aria-label={t("lesson.circle.close")} className="pressable flex size-10 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted">
        <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
      </button>
    </div>
  );

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-canvas" role="dialog" aria-modal="true">
      {step === "exam" ? (
        <div className="notes-page-in flex flex-1 flex-col">
          {closeBar}
          <div className="flex flex-1 flex-col items-center justify-center gap-5 px-8 text-center">
            <Mika mood="think" size={150} label="" />
            <h2 className="text-[26px] font-bold leading-tight text-ink">{t("lesson.create.examQuestion")}</h2>
          </div>
          <div className="mx-auto flex w-full max-w-[420px] flex-col gap-3 px-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
            <LessonPrimaryButton onClick={() => setStep("date")}>{t("lesson.create.examYes")}</LessonPrimaryButton>
            <LessonSecondaryButton onClick={() => void start(null)}>{t("lesson.create.examNo")}</LessonSecondaryButton>
          </div>
        </div>
      ) : step === "date" ? (
        <div className="notes-page-in flex flex-1 flex-col">
          {closeBar}
          <div className="flex flex-1 flex-col items-center gap-6 px-8 pt-2 text-center">
            <h2 className="text-[26px] font-bold leading-tight text-ink">{t("lesson.create.dateQuestion")}</h2>
            <input
              type="date"
              value={examDate}
              min={tomorrow()}
              onChange={(event) => setExamDate(event.target.value)}
              className="rounded-[18px] bg-surface px-5 py-4 text-[22px] font-extrabold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)] outline-none focus-visible:shadow-[inset_0_0_0_2px_var(--color-accent)]"
            />
          </div>
          <div className="mx-auto w-full max-w-[420px] px-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
            <LessonPrimaryButton disabled={!examDate || examDate < tomorrow()} onClick={() => void start(examDate)}>
              {t("lesson.create.continue")}
            </LessonPrimaryButton>
          </div>
        </div>
      ) : (
        <div className="score-in flex flex-1 flex-col">
          {failure ? closeBar : <div className="h-14" />}
          <div className="flex flex-1 flex-col items-center justify-center gap-[18px] px-8 text-center">
            <Mika mood={failure ? "sad" : "think"} size={170} label="" />
            <h2 className="text-[26px] font-bold leading-tight text-ink">{failure ? t("lesson.create.failedTitle") : t("lesson.create.generatingTitle")}</h2>
            {failure ? (
              <p className="max-w-[420px] text-[16px] font-medium text-ink-secondary">{failure}</p>
            ) : (
              <GenerationSteps current={stage} hasSupports={hasSupports} />
            )}
          </div>
          {failure ? (
            <div className="mx-auto flex w-full max-w-[420px] flex-col gap-3 px-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
              <LessonPrimaryButton onClick={() => void start(pending.current)}>{t("lesson.path.retry")}</LessonPrimaryButton>
              <LessonSecondaryButton onClick={onCancel}>{t("lesson.create.cancel")}</LessonSecondaryButton>
            </div>
          ) : null}
        </div>
      )}
    </div>
  );
}

/** Les quatre étapes de la génération, cochées au rythme du vrai travail. */
function GenerationSteps({ current, hasSupports }: { current: GenerationStage | null; hasSupports: boolean }) {
  const { t } = useI18n();
  const rank = (stage: GenerationStage) => GENERATION_STAGES.indexOf(stage);
  return (
    <ol className="mt-2 flex w-full max-w-[360px] flex-col gap-4 text-left">
      {GENERATION_STAGES.map((stage) => {
        const done = current !== null && rank(stage) < rank(current);
        const active = current === stage || (current === null && stage === "reading");
        const key = stage === "reading" ? (hasSupports ? "lesson.create.stageReading" : "lesson.create.stageTopic") : stage === "cutting" ? "lesson.create.stageCutting" : stage === "writing" ? "lesson.create.stageWriting" : "lesson.create.stageQuestions";
        return (
          <li key={stage} className="flex items-center gap-3.5">
            <span className={`flex size-[30px] shrink-0 items-center justify-center rounded-full transition-colors ${done ? "bg-correct" : active ? "bg-accent-soft" : "bg-surface-sunken"}`}>
              {done ? <Check aria-hidden="true" className="size-4 text-on-ink" strokeWidth={3.4} /> : active ? <Loader2 aria-hidden="true" className="size-4 animate-spin text-accent" /> : null}
            </span>
            <span className={`text-[17px] ${active ? "font-extrabold" : "font-bold"} ${done || active ? "text-ink" : "text-ink-tertiary"}`}>{t(key)}</span>
          </li>
        );
      })}
    </ol>
  );
}

function tomorrow(): string {
  const date = new Date();
  date.setDate(date.getDate() + 1);
  return toDateInput(date);
}

function defaultExamDate(): string {
  const date = new Date();
  date.setDate(date.getDate() + 14);
  return toDateInput(date);
}

function toDateInput(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}
