"use client";

import type { Route } from "next";
import Link from "next/link";
import { BookOpen, CalendarSync, Repeat, TrendingUp, Zap } from "lucide-react";

import { REVIEW_RATINGS, type ReviewRating } from "@micabo/core";

import { AppearanceSwitcher } from "@/components/appearance/AppearanceSwitcher";
import { BrandLockup, BrandMark } from "@/components/BrandMark";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";
import { copyExamCountdown, reviewRatingLabel, type Translator } from "@/lib/i18n/copy";
import { localizedHref } from "@/lib/i18n/paths";
import { APP_STORE_URL, FULL_SITE_PARAM } from "@/lib/iphone";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";
import { SITE_PAGES, siteNavKey } from "@/lib/site-pages";

/**
 * **L'accueil, vu depuis un iPhone.**
 *
 * Ce n'est pas la vitrine rétrécie : c'est l'autre page. Un visiteur qui arrive sur
 * `micabo.app` avec un iPhone dans la main a déjà l'appareil sur lequel Micabo est le
 * meilleur, et lui dérouler neuf sections pour finir par un badge en bas de page serait lui
 * faire lire la démonstration d'une chose qu'il tient déjà. Donc : l'icône, une phrase, le
 * bouton, et l'écran qu'il ouvrira.
 *
 * La page dit **pourquoi** elle bascule plutôt que de basculer en silence — « le site est
 * fait pour le bureau » est la thèse de `docs/web.md`, pas une excuse inventée après coup.
 * Et elle laisse une porte : `?web` rend la vitrine complète, parce qu'un téléphone n'est
 * pas une raison de refuser une page à quelqu'un qui la demande.
 *
 * Aucun shader ici, contrairement au bandeau du bureau : la lueur est un radial CSS. Un
 * contexte WebGL coûte de la batterie et un temps d'affichage sur un appareil qu'on tient à
 * la main, et cette page a exactement un travail — mener au bouton.
 */
