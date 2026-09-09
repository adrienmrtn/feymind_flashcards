"use client";

import Link from "next/link";

import type { Mastery } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";

/**
 * **Le seul chiffre du produit qui a une fin.**
 *
 * Les tableaux de bord d'apps d'étude affichent des volumes - cartes vues, minutes, série.
 * Ils montent même quand rien n'est appris, et ils ne répondent pas à la question qui amène
 * l'étudiant ici la veille d'un partiel, qui est « est-ce que je sais mon cours ». La
 * maîtrise y répond, et 100 % veut dire quelque chose : plus une carte du programme qui ne
 * soit acquise et stable.
 *
 * La barre est **segmentée** et non pleine, parce que le reste à faire n'est pas
 * indifférencié : des cartes jamais vues se rattrapent en apprenant, des cartes fragiles se
 * rattrapent en corrigeant. Les deux ne demandent pas le même effort et ne doivent pas
 * partager la même couleur.
 */
export function MasteryCard({ mastery }: { mastery: Mastery }) {
  const { t } = useI18n();

  if (mastery.cardCount === 0) {
    return (
      <section className="rounded-group border border-border bg-card p-5">
        <h2 className="text-[15px] font-semibold text-ink">{t("app.home.mastery.title")}</h2>
        <p className="mt-2 text-[14px] text-ink-secondary">{t("app.home.mastery.empty")}</p>
      </section>
    );
  }

  const parts = [
    { key: "solid", value: mastery.solid, className: "bg-positive" },
    { key: "fragile", value: mastery.fragile, className: "bg-caution" },
    { key: "learning", value: mastery.learning, className: "bg-accent" },
    { key: "untouched", value: mastery.untouched, className: "bg-surface-sunken" },
  ].filter((part) => part.value > 0);

  return (
    <section className="rounded-group border border-border bg-card p-5" data-tour="maitrise">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <h2 className="text-[15px] font-semibold text-ink">{t("app.home.mastery.title")}</h2>
        <Link
          href={"/app/cours" as never}
          className="underline-draw text-[13px] font-medium text-ink-secondary"
        >
          {t("app.home.mastery.byCourse")}
        </Link>
      </div>

      <p className="mt-3 flex items-baseline gap-2">
        <span className="numeral text-[38px] font-bold leading-none tracking-tight text-ink">
          {mastery.percent}
          <span className="text-[22px]"> %</span>
        </span>
        <span className="text-[13px] text-ink-tertiary">
          {t("app.home.mastery.of", { count: mastery.cardCount })}
        </span>
      </p>

      <div
        className="mt-4 flex h-2.5 w-full overflow-hidden rounded-pill bg-surface-sunken"
        role="img"
        aria-label={t("app.home.mastery.aria", {
          percent: mastery.percent,
          solid: mastery.solid,
          fragile: mastery.fragile,
          learning: mastery.learning,
          untouched: mastery.untouched,
        })}
      >
        {parts.map((part) => (
          <span
            key={part.key}
            aria-hidden
            className={part.className}
            style={{ width: `${(part.value / mastery.cardCount) * 100}%` }}
          />
        ))}
      </div>

      <ul className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 sm:grid-cols-4">
        <Legend tone="bg-positive" label={t("app.home.mastery.solid")} value={mastery.solid} />
        <Legend tone="bg-caution" label={t("app.home.mastery.fragile")} value={mastery.fragile} />
        <Legend tone="bg-accent" label={t("app.home.mastery.learning")} value={mastery.learning} />
        <Legend
          tone="bg-surface-sunken"
          label={t("app.home.mastery.untouched")}
          value={mastery.untouched}
        />
      </ul>
    </section>
  );
}

function Legend({ tone, label, value }: { tone: string; label: string; value: number }) {
  return (
    <li className="flex items-center gap-2">
      <span aria-hidden className={`h-2 w-2 shrink-0 rounded-full ${tone}`} />
      <span className="min-w-0 truncate text-[12.5px] text-ink-secondary">{label}</span>
      <span className="numeral ml-auto text-[12.5px] font-medium text-ink">{value}</span>
    </li>
  );
}
