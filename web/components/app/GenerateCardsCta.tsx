"use client";

import Link from "next/link";

import { useI18n } from "@/lib/i18n/client";

/**
 * Le geste d'écrire les cartes, depuis un cours.
 *
 * Ce n'est plus une rangée blanche comme l'espace des cartes : c'est le CTA
 * du cours tant qu'il n'y a pas de paquet. Encre, un verbe, un bouton.
 */
const shell =
  "flex w-full flex-col gap-4 rounded-2xl bg-accent px-6 py-5 text-left text-on-ink transition-[scale,background-color] duration-press ease-out-strong hover:bg-accent/90 active:scale-[0.96] sm:flex-row sm:items-center sm:gap-5";

export function GenerateCardsCta({
  href,
  onClick,
}: {
  href?: string;
  onClick?: () => void;
}) {
  const body = <CtaBody />;

  if (href) {
    return (
      <Link href={href as never} className={shell} data-print="hide">
        {body}
      </Link>
    );
  }

  return (
    <button type="button" onClick={onClick} className={shell} data-print="hide">
      {body}
    </button>
  );
}

function CtaBody() {
  const { t } = useI18n();
  return (
    <>
      <span className="flex min-w-0 flex-1 items-center gap-4">
        <span
          aria-hidden
          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-tile bg-on-ink/10 sm:h-14 sm:w-14"
        >
          <svg viewBox="0 0 24 24" className="h-6 w-6">
            <path
              d="M12 5v14M5 12h14"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
            />
          </svg>
        </span>
        <span className="min-w-0">
          <span className="block text-[18px] font-bold leading-tight">{t("copy.cardsButton")}</span>
          <span className="mt-1 block text-[14px] text-on-ink-muted">
            {t("app.generate.ctaHint")}
          </span>
        </span>
      </span>
      <span className="inline-flex h-11 w-full shrink-0 items-center justify-center rounded-button bg-on-ink px-4 text-[15px] font-semibold text-ink sm:h-10 sm:w-auto">
        {t("app.generate.ctaAction")}
      </span>
    </>
  );
}
