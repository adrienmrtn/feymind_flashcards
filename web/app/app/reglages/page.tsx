import {
  DEFAULT_DAILY_MINUTES,
  DEFAULT_SHEET_LENGTH,
  entitlement,
  isSheetLength,
  sheetLanguage,
} from "@micabo/core";
import Link from "next/link";

import { DeleteAccount } from "@/components/app/DeleteAccount";
import { ExportData } from "@/components/app/ExportData";
import { FeedbackCard } from "@/components/app/FeedbackCard";
import { ProfileSettings } from "@/components/app/ProfileSettings";
import { ReplayOnboarding } from "@/components/app/ReplayOnboarding";
import { ReplayPaywallOnboarding } from "@/components/app/ReplayPaywallOnboarding";
import { ReplayTour } from "@/components/app/ReplayTour";
import { AppearanceSwitcher } from "@/components/appearance/AppearanceSwitcher";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { T } from "@/components/i18n/T";
import { SheetLanguageCard } from "@/components/app/SheetLanguageCard";
import { SignOutButton } from "@/components/app/SignOutButton";
import { SubscriptionCard } from "@/components/app/SubscriptionCard";
import { readEntitlement } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";
import { currentUser } from "@/lib/data/user";
import { canReadInbox } from "@/lib/feedback";

/**
 * Les réglages, en **trois sections** et non dix cartes en vrac.
 *
 * L'écran alignait abonnement, langue de l'interface, apparence, profil, langue des fiches,
 * retours, déconnexion, trois « rejouer », export et suppression - au même niveau, sans
 * ordre, avec deux cartes distinctes portant le mot « langue ». Trouver quoi que ce soit
 * demandait de tout lire.
 *
 * Les trois sections répondent à trois intentions différentes : **ton étude** est ce qui
 * change ce que l'app te sert, **l'app** est son apparence et sa langue, **ton compte** est
 * l'abonnement et les données. Les « rejouer » descendent dans un pli d'aide : ce sont des
 * outils de dépannage, pas des réglages.
 */
export default async function SettingsPage() {
  const [user, profile, right] = await Promise.all([
    currentUser(),
    readProfile(),
    readEntitlement(),
  ]);

  const minutes = profile?.daily_minutes ?? DEFAULT_DAILY_MINUTES;
  const handle = profile?.username ?? "";

  return (
    <>
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">
          <T k="settings.title" />
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          <T k="settings.lead" />
        </p>
      </header>

      <Section titleKey="settings.section.study" hintKey="settings.section.studyHint">
        <div className="min-w-0" data-tour="reglages-toi">
          <ProfileSettings
            initialName={profile?.display_name ?? ""}
            initialUsername={handle}
            initialMinutes={minutes}
            initialLength={
              isSheetLength(profile?.sheet_length) ? profile.sheet_length : DEFAULT_SHEET_LENGTH
            }
            initialSubjects={Array.isArray(profile?.subjects) ? profile.subjects : []}
            initialSchool={profile?.institution_name ?? ""}
            initialSchoolId={profile?.institution_id ?? null}
            initialCountry={profile?.country_code}
          />
        </div>

        <Link
          href={"/app/plan/semaines" as never}
          className="hover-tile flex items-center justify-between gap-4 rounded-group border border-border bg-card px-5 py-4"
        >
          <span className="min-w-0">
            <span className="block text-[15px] font-semibold text-ink">
              <T k="settings.weekly.title" />
            </span>
            <span className="mt-0.5 block text-[13px] text-ink-tertiary">
              <T k="settings.weekly.detail" />
            </span>
          </span>
          <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4 shrink-0 text-ink-tertiary">
            <path
              d="M7 4l6 6-6 6"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
            />
          </svg>
        </Link>
      </Section>

      <Section titleKey="settings.section.app" hintKey="settings.section.appHint">
        <div className="grid min-w-0 items-start gap-4 lg:grid-cols-2">
          <LanguageSwitcher variant="card" />
          <section className="saas-card p-7" data-tour="reglages-langue">
            <SheetLanguageCard
              initial={sheetLanguage(profile?.sheet_language, profile?.country_code)}
              embedded
            />
          </section>
          <div className="lg:col-span-2">
            <AppearanceSwitcher />
          </div>
        </div>
      </Section>

      <Section titleKey="settings.section.account" hintKey="settings.section.accountHint">
        <div className="grid min-w-0 items-start gap-4 lg:grid-cols-2">
          <SubscriptionCard
            paid={entitlement.isPaid(right)}
            store={right.store ?? null}
            periodType={right.periodType ?? null}
            expiresAt={right.expiresAt ? right.expiresAt.toISOString() : null}
            willRenew={Boolean(right.willRenew)}
            productId={right.productId ?? null}
          />
          <FeedbackCard />
          <ExportData />
          <DeleteAccount email={user?.email ?? ""} />
        </div>

        <section className="saas-card overflow-hidden">
          <SignOutButton />
        </section>
      </Section>

      <details className="rounded-group border border-border bg-card">
        <summary className="cursor-pointer list-none px-5 py-4 text-[14px] font-medium text-ink-secondary">
          <T k="settings.help.title" />
        </summary>
        <div className="border-t border-hairline">
          <ReplayTour />
          <div className="border-t border-hairline">
            <ReplayOnboarding />
          </div>
          <div className="border-t border-hairline">
            <ReplayPaywallOnboarding />
          </div>
        </div>
      </details>

      {canReadInbox(user?.email) ? (
        <p className="px-1 text-[13.5px]">
          <Link href={"/app/retours" as never} className="underline-draw font-medium text-ink">
            <T k="app.settings.readFeedback" />
          </Link>
        </p>
      ) : null}
    </>
  );
}

/** Une section de réglages : un titre, une phrase, et ce qu'elle contient. */
function Section({
  titleKey,
  hintKey,
  children,
}: {
  titleKey: string;
  hintKey: string;
  children: React.ReactNode;
}) {
  return (
    <section className="space-y-4">
      <div>
        <h2 className="text-[15px] font-semibold text-ink">
          <T k={titleKey} />
        </h2>
        <p className="mt-0.5 text-[13px] text-muted-foreground">
          <T k={hintKey} />
        </p>
      </div>
      {children}
    </section>
  );
}
