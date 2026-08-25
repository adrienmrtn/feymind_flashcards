import Link from "next/link";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

import { AppNav } from "@/components/app/AppNav";

/**
 * La charpente de l'app web : **une barre latérale, pas trois onglets.**
 *
 * L'iPhone a trois onglets avec Réviser au milieu, parce que c'est là que le pouce tombe et qu'on
 * sort son téléphone dans une file d'attente. On s'assied devant un écran pour **travailler** : la
 * navigation part donc sur le côté, elle est toujours visible, et **Cours est l'écran d'ouverture**.
 * Un bureau s'ouvre sur ce qu'on a posé dessus.
 *
 * La porte est fermée ici et pas dans chaque page : une redirection oubliée sur un seul écran est
 * une fuite, et le cloisonnement de Postgres rattraperait les données mais pas la page vide qu'on
 * aurait montrée.
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/commencer/compte?suite=%2Fapp");

  return (
    <div className="min-h-svh bg-canvas lg:flex">
      <AppNav />

      <main className="min-w-0 flex-1 pb-24 lg:pb-0">
        <div className="mx-auto max-w-[860px] px-screen py-8 lg:py-12">{children}</div>
      </main>
    </div>
  );
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
