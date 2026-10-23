"use client";

import type { LessonTone } from "@micabo/core";

import { CircleTopBar } from "@/components/lesson/CircleTopBar";
import { KeywordText } from "@/components/lesson/KeywordText";
import { LessonPrimaryButton } from "@/components/lesson/LessonButtons";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { useI18n } from "@/lib/i18n/client";

/** **La Conclusion** : « À retenir », cinq phrases clés, le score moyen des quiz, « Terminer ». Jumeau de `ConclusionCircleView`. */
export function ConclusionCircle({
  takeaways,
  averagePercent,
  tone,
  pending,
  onClose,
  onDone,
}: {
  takeaways: string[];
  averagePercent: number | null;
  tone: LessonTone;
  pending?: boolean;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t } = useI18n();
  return (
    <div className="notes-page-in flex min-h-[calc(100svh-6rem)] flex-col">
      <CircleTopBar tone={tone} onClose={onClose} />
      <div className="mx-auto flex w-full max-w-[560px] flex-1 flex-col gap-5 px-1 pb-6">
        <div className="flex justify-center">
          <MicaboIcon id="trophee" size={84} />
        </div>
        <h1 className="text-[26px] font-bold leading-tight text-ink">{t("lesson.conclusion.title")}</h1>

        {takeaways.length > 0 ? (
          <ul className="flex flex-col gap-3 rounded-[20px] p-[18px]" style={{ background: `var(--color-tone-${tone}-pale)` }}>
            {takeaways.map((line, index) => (
              <li key={index} className="flex items-start gap-2.5 text-[17px] leading-[1.35] text-ink">
                <span aria-hidden="true" className="mt-2 size-2 shrink-0 rounded-full" style={{ background: `var(--color-tone-${tone}-vivid)` }} />
                <span>
                  <KeywordText text={line} />
                </span>
              </li>
            ))}
          </ul>
        ) : null}

        {averagePercent !== null ? (
          <div className="flex items-center justify-between rounded-[20px] bg-surface p-[18px] shadow-floating">
            <span className="text-[17px] font-bold text-ink">{t("lesson.conclusion.score")}</span>
            <span className="numeral text-[28px] font-extrabold" style={{ color: `var(--color-tone-${tone}-ink)` }}>
              {averagePercent} %
            </span>
          </div>
        ) : null}
      </div>
      <div className="lesson-bottom-bar -mx-4 bg-canvas px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-2 lg:-mx-10 lg:px-10">
        <div className="mx-auto w-full max-w-[560px]">
          <LessonPrimaryButton onClick={onDone} disabled={pending}>
            {t("lesson.conclusion.finish")}
          </LessonPrimaryButton>
        </div>
      </div>
    </div>
  );
}
