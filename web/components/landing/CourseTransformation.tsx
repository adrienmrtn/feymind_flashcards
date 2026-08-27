"use client";

import { useEffect, useRef, useState } from "react";

import { RawPage } from "@/components/demo/RawPage";
import { DEMO_COURSE, TRANSFORMATION_SHEET } from "@/components/demo/demo-course";
import { SheetBlocks } from "@/components/sheet/SheetBlocks";

/**
 * Le trajet complet du document, lié au défilement :
 *
 * cours → fiche, puis fiche → cartes. Le mouvement ne change que des transforms
 * et l'opacité, donc le navigateur peut le composer sans recalculer la page.
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
      const distance = Math.max(1, rect.height - window.innerHeight);
      const next = Math.min(1, Math.max(0, -rect.top / distance));
      setProgress(reduced.matches ? (next < 0.5 ? 0 : 1) : next);
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

  return (
    <section
      ref={section}
      className="transformation-scroll relative mx-auto mt-16 max-w-page px-screen"
      aria-label="Ton cours devient une fiche, puis des cartes"
      style={
        {
          "--transformation-progress": progress,
          "--transformation-inverse": 1 - progress,
        } as React.CSSProperties
      }
    >
      <div className="transformation-sticky">
        <div className="transformation-stage">
          <div className="transformation-course">
            <p className="eyebrow mb-3 text-center text-ink-tertiary">Ton cours</p>
            <RawPage className="h-full rotate-[-1.2deg]" fill />
          </div>

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

          <div className="transformation-sheet">
            <p className="eyebrow mb-3 text-center text-accent">Ta fiche</p>
            <div className="paper h-full overflow-hidden rounded-group bg-surface p-5">
              <SheetBlocks blocks={TRANSFORMATION_SHEET} tint={DEMO_COURSE.accent} />
            </div>
          </div>

          <div className="transformation-cards">
            <p className="eyebrow mb-3 text-center text-accent">Tes cartes</p>
            <div className="paper h-full overflow-hidden rounded-group bg-surface p-4">
              <GeneratedCards progress={progress} />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function GeneratedCards({ progress }: { progress: number }) {
  const cards = [
    {
      kind: "Schéma",
      body: (
        <div className="mt-3 flex items-center gap-1.5">
          {["Évaporation", "?", "Précipitations"].map((label, index) => (
            <div key={label} className="contents">
              <span className="min-w-0 flex-1 rounded-[9px] bg-info-soft px-2 py-2 text-center text-[9px] font-semibold text-info">
                {label}
              </span>
              {index < 2 ? <span className="text-[11px] text-ink-tertiary">→</span> : null}
            </div>
          ))}
        </div>
      ),
    },
    {
      kind: "Texte à trou",
      body: (
        <p className="mt-3 text-[12px] font-medium leading-relaxed text-ink">
          Les gouttelettes retombent sous forme de{" "}
          <span className="inline-block min-w-20 border-b-2 border-accent text-transparent">
            pluie
          </span>
          .
        </p>
      ),
    },
    {
      kind: "QCM",
      body: (
        <div className="mt-2.5 grid grid-cols-3 gap-1.5">
          {["En altitude", "Sous la mer", "Dans le sol"].map((choice, index) => (
            <span
              key={choice}
              className={`rounded-[8px] px-1.5 py-2 text-center text-[9px] font-medium ${
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
    <div className="grid h-full content-center gap-2.5">
      {cards.map((card, index) => {
        const cardProgress = Math.min(1, Math.max(0, (progress - 0.38 - index * 0.08) / 0.34));
        return (
          <article
            key={card.kind}
            className="rounded-button border border-stroke bg-surface px-3.5 py-3 shadow-sm"
            style={{
              opacity: cardProgress,
              transform: `translateY(${(1 - cardProgress) * 28}px) rotate(${(1 - cardProgress) * (index - 1) * 2}deg)`,
            }}
          >
            <span className="rounded-pill bg-accent-soft px-2 py-0.5 text-[9px] font-bold uppercase tracking-caps text-accent">
              {card.kind}
            </span>
            {card.body}
          </article>
        );
      })}
    </div>
  );
}
