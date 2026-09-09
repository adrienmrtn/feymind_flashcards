"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";
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
  { headline: "onboarding.parcoursWorking1", step: "onboarding.parcoursStep1" },
  { headline: "onboarding.parcoursWorking2", step: "onboarding.parcoursStep2" },
  { headline: "onboarding.parcoursWorking3", step: "onboarding.parcoursStep3" },
  { headline: "onboarding.parcoursWorking4", step: "onboarding.parcoursStep4" },
] as const;

export default function PersonalizingStep() {
  const { answers } = useOnboarding();
  const { t } = useI18n();
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
      title={isDone ? t("onboarding.parcoursDone") : t(current.headline)}
      footer={
        <ContinueButton
          label={
            isDone
              ? signedIn
                ? t("onboarding.openMicabo")
                : t("onboarding.createAccount")
              : t("onboarding.parcoursBusyBtn")
          }
          enabled={isDone && !leaving}
          onPress={() => void continueOn()}
        />
      }
    >
      {/*
        L'écran tenait sur 400 px de haut : un anneau de 148, quatre lignes de 52, et un
        résumé. Sur un portable, la dernière phase passait sous le pli, si bien qu'on
        attendait la fin d'une liste dont on ne voyait pas le bout. Tout se resserre d'un
        cran ; rien ne disparaît.
      */}
      {summary ? <p className="mb-3 text-center text-[12.5px] text-ink-tertiary">{summary}</p> : null}

      <div className="flex flex-col items-center justify-center">
        <div className="relative flex h-[112px] w-[112px] items-center justify-center">
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
              strokeWidth="9"
              opacity={0.16}
            />
            <circle
              cx="60"
              cy="60"
              r="52"
              fill="none"
              stroke="var(--color-accent)"
              strokeWidth="9"
              strokeLinecap="round"
              pathLength={100}
              strokeDasharray={100}
              strokeDashoffset={100 - Math.max(0.8, progress * 100)}
            />
          </svg>
          {/* Le mot sort de l'anneau : à 112 px, « Micabo travaille » venait mordre le
              tracé, et un texte posé sur un trait qui tourne se lit deux fois moins vite. */}
          <p className="numeral relative text-[34px] font-bold leading-none tracking-display text-ink">
            {Math.round(progress * 100)}
            <span className="text-[17px]"> %</span>
          </p>
        </div>
        <p className="mt-2.5 text-[12px] font-medium text-ink-secondary">
          {isDone ? t("onboarding.parcoursFinished") : t("onboarding.parcoursBusy")}
        </p>
      </div>

      <div className="paper mt-5 shrink-0 divide-y divide-hairline overflow-hidden rounded-group bg-surface">
        {PHASES.map((phase, index) => {
          const done = index < completed || isDone;
          const active = !isDone && index === completed;
          return (
            <div key={phase.step} className="flex items-center gap-3 px-4 py-2.5">
              <span
                aria-hidden
                className={`flex h-5 w-5 shrink-0 items-center justify-center rounded-full ${
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
                className={`text-[14px] ${
                  done || active ? "font-medium text-ink" : "text-ink-tertiary"
                }`}
              >
                {t(phase.step)}
              </span>
            </div>
          );
        })}
      </div>

    </Scaffold>
  );
}
