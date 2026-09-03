"use client";

import { useEffect, useRef, useState } from "react";

import { RawPage } from "@/components/demo/RawPage";
import { DEMO_ACCENT, localizedTransformationSheet } from "@/components/demo/demo-course";
import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { useI18n } from "@/lib/i18n/client";

const PANEL_COUNT = 4;
/** Après « Ton examen », on reste encore un peu — autrement le reste de la page arrive tout de suite. */
const HOLD_VIEWPORTS = 0.7;

/**
 * Le trajet complet du document, lié au défilement :
 *
 * cours → fiche, puis fiche → cartes, puis cartes → examen. Deux places, quatre
 * objets. Le dernier couple (cartes | examen) tient encore un peu après la
 * course, pour qu'on le lise avant que la page continue. Le mouvement ne
 * change que des transforms et l'opacité, donc le navigateur peut le composer
 * sans recalculer la page.
 */
export function CourseTransformation() {
  const section = useRef<HTMLElement>(null);
  const frame = useRef<number | null>(null);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)");

    function measure() {
      frame.current = null;
      const element = section.current;
      if (!element) return;

      const rect = element.getBoundingClientRect();
      const extra = Math.max(1, rect.height - window.innerHeight);
      const animated = Math.max(1, extra - window.innerHeight * HOLD_VIEWPORTS);
      const next = Math.min(1, Math.max(0, -rect.top / animated));

      if (reduced.matches) {
        setProgress(next < 1 / 3 ? 0 : next < 2 / 3 ? 0.5 : 1);
        return;
      }

      setProgress(next);
    }

    function schedule() {
      if (frame.current === null) frame.current = window.requestAnimationFrame(measure);
    }

    measure();
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule);
    reduced.addEventListener("change", schedule);

    return () => {
      window.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
      reduced.removeEventListener("change", schedule);
      if (frame.current !== null) window.cancelAnimationFrame(frame.current);
    };
  }, []);

  const travel = progress * (PANEL_COUNT - 2);
  const { t } = useI18n();
  const sheet = localizedTransformationSheet(t);

  return (
    <section
      ref={section}
      className="transformation-scroll relative mx-auto mt-16 max-w-page px-screen"
      aria-label={t("demo.transformAria")}
    >
      <div className="transformation-sticky">
        <div className="transformation-stage">
          <Panel slot={0 - travel} label={t("demo.panelCourse")}>
            <RawPage className="h-full rotate-[-1.2deg]" fill />
          </Panel>

          <div className="transformation-arrow">
            <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5">
              <path
                d="M4 10h12M11 5l5 5-5 5"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </div>

          <Panel slot={1 - travel} label={t("demo.panelSheet")} accent>
            <div className="paper h-full overflow-hidden rounded-group bg-surface p-5">
              <SheetBlocks blocks={sheet} tint={DEMO_ACCENT} />
            </div>
          </Panel>

          <Panel slot={2 - travel} label={t("demo.panelCards")} accent>
            <div className="paper h-full overflow-hidden rounded-group bg-surface p-4">
              <GeneratedCards reveal={opacityForSlot(2 - travel)} />
            </div>
          </Panel>

          <Panel slot={3 - travel} label={t("demo.panelExam")} accent>
            <div className="paper h-full overflow-hidden rounded-group bg-surface p-3.5 sm:p-4">
              <ExamPreview />
            </div>
          </Panel>
        </div>
      </div>
    </section>
  );
}

function Panel({
  slot,
  label,
  accent = false,
  children,
}: {
  slot: number;
  label: string;
  accent?: boolean;
  children: React.ReactNode;
}) {
  const opacity = opacityForSlot(slot);
  const incoming = slot > 0.45;

  return (
    <div
      className="transformation-panel"
      style={
        {
          "--slot": slot,
          opacity,
          zIndex: incoming ? 2 : 1,
          pointerEvents: opacity < 0.08 ? "none" : undefined,
        } as React.CSSProperties
      }
      aria-hidden={opacity < 0.08}
    >
      <p
        className={`eyebrow mb-3 text-center ${
          accent && incoming ? "text-accent" : "text-ink-tertiary"
        }`}
      >
        {label}
      </p>
      {children}
    </div>
  );
}

function opacityForSlot(slot: number) {
  if (slot >= 0 && slot <= 1) return 1;
  if (slot > 1 && slot < 1.28) return 1 - (slot - 1) / 0.28;
  if (slot < 0 && slot > -0.28) return 1 + slot / 0.28;
  return 0;
}

