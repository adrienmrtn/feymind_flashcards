import { redirect } from "next/navigation";

/**
 * « Commencer » n'est pas une seconde landing : c'est la porte du parcours.
 * Le premier écran est le pays. Le compte n'arrive qu'à la fin.
 */
export default function CommencerEntry() {
  redirect("/commencer/pays");
}
