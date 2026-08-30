"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { persistStoredAnswers } from "@/lib/onboarding/persist";
import { useOnboarding } from "@/lib/onboarding/store";
import { createClient } from "@/lib/supabase/client";

/**
 * L'écran de configuration, juste avant le compte.
 *
 * Porté depuis `PersonalizingStepView` : les réponses sont déjà là, rien ne se calcule
 * vraiment, mais un écran qui annonce qu'il construit un parcours puis disparaît en une
 * seconde n'a rien construit. Quatre phases, un anneau qui fait son tour, et c'est
 * l'étudiant qui appuie pour continuer.
 *
 * S'il a déjà une session, le bouton ouvre l'app - le compte est derrière lui.
 */

/** Onze secondes au départ, un tiers de moins depuis : l'attente se sentait. */
const DURATION_MS = 7_700;

const PHASES = [
  {
    headline: "On lit tes réponses.",
    step: "Lecture de tes réponses",
  },
  {
    headline: "On calibre tes intervalles.",
    step: "Calibrage de la répétition",
  },
  {
    headline: "On trace ton parcours.",
    step: "Tracé de ton parcours",
  },
  {
    headline: "On prépare ta première session.",
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
    const started = Date.now();
    const id = window.setInterval(() => {
      const next = Math.min(DURATION_MS, Date.now() - started);
      setElapsed(next);
      if (next >= DURATION_MS) window.clearInterval(id);
    }, 40);
    return () => window.clearInterval(id);
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
    <Scaffold
      eyebrow="Personnalisation"
      title={isDone ? "Ton parcours est prêt." : current.headline}
      footer={
        <ContinueButton
          label={
            isDone ? (signedIn ? "Ouvrir Micabo" : "Créer mon compte") : "Micabo travaille…"
          }
          enabled={isDone && !leaving}
          onPress={() => void continueOn()}
        />
      }
    >
      {summary ? <p className="mb-4 text-[13px] text-ink-tertiary">{summary}</p> : null}

      <div className="flex flex-col items-center justify-center py-4">
        <div className="relative flex h-[148px] w-[148px] items-center justify-center">
          <svg
            viewBox="0 0 120 120"
            className="absolute inset-0 h-full w-full -rotate-90"
            aria-hidden
          >
            <circle
              cx="60"
              cy="60"
              r="52"
              fill="none"
              stroke="var(--color-accent)"
              strokeWidth="8"
              opacity={0.16}
            />
            <circle
              cx="60"
              cy="60"
              r="52"
              fill="none"
              stroke="var(--color-accent)"
              strokeWidth="8"
              strokeLinecap="round"
              pathLength={100}
              strokeDasharray={100}
              strokeDashoffset={100 - Math.max(0.8, progress * 100)}
            />
          </svg>
          <div className="relative flex flex-col items-center">
            <p className="numeral text-[44px] font-bold leading-none tracking-display text-ink">
              {Math.round(progress * 100)}
              <span className="text-[22px]"> %</span>
            </p>
            <p className="mt-2 text-[12px] font-medium text-ink-secondary">
              {isDone ? "Terminé" : "Micabo travaille"}
            </p>
          </div>
        </div>
      </div>

      <div className="paper mb-4 shrink-0 divide-y divide-hairline overflow-hidden rounded-group bg-surface">
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

    </Scaffold>
  );
}
