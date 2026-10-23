"use client";

import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";
import { SectionHeading } from "./SectionHeading";
import { StoreBadges } from "./StoreBadges";

/**
 * **Le même compte sur iPhone, Android et le web.**
 *
 * Une fenêtre de navigateur et un téléphone qui montrent la même leçon : l'étape se coche
 * sur le téléphone, puis sur le web un instant après. C'est la promesse de la section, dite
 * par l'image avant de l'être par le texte.
 */
export function AppsSection({ id }: { id: string }) {
  const { t } = useI18n();
  const points = [t("landing.appsPoint1"), t("landing.appsPoint2"), t("landing.appsPoint3")];
  return (
    <section id={id} className="mx-auto mt-28 max-w-page scroll-mt-20 px-screen sm:mt-36">
      <div className="grid items-center gap-12 overflow-hidden rounded-[36px] bg-surface p-6 lp-surface-shadow sm:p-10 lg:grid-cols-[1fr_1.05fr] lg:gap-10 lg:p-14">
        <div>
          <SectionHeading align="left" eyebrow="landing.appsEyebrow" title="landing.appsTitle" note="landing.appsNote" />
          <Reveal delay={3}>
            <ul className="mt-7 space-y-3">
              {points.map((point) => (
                <li key={point} className="flex items-start gap-3 text-[15.5px] font-semibold text-ink">
                  <span className="mt-0.5 flex size-[22px] shrink-0 items-center justify-center rounded-full bg-accent-soft text-accent">
                    <svg aria-hidden viewBox="0 0 16 16" className="size-3" fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round">
                      <path d="m3.5 8.4 2.9 2.9 6.1-6.6" />
                    </svg>
                  </span>
                  {point}
                </li>
              ))}
            </ul>
          </Reveal>
          <Reveal delay={4}>
            <StoreBadges className="mt-8" />
          </Reveal>
        </div>

        <Reveal delay={2} className="lp-mock">
          <Devices />
        </Reveal>
      </div>
    </section>
  );
}

function Devices() {
  const { t } = useI18n();
  return (
    <div aria-hidden className="relative mx-auto h-[300px] w-full max-w-[500px] sm:h-[340px]">
      {/* Le web. */}
      <div className="absolute left-0 top-2 w-[84%] overflow-hidden rounded-[20px] bg-canvas lp-surface-shadow">
        <div className="flex h-9 items-center gap-1.5 border-b border-hairline px-3.5">
          <span className="size-2.5 rounded-full bg-[#ff5f57]" />
          <span className="size-2.5 rounded-full bg-[#febc2e]" />
          <span className="size-2.5 rounded-full bg-[#28c840]" />
          <span className="ml-3 rounded-pill bg-surface px-3 py-0.5 text-[11px] font-bold text-ink-tertiary">micabo.app</span>
        </div>
        <div className="p-4 sm:p-5">
          <p className="text-[15px] font-extrabold text-ink">{t("landing.demoLessonTitle")}</p>
          <div className="mt-3 space-y-2 pr-[30%]">
            <MiniRow icon="fiche" tone="blue" label={t("landing.demoStepNotes")} done />
            <MiniRow icon="quiz" tone="mint" label={t("landing.demoStepQuiz")} syncDelay={700} />
            <MiniRow icon="cartes" tone="yellow" label={t("landing.demoStepCards")} />
          </div>
        </div>
      </div>

      {/* Le téléphone. */}
      <div className="absolute bottom-0 right-1 w-[40%] max-w-[178px] rounded-[34px] bg-[#111215] p-[6px] shadow-[0_30px_60px_-28px_oklch(0_0_0/0.55),inset_0_0_0_1px_rgb(255_255_255/0.08)]">
        <div className="relative flex aspect-[9/18] flex-col overflow-hidden rounded-[28px] bg-canvas px-3 pb-3 pt-6">
          <span className="absolute left-1/2 top-2 h-[5px] w-12 -translate-x-1/2 rounded-pill bg-[#111215]" />
          <p className="text-[12px] font-extrabold leading-tight text-ink">{t("landing.demoLessonTitle")}</p>
          <div className="mt-3 flex flex-1 flex-col items-center justify-around">
            <MiniNode icon="fiche" tone="blue" done offset={-18} />
            <MiniNode icon="quiz" tone="mint" syncDelay={0} offset={16} />
            <MiniNode icon="cartes" tone="yellow" offset={-12} />
          </div>
        </div>
      </div>

      <span className="absolute left-[46%] top-[58%] flex items-center gap-1.5 rounded-pill bg-surface px-3 py-1.5 text-[12px] font-extrabold text-ink shadow-paper">
        <span className="relative flex size-2">
          <span className="absolute inset-0 rounded-full bg-correct" />
        </span>
        {t("landing.appsSynced")}
      </span>
    </div>
  );
}

function MiniRow({
  icon,
  tone,
  label,
  done = false,
  syncDelay,
}: {
  icon: string;
  tone: string;
  label: string;
  done?: boolean;
  syncDelay?: number;
}) {
  return (
    <div className="flex items-center gap-2.5 rounded-[14px] bg-surface px-2.5 py-2 shadow-paper">
      <span className="flex size-8 shrink-0 items-center justify-center rounded-full" style={{ background: `var(--color-tone-${tone}-pale)` }}>
        <MicaboIcon id={icon} size={20} />
      </span>
      <span className="flex-1 truncate text-[12.5px] font-bold text-ink">{label}</span>
      {done || syncDelay !== undefined ? (
        <span
          className={`flex size-[18px] items-center justify-center rounded-full bg-correct text-white ${syncDelay !== undefined ? "lp-sync-check" : ""}`}
          style={syncDelay !== undefined ? { ["--d" as string]: `${syncDelay}ms` } : undefined}
        >
          <TinyCheck />
        </span>
      ) : null}
    </div>
  );
}

function MiniNode({
  icon,
  tone,
  done = false,
  syncDelay,
  offset,
}: {
  icon: string;
  tone: string;
  done?: boolean;
  syncDelay?: number;
  offset: number;
}) {
  return (
    <span
      className="relative flex size-11 items-center justify-center rounded-full"
      style={{ background: `var(--color-tone-${tone}-pale)`, transform: `translateX(${offset}px)` }}
    >
      <MicaboIcon id={icon} size={26} />
      {done || syncDelay !== undefined ? (
        <span
          className={`absolute -bottom-0.5 -right-0.5 flex size-4 items-center justify-center rounded-full bg-correct text-white ring-2 ring-canvas ${syncDelay !== undefined ? "lp-sync-check" : ""}`}
          style={syncDelay !== undefined ? { ["--d" as string]: `${syncDelay}ms` } : undefined}
        >
          <TinyCheck />
        </span>
      ) : null}
    </span>
  );
}

function TinyCheck() {
  return (
    <svg viewBox="0 0 16 16" className="size-2.5" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
      <path d="m3.5 8.4 2.9 2.9 6.1-6.6" />
    </svg>
  );
}
