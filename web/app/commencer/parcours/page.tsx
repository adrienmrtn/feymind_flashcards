"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import { persistStoredAnswers } from "@/lib/onboarding/persist";
import { useOnboarding } from "@/lib/onboarding/store";
import { createClient } from "@/lib/supabase/client";

/**
 * L'écran de configuration, juste avant le compte.
 *
 * Porté depuis `PersonalizingStepView` : les réponses sont déjà là, rien ne se calcule
 * vraiment, mais un écran qui annonce qu'il construit un parcours puis disparaît en une
 * seconde n'a rien construit. Quatre phases, cinq secondes, un anneau qui fait son tour,
 * et c'est l'étudiant qui appuie pour continuer.
 *
 * S'il a déjà une session, le bouton ouvre l'app - le compte est derrière lui.
 */

const DURATION_MS = 5000;

const PHASES = [
  {
    headline: "On lit tes réponses.",
    detail: "Ton objectif, tes matières, ton rythme : tout est déjà là.",
    step: "Lecture de tes réponses",
  },
  {
    headline: "On calibre tes intervalles.",
    detail: "Les rappels s'ajustent au temps que tu t'accordes chaque jour.",
    step: "Calibrage de la répétition",
  },
  {
    headline: "On trace ton parcours.",
    detail: "Matière par matière, du premier jour jusqu'à tes examens.",
    step: "Tracé de ton parcours",
  },
  {
    headline: "On prépare ta première session.",
    detail: "Elle t'attendra dès l'ouverture de l'app.",
    step: "Préparation de ta session",
  },
] as const;

export default function PersonalizingStep() {
  const { answers } = useOnboarding();
  const router = useRouter();
  const [elapsed, setElapsed] = useState(0);
  const [signedIn, setSignedIn] = useState(false);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    void supabase.auth.getUser().then(({ data }) => {
      setSignedIn(Boolean(data.user));
    });
  }, []);

  useEffect(() => {
    const started = performance.now();
    let frame = 0;
    const tick = (now: number) => {
      const next = Math.min(DURATION_MS, now - started);
      setElapsed(next);
      if (next < DURATION_MS) frame = window.requestAnimationFrame(tick);
    };
    frame = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(frame);
  }, []);

  const progress = elapsed / DURATION_MS;
  const completed = Math.min(PHASES.length, Math.floor(progress * PHASES.length + 0.001));
  const isDone = progress >= 1;
  const current = PHASES[Math.min(completed, PHASES.length - 1)] ?? PHASES[0];

  const summary = useMemo(() => {
    const bits = [
      answers.institutionName,
      answers.subjects?.slice(0, 2).join(", "),
      answers.examName,
    ].filter(Boolean);
    return bits.length > 0 ? bits.join(" · ") : null;
  }, [answers.examName, answers.institutionName, answers.subjects]);

  async function continueOn() {
    if (leaving || !isDone) return;
    setLeaving(true);
    if (signedIn) {
      await persistStoredAnswers();
      router.push("/app?bienvenue=1");
      return;
    }
    router.push("/commencer/compte");
  }

  return (
    <div className="center-safe mx-auto flex min-h-[calc(100svh-var(--onboarding-chrome))] w-full max-w-[560px] flex-col px-screen pb-10">
      <div className="pt-3 sm:pt-0">
        <p className="eyebrow text-accent">Personnalisation</p>
        <h1 className="rise mt-3 min-h-[2.4em] text-[28px] font-bold leading-[1.12] tracking-tight-title text-ink sm:text-[34px]">
          {isDone ? "Ton parcours est prêt." : current.headline}
        </h1>
        <p className="mt-2 min-h-[3em] text-[15px] leading-relaxed text-ink-secondary">
          {isDone ? "Quand tu veux." : current.detail}
        </p>
        {summary ? (
          <p className="mt-1 text-[13px] text-ink-tertiary">{summary}</p>
        ) : null}
      </div>

      <div className="flex flex-1 flex-col items-center justify-center py-8">
        <div className="relative flex h-[184px] w-[184px] items-center justify-center">
          <svg viewBox="0 0 120 120" className="absolute inset-0 h-full w-full -rotate-90">
            <circle
              cx="60"
              cy="60"
              r="52"
              fill="none"
              stroke="currentColor"
              strokeWidth="8"
              className="text-accent/15"
            />
            <circle
              cx="60"
              cy="60"
              r="52"
              fill="none"
              stroke="currentColor"
              strokeWidth="8"
              strokeLinecap="round"
              className="text-accent transition-[stroke-dashoffset] duration-100"
              strokeDasharray={2 * Math.PI * 52}
              strokeDashoffset={2 * Math.PI * 52 * (1 - Math.max(0.008, progress))}
            />
          </svg>
          <div className="relative flex flex-col items-center">
            {isDone ? (
              <p className="numeral text-[44px] font-bold leading-none tracking-display text-ink">
                100
                <span className="text-[22px]"> %</span>
              </p>
            ) : (
              <ThinkingOrb state="composing" size={64} />
            )}
            <p className="mt-2 text-[12px] font-medium text-ink-secondary">
              {isDone ? "Terminé" : "Micabo travaille"}
            </p>
          </div>
        </div>
      </div>

      <div className="paper mb-6 divide-y divide-hairline overflow-hidden rounded-group bg-surface">
        {PHASES.map((phase, index) => {
          const done = index < completed || isDone;
          const active = !isDone && index === completed;
          return (
            <div key={phase.step} className="flex items-center gap-3 px-4 py-3.5">
              <span
                aria-hidden
                className={`flex h-[22px] w-[22px] shrink-0 items-center justify-center rounded-full ${
                  done
                    ? "bg-accent text-on-ink"
                    : active
                      ? "bg-accent-soft text-accent"
                      : "border-[1.5px] border-stroke-strong"
                }`}
              >
                {done ? (
                  <svg viewBox="0 0 20 20" className="h-3 w-3">
                    <path
                      d="M5 10.5l3.2 3.2L15 7"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2.6"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                ) : null}
              </span>
              <span
                className={`text-[15px] ${
                  done || active ? "font-medium text-ink" : "text-ink-tertiary"
                }`}
              >
                {phase.step}
              </span>
            </div>
          );
        })}
      </div>

      <button
        type="button"
        disabled={!isDone || leaving}
        onClick={() => void continueOn()}
        className={`pressable flex h-14 w-full items-center justify-center gap-2 rounded-button text-[16px] font-semibold transition-colors duration-hover ${
          isDone
            ? "shiny bg-ink text-on-ink"
            : "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
        }`}
      >
        {isDone
          ? signedIn
            ? "Ouvrir Micabo"
            : "Créer mon compte"
          : "Micabo travaille…"}
      </button>
    </div>
  );
}
