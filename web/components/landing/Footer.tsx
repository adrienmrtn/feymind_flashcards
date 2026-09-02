"use client";

import type { Route } from "next";
import Link from "next/link";

import { BrandLockup } from "@/components/BrandMark";
import { Separator } from "@/components/ui/separator";
import { useI18n } from "@/lib/i18n/client";
import { LANDING_SECTIONS } from "@/lib/landing-sections";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";
import { SITE_PAGES } from "@/lib/site-pages";

/**
 * Le pied de page de la vitrine.
 *
 * Pas de badge App Store tant que le lien n'est pas public : un badge mort se voit.
 * Confidentialité et conditions sont les adresses que l'iPhone ouvre déjà. Le parcours
 * s'ouvre par **Commencer**. Une session déjà ouverte remplace ça par Ouvrir l'app.
 */
export function Footer({ signedIn = false }: { signedIn?: boolean }) {
  const { t } = useI18n();
  const product = [
    { href: `#${LANDING_SECTIONS.method}`, label: t("site.method") },
    { href: `#${LANDING_SECTIONS.exam}`, label: t("site.exam") },
    { href: `#${LANDING_SECTIONS.questions}`, label: t("site.questions") },
  ];
  const pages = SITE_PAGES.map((page) => ({
    path: page.path,
    label:
      page.path === "/methode"
        ? t("site.method")
        : page.path === "/mode-examen"
          ? t("site.exam")
          : t("site.anki"),
  }));
  return (
    <footer className="mt-24" data-print="hide">
      <Separator />
      <div className="mx-auto max-w-page px-screen py-14">
        <div className="flex flex-col gap-10 sm:flex-row sm:items-start sm:justify-between">
          <div className="max-w-[34ch]">
            <BrandLockup
              href="/"
              size={32}
              className="text-ink"
              wordClassName="text-[15px] font-bold text-ink"
            />
            <p className="mt-2.5 text-[13.5px] leading-relaxed text-ink-secondary">
              {t("landing.footerTagline")}
            </p>
          </div>

          <div className="flex flex-wrap gap-x-14 gap-y-8 text-[13.5px]">
            {/* La même structure qu'en haut, en clair. C'est le pied de page qui porte les
                sections sur mobile, où la barre n'a pas la place de les montrer. */}
            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">{t("landing.footerProduct")}</p>
              <ul className="space-y-1.5 text-ink-secondary">
                {product.map((item) => (
                  <li key={item.href}>
                    <Link href={item.href as Route} className="underline-draw" data-print="bare">
                      {item.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">{t("landing.footerSite")}</p>
              <ul className="space-y-1.5 text-ink-secondary">
                {signedIn ? (
                  <li>
                    <Link href="/app" className="underline-draw" data-print="bare">
                      {t("common.openApp")}
                    </Link>
                  </li>
                ) : (
                  <>
                    <li>
                      <Link href="/commencer" className="underline-draw" data-print="bare">
                        {t("common.start")}
                      </Link>
                    </li>
                    <li>
                      <Link
                        href="/commencer/compte?suite=%2Fapp"
                        className="underline-draw"
                        data-print="bare"
                      >
                        {t("common.signIn")}
                      </Link>
                    </li>
                  </>
                )}
              </ul>
            </div>

            {/* Les pages de fond, liées depuis **chaque** page du site. C'est ce qui les rend
                explorables sans dépendre d'un lien dans un paragraphe, et ce qui donne à
                Google des pages à proposer sous le résultat de la marque. */}
            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">{t("landing.footerRead")}</p>
              <ul className="space-y-1.5 text-ink-secondary">
                {pages.map((page) => (
                  <li key={page.path}>
                    <Link href={page.path} className="underline-draw" data-print="bare">
                      {page.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <p className="eyebrow mb-3 text-ink-tertiary">{t("landing.footerLegal")}</p>
              <ul className="space-y-1.5 text-ink-secondary">
                <li>
                  <Link href={PRIVACY_PATH} className="underline-draw" data-print="bare">
                    {t("common.privacy")}
                  </Link>
                </li>
                <li>
                  <Link href={TERMS_PATH} className="underline-draw" data-print="bare">
                    {t("common.terms")}
                  </Link>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <p className="mt-12 text-[12px] text-ink-tertiary">
          © {new Date().getFullYear()} Micabo
          <span aria-hidden> · </span>
          <Link href={PRIVACY_PATH} className="underline-draw">
            {t("common.privacy")}
          </Link>
          <span aria-hidden> · </span>
          <Link href={TERMS_PATH} className="underline-draw">
            {t("common.terms")}
          </Link>
        </p>
      </div>
    </footer>
  );
}
