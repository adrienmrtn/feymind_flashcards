"use client";

import type { LessonTone } from "@micabo/core";

import { CircleTopBar } from "@/components/lesson/CircleTopBar";
import { KeywordText } from "@/components/lesson/KeywordText";
import { LessonPrimaryButton } from "@/components/lesson/LessonButtons";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

/**
 * **L'Intro** : « Ce que tu vas apprendre », trois lignes, les thèmes et leurs icônes, le
 * temps estimé, « C'est parti ». Jumeau de `IntroCircleView`.
 */
export function IntroCircle({
  lines,
  minutes,
  themes,
  tone,
  onClose,
  onDone,
}: {
  lines: string[];
  minutes: number;
  themes: { title: string; icon: string | null }[];
  tone: LessonTone;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t } = useI18n();
  return (
    <div className="flex min-h-[calc(100svh-6rem)] flex-col">
      <CircleTopBar tone={tone} onClose={onClose} />
      <div className="mx-auto flex w-full max-w-[560px] flex-1 flex-col gap-[22px] px-1 pb-6">
        <div className="flex justify-center">
          <Mika mood="wave" size={130} label="" />
        </div>
        <h1 className="text-[26px] font-bold leading-tight text-ink">{t("lesson.intro.title")}</h1>

        {lines.length > 0 ? (
          <div className="flex flex-col gap-2.5 rounded-[20px] p-[18px]" style={{ background: `var(--color-tone-${tone}-pale)` }}>
            {lines.map((line, index) => (
              <p key={index} className="text-[17px] leading-[1.35] text-ink">
                <KeywordText text={line} />
              </p>
            ))}
          </div>
        ) : null}

        <ul className="flex flex-col gap-3">
          {themes.map((theme, index) => (
            <li key={index} className="flex items-center gap-3.5">
              <MicaboIcon id={theme.icon} size={36} />
              <span className="text-[17px] font-bold text-ink">{theme.title}</span>
            </li>
          ))}
        </ul>

        {minutes > 0 ? <p className="text-[12px] font-bold uppercase tracking-caps text-ink-secondary">{t("lesson.intro.estimate", { minutes })}</p> : null}
      </div>
      <div className="lesson-bottom-bar -mx-4 bg-canvas px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-2 lg:-mx-10 lg:px-10">
        <div className="mx-auto w-full max-w-[560px]">
          <LessonPrimaryButton onClick={onDone}>{t("lesson.intro.go")}</LessonPrimaryButton>
        </div>
      </div>
    </div>
  );
}
