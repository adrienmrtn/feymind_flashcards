import { Scissors } from "lucide-react";

import type { LessonTone } from "@micabo/core";

import { MicaboIcon } from "@/components/lesson/MicaboIcon";

/**
 * **L'en-tête d'une leçon** : la grande illustration, le titre, « 27 % · 3 sur 11 étapes »
 * et la barre qui se remplit, l'examen s'il y en a un. Jumeau de `LessonPathHeader`.
 *
 * Présentationnel : les phrases arrivent déjà traduites, parce que l'en-tête se rend aussi
 * bien depuis le serveur que depuis le chemin qui se met à jour.
 */
export function LessonHeader({
  title,
  icon,
  tone,
  percent,
  stepsLabel,
  shortenedLabel,
  examLabel,
}: {
  title: string;
  icon: string | null;
  tone: LessonTone;
  percent: number;
  stepsLabel: string;
  shortenedLabel?: string | null;
  examLabel?: string | null;
}) {
  const vivid = `var(--color-tone-${tone}-vivid)`;
  const ink = `var(--color-tone-${tone}-ink)`;
  const pale = `var(--color-tone-${tone}-pale)`;
  return (
    <header className="flex flex-col items-center gap-4 px-7 text-center">
      <div className="relative flex items-center justify-center py-3">
        <span
          aria-hidden="true"
          className="absolute size-[180px] rounded-full"
          style={{ background: `radial-gradient(circle, color-mix(in srgb, ${vivid} 22%, transparent) 0%, transparent 70%)` }}
        />
        {/* 88 points : les icônes 3D font 256 pixels, au-delà elles s'étirent et floutent. */}
        <MicaboIcon id={icon} size={88} className="relative drop-shadow-[0_14px_24px_color-mix(in_srgb,var(--color-ink)_12%,transparent)]" />
      </div>
      <h1 className="line-clamp-3 text-balance text-[30px] font-extrabold leading-[1.1] tracking-tight-title text-ink">{title}</h1>
      <div className="flex w-full max-w-[420px] flex-col gap-2.5">
        <div className="flex items-baseline justify-between gap-2 tabular-nums">
          <span className="numeral text-[26px] font-extrabold" style={{ color: ink }}>
            {percent} %
          </span>
          <span className="text-[17px] font-semibold text-ink-secondary">{stepsLabel}</span>
        </div>
        <div className="relative h-3.5 w-full overflow-hidden rounded-pill" style={{ background: "var(--color-track)" }}>
          <div
            className="absolute inset-y-0 left-0 rounded-pill transition-[width] duration-700 ease-out-strong"
            style={{
              width: `max(14px, ${percent}%)`,
              background: `linear-gradient(to right, ${vivid}, color-mix(in srgb, ${vivid} 85%, transparent))`,
              opacity: percent === 0 ? 0.35 : 1,
            }}
          >
            <span aria-hidden="true" className="absolute inset-x-1.5 top-[3px] h-[3px] rounded-pill bg-white/28" />
          </div>
        </div>
      </div>
      {shortenedLabel ? (
        <span className="inline-flex items-center gap-1.5 rounded-pill bg-surface-muted px-3 py-1.5 text-[13px] font-bold text-ink-secondary">
          <Scissors aria-hidden="true" className="size-3.5" />
          {shortenedLabel}
        </span>
      ) : null}
      {examLabel ? (
        <span className="inline-flex items-center gap-2 rounded-pill px-3.5 py-2 text-[14px] font-bold" style={{ background: pale, color: ink }}>
          <MicaboIcon id="examen" size={20} />
          {examLabel}
        </span>
      ) : null}
    </header>
  );
}
