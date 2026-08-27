"use client";

import { useState } from "react";

import { DEMO_CARDS, DEMO_COURSE, type DemoCard } from "@/components/demo/demo-course";

/**
 * Les cartes que Micabo tire d'une fiche - **et elles se retournent.**
 *
 * Quatre formats, parce qu'un cours ne se révise pas d'une seule façon, et parce qu'une
 * démonstration qui ne montre que du recto verso laisse croire que Micabo ne fait que ça. Le
 * quatrième est celui qu'on oublie toujours d'annoncer : **le schéma**, dont on nomme les parties.
 *
 * C'est le seul endroit du produit où une carte a le droit de pivoter, et la raison est la table
 * des fréquences : cet écran-là se voit **une fois**. La session réelle, elle, ne s'animera pas  - 
 * espace retourne et 1 à 4 notent, des centaines de fois par soirée, et une carte qui pivote
 * joliment devient au bout de vingt cartes la chose qui ralentit le travail.
 *
 * Le survol qui bouge est enfermé derrière `hover: hover` : sur un écran tactile, un appui déclenche
 * un faux survol et la carte resterait retournée après que le doigt est parti.
 */
export function DemoCards({ layout = "wide" }: { layout?: "wide" | "compact" }) {
  return (
    <div
      className={`grid gap-3.5 sm:grid-cols-2 ${layout === "wide" ? "lg:grid-cols-4" : ""}`}
    >
      {DEMO_CARDS.map((card) => (
        <FlipCard key={card.front} card={card} />
      ))}
    </div>
  );
}

function FlipCard({ card }: { card: DemoCard }) {
  const [tapped, setTapped] = useState(false);

  return (
    <button
      type="button"
      onClick={() => setTapped((value) => !value)}
      aria-label={`${card.kindLabel} : ${card.front} - ${card.back}`}
      /* Une hauteur fixe, et assez grande pour la carte la plus chargée - le QCM. Une hauteur qui
         s'adapte au contenu donnerait quatre cartes de tailles différentes, et un dos plus court
         que son recto laisse un trou au retournement. */
      className="group h-[248px] w-full text-left [perspective:1200px]"
      data-flipped={tapped ? "true" : undefined}
    >
      <div className="relative h-full w-full transition-transform duration-[460ms] ease-out-strong [transform-style:preserve-3d] group-data-[flipped]:[transform:rotateY(180deg)] hover-flip">
        <Face>
          <Badge kind={card.kindLabel} />
          <p className="mt-2.5 text-[14.5px] font-medium leading-snug text-ink">{card.front}</p>

          {card.choices ? (
            <ul className="mt-2.5 space-y-1">
              {card.choices.map((choice) => (
                <li
                  key={choice}
                  className="truncate rounded-[8px] bg-surface-muted px-2.5 py-1.5 text-[12px] text-ink-secondary"
                >
                  {choice}
                </li>
              ))}
            </ul>
          ) : null}

          {card.labels ? <Diagram labels={card.labels} revealed={false} /> : null}

        </Face>

        <Face className="[transform:rotateY(180deg)]">
          <Badge kind="Réponse" tone="accent" />
          <p className="mt-2.5 text-[14.5px] font-semibold leading-snug text-ink">{card.back}</p>

          {card.choices ? (
            <p className="mt-2.5 rounded-[8px] bg-positive-soft px-2.5 py-1.5 text-[12px] font-medium text-positive">
              {card.choices[card.answerIndex ?? 0]}
            </p>
          ) : null}

          {card.labels ? <Diagram labels={card.labels} revealed /> : null}

          {card.note ? (
            <p className="mt-2.5 text-[11.5px] leading-relaxed text-ink-secondary">{card.note}</p>
          ) : null}

          <p className="mt-auto pt-3 text-[11px] text-ink-tertiary">
            En session, tu te notes de 1 à 4
          </p>
        </Face>
      </div>
    </button>
  );
}

/**
 * Le schéma d'une carte, **au recto avec ses trous et au verso rempli.**
 *
 * Trois pastilles reliées par des flèches : c'est le cycle, et c'est la même figure que la fiche
 * porte. Au recto les étiquettes sont des tirets - un schéma dont tout est déjà écrit ne demande
 * rien.
 */
function Diagram({
  labels,
  revealed,
}: {
  labels: readonly { text: string; hidden?: boolean }[];
  revealed: boolean;
}) {
  return (
    <div
      className="mt-3 rounded-[10px] p-2.5"
      style={{ backgroundColor: `${DEMO_COURSE.accent}14` }}
    >
      <div className="flex items-center justify-between gap-1">
        {labels.map((label, index) => (
          <div key={label.text} className="flex flex-1 items-center gap-1">
            <div className="flex-1 text-center">
              <span
                aria-hidden
                className="mx-auto block h-2.5 w-2.5 rounded-full"
                style={{ backgroundColor: DEMO_COURSE.accent, opacity: revealed ? 1 : 0.35 }}
              />
              <p
                className={`mt-1.5 text-[9.5px] font-semibold leading-tight ${
                  revealed ? "text-ink" : "text-ink-tertiary"
                }`}
              >
                {revealed || !label.hidden ? label.text : "?"}
              </p>
            </div>
            {index < labels.length - 1 ? (
              <svg
                aria-hidden
                viewBox="0 0 12 12"
                className="mt-[-10px] h-2.5 w-2.5 shrink-0"
                style={{ color: DEMO_COURSE.accent, opacity: 0.5 }}
              >
                <path
                  d="M2 6h7M6.5 3l3 3-3 3"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            ) : null}
          </div>
        ))}
      </div>
    </div>
  );
}

function Badge({ kind, tone = "neutral" }: { kind: string; tone?: "neutral" | "accent" }) {
  return (
    <span
      className={`inline-flex rounded-pill px-2 py-0.5 text-[10px] font-bold uppercase tracking-caps ${
        tone === "accent" ? "bg-accent-soft text-accent" : "bg-surface-muted text-ink-tertiary"
      }`}
    >
      {kind}
    </span>
  );
}

function Face({ className, children }: { className?: string; children: React.ReactNode }) {
  return (
    <div
      className={`paper absolute inset-0 flex flex-col rounded-group bg-surface p-4 [backface-visibility:hidden] ${
        className ?? ""
      }`}
    >
      {children}
    </div>
  );
}
