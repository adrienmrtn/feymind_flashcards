import {
  DEFAULT_DAILY_MINUTES,
  DEFAULT_SHEET_LENGTH,
  isSheetLength,
  sheetLanguage,
} from "@micabo/core";

import { DeleteAccount } from "@/components/app/DeleteAccount";
import { ProfileSettings } from "@/components/app/ProfileSettings";
import { ReplayOnboarding } from "@/components/app/ReplayOnboarding";
import { ReplayPaywallOnboarding } from "@/components/app/ReplayPaywallOnboarding";
import { SheetLanguageCard } from "@/components/app/SheetLanguageCard";
import { SignOutButton } from "@/components/app/SignOutButton";
import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * Les réglages, **à part du profil**.
 *
 * Le profil raconte qui l'on est et ce qu'on a révisé. Ici on change le
 * compte : nom, rythme, fiches, langue, session, suppression. Ce qui
 * s'écrivait en bas du profil n'a plus à se cacher sous les statistiques.
 */
export default async function SettingsPage() {
  const supabase = await createClient();
  const user = await currentUser();

  const profile = user
    ? await supabase
        .from("profiles")
        .select(
          "display_name, username, country_code, subjects, institution_name, institution_id, daily_minutes, sheet_length, sheet_language",
        )
        .eq("id", user.id)
        .maybeSingle()
        .then((result) => result.data)
    : null;

  const minutes = profile?.daily_minutes ?? DEFAULT_DAILY_MINUTES;
  const handle = profile?.username ?? "";

  return (
    <div className="mx-auto max-w-[560px]">
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">Réglages</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Ce que tu changes ici suit sur l&apos;iPhone.
        </p>
      </header>

      <div className="mt-5 space-y-4">
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

        <section className="saas-card p-7">
          <SheetLanguageCard
            initial={sheetLanguage(profile?.sheet_language, profile?.country_code)}
            embedded
          />
        </section>

        <section className="saas-card overflow-hidden">
          <SignOutButton />
          <div className="border-t border-hairline">
            <ReplayOnboarding />
          </div>
          <div className="border-t border-hairline">
            <ReplayPaywallOnboarding />
          </div>
        </section>

        <DeleteAccount email={user?.email ?? ""} />
      </div>
    </div>
  );
}
