"use client";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * Le mode d'emploi, **avant** de le faire.
 *
 * L'écran suivant demande de glisser un PDF. Sans celui-ci, on arrive sur un geste sans
 * savoir pourquoi. Trois phrases, dans l'ordre du produit, et un seul bouton.
 */

const BEATS = [
  {
    emoji: "📄",
    title: "Tu déposes un cours.",
    detail: "Un PDF, un polycopié, une vidéo. Micabo le lit.",
  },
  {
    emoji: "✍️",
    title: "Micabo en écrit la fiche.",
    detail: "Les idées, les définitions, les schémas - plus le mur de texte.",
  },
  {
    emoji: "🃏",
    title: "Tu révises jusqu'à l'examen.",
    detail: "Les cartes reviennent le jour où tu allais oublier.",
  },
] as const;

export default function HowItWorksStep() {
  return (
    <Scaffold
      eyebrow="Comment ça marche"
      title="Voici comment ça marche."
      footer={<ContinueButton label="Continuer" enabled href="/commencer/demo" shiny />}
    >
      <ol className="space-y-3">
        {BEATS.map((beat, index) => (
          <li
            key={beat.title}
            className="rise paper flex items-start gap-4 rounded-group bg-surface px-4 py-4"
            style={{ animationDelay: `${index * 90}ms` }}
          >
            <span
              aria-hidden
              className="emoji mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-tile bg-accent-soft text-[20px]"
            >
              {beat.emoji}
            </span>
            <span className="min-w-0">
              <span className="block text-[16px] font-semibold text-ink">{beat.title}</span>
              <span className="mt-1 block text-[13.5px] leading-relaxed text-ink-secondary">
                {beat.detail}
              </span>
            </span>
          </li>
        ))}
      </ol>
    </Scaffold>
  );
}
