import {
  DEFAULT_DAILY_MINUTES,
  DEFAULT_SHEET_LENGTH,
  entitlement,
  isSheetLength,
  sheetLanguage,
} from "@micabo/core";

import { DeleteAccount } from "@/components/app/DeleteAccount";
import { ExportData } from "@/components/app/ExportData";
import { FeedbackCard } from "@/components/app/FeedbackCard";
import { ProfileSettings } from "@/components/app/ProfileSettings";
import { ReplayOnboarding } from "@/components/app/ReplayOnboarding";
import { ReplayPaywallOnboarding } from "@/components/app/ReplayPaywallOnboarding";
import { ReplayTour } from "@/components/app/ReplayTour";
import { SheetLanguageCard } from "@/components/app/SheetLanguageCard";
import { SignOutButton } from "@/components/app/SignOutButton";
import { SubscriptionCard } from "@/components/app/SubscriptionCard";
import { readEntitlement } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";
import { currentUser } from "@/lib/data/user";

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
    <div className="mx-auto max-w-[560px]">
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">Réglages</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Abonnement, rythme, fiches. Ce que tu changes ici suit sur l&apos;iPhone.
        </p>
      </header>

      <div className="mt-5 space-y-4">
        <SubscriptionCard
          paid={entitlement.isPaid(right)}
          store={right.store ?? null}
          periodType={right.periodType ?? null}
          expiresAt={right.expiresAt ? right.expiresAt.toISOString() : null}
          willRenew={Boolean(right.willRenew)}
          productId={right.productId ?? null}
        />

        <div data-tour="reglages-toi">
          <ProfileSettings
            heading="Toi"
            initialName={profile?.display_name ?? ""}
            initialUsername={handle}
            initialMinutes={minutes}
            initialLength={
              isSheetLength(profile?.sheet_length) ? profile.sheet_length : DEFAULT_SHEET_LENGTH
            }
            initialSubjects={Array.isArray(profile?.subjects) ? profile.subjects : []}
            initialSchool={profile?.institution_name ?? ""}
            initialSchoolId={profile?.institution_id ?? null}
          />
        </div>

        <section className="saas-card p-7" data-tour="reglages-langue">
          <SheetLanguageCard
            initial={sheetLanguage(profile?.sheet_language, profile?.country_code)}
            embedded
          />
        </section>

        <FeedbackCard />

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

        <ExportData />

        <DeleteAccount email={user?.email ?? ""} />
      </div>
    </div>
  );
}
