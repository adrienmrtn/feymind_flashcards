"use client";

import { ArrowUp } from "lucide-react";

import { SUPPORT_ICONS, SUPPORT_KINDS } from "@micabo/core";

import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { Mika } from "@/components/mika/Mika";
import { PathStory } from "@/components/onboarding/stories/PathStory";
import { QuizStory } from "@/components/onboarding/stories/QuizStory";
import { useI18n } from "@/lib/i18n/client";

/**
 * **La vitrine, faite des vrais composants** : Home avec sa question, sa barre et ses cinq
 * supports ; le chemin d'une leçon ; une question du quiz à laquelle on répond vraiment.
 * Trois écrans côte à côte sur grand écran, empilés sur téléphone.
 */
export function LessonShowcase() {
  const { t } = useI18n();
  const title = t("lesson.home.title").split("**");

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <Panel label={t("lesson.tab.home")}>
        <div className="flex flex-col items-center gap-3 px-1 pt-1">
          <p className="text-balance text-center text-[22px] font-extrabold leading-[1.1] tracking-tight-title text-ink">
            {title.map((part, index) => (index % 2 === 1 ? <span key={index} className="home-gradient-text">{part}</span> : <span key={index}>{part}</span>))}
          </p>
          <Mika mood="wave" size={64} label="" />
          <div className="home-bar flex w-full min-h-[84px] flex-col justify-end py-2.5 pl-4 pr-2 text-left">
            <div className="flex items-end gap-2">
              <span className="flex-1 pb-2 text-[15px] font-semibold text-ink-tertiary">{t("lesson.home.placeholder")}</span>
              <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-ink text-on-ink">
                <ArrowUp aria-hidden="true" className="size-4" strokeWidth={2.8} />
              </span>
            </div>
          </div>
          <ul className="grid w-full grid-cols-5 gap-1.5">
            {SUPPORT_KINDS.map((kind) => (
              <li key={kind} className="flex flex-col items-center gap-1 rounded-[14px] bg-surface py-2 shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
                <MicaboIcon id={SUPPORT_ICONS[kind]} size={24} />
                <span className="text-[9.5px] font-extrabold text-ink-secondary">{t(`lesson.import.${kind}`)}</span>
              </li>
            ))}
          </ul>
        </div>
      </Panel>
      <Panel label={t("landing.showcasePath")}>
        <PathStory scale={0.72} height={340} />
      </Panel>
      <Panel label={t("landing.showcaseQuiz")}>
        <QuizStory />
      </Panel>
    </div>
  );
}

function Panel({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="paper flex min-h-[380px] flex-col gap-3 rounded-[28px] bg-canvas p-4">
      <p className="text-[11px] font-extrabold uppercase tracking-caps text-ink-tertiary">{label}</p>
      <div className="flex flex-1 items-center justify-center">{children}</div>
    </div>
  );
}
