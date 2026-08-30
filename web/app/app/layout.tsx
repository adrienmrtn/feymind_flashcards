import { Suspense } from "react";
import { redirect } from "next/navigation";

import { AppChrome } from "@/components/app/AppChrome";
import { DiscountHost } from "@/components/app/DiscountOffer";
import { PaywallHost } from "@/components/app/PaywallFlow";
import { entitlement } from "@micabo/core";

import { canImportNow, ownedCourseCount, readEntitlement } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";
import { currentUser } from "@/lib/data/user";

/**
 * La charpente de l'app : le chrome de micabo OS.
 *
 * Sidebar, en-tête, page. Le compte se reconnaît en bas à gauche.
 *
 * Le nom et le droit d'importer partent **ensemble** : la charpente n'a pas besoin du premier
 * pour attendre le second, et les enchaîner ajoutait un aller-retour à chaque ouverture dure.
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await currentUser();
  if (!user) redirect("/commencer/compte?suite=%2Fapp");

  const [profile, canImport] = await Promise.all([readProfile(), canImportNow()]);

  const userName =
    profile?.display_name?.trim() ||
    (profile?.username ? `@${profile.username}` : user.email?.split("@")[0] || "Compte");
  const userInitial = userName.replace(/^@/, "").charAt(0).toUpperCase() || "M";

  return (
    <AppChrome userName={userName} userInitial={userInitial} canImport={canImport}>
      {children}
      <Suspense fallback={null}>
        <PaywallGate />
      </Suspense>
    </AppChrome>
  );
}

/**
 * Les deux offres, montées une fois pour toute l'app.
 *
 * Le cadeau passe **avant** le paywall ordinaire quand il a quelque chose à
 * dire : deux cartes qui s'ouvrent l'une sur l'autre ne se lisent pas, et celle
 * qui porte un prix réduit est celle qu'on veut voir lue.
 */
async function PaywallGate() {
  const [right, courses] = await Promise.all([readEntitlement(), ownedCourseCount()]);
  const isPaid = entitlement.isPaid(right);
  return (
    <>
      <PaywallHost isPaid={isPaid} />
      <DiscountHost isPaid={isPaid} courseCount={courses} />
    </>
  );
}
