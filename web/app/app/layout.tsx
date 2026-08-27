import { Suspense } from "react";
import Link from "next/link";
import { redirect } from "next/navigation";

import { AppNav } from "@/components/app/AppNav";
import { PageEnter } from "@/components/app/PageEnter";
import { PaywallHost } from "@/components/app/PaywallFlow";
import { entitlement } from "@micabo/core";

import { readEntitlement } from "@/lib/data/entitlement";
import { currentUser } from "@/lib/data/user";

/**
 * La charpente de l'app web : **une barre latérale, pas trois onglets.**
 *
 * L'iPhone a trois onglets avec Réviser au milieu, parce que c'est là que le pouce tombe et qu'on
 * sort son téléphone dans une file d'attente. On s'assied devant un écran pour **travailler** : la
 * navigation part donc sur le côté, elle est toujours visible, et **Accueil est l'écran
 * d'ouverture** - examen, cartes du jour, derniers cours. L'étagère vit sous Cours.
 *
 * La porte est fermée ici et pas dans chaque page : une redirection oubliée sur un seul écran est
 * une fuite, et le cloisonnement de Postgres rattraperait les données mais pas la page vide qu'on
 * aurait montrée.
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const user = await currentUser();
  if (!user) redirect("/commencer/compte?suite=%2Fapp");

  return (
    <div className="min-h-svh bg-canvas lg:flex">
      <AppNav />

      <main className="min-w-0 flex-1 pb-32 lg:pb-0">
        <div className="mx-auto max-w-[860px] px-screen py-8 lg:py-12">
          <PageEnter>{children}</PageEnter>
        </div>
      </main>

      <Suspense fallback={null}>
        <PaywallGate />
      </Suspense>
    </div>
  );
}

async function PaywallGate() {
  const right = await readEntitlement();
  return <PaywallHost isPaid={entitlement.isPaid(right)} />;
}

/** Le pied de page de l'app, pour les liens qui n'ont pas leur place dans la navigation. */
export function AppFooter() {
  return (
    <p className="mt-16 text-[12.5px] text-ink-tertiary" data-print="hide">
      <Link href="/" className="underline-draw">
        Le site
      </Link>
    </p>
  );
}
