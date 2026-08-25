"use client";

import { useState } from "react";

import { DEMO_CARDS, type DemoCard } from "@/components/demo/demo-course";

/**
 * Les cartes que Micabo tire d'une fiche — **et elles se retournent au survol.**
 *
 * C'est le seul endroit du produit où une carte a le droit de pivoter, et la raison est la table
 * des fréquences : cet écran-là se voit **une fois**, sur une page d'accueil qu'on visite une
 * fois. C'est exactement là que le budget d'enchantement se dépense.
 *
 * La session réelle, elle, ne s'animera pas : espace retourne la carte et 1 à 4 la notent, des
 * centaines de fois par soirée de révision, et une carte qui pivote joliment devient au bout de
 * vingt cartes la chose qui ralentit le travail. La même animation, aux deux endroits, serait
 * juste ici et fausse là-bas.
 *
 * Le survol qui bouge est enfermé derrière `hover: hover` : sur un écran tactile, un appui
 * déclenche un faux survol et la carte resterait retournée après que le doigt est parti. Sur
 * mobile, c'est donc l'appui qui retourne, ce qui est le geste juste de toute façon.
 */
export function DemoCards() {
  return (
    <div className="grid gap-4 sm:grid-cols-3">
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
      aria-label={`${card.kindLabel} : ${card.front} — ${card.back}`}
      className="group h-[190px] w-full text-left [perspective:1000px]"
      data-flipped={tapped ? "true" : undefined}
    >
      <div className="relative h-full w-full transition-transform duration-[420ms] ease-out-strong [transform-style:preserve-3d] group-data-[flipped]:[transform:rotateY(180deg)] hover-flip">
        {/* Recto */}
        <Face>
          <p className="eyebrow text-ink-tertiary">{card.kindLabel}</p>
          <p className="mt-3 text-[15px] font-medium leading-snug text-ink">{card.front}</p>

          {card.choices ? (
            <ul className="mt-3 space-y-1.5">
              {card.choices.map((choice) => (
                <li
                  key={choice}
                  className="rounded-[10px] bg-surface-muted px-2.5 py-1.5 text-[12.5px] text-ink-secondary"
                >
                  {choice}
                </li>
              ))}
            </ul>
          ) : null}

          <p className="mt-auto pt-3 text-[12px] text-ink-tertiary">
            Passe la souris, ou touche
          </p>
        </Face>

        {/* Verso */}
        <Face className="[transform:rotateY(180deg)]">
          <p className="eyebrow text-accent">Réponse</p>
          <p className="mt-3 text-[15px] font-semibold leading-snug text-ink">{card.back}</p>

          {card.choices ? (
            <p className="mt-3 rounded-[10px] bg-positive-soft px-2.5 py-1.5 text-[12.5px] font-medium text-positive">
              {card.choices[card.answerIndex ?? 0]}
            </p>
          ) : null}

          <p className="mt-auto pt-3 text-[12px] text-ink-tertiary">
            En session, tu te notes de 1 à 4
          </p>
        </Face>
      </div>
    </button>
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
