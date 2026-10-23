"use client";

import { useMemo } from "react";

import { LESSON_TONES, SeededGenerator, type LessonTone } from "@micabo/core";

import { LessonPrimaryButton, LessonSecondaryButton } from "@/components/lesson/LessonButtons";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

/**
 * **« Leçon terminée »** : plein écran, Mika fait la fête, des confettis qui tombent une fois,
 * le score et le temps, deux boutons. Jumeau de `LessonFinishedView`.
 */
export function LessonFinished({
  tone,
  averagePercent,
  minutes,
  onCards,
  onBack,
}: {
  tone: LessonTone;
  averagePercent: number | null;
  minutes: number;
  onCards: () => void;
  onBack: () => void;
}) {
  const { t } = useI18n();
  return (
    <div className="score-in relative flex min-h-[calc(100svh-6rem)] flex-col items-center justify-center gap-[22px] overflow-hidden px-1 text-center">
      <Confetti />
      <Mika mood="celebrate" size={200} label="" />
      <h1 className="text-[32px] font-extrabold leading-tight tracking-tight-title text-ink">{t("lesson.finished.title")}</h1>
      <div className="grid w-full max-w-[420px] grid-cols-2 gap-3.5">
        <Stat value={averagePercent === null ? "-" : `${averagePercent} %`} label={t("lesson.finished.score")} tone={tone} />
        <Stat value={t("lesson.finished.minutes", { n: Math.max(1, minutes) })} label={t("lesson.finished.time")} tone={tone} />
      </div>
      <div className="mt-6 flex w-full max-w-[420px] flex-col gap-3">
        <LessonPrimaryButton onClick={onCards}>{t("lesson.finished.cards")}</LessonPrimaryButton>
        <LessonSecondaryButton onClick={onBack}>{t("lesson.finished.back")}</LessonSecondaryButton>
      </div>
    </div>
  );
}

function Stat({ value, label, tone }: { value: string; label: string; tone: LessonTone }) {
  return (
    <div className="flex flex-col items-center gap-1 rounded-[20px] bg-surface py-4 shadow-floating">
      <span className="numeral text-[30px] font-extrabold leading-none" style={{ color: `var(--color-tone-${tone}-ink)` }}>
        {value}
      </span>
      <span className="text-[12px] font-bold uppercase tracking-caps text-ink-secondary">{label}</span>
    </div>
  );
}

/** Des confettis légers, qui tombent une fois : soixante pièces aux couleurs des cinq tons. */
function Confetti() {
  const pieces = useMemo(() => {
    const generator = new SeededGenerator(7n);
    const unit = () => generator.below(1000) / 1000;
    return Array.from({ length: 60 }, (_, index) => ({
      left: unit() * 100,
      delay: unit() * 0.8,
      duration: 2.4 + unit() * 1.4,
      tone: LESSON_TONES[index % LESSON_TONES.length]!,
      sway: (unit() - 0.5) * 28,
    }));
  }, []);
  return (
    <div aria-hidden="true" className="pointer-events-none absolute inset-0">
      {pieces.map((piece, index) => (
        <span
          key={index}
          className="confetti-piece"
          style={{
            left: `calc(${piece.left}% + ${piece.sway}px)`,
            background: `var(--color-tone-${piece.tone}-vivid)`,
            ["--delay" as string]: `${piece.delay}s`,
            ["--duration" as string]: `${piece.duration}s`,
            ["--drop" as string]: "110vh",
          }}
        />
      ))}
    </div>
  );
}