function GeneratedCards({ reveal }: { reveal: number }) {
  const { t } = useI18n();
  const cards = [
    {
      kind: t("demo.card4Kind"),
      prompt: t("demo.card4Front"),
      body: (
        <div className="mt-2 flex items-center gap-1.5">
          {[t("demo.evap"), "?", t("demo.precip")].map((label, index) => (
            <div key={label} className="contents">
              <span
                className={`min-w-0 flex-1 rounded-[9px] px-2 py-1.5 text-center text-[9px] font-semibold ${
                  label === "?"
                    ? "bg-caution-soft text-caution"
                    : "bg-info-soft text-info"
                }`}
              >
                {label}
              </span>
              {index < 2 ? <span className="text-[11px] text-ink-tertiary">→</span> : null}
            </div>
          ))}
        </div>
      ),
    },
    {
      kind: t("demo.card3Kind"),
      prompt: t("demo.card3Front"),
      body: (
        <p className="mt-2 text-[12px] font-medium leading-relaxed text-ink">
          {t("demo.card3Front")}
        </p>
      ),
    },
    {
      kind: t("demo.card2Kind"),
      prompt: t("demo.card2Front"),
      body: (
        <div className="mt-2 grid grid-cols-3 gap-1.5">
          {[t("demo.card2c1"), t("demo.card2c3"), t("demo.card2c2")].map((choice, index) => (
            <span
              key={choice}
              className={`rounded-[8px] px-1.5 py-1.5 text-center text-[9px] font-medium ${
                index === 0 ? "bg-positive-soft text-positive" : "bg-surface-muted text-ink-secondary"
              }`}
            >
              {choice}
            </span>
          ))}
        </div>
      ),
    },
  ] as const;

  return (
    <div className="grid h-full content-center gap-2">
      {cards.map((card, index) => {
        const cardProgress = Math.min(1, Math.max(0, (reveal - index * 0.16) / 0.55));
        return (
          <article
            key={card.kind}
            className="rounded-button border border-stroke bg-surface px-3 py-2.5 shadow-sm"
            style={{
              opacity: cardProgress,
              transform: `translateY(${(1 - cardProgress) * 22}px) rotate(${(1 - cardProgress) * (index - 1) * 1.6}deg)`,
            }}
          >
            <span className="rounded-pill bg-accent-soft px-2 py-0.5 text-[9px] font-bold uppercase tracking-caps text-accent">
              {card.kind}
            </span>
            <p className="mt-1.5 text-[12px] font-semibold leading-snug text-ink">{card.prompt}</p>
            {card.body}
          </article>
        );
      })}
    </div>
  );
}

