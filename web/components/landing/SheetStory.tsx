"use client";

import { DEMO_ACCENT, localizedDemoCards, localizedTransformationSheet } from "@/components/demo/demo-course";
import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { useI18n } from "@/lib/i18n/client";

/**
 * La vignette « fiche, puis cartes » : **le vrai composant de fiche, les vraies cartes.**
 *
 * Le document déposé est réduit à une étiquette dans le coin : ce qu'on veut lire, c'est ce
 * qu'il devient. La fiche est rendue par `SheetBlocks`, le composant qui affiche une fiche
 * réelle dans l'app, sur le document de démonstration du parcours d'accueil. Les deux cartes
 * en bas sortent du même jeu que celles qu'on retourne plus bas sur la page.
 *
 * La fiche est coupée avec un fondu : une fiche entière ferait une vignette de deux écrans, et
 * une vignette qu'on fait défiler n'est plus une vignette.
 */
export function SheetStory() {
  const { t } = useI18n();
  const sheet = localizedTransformationSheet(t);
  const cards = localizedDemoCards(t).slice(0, 2);

  return (
    <div className="relative w-full max-w-[360px]">
      <span className="paper absolute -left-2 -top-3 z-10 inline-flex items-center gap-1.5 rounded-pill bg-surface px-2.5 py-1 text-[10.5px] font-semibold text-ink-secondary">
        <svg aria-hidden viewBox="0 0 24 24" className="h-3.5 w-3.5 text-negative">
          <path
            d="M6 3.5h7L18.5 9v11.5h-12z"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinejoin="round"
          />
          <path d="M13 3.5V9h5.5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
        </svg>
        {t("landing.sheetSourceChip")}
      </span>

      <div className="paper relative max-h-[236px] overflow-hidden rounded-[18px] bg-surface p-4 pt-5">
        <SheetBlocks blocks={sheet} tint={DEMO_ACCENT} />
        <div
          aria-hidden
          className="pointer-events-none absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-surface to-transparent"
        />
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2.5">
        {cards.map((card, index) => (
          <article
            key={card.front}
            className="paper rounded-[14px] bg-surface px-3 py-2.5"
            style={{ animation: `micabo-rise 420ms var(--ease-out-strong) ${260 + index * 120}ms both` }}
          >
            <span className="rounded-pill bg-accent-soft px-2 py-0.5 text-[9px] font-bold uppercase tracking-caps text-accent">
              {card.kindLabel}
            </span>
            <p className="mt-1.5 line-clamp-3 text-[11.5px] font-medium leading-snug text-ink">{card.front}</p>
          </article>
        ))}
      </div>
    </div>
  );
}
