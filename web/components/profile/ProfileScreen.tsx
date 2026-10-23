"use client";

import { useEffect, useState, useTransition, type ReactNode } from "react";
import Link from "next/link";
import { useRouter, usePathname } from "next/navigation";
import { ChevronRight, Crown, FileText, Gift, Globe, Inbox, Mail, Palette, Shield, Smartphone, Star, Trophy, Users } from "lucide-react";

import { discount, displayUsername, pricing } from "@micabo/core";

import { useAppearance } from "@/components/appearance/AppearanceProvider";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { ProfileDetail, type ProfileDetailProps } from "@/components/profile/ProfileDetail";
import { APP_STORE_LISTING, PLAY_STORE_LISTING, ratingListings, type StorePlatform } from "@/components/profile/stores";
import { manageSubscription } from "@/lib/actions/checkout";
import { setUiLocale } from "@/lib/actions/locale";
import { APPEARANCES, type Appearance } from "@/lib/appearance";
import { readDiscountStart, requestDiscount } from "@/lib/discount";
import { useI18n } from "@/lib/i18n/client";
import { useLocalizedHref } from "@/lib/i18n/href";
import { UI_LOCALES, UI_LOCALE_META, type UiLocale } from "@/lib/i18n/locales";
import { localeSwitchHref } from "@/lib/i18n/paths";
import { FRIENDS_PATH } from "@/lib/lesson/routes";
import { requestPaywall } from "@/lib/paywall";
import { manageLabel, subscriptionDetail, subscriptionHeadline, type SubscriptionView } from "@/lib/subscription-copy";

/** Où l'on écrit, et nos autres apps : les mêmes adresses que `ProfileLinks` côté Swift. */
export const SUPPORT_EMAIL = "team@micabo.app";
export const OTHER_APPS_URL = "https://vikstudios.com";

export interface RankingRow {
  userId: string;
  username: string | null;
  passes: number;
  isMe: boolean;
}

/**
 * **L'onglet Profil.** La carte profil (un appui ouvre toutes les infos et le compte),
 * « Passer en Pro » pour qui n'est pas abonné, le classement de la semaine et les amis, les
 * réglages (langue, thème, nous noter), le support. Jumeau de `ProfileView` + `ProfileSections`.
 */
