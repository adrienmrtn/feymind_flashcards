"use client";

import Link from "next/link";

import { buttonVariants } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";

/**
 * Le geste d'écrire les cartes, depuis un cours.
 *
 * C'était un pavé bleu pleine largeur, encre inversée, avec une pastille blanche en guise de
 * bouton. Il criait sur une page qui, elle, ne parle qu'en panneaux clairs cernés d'un trait :
 * la seule tache de couleur pleine de l'app arrivait sous une fiche, sans que rien d'autre ne
 * lui réponde. Ce n'était pas un accent, c'était une pièce rapportée.
 *
 * Il prend donc la forme commune - le panneau - et garde sa priorité autrement : l'action est
 * un vrai bouton primaire à droite, la seule chose colorée du bloc. C'est comme ça que le reste
 * de l'app distingue ce qui se clique de ce qui se lit, et un CTA n'a pas besoin d'un dialecte
 * à lui.
 */
const shell =
  "panel group flex w-full flex-col gap-4 p-5 text-left transition-[border-color] duration-press ease-out-strong hover:border-stroke-strong sm:flex-row sm:items-center sm:gap-5";

export function GenerateCardsCta({ href, onClick }: { href?: string; onClick?: () => void }) {
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
          className="flex h-11 w-11 shrink-0 items-center justify-center rounded-tile bg-surface-muted text-ink-secondary"
        >
          <svg viewBox="0 0 24 24" className="h-5 w-5">
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
          <span className="section-title block">{t("copy.cardsButton")}</span>
          <span className="section-lead block max-w-[46ch]">{t("app.generate.ctaHint")}</span>
        </span>
      </span>
      <span
        aria-hidden
        className={buttonVariants({
          className: "w-full shrink-0 group-active:scale-[0.96] sm:w-auto",
          size: "lg",
        })}
      >
        {t("app.generate.ctaAction")}
      </span>
    </>
  );
}
