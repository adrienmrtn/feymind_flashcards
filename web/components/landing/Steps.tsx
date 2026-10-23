"use client";

import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";
import { SourceBadge } from "./SourceBadge";

/**
 * **Trois étapes, dans l'ordre où elles se vivent** : tu déposes ton cours, Mika écrit la
 * leçon, tu suis le chemin. Trois cartes de même hauteur, qui montent l'une après l'autre.
 */
export function Steps() {
  const { t } = useI18n();
  const steps = [
    { key: "import", title: t("landing.step1Title"), body: t("landing.step1Body"), figure: <ImportFigure /> },
    { key: "mika", title: t("landing.step2Title"), body: t("landing.step2Body"), figure: <MikaFigure /> },
    { key: "path", title: t("landing.step3Title"), body: t("landing.step3Body"), figure: <PathFigure /> },
  ];

  return (
    <ol className="mt-12 grid gap-5 sm:mt-14 md:grid-cols-3">
      {steps.map((step, index) => (
        <Reveal as="li" key={step.key} delay={index} className="h-full">
          <div className="lp-card flex h-full flex-col rounded-[28px] bg-surface p-5 lp-surface-shadow sm:p-6">
            <div className="flex h-[168px] items-center justify-center overflow-hidden rounded-[20px] bg-surface-muted">
              {step.figure}
            </div>
            <p className="mt-6 flex items-center gap-2.5">
              <span className="numeral flex size-7 items-center justify-center rounded-full bg-accent text-[13px] font-extrabold text-on-ink">
                {index + 1}
              </span>
              <span className="text-[12.5px] font-extrabold uppercase tracking-caps text-ink-tertiary">
                {t("landing.stepEyebrow", { n: index + 1 })}
              </span>
            </p>
            <h3 className="mt-3 text-[21px] font-extrabold leading-[1.15] tracking-tight-title text-ink">{step.title}</h3>
            <p className="mt-2.5 text-[15.5px] leading-relaxed text-ink-secondary">{step.body}</p>
          </div>
        </Reveal>
      ))}
    </ol>
  );
}

/** Les supports, en éventail. */
function ImportFigure() {
  return (
    <div aria-hidden className="relative h-[96px] w-[220px]">
      {(["pdf", "word", "youtube", "audio"] as const).map((kind, index) => (
        <span
          key={kind}
          className="absolute top-1/2 rounded-[18px] bg-surface p-2 shadow-paper"
          style={{
            left: `${index * 25}%`,
            transform: `translateY(-50%) rotate(${(index - 1.5) * 7}deg) translateY(${Math.abs(index - 1.5) * 6}px)`,
          }}
        >
          <SourceBadge kind={kind} size={44} />
        </span>
      ))}
    </div>
  );
}

/** Mika qui réfléchit, au-dessus de la page qu'il écrit. */
function MikaFigure() {
  return (
    <div aria-hidden className="flex items-end gap-4">
      <div className="w-[92px]">
        <Mika mood="think" label="" />
      </div>
      <div className="mb-2 w-[104px] space-y-2 rounded-[14px] bg-surface p-3 shadow-paper">
        <span className="block h-2 w-[70%] rounded-pill bg-ink/80" />
        <span className="block h-1.5 w-full rounded-pill bg-stroke-strong" />
        <span className="block h-1.5 w-[86%] rounded-pill bg-stroke-strong" />
        <span className="block h-1.5 w-[60%] rounded-pill bg-keyword/50" />
      </div>
    </div>
  );
}

/** Trois étapes du chemin : deux faites, une allumée. */
function PathFigure() {
  const nodes = [
    { icon: "fiche", tone: "blue", done: true },
    { icon: "quiz", tone: "mint", done: true },
    { icon: "cartes", tone: "yellow", done: false },
  ];
  return (
    <div aria-hidden className="relative flex items-center gap-5">
      <span className="absolute left-6 right-6 top-1/2 h-[3px] -translate-y-1/2 rounded-pill bg-track" />
      <span className="absolute left-6 top-1/2 h-[3px] w-[52%] -translate-y-1/2 rounded-pill bg-progress" />
      {nodes.map((node) => (
        <span
          key={node.icon}
          className={`relative flex size-[52px] items-center justify-center rounded-full ${node.done ? "" : "ring-[3px] ring-accent ring-offset-[3px] ring-offset-surface-muted"}`}
          style={{ background: `var(--color-tone-${node.tone}-pale)` }}
        >
          <MicaboIcon id={node.icon} size={30} />
          {node.done ? (
            <span className="absolute -bottom-0.5 -right-0.5 flex size-5 items-center justify-center rounded-full bg-correct text-white ring-[3px] ring-surface-muted">
              <svg viewBox="0 0 16 16" className="size-2.5" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                <path d="m3.5 8.4 2.9 2.9 6.1-6.6" />
              </svg>
            </span>
          ) : null}
        </span>
      ))}
    </div>
  );
}
