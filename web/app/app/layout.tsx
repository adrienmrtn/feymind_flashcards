import { Suspense } from "react";
import { redirect } from "next/navigation";

import { AppChrome } from "@/components/app/AppChrome";
import { DiscountHost } from "@/components/app/DiscountOffer";
import { PaywallHost } from "@/components/app/PaywallFlow";
import { TourHost } from "@/components/app/Tour";
import { entitlement } from "@micabo/core";

import { ownedCourseCount, readEntitlement } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";
import { currentUser } from "@/lib/data/user";
import { getTranslator } from "@/lib/i18n/server";
import { PresentmentProvider } from "@/lib/presentment";

/**
 * La charpente de l'app : quatre onglets (Home, Leçons, Examen, Profil), la page, et les
 * offres montées une fois pour toute l'app. Le compte se reconnaît en bas à gauche.
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await currentUser();
  if (!user) redirect("/commencer/compte?suite=%2Fapp");

  const [profile, { t }] = await Promise.all([readProfile(), getTranslator()]);

  const userName =
    profile?.display_name?.trim() ||
    (profile?.username ? `@${profile.username}` : user.email?.split("@")[0] || t("app.auth.accountFallback"));
  const userInitial = userName.replace(/^@/, "").charAt(0).toUpperCase() || "M";

  return (
    <AppChrome userName={userName} userInitial={userInitial}>
      <PresentmentProvider country={profile?.country_code}>
        {children}
        <Suspense fallback={null}>
          <PaywallGate
            tourSeen={profile?.tour_seen ?? []}
            tourSkipped={profile?.tour_skipped ?? false}
          />
        </Suspense>
      </PresentmentProvider>
    </AppChrome>
  );
}

/**
 * Les deux offres et la visite, montées une fois pour toute l'app.
 *
 * Le cadeau passe **avant** le paywall ordinaire quand il a quelque chose à
 * dire : deux cartes qui s'ouvrent l'une sur l'autre ne se lisent pas, et celle
 * qui porte un prix réduit est celle qu'on veut voir lue.
 *
 * La visite guidée vient en dernier, et son ordre de montage compte : son effet
 * lit le drapeau que le cadeau vient de lever, donc il doit passer après lui.
 */
async function PaywallGate({
  tourSeen,
  tourSkipped,
}: {
  tourSeen: readonly string[];
  tourSkipped: boolean;
}) {
  const [right, courses] = await Promise.all([readEntitlement(), ownedCourseCount()]);
  const isPaid = entitlement.isPaid(right);
  return (
    <>
      <PaywallHost isPaid={isPaid} />
      <DiscountHost isPaid={isPaid} courseCount={courses} />
      <TourHost isPaid={isPaid} seen={tourSeen} skipped={tourSkipped} />
    </>
  );
}