export function ProfileScreen({
  name,
  identity,
  studies,
  email,
  isPaid,
  subscription,
  ranking,
  friendCount,
  requestCount,
  showInbox,
  detail,
  platform,
}: {
  name: string;
  identity: string | null;
  studies: string | null;
  email: string;
  isPaid: boolean;
  subscription: SubscriptionView;
  ranking: RankingRow[];
  friendCount: number;
  requestCount: number;
  showInbox: boolean;
  detail: ProfileDetailProps;
  /** La boutique de cet appareil, lue sur l'agent par la page : « Nous noter » y mène. */
  platform: StorePlatform;
}) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const ratings = ratingListings(platform);
  const terms = useLocalizedHref("/conditions");
  const privacy = useLocalizedHref("/confidentialite");

  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-6 pb-6">
      <header className="pt-1">
        <h1 className="text-[32px] font-extrabold leading-tight tracking-tight-title text-ink">{t("lesson.tab.profile")}</h1>
      </header>

      <button type="button" onClick={() => setOpen(true)} className="pressable flex items-center gap-3.5 rounded-[24px] bg-surface p-4 text-start shadow-floating" data-tour="profil-carte">
        <span className="numeral flex size-[60px] shrink-0 items-center justify-center rounded-full bg-accent text-[26px] font-extrabold text-on-ink">{name.charAt(0).toUpperCase()}</span>
        <span className="flex min-w-0 flex-1 flex-col gap-0.5">
          <span className="truncate text-[19px] font-extrabold text-ink">{name}</span>
          {identity ? <span className="truncate text-[14px] font-bold text-accent">{identity}</span> : null}
          {studies ? <span className="truncate text-[14px] font-medium text-ink-secondary">{studies}</span> : null}
        </span>
        <ChevronRight aria-hidden="true" className="size-5 shrink-0 text-ink-tertiary" strokeWidth={2.6} />
      </button>

      {isPaid ? (
        <SubscriptionRow view={subscription} />
      ) : (
        <>
          <ProUpgradeCard />
          {discount.isReachable({ isPaid, courseCount: discount.giftAfterCourses }) ? <OfferRow /> : null}
        </>
      )}

      <section className="flex flex-col gap-3">
        {ranking.length >= 2 ? <WeekRankingCard rows={ranking} /> : null}
        <Link href={FRIENDS_PATH} className="pressable flex items-center gap-3.5 rounded-[22px] bg-surface p-3.5 shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
          <span className="flex size-11 items-center justify-center rounded-[14px] bg-accent-soft text-accent">
            <Users aria-hidden="true" className="size-[22px]" strokeWidth={2.4} />
          </span>
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="text-[17px] font-extrabold text-ink">{t("app.profileTab.friends")}</span>
            <span className="truncate text-[14px] font-semibold text-ink-secondary">
              {friendCount === 0 ? t("app.friends.emptyTitle") : t("app.profileTab.friendCount", { count: friendCount })}
              {requestCount > 0 ? ` · ${t("app.profileTab.requests", { count: requestCount })}` : ""}
            </span>
          </span>
          {requestCount > 0 ? <span className="numeral rounded-pill bg-accent px-2 py-0.5 text-[12px] font-extrabold text-on-ink">{requestCount}</span> : null}
          <ChevronRight aria-hidden="true" className="size-5 shrink-0 text-ink-tertiary" strokeWidth={2.6} />
        </Link>
      </section>

      <ProfileGroup title={t("lesson.profile.settings")} tour="profil-reglages">
        <LanguageRow />
        <ThemeRow />
        {ratings.map((rating, index) => (
          <ProfileRow
            key={rating.store}
            icon={<Star aria-hidden="true" className="size-5" strokeWidth={2.4} />}
            title={ratings.length === 1 ? t("lesson.profile.rate") : t(rating.store === "ios" ? "app.profileTab.rateAppStore" : "app.profileTab.ratePlay")}
            href={rating.href}
            external
            last={index === ratings.length - 1}
          />
        ))}
      </ProfileGroup>

      <PhoneApps />

      <ProfileGroup title={t("lesson.profile.support")}>
        <ProfileRow icon={<Mail aria-hidden="true" className="size-5" strokeWidth={2.4} />} title={t("lesson.profile.contact")} href={`mailto:${SUPPORT_EMAIL}?subject=Micabo`} external />
        <ProfileRow icon={<Smartphone aria-hidden="true" className="size-5" strokeWidth={2.4} />} title={t("lesson.profile.otherApps")} href={OTHER_APPS_URL} external />
        <ProfileRow icon={<FileText aria-hidden="true" className="size-5" strokeWidth={2.4} />} title={t("lesson.profile.terms")} href={terms} />
        <ProfileRow icon={<Shield aria-hidden="true" className="size-5" strokeWidth={2.4} />} title={t("lesson.profile.privacy")} href={privacy} last={!showInbox} />
        {showInbox ? <ProfileRow icon={<Inbox aria-hidden="true" className="size-5" strokeWidth={2.4} />} title={t("app.profileTab.inbox")} href="/app/retours" last /> : null}
      </ProfileGroup>

      {open ? <ProfileDetail {...detail} email={email} onClose={() => setOpen(false)} /> : null}
    </div>
  );
}

/** « Passer en Pro » : la carte d'encre, pour qui n'est pas abonné. */
function ProUpgradeCard() {
  const { t } = useI18n();
  return (
    <button type="button" onClick={() => requestPaywall("upgrade")} className="pressable flex items-center gap-3.5 rounded-[24px] bg-ink p-4 text-start">
      <span className="flex size-11 shrink-0 items-center justify-center rounded-[14px] bg-white/10">
        <Crown aria-hidden="true" className="size-6 text-caution-vivid" strokeWidth={2.4} />
      </span>
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="text-[17px] font-extrabold text-on-ink">{t("lesson.profile.goPro")}</span>
        <span className="text-[14px] font-medium text-on-ink/75">{t("lesson.profile.goProBody")}</span>
      </span>
      <ChevronRight aria-hidden="true" className="size-5 shrink-0 text-on-ink/60" strokeWidth={2.6} />
    </button>
  );
}