export function IphoneLanding({ signedIn = false }: { signedIn?: boolean }) {
  const { t, locale } = useI18n();
  const home = localizedHref(locale, "/");

  return (
    <>
      {/* La barre ne porte ni sections ni bouton : la page entière est le bouton. Restent la
          marque, la langue et l'apparence — trois réglages, pas une navigation. */}
      <header className="sticky top-0 z-20 border-b border-hairline-on-canvas bg-canvas/80 backdrop-blur-md">
        <div className="mx-auto flex h-14 max-w-page items-center justify-between gap-3 px-screen">
          <BrandLockup
            href={home}
            size={28}
            className="shrink-0 text-ink"
            wordClassName="text-[15px] font-bold tracking-tight text-ink"
          />
          <div className="flex min-w-0 items-center justify-end gap-1.5">
            <AppearanceSwitcher variant="compact" />
            <LanguageSwitcher />
          </div>
        </div>
      </header>

      <main id="contenu" className="relative overflow-clip">
        <Glow />

        <div className="relative mx-auto max-w-[620px] px-screen pb-4 pt-10 text-center">
          {/* L'icône de l'app, en grand. C'est le même fichier que le favicon et que la
              vignette de l'App Store : le visiteur reconnaîtra la tuile qu'il doit chercher
              sur son écran d'accueil une fois l'installation finie. */}
          <div className="rise flex justify-center" style={{ animationDelay: "40ms" }}>
            {/* L'ombre est sur l'enveloppe, pas sur l'image : `brand-mark` détoure l'icône
                au `clip-path`, et ce qui est détouré ne porte plus d'ombre. */}
            <span
              className="inline-flex rounded-[24px]"
              style={{ boxShadow: "0 20px 44px -20px oklch(0 0 0 / 0.5)" }}
            >
              <BrandMark size={88} />
            </span>
          </div>

          <p className="rise eyebrow mt-6 text-ink-tertiary" style={{ animationDelay: "80ms" }}>
            {t("landing.iosEyebrow")}
          </p>

          <h1
            className="rise mx-auto mt-2.5 max-w-[16ch] text-balance text-[38px] font-bold leading-[1.04] tracking-display text-ink sm:text-[52px]"
            style={{ animationDelay: "120ms" }}
          >
            {t("landing.iosTitleBefore")}{" "}
            <span className="relative whitespace-nowrap text-accent">
              {t("landing.iosTitleAccent")}
              <svg
                aria-hidden
                viewBox="0 0 200 12"
                preserveAspectRatio="none"
                className="absolute -bottom-1.5 left-0 h-2.5 w-full text-accent-vivid"
              >
                <path
                  d="M2 8c40-5 90-7 196-4"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="4"
                  strokeLinecap="round"
                />
              </svg>
            </span>
            .
          </h1>

          <p
            className="rise mx-auto mt-6 max-w-reading text-[16px] leading-relaxed text-ink-secondary sm:text-[17px]"
            style={{ animationDelay: "160ms" }}
          >
            {t("landing.iosSubtitle")}
          </p>

          <div className="rise mt-8" style={{ animationDelay: "200ms" }}>
            <Button
              size="xl"
              className="h-14 w-full max-w-[360px] px-7 text-[16px] sm:h-14 sm:text-[16px]"
              render={<a href={APP_STORE_URL} />}
            >
              <AppleMark />
              {t("landing.iosCta")}
            </Button>
            <p className="mx-auto mt-3.5 max-w-[34ch] text-[13px] leading-relaxed text-ink-tertiary">
              {t("landing.iosCtaNote")}
            </p>
          </div>
        </div>

        {/* L'écran et les trois raisons. Côte à côte dès qu'il y a la largeur — un iPhone
            couché en fait 900, et une colonne unique y laisserait deux marges vides. */}
        <div className="relative mx-auto mt-10 grid max-w-page items-center gap-12 px-screen sm:mt-14 sm:grid-cols-[minmax(0,320px)_minmax(0,1fr)] sm:gap-14 sm:px-8 lg:gap-20">
          <div className="rise" style={{ animationDelay: "260ms" }}>
            <PhoneFrame />
            <p className="mt-5 text-center text-[13px] text-ink-tertiary">
              {t("landing.iosScreenCaption")}
            </p>
          </div>

          <ul className="rise space-y-7 text-left" style={{ animationDelay: "320ms" }}>
            {points(t).map((point) => (
              <li key={point.title} className="flex gap-4">
                <span className="mt-0.5 flex size-10 shrink-0 items-center justify-center rounded-tile bg-accent-soft text-accent">
                  <point.icon className="size-5" strokeWidth={1.8} aria-hidden />
                </span>
                <div className="min-w-0">
                  <h2 className="text-[16.5px] font-semibold leading-snug text-ink">
                    {point.title}
                  </h2>
                  <p className="mt-1.5 text-[14.5px] leading-relaxed text-ink-secondary">
                    {point.body}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        </div>

        {/* La porte de sortie. Discrète, mais elle existe : quelqu'un qui veut le site sur son
            téléphone y a droit, et quelqu'un qui a déjà un compte veut son tableau de bord. */}
        <p className="relative mt-14 text-center">
          <Link
            href={(signedIn ? "/app" : `${home}?${FULL_SITE_PARAM}=1`) as Route}
            className="underline-draw text-[14px] font-medium text-ink-secondary"
          >
            {signedIn ? t("common.openApp") : t("landing.iosFullSite")}
          </Link>
        </p>
      </main>

      <SlimFooter />
    </>
  );
}

/**
 * La lueur, en radial pur.
 *
 * Le bandeau du bureau pose un maillage WebGL ; ici il n'y a rien à animer et tout à
 * économiser. Deux ellipses, l'accent au-dessus de l'icône, et le masque qui les éteint
 * avant le bord.
 */
function Glow() {
  return (
    <div
      aria-hidden
      data-print="hide"
      className="pointer-events-none absolute inset-x-[-30%] -top-52 h-[520px]"
      style={{
        background:
          "radial-gradient(ellipse 42% 46% at 50% 58%, color-mix(in oklch, var(--color-accent-vivid) 26%, transparent), transparent 70%)",
      }}
    />
  );
}

/** Le logo d'Apple, posé sur le bouton qui mène à l'App Store. */
function AppleMark() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden className="size-5 opacity-100" fill="currentColor">
      <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
    </svg>
  );
}

function points(t: Translator) {
  return [
    { icon: BookOpen, title: t("landing.iosPoint1Title"), body: t("landing.iosPoint1Body") },
    { icon: Zap, title: t("landing.iosPoint2Title"), body: t("landing.iosPoint2Body") },
    { icon: CalendarSync, title: t("landing.iosPoint3Title"), body: t("landing.iosPoint3Body") },
  ];
}

/**
 * **Le cadre, et l'écran de révision dedans.**
 *
 * La carte est montrée **retournée**, verso compris. Un recto seul demande au visiteur de
 * croire qu'une réponse existe derrière ; la réponse écrite lui montre ce que Micabo tire
 * d'un cours, et c'est le seul argument de la page après le bouton.
 *
 * Le graphite du châssis ne vient pas de la palette et ne change pas avec l'apparence : un
 * téléphone est un objet, pas une surface de l'interface, et une bordure qui s'éclaircit la
 * nuit se lirait comme un cadre blanc autour de l'écran. Ce qui le détache du fond n'est donc
 * pas sa couleur mais **le filet clair sur sa tranche** — l'ombre portée, elle, ne se voit que
 * de jour, et la nuit un téléphone posé sur du noir ne se lirait plus que par ce reflet.
 */
function PhoneFrame() {
  const { t } = useI18n();

  return (
    <div
      role="img"
      aria-label={t("landing.iosPhoneAria")}
      className="mx-auto w-full max-w-[320px] rounded-[46px] bg-[#25272e] p-[11px]"
      style={{
        boxShadow:
          "inset 0 0 0 1px oklch(1 0 0 / 0.14), 0 30px 60px -24px oklch(0 0 0 / 0.45), 0 0 0 1px oklch(0 0 0 / 0.08)",
      }}
    >
      <div className="relative overflow-hidden rounded-[36px] bg-canvas">
        {/* L'île, à la bonne place : c'est elle qui fait lire « iPhone » plutôt que
            « rectangle arrondi ». */}
        <div className="flex h-11 items-center justify-center">
          <span className="h-[26px] w-[86px] rounded-pill bg-[#22242a]" />
        </div>

        <div className="space-y-3 px-3.5 pb-3">
          <div className="flex items-center justify-between gap-2">
            <p className="truncate text-[13.5px] font-semibold text-ink">{t("landing.appExam1")}</p>
            <span className="numeral shrink-0 rounded-pill bg-caution-soft px-2 py-0.5 text-[11px] font-semibold text-caution">
              {copyExamCountdown(t, 5)}
            </span>
          </div>

          <div>
            <div className="flex items-baseline justify-between text-[10.5px] text-ink-tertiary">
              <span className="numeral">12 / 48</span>
              <span className="numeral">25 %</span>
            </div>
            <div className="mt-1 h-1 overflow-hidden rounded-full bg-progress-track">
              <div className="h-full w-1/4 rounded-full bg-progress" />
            </div>
          </div>

          <div className="rounded-[18px] bg-surface p-3.5 text-left shadow-paper">
            <span className="inline-flex rounded-pill bg-surface-muted px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-caps text-ink-tertiary">
              {t("demo.card1Kind")}
            </span>
            <p className="mt-2 text-[13px] font-medium leading-snug text-ink">
              {t("landing.appCard1Front")}
            </p>
            <p className="mt-2.5 border-t border-hairline pt-2.5 text-[11.5px] leading-relaxed text-ink-secondary">
              {t("landing.appCard1Back")}
            </p>
          </div>

          <div className="grid grid-cols-4 gap-1.5">
            {REVIEW_RATINGS.map((rating) => (
              <span
                key={rating}
                className={`rounded-[10px] px-1 py-2 text-center ${ratingTone(rating)}`}
              >
                <span className="block truncate text-[10.5px] font-semibold">
                  {reviewRatingLabel(t, rating)}
                </span>
                <span className="numeral mt-0.5 block text-[9.5px] opacity-80">
                  {t(INTERVAL_KEYS[rating])}
                </span>
              </span>
            ))}
          </div>
        </div>

        {/* Les trois onglets de l'app, Réviser au milieu et plein — c'est la règle de la
            barre d'onglets iOS, et c'est ce que le visiteur retrouvera. */}
        <div className="border-t border-hairline bg-surface px-2 pb-2 pt-2">
          <div className="flex items-center justify-around">
            <Tab icon={BookOpen} label={t("nav.courses")} />
            <Tab icon={Repeat} label={t("nav.review")} active />
            <Tab icon={TrendingUp} label={t("nav.progress")} />
          </div>
          {/* La barre d'accueil. Trois pixels qui coûtent zéro et qui achèvent de faire lire
              « iPhone » plutôt que « écran rectangulaire ». */}
          <span className="mx-auto mb-1.5 mt-2.5 block h-[4px] w-[108px] rounded-full bg-ink/25" />
        </div>
      </div>
    </div>
  );
}

function Tab({
  icon: Icon,
  label,
  active = false,
}: {
  icon: typeof BookOpen;
  label: string;
  active?: boolean;
}) {
  return (
    <span
      className={`flex min-w-0 flex-col items-center gap-0.5 ${active ? "text-accent" : "text-ink-tertiary"}`}
    >
      <Icon className="size-[18px]" strokeWidth={active ? 2.2 : 1.7} aria-hidden />
      <span className="truncate text-[9.5px] font-medium">{label}</span>
    </span>
  );
}

/** Les intervalles d'une carte sous examen actif : courts, rien ne repart au-delà du jour J. */
const INTERVAL_KEYS: Record<ReviewRating, string> = {
  1: "landing.appIntervalAgain",
  2: "landing.appIntervalHard",
  3: "landing.appIntervalGood",
  4: "landing.appIntervalEasy",
};

function ratingTone(rating: ReviewRating): string {
  if (rating === 1) return "bg-negative-soft text-negative";
  if (rating === 2) return "bg-caution-soft text-caution";
  if (rating === 3) return "bg-accent-soft text-accent";
  return "bg-positive-soft text-positive";
}

/**
 * Le pied de page de cette page-là, et pas celui de la vitrine.
 *
 * Le pied complet renvoie aux sections de l'accueil (`/#comment-ca-marche`) — des ancres qui
 * ne mènent nulle part ici, puisque l'accueil n'est plus la vitrine. Restent les pages qui
 * existent vraiment, et le cadre légal qu'Apple demande de toute façon.
 */
function SlimFooter() {
  const { t, locale } = useI18n();
  const pages = SITE_PAGES.map((page) => ({
    path: localizedHref(locale, page.path),
    label: t(siteNavKey(page.id)),
  }));

  return (
    <footer className="mt-16 border-t border-hairline-on-canvas" data-print="hide">
      <div className="mx-auto max-w-page px-screen py-10">
        <ul className="flex flex-wrap justify-center gap-x-6 gap-y-2.5 text-[13.5px] text-ink-secondary">
          {pages.map((page) => (
            <li key={page.path}>
              <Link href={page.path} className="underline-draw">
                {page.label}
              </Link>
            </li>
          ))}
          <li>
            <Link href={localizedHref(locale, PRIVACY_PATH)} className="underline-draw">
              {t("common.privacy")}
            </Link>
          </li>
          <li>
            <Link href={localizedHref(locale, TERMS_PATH)} className="underline-draw">
              {t("common.terms")}
            </Link>
          </li>
        </ul>
        <p className="mt-7 text-center text-[12px] text-ink-tertiary">
          © {new Date().getFullYear()} Micabo
        </p>
      </div>
    </footer>
  );
}