function ExamPreview() {
  const { t } = useI18n();
  return (
    <div className="flex h-full flex-col">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[14px] font-semibold leading-tight text-ink sm:text-[15px]">
            {t("demo.examTitle")}
          </p>
          <p className="mt-0.5 text-[11px] text-ink-tertiary">
            {t("demo.targetGrade")}{" "}
            <span className="numeral font-bold text-ink">16</span>
            <span className="text-ink-tertiary">/20</span>
          </p>
        </div>
        <span className="rounded-pill bg-negative-soft px-2 py-0.5 text-[11px] font-bold tracking-caps text-negative">
          {t("app.exams.countdown.inDays", { days: 3 })}
        </span>
      </div>

      <p className="mt-2.5 text-[12px] font-medium text-ink sm:mt-3">
        {t("demo.progress")} <span className="numeral font-bold text-accent">78%</span>
      </p>
      <div className="mt-1 h-1.5 overflow-hidden rounded-pill bg-progress-track">
        <div className="h-full w-[78%] rounded-pill bg-progress" />
      </div>

      <RetentionBars />

      <p className="mt-2.5 text-[10px] font-bold uppercase tracking-caps text-ink-tertiary sm:mt-3">
        {t("demo.weakTitle")}
      </p>
      <ul className="mt-1.5 space-y-1.5">
        {weakCards(t).map((card, index) => (
          <li
            key={card.prompt}
            className={`flex items-center gap-2 rounded-[10px] border border-stroke bg-surface px-2 py-1.5 ${
              index === 2 ? "hidden sm:flex" : ""
            }`}
          >
            <span className="shrink-0 rounded-pill bg-caution-soft px-1.5 py-0.5 text-[8px] font-bold uppercase tracking-caps text-caution">
              {card.kind}
            </span>
            <span className="min-w-0 flex-1 truncate text-[11px] font-medium text-ink">
              {card.prompt}
            </span>
            <span className="hidden shrink-0 text-[10px] text-ink-tertiary sm:inline">
              {card.note}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function weakCards(t: ReturnType<typeof useI18n>["t"]) {
  return [
    { kind: t("demo.card2Kind"), prompt: t("demo.weak1"), note: t("demo.weak1note") },
    { kind: t("demo.card3Kind"), prompt: t("demo.weak2"), note: t("demo.weak2note") },
    { kind: t("demo.card4Kind"), prompt: t("demo.weak3"), note: t("demo.weak3note") },
  ];
}

/**
 * Charge de révision (barres) + rétention (courbes). Les barres se resserrent
 * vers le jour J ; la courbe Micabo reste haute et y culmine, l'oubli naturel
 * s'effondre. C'est le même argument que `planExam`, dessiné plus dense.
 */
function RetentionBars() {
  const { t } = useI18n();
  const reviews = [3, 5, 7, 8, 6, 5, 4, 3, 5, 7, 6, 4, 0];
  const withMicabo = [70, 76, 81, 84, 83, 86, 87, 85, 88, 90, 93, 96, 98];
  const without = [70, 66, 60, 54, 49, 45, 42, 39, 37, 35, 33, 32, 30];
  const peak = Math.max(...reviews, 1);
  const today = 9;
  const exam = reviews.length - 1;
  const width = 280;
  const height = 78;
  const pad = { top: 6, right: 4, bottom: 14, left: 4 };
  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;
  const gap = 2;
  const barW = (innerW - gap * (reviews.length - 1)) / reviews.length;
  const xAt = (index: number) => pad.left + index * (barW + gap) + barW / 2;
  const yAt = (value: number) => pad.top + innerH * (1 - value / 100);

  const line = (values: readonly number[]) =>
    values.map((value, index) => `${index === 0 ? "M" : "L"}${xAt(index)} ${yAt(value)}`).join(" ");

  return (
    <figure className="mt-2.5 min-h-0 flex-1 sm:mt-3">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="h-full w-full"
        role="img"
        aria-label={t("demo.legendWith")}
      >
        <line
          x1={xAt(today)}
          y1={pad.top}
          x2={xAt(today)}
          y2={pad.top + innerH}
          stroke="var(--color-stroke-strong)"
          strokeDasharray="2 3"
          strokeWidth="1"
        />
        <line
          x1={xAt(exam)}
          y1={pad.top}
          x2={xAt(exam)}
          y2={pad.top + innerH}
          stroke="var(--color-negative)"
          strokeWidth="1.4"
        />
        {reviews.map((count, index) => (
          <rect
            key={index}
            x={pad.left + index * (barW + gap)}
            y={pad.top + innerH - (count / peak) * innerH * 0.72}
            width={barW}
            height={(count / peak) * innerH * 0.72}
            rx="1.4"
            fill={
              index >= reviews.length - 4
                ? "var(--color-accent)"
                : "color-mix(in oklch, var(--color-accent) 38%, var(--color-surface-sunken))"
            }
            opacity={index === exam ? 0 : 0.9}
          />
        ))}
        <path
          d={line(without)}
          fill="none"
          stroke="var(--color-ink-tertiary)"
          strokeWidth="1.3"
          strokeDasharray="3 3"
          strokeLinecap="round"
        />
        <path
          d={line(withMicabo)}
          fill="none"
          stroke="var(--color-accent)"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <circle cx={xAt(exam)} cy={yAt(withMicabo[exam]!)} r="2.4" fill="var(--color-accent)" />
        <text
          x={xAt(0)}
          y={height - 1}
          textAnchor="start"
          fill="var(--color-ink-tertiary)"
          fontSize="8"
        >
          {t("demo.axisPast")}
        </text>
        <text
          x={xAt(today)}
          y={height - 1}
          textAnchor="middle"
          fill="var(--color-ink-secondary)"
          fontSize="8"
        >
          {t("demo.axisToday")}
        </text>
        <text
          x={xAt(exam)}
          y={height - 1}
          textAnchor="end"
          fill="var(--color-negative)"
          fontSize="8"
          fontWeight="700"
        >
          {t("demo.axisExam")}
        </text>
      </svg>
    </figure>
  );
}