/**
 * **L'offre de bienvenue, toujours atteignable.** La rangée des Réglages de l'iPhone
 * (`DiscountOffer.isReachable`) : le cadeau surgit une fois, elle reste. Elle ouvre le tarif
 * directement — on ne fait pas déballer deux fois — et dit le temps qui reste quand une
 * fenêtre court.
 */
function OfferRow() {
  const { t } = useI18n();
  const [left, setLeft] = useState(0);

  useEffect(() => {
    function tick() {
      const startedAt = readDiscountStart();
      setLeft(startedAt === null ? 0 : discount.windowRemaining(startedAt, Date.now()));
    }
    tick();
    const timer = window.setInterval(tick, 1000);
    return () => window.clearInterval(timer);
  }, []);

  const percent = t("app.profileTab.offerHelp", { percent: pricing.discountSavingsPercent() });
  return (
    <button type="button" onClick={() => requestDiscount("paywall")} className="pressable -mt-3 flex items-center gap-3.5 rounded-[22px] bg-surface p-3.5 text-start shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
      <span className="flex size-11 shrink-0 items-center justify-center rounded-[14px] bg-offer-wash text-offer-sky">
        <Gift aria-hidden="true" className="size-[22px]" strokeWidth={2.4} />
      </span>
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="text-[17px] font-extrabold text-ink">{t("app.profileTab.offer")}</span>
        <span className="truncate text-[14px] font-semibold text-ink-secondary">
          {percent}
          {left > 0 ? <span className="numeral tabular-nums"> · {discount.countdown(left)}</span> : null}
        </span>
      </span>
      <ChevronRight aria-hidden="true" className="size-5 shrink-0 text-ink-tertiary" strokeWidth={2.6} />
    </button>
  );
}

/**
 * **Micabo sur ton téléphone** : les deux fiches, App Store et Google Play. Le même compte
 * ouvre les deux apps et le site ; ce bloc le dit à qui ne révise encore que sur un écran.
 */
function PhoneApps() {
  const { t } = useI18n();
  return (
    <section className="flex flex-col gap-3 rounded-[22px] bg-surface p-4 shadow-[inset_0_0_0_1.5px_var(--color-stroke)]" aria-labelledby="profil-telephone">
      <div className="flex items-center gap-3">
        <span className="flex size-10 shrink-0 items-center justify-center rounded-[12px] bg-accent-soft text-accent">
          <Smartphone aria-hidden="true" className="size-5" strokeWidth={2.4} />
        </span>
        <span className="flex min-w-0 flex-col">
          <h2 id="profil-telephone" className="text-[16.5px] font-extrabold text-ink">
            {t("app.profileTab.phoneTitle")}
          </h2>
          <span className="text-[13.5px] font-medium text-ink-secondary">{t("app.profileTab.phoneBody")}</span>
        </span>
      </div>
      <div className="flex flex-wrap gap-2.5">
        <a href={APP_STORE_LISTING} target="_blank" rel="noreferrer" className="pressable flex items-center gap-2 rounded-pill bg-ink px-4 py-2.5 text-[14px] font-extrabold text-on-ink">
          <AppleGlyph />
          {t("app.profileTab.appStore")}
        </a>
        <a href={PLAY_STORE_LISTING} target="_blank" rel="noreferrer" className="pressable flex items-center gap-2 rounded-pill bg-ink px-4 py-2.5 text-[14px] font-extrabold text-on-ink">
          <PlayGlyph />
          {t("app.profileTab.googlePlay")}
        </a>
      </div>
    </section>
  );
}

function AppleGlyph() {
  return (
    <svg aria-hidden viewBox="0 0 24 24" className="size-[18px]" fill="currentColor">
      <path d="M16.4 12.6c0-2.4 2-3.6 2.1-3.7-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.8-1.6 0-3.1 1-4 2.4-1.7 3-.4 7.3 1.2 9.7.8 1.2 1.8 2.5 3 2.4 1.2 0 1.7-.8 3.1-.8 1.5 0 1.9.8 3.2.8 1.3 0 2.1-1.2 2.9-2.4.9-1.4 1.3-2.7 1.3-2.8 0 0-2.4-1-2.4-3.8zM14 5.4c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1 .1 2.1-.6 2.8-1.4z" />
    </svg>
  );
}

