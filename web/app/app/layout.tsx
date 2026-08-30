import { Suspense } from "react";
import { redirect } from "next/navigation";

import { AppChrome } from "@/components/app/AppChrome";
import { PaywallHost } from "@/components/app/PaywallFlow";
import { entitlement } from "@micabo/core";

import { canImportNow, readEntitlement } from "@/lib/data/entitlement";
import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * La charpente de l'app : le chrome de micabo OS.
 *
 * Sidebar, en-tête, page. Le compte se reconnaît en bas à gauche.
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await currentUser();
  if (!user) redirect("/commencer/compte?suite=%2Fapp");

  const supabase = await createClient();
  const { data: profile } = await supabase
    .from("profiles")
    .select("display_name, username")
    .eq("id", user.id)
    .maybeSingle();

  const userName =
    profile?.display_name?.trim() ||
    (profile?.username ? `@${profile.username}` : user.email?.split("@")[0] || "Compte");
  const userInitial = userName.replace(/^@/, "").charAt(0).toUpperCase() || "M";
  const canImport = await canImportNow();

  return (
    <AppChrome userName={userName} userInitial={userInitial} canImport={canImport}>
      {children}
      <Suspense fallback={null}>
        <PaywallGate />
      </Suspense>
    </AppChrome>
  );
}

async function PaywallGate() {
  const right = await readEntitlement();
  return <PaywallHost isPaid={entitlement.isPaid(right)} />;
}
