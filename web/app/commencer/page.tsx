import type { Route } from "next";
import { redirect } from "next/navigation";

import { resumePath } from "@/lib/auth/resume";

/**
 * « Commencer » n'est pas une seconde landing : c'est la porte du parcours.
 * Le premier écran est l'accueil. Si on est déjà connecté, on ouvre l'app.
 */
export default async function CommencerEntry() {
  redirect((await resumePath()) as Route);
}