function PlayGlyph() {
  return (
    <svg aria-hidden viewBox="0 0 24 24" className="size-[18px]" fill="currentColor">
      <path d="M4.2 2.6c-.3.3-.4.7-.4 1.2v16.4c0 .5.1.9.4 1.2l.1.1L13.5 12v-.2L4.3 2.5l-.1.1zM16.6 15.1l-3.1-3.1v-.2l3.1-3.1.1.1 3.7 2.1c1 .6 1 1.6 0 2.2l-3.7 2.1-.1-.1zM16.7 15l-3.2-3.1-9.3 9.3c.4.4.9.4 1.6.1l10.9-6.3M16.7 8.8 5.8 2.5c-.7-.4-1.2-.3-1.6.1l9.3 9.3 3.2-3.1z" />
    </svg>
  );
}

/** L'abonnement, pour qui l'a : d'où il vient, jusqu'à quand, et où le gérer. */
function SubscriptionRow({ view }: { view: SubscriptionView }) {
  const { t, locale } = useI18n();
  const [pending, startTransition] = useTransition();
  const [failure, setFailure] = useState<string | null>(null);
  const action = manageLabel(t, view);

  function manage() {
    if (!action || pending) return;
    setFailure(null);
    startTransition(async () => {
      const result = await manageSubscription();
      if (result.status === "redirect" && result.url) {
        window.location.href = result.url;
        return;
      }
      setFailure(result.message ?? t("app.subscription.portalError"));
    });
  }

  return (
    <div className="flex flex-wrap items-center gap-x-3.5 gap-y-3 rounded-[24px] bg-surface p-4 shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
      <MicaboIcon id="couronne" size={44} />
      <div className="flex min-w-0 flex-1 basis-[12rem] flex-col gap-0.5">
        <span className="text-[17px] font-extrabold text-ink">{subscriptionHeadline(t, view)}</span>
        <span className="text-[13.5px] font-medium text-ink-secondary">{subscriptionDetail(t, locale, view)}</span>
        {failure ? (
          <span role="alert" className="text-[13px] font-bold text-wrong-ink">
            {failure}
          </span>
        ) : null}
      </div>
      {action ? (
        <button type="button" onClick={manage} disabled={pending} className="pressable shrink-0 rounded-pill bg-surface-muted px-3.5 py-2 text-[13.5px] font-extrabold text-ink disabled:opacity-50">
          {pending ? t("app.subscription.opening") : action}
        </button>
      ) : null}
    </div>
  );
}

/** Le classement de la semaine, entre amis : qui a passé le plus de cartes. */
function WeekRankingCard({ rows }: { rows: RankingRow[] }) {
  const { t } = useI18n();
  return (
    <section className="flex flex-col gap-3 rounded-[22px] bg-surface p-4 shadow-[inset_0_0_0_1.5px_var(--color-stroke)]" aria-label={t("app.profileTab.ranking")}>
      <h2 className="flex items-center gap-2 text-[16px] font-extrabold text-ink">
        <Trophy aria-hidden="true" className="size-[18px] text-caution-vivid" strokeWidth={2.4} />
        {t("app.profileTab.ranking")}
      </h2>
      <ol className="flex flex-col gap-1.5">
        {rows.slice(0, 8).map((row, index) => (
          <li key={row.userId} className={`flex items-center gap-3 rounded-[14px] px-3 py-2 ${row.isMe ? "bg-accent-soft" : ""}`}>
            <span className={`numeral w-6 text-[15px] font-extrabold ${index === 0 ? "text-caution-ink" : "text-ink-tertiary"}`}>{index + 1}</span>
            <span className={`flex-1 truncate text-[15px] font-bold ${row.isMe ? "text-accent" : "text-ink"}`}>{row.isMe ? t("app.profileTab.you") : row.username ? displayUsername(row.username) : t("app.friends.someone")}</span>
            <span className="numeral text-[14px] font-bold text-ink-secondary">{t("app.profileTab.passes", { count: row.passes })}</span>
          </li>
        ))}
      </ol>
    </section>
  );
}

