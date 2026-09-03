"use client";

import { requestPaywall } from "@/lib/paywall";
import { useI18n } from "@/lib/i18n/client";

/**
 * Le deuxième cours, pour qui n'est pas abonné.
 *
 * On refuse **avant** le dépôt : un paywall après l'analyse d'un PDF est
 * un paywall qui fait fermer l'onglet.
 */
export function SecondCourseCard() {
  const { t } = useI18n();
  return (
    <section className="saas-card mx-auto max-w-[440px] px-7 py-10 text-center">
      <span
        aria-hidden
        className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-ink text-on-ink"
      >
        <svg viewBox="0 0 20 20" className="h-5 w-5" fill="currentColor">
          <path d="M10 1.5a3.5 3.5 0 0 0-3.5 3.5v2H6a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2v-6a2 2 0 0 0-2-2h-.5V5A3.5 3.5 0 0 0 10 1.5zm-2 3.5a2 2 0 1 1 4 0v2H8V5z" />
        </svg>
      </span>
      <h2 className="mt-4 text-[18px] font-bold tracking-tight text-ink">
        {t("app.import.secondCourse.title")}
      </h2>
      <p className="mx-auto mt-2 max-w-[36ch] text-[14px] leading-relaxed text-ink-secondary">
        {t("app.import.secondCourse.body")}
      </p>
      <button
        type="button"
        onClick={requestPaywall}
        className="mt-6 inline-flex items-center justify-center rounded-full bg-accent px-5 py-3 text-[14.5px] font-semibold text-on-ink"
      >
        {t("app.import.secondCourse.cta")}
      </button>
    </section>
  );
}

export function LockedAddCourseCard() {
  const { t } = useI18n();
  return (
    <button
      type="button"
      onClick={requestPaywall}
      className="relative flex flex-col gap-4 rounded-2xl border border-dashed border-border bg-card p-5 text-left transition-[scale,background-color,border-color] duration-press ease-out-strong hover:border-stroke-strong hover:bg-surface-muted active:scale-[0.96]"
    >
      <span
        aria-hidden
        className="flex h-12 w-12 items-center justify-center rounded-tile bg-accent text-on-ink"
      >
        <svg viewBox="0 0 20 20" className="h-5 w-5" fill="currentColor">
          <path d="M10 1.5a3.5 3.5 0 0 0-3.5 3.5v2H6a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2v-6a2 2 0 0 0-2-2h-.5V5A3.5 3.5 0 0 0 10 1.5zm-2 3.5a2 2 0 1 1 4 0v2H8V5z" />
        </svg>
      </span>
      <span className="min-w-0">
        <span className="line-clamp-2 block text-[16px] font-semibold leading-snug text-ink">
          {t("app.courses.addTitle")}
        </span>
        <span className="mt-1.5 line-clamp-2 block text-[13px] text-ink-tertiary">
          {t("app.import.secondCourse.lockedHint")}
        </span>
      </span>
    </button>
  );
}
