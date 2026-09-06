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
 * Les réglages, **à part du profil**.
 *
 * Le profil raconte qui l'on est et ce qu'on a révisé. Ici on change le
 * compte : abonnement, nom, rythme, fiches, langue, session, suppression.
 * L'abonnement est en tête : c'est ce qu'on vient chercher, et ça ne doit
 * plus se cacher sous le rythme quotidien.
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

      <div className="grid min-w-0 items-start gap-4 lg:grid-cols-2">
        <SubscriptionCard
          paid={entitlement.isPaid(right)}
          store={right.store ?? null}
          periodType={right.periodType ?? null}
          expiresAt={right.expiresAt ? right.expiresAt.toISOString() : null}
          willRenew={Boolean(right.willRenew)}
          productId={right.productId ?? null}
        />

        <LanguageSwitcher variant="card" />

        <AppearanceSwitcher />

        <div className="min-w-0 lg:col-span-2" data-tour="reglages-toi">
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

        <section className="saas-card p-7" data-tour="reglages-langue">
          <SheetLanguageCard
            initial={sheetLanguage(profile?.sheet_language, profile?.country_code)}
            embedded
          />
        </section>

        <FeedbackCard />

        {canReadInbox(user?.email) ? (
          <p className="px-1 text-[13.5px] lg:col-span-2">
            <Link href={"/app/retours" as never} className="underline-draw font-medium text-ink">
              Lire les retours
            </Link>
          </p>
        ) : null}

        <section className="saas-card overflow-hidden">
          <SignOutButton />
          <div className="border-t border-hairline">
            <ReplayTour />
          </div>
          <div className="border-t border-hairline">
            <ReplayOnboarding />
          </div>
          <div className="border-t border-hairline">
            <ReplayPaywallOnboarding />
          </div>
        </section>

        <div className="grid min-w-0 gap-4">
          <ExportData />
          <DeleteAccount email={user?.email ?? ""} />
        </div>
      </div>
    </>
  );
}
