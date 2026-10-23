"use client";

import { useEffect, useRef, useState } from "react";

import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { Mika } from "@/components/mika/Mika";
import type { MikaMood } from "@/components/mika/moods";
import { useI18n } from "@/lib/i18n/client";
import { usePrefersReducedMotion } from "@/lib/usePrefersReducedMotion";

import { SourceBadge, type SourceKind } from "./SourceBadge";

/**
 * **La carte produit du héros**, en boucle : ce qu'on dépose, puis la leçon qui en sort.
 *
 * Une seule horloge (`phase`) et des attributs `data-*` : tout le mouvement est en CSS, en
 * transitions sur `transform` et `opacity`, donc rien ne se met en page pendant la boucle et
 * une transition interrompue repart d'où elle en est. Le React ne fait qu'avancer l'aiguille.
 *
 * | phase | ce qu'on voit |
 * | --- | --- |
 * | 0 | la carte vide, Mika salue |
 * | 1 – 4 | les quatre supports entrent, chacun coché à son tour |
 * | 5 | « Générer ma leçon » s'allume et appelle |
 * | 6 | le bouton travaille, Mika réfléchit |
 * | 7 | la carte devient la leçon, Mika fait la fête |
 * | 8 – 9 | les Notes, puis le Quiz se cochent ; les Flashcards s'allument |
 *
 * La boucle ne tourne que si la carte est à l'écran et l'onglet visible. « Réduire les
 * animations » l'arrête sur la leçon, deux étapes cochées : l'état qui dit tout.
 */
const TIMELINE: readonly (readonly [phase: number, hold: number])[] = [
  [0, 800],
  [1, 440],
  [2, 440],
  [3, 440],
  [4, 760],
  [5, 1500],
  [6, 1650],
  [7, 1500],
  [8, 950],
  [9, 2900],
];

const FINAL_PHASE = 9;

function moodFor(phase: number): MikaMood {
  if (phase <= 1) return "wave";
  if (phase === 6) return "think";
  if (phase === 7) return "celebrate";
  if (phase === 8) return "happy";
  return "idle";
}