/** Un groupe de rangées, sous son petit titre. */
function ProfileGroup({ title, tour, children }: { title: string; tour?: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-2" data-tour={tour}>
      <h2 className="ps-1 text-[12px] font-extrabold uppercase tracking-caps text-ink-secondary">{title}</h2>
      <div className="overflow-hidden rounded-[22px] bg-surface shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">{children}</div>
    </section>
  );
}

function RowShell({ icon, title, value, last, children }: { icon: ReactNode; title: string; value?: ReactNode; last?: boolean; children?: ReactNode }) {
  return (
    <div className={`flex min-h-[60px] items-center gap-3.5 px-3.5 py-2.5 ${last ? "" : "border-b border-hairline"}`}>
      <span className="flex size-9 shrink-0 items-center justify-center rounded-[12px] bg-surface-muted text-ink">{icon}</span>
      <span className="flex-1 truncate text-[16.5px] font-bold text-ink">{title}</span>
      {value ? <span className="truncate text-[14.5px] font-semibold text-ink-secondary">{value}</span> : null}
      {children}
    </div>
  );
}

/** Une rangée qui mène quelque part : son icône, son nom, un chevron. */
function ProfileRow({ icon, title, href, external, last }: { icon: ReactNode; title: string; href: string; external?: boolean; last?: boolean }) {
  const content = (
    <RowShell icon={icon} title={title} last={last}>
      <ChevronRight aria-hidden="true" className="size-[18px] shrink-0 text-ink-tertiary" strokeWidth={2.6} />
    </RowShell>
  );
  const className = "pressable block hover:bg-surface-muted/60";
  return external ? (
    <a href={href} target={href.startsWith("mailto:") ? undefined : "_blank"} rel="noreferrer" className={className}>
      {content}
    </a>
  ) : (
    <Link href={href as never} className={className}>
      {content}
    </Link>
  );
}

/** Changer la langue : une liste, le nom de chaque langue dans sa langue. */
function LanguageRow() {
  const { locale, t, pick } = useI18n();
  const router = useRouter();
  const pathname = usePathname();
  const [pending, startTransition] = useTransition();

  function choose(next: UiLocale) {
    if (next === locale || pending) return;
    pick(next);
    startTransition(async () => {
      await setUiLocale(next);
      const target = localeSwitchHref(pathname, next);
      if (target) {
        window.location.assign(target);
        return;
      }
      router.refresh();
    });
  }

  return (
    <RowShell icon={<Globe aria-hidden="true" className="size-5" strokeWidth={2.4} />} title={t("lesson.profile.language")}>
      <select value={locale} onChange={(event) => choose(event.target.value as UiLocale)} aria-label={t("lesson.profile.language")} className="rounded-pill bg-surface-muted px-3 py-1.5 text-[14px] font-bold text-ink outline-none focus-visible:shadow-[0_0_0_2px_var(--color-accent)]">
        {UI_LOCALES.map((code) => (
          <option key={code} value={code}>
            {UI_LOCALE_META[code].flag} {UI_LOCALE_META[code].native}
          </option>
        ))}
      </select>
    </RowShell>
  );
}

const THEME_KEY: Record<Appearance, string> = { day: "settings.appearanceDay", night: "settings.appearanceNight", twilight: "settings.appearanceTwilight" };

/** Changer le thème : clair, sombre, crépuscule. Reste sur cet appareil. */
function ThemeRow() {
  const { t } = useI18n();
  const { appearance, setAppearance } = useAppearance();
  return (
    <RowShell icon={<Palette aria-hidden="true" className="size-5" strokeWidth={2.4} />} title={t("lesson.profile.theme")}>
      <select value={appearance} onChange={(event) => setAppearance(event.target.value as Appearance)} aria-label={t("lesson.profile.theme")} className="rounded-pill bg-surface-muted px-3 py-1.5 text-[14px] font-bold text-ink outline-none focus-visible:shadow-[0_0_0_2px_var(--color-accent)]">
        {APPEARANCES.map((value) => (
          <option key={value} value={value}>
            {t(THEME_KEY[value])}
          </option>
        ))}
      </select>
    </RowShell>
  );
}
