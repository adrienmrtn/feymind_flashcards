"use client";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * La charnière du parcours.
 *
 * Avant : on montrait le produit. Après : on pose quatre questions. Sans cet
 * écran, la première question tombe sans qu'on sache pourquoi on y répond —
 * et une question dont on ignore l'usage se remplit au hasard.
 */
const STEPS = [
  { emoji: "🌍", title: "Ton pays", detail: "Le système scolaire, et la langue." },
  { emoji: "🎓", title: "Ton niveau", detail: "Le registre des fiches." },
  { emoji: "📚", title: "Tes matières", detail: "Ce qu'on te propose en premier." },
  { emoji: "🏫", title: "Ton école", detail: "Pour retrouver tes camarades." },
] as const;

export default function PersonalizeIntroStep() {
  return (
    <Scaffold
      title="On va personnaliser ton compte."
      footer={<ContinueButton label="C'est parti" enabled href="/commencer/pays" />}
    >
      <div className="mx-auto w-full max-w-[420px]">
        <p className="text-[14.5px] leading-relaxed text-ink-secondary">
          Quatre questions, une minute. Elles changent la façon dont Micabo écrit tes fiches.
        </p>

        <div className="mt-4 space-y-2">
          {STEPS.map((step, index) => (
            <div
              key={step.title}
              className="flex items-center gap-3.5 rounded-button bg-surface px-4 py-3 paper"
              style={{
                animation: `micabo-rise 380ms var(--ease-out-strong) ${index * 90}ms both`,
              }}
            >
              <span aria-hidden className="emoji text-[22px]">
                {step.emoji}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block text-[15px] font-medium text-ink">{step.title}</span>
                <span className="mt-0.5 block text-[12.5px] text-ink-tertiary">{step.detail}</span>
              </span>
            </div>
          ))}
        </div>
      </div>
    </Scaffold>
  );
}