export function HeroDemo() {
  const { t } = useI18n();
  const reduced = usePrefersReducedMotion();
  const root = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const element = root.current;
    if (!element) return;
    let onScreen = false;
    const sync = () => setVisible(onScreen && document.visibilityState === "visible");
    const observer = new IntersectionObserver(
      ([entry]) => {
        onScreen = entry?.isIntersecting ?? false;
        sync();
      },
      { threshold: 0.2 },
    );
    observer.observe(element);
    document.addEventListener("visibilitychange", sync);
    return () => {
      observer.disconnect();
      document.removeEventListener("visibilitychange", sync);
    };
  }, []);

  useEffect(() => {
    if (reduced || !visible) return;
    const timer = window.setTimeout(() => {
      setIndex((current) => (current + 1) % TIMELINE.length);
    }, TIMELINE[index]?.[1] ?? 800);
    return () => window.clearTimeout(timer);
  }, [index, visible, reduced]);

  const phase = reduced ? FINAL_PHASE : (TIMELINE[index]?.[0] ?? 0);
  const view = phase >= 7 ? "path" : "inputs";
  const done = phase >= 9 ? 2 : phase >= 8 ? 1 : 0;

  const sources: { kind: SourceKind; name: string; meta: string }[] = [
    { kind: "pdf", name: t("landing.demoFile1"), meta: t("landing.demoFile1Meta") },
    { kind: "word", name: t("landing.demoFile2"), meta: t("landing.demoFile2Meta") },
    { kind: "youtube", name: t("landing.demoFile3"), meta: t("landing.demoFile3Meta") },
    { kind: "audio", name: t("landing.demoFile4"), meta: t("landing.demoFile4Meta") },
  ];

  const steps = [
    { icon: "fiche", tone: "blue", title: t("landing.demoStepNotes"), meta: t("landing.demoStepNotesMeta") },
    { icon: "quiz", tone: "mint", title: t("landing.demoStepQuiz"), meta: t("landing.demoStepQuizMeta") },
    { icon: "cartes", tone: "yellow", title: t("landing.demoStepCards"), meta: t("landing.demoStepCardsMeta") },
    { icon: "examen", tone: "lilac", title: t("landing.demoStepExam"), meta: t("landing.demoStepExamMeta") },
  ];

  return (
    <div ref={root} className="relative mx-auto w-full max-w-[452px] pt-[78px]">
      <p className="sr-only">{t("landing.demoAria")}</p>
      {/* `relative` : sans lui, Mika se placerait par rapport au bloc du dessus dès que la
          flottaison s'arrête (« réduire les animations »), et décollerait de la carte. */}
      <div className="lp-float relative" aria-hidden>
        {/* Mika, perché sur le bord de la carte : ses pieds touchent le haut du cadre. Sans
            `size`, il garde ses animations (respirer, sauter, faire la fête). */}
        <div className="absolute right-7 top-[-84px] z-10 w-[92px] sm:right-9">
          <Mika mood={reduced ? "idle" : moodFor(phase)} label="" />
        </div>

        <div
          className="lp-demo lp-demo-card relative rounded-[30px] bg-surface p-4 sm:p-5"
          data-phase={phase}
          data-view={view}
          data-ready={phase >= 5 ? "true" : "false"}
          data-busy={phase >= 6 ? "true" : "false"}
          data-done={done}
        >
          <div className="relative h-[384px]">
            {/* ---- Les supports ---- */}
            <div className="lp-view lp-view-inputs flex flex-col">
              <div className="px-1 pt-1">
                <p className="text-[17px] font-extrabold leading-tight tracking-tight-title text-ink">{t("landing.demoTitle")}</p>
                <p className="mt-0.5 text-[13px] font-semibold text-ink-tertiary">{t("landing.demoHint")}</p>
              </div>

              <ul className="mt-4 space-y-2">
                {sources.map((source, position) => (
                  <li
                    key={source.kind}
                    className="lp-row flex h-[58px] items-center gap-3 rounded-[18px] bg-surface-muted px-3"
                    data-on={phase >= position + 1 ? "true" : "false"}
                  >
                    <SourceBadge kind={source.kind} size={38} />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[14.5px] font-bold text-ink">{source.name}</span>
                      <span className="block truncate text-[12.5px] font-semibold text-ink-tertiary">{source.meta}</span>
                    </span>
                    <span className="lp-row-check flex size-6 shrink-0 items-center justify-center rounded-full bg-correct text-white">
                      <Check className="size-3.5" />
                    </span>
                  </li>
                ))}
              </ul>

              <div className="lp-generate-press mt-auto">
                <div className="lp-generate relative flex h-[52px] items-center justify-center overflow-hidden rounded-[18px] lp-gradient-fill text-[15.5px] font-extrabold text-white">
                  <span className="lp-generate-ring" />
                  <span className="lp-label lp-label-idle flex items-center gap-2">
                    {t("landing.demoGenerate")}
                    <ArrowRight className="size-4 lp-arrow" />
                  </span>
                  <span className="lp-label lp-label-busy flex items-center justify-center gap-2">
                    <Dots />
                    {t("landing.demoGenerating")}
                  </span>
                  <span className="absolute inset-x-0 bottom-0 h-[3px] bg-white/25">
                    <span className="lp-progress block h-full w-full bg-white/85" />
                  </span>
                </div>
              </div>
            </div>

            {/* ---- La leçon ---- */}
            <div className="lp-view lp-view-path flex flex-col">
              <div className="lp-path-head flex items-center gap-3 px-1 pt-1">
                <span className="flex size-12 shrink-0 items-center justify-center rounded-[15px] bg-tone-mint-pale">
                  <MicaboIcon id="fiole" size={32} />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[17px] font-extrabold leading-tight tracking-tight-title text-ink">{t("landing.demoLessonTitle")}</span>
                  <span className="mt-0.5 block text-[12.5px] font-semibold text-ink-tertiary">{t("landing.demoLessonMeta")}</span>
                </span>
              </div>
              <div className="lp-path-head mx-1 mt-3 h-2 overflow-hidden rounded-pill bg-track">
                <span className="lp-path-bar block h-full w-full rounded-pill bg-progress" />
              </div>

              <ol className="relative mt-4 flex-1 space-y-1.5">
                {/* Le rail qui relie les étapes, et sa part déjà parcourue. */}
                <span aria-hidden className="lp-rail absolute bottom-9 left-[35px] top-9 w-[3px] overflow-hidden rounded-pill bg-track">
                  <span className="lp-rail-fill block h-full w-full bg-progress" />
                </span>
                {steps.map((step, position) => {
                  const isDone = position < done;
                  const isCurrent = view === "path" && position === done;
                  return (
                    <li
                      key={step.icon}
                      className="lp-step relative flex h-[66px] items-center gap-3.5 rounded-[20px] px-2"
                      style={{ ["--i" as string]: position }}
                      data-done={isDone ? "true" : "false"}
                      data-current={isCurrent ? "true" : "false"}
                    >
                      <span className="lp-step-current absolute inset-0 rounded-[20px] bg-accent-soft/70" />
                      <span
                        className="relative flex size-[54px] shrink-0 items-center justify-center rounded-full"
                        style={{ background: `var(--color-tone-${step.tone}-pale)` }}
                      >
                        <span className="lp-step-halo absolute inset-0 rounded-full border-2 border-accent" />
                        <MicaboIcon id={step.icon} size={32} />
                        <span className="lp-step-done absolute -bottom-0.5 -right-0.5 flex size-[22px] items-center justify-center rounded-full bg-correct text-white ring-[3px] ring-surface">
                          <Check className="size-3" />
                        </span>
                      </span>
                      <span className="relative min-w-0 flex-1">
                        <span className="block truncate text-[15px] font-extrabold text-ink">{step.title}</span>
                        <span className="block truncate text-[12.5px] font-semibold text-ink-tertiary">{step.meta}</span>
                      </span>
                      <span className="lp-step-current relative shrink-0 rounded-pill bg-accent px-2.5 py-1 text-[11.5px] font-extrabold text-on-ink">
                        {t("landing.demoNow")}
                      </span>
                    </li>
                  );
                })}
              </ol>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function Check({ className = "" }: { className?: string }) {
  return (
    <svg aria-hidden viewBox="0 0 16 16" className={className} fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="m3.5 8.4 2.9 2.9 6.1-6.6" />
    </svg>
  );
}

function ArrowRight({ className = "" }: { className?: string }) {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className={className} fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 10h11M11 5l5 5-5 5" />
    </svg>
  );
}

/** Trois points qui respirent : Mika écrit. */
function Dots() {
  return (
    <span aria-hidden className="flex items-center gap-1">
      {[0, 1, 2].map((dot) => (
        <span key={dot} className="lp-dot size-1.5 rounded-full bg-white" style={{ animationDelay: `${dot * 140}ms` }} />
      ))}
    </span>
  );
}
