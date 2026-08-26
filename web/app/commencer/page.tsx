import { redirect } from "next/navigation";

/**
 * « Commencer » n'est pas une seconde landing : c'est la porte du parcours.
 * Le premier écran est le compte, puis les questions s'enchaînent une par une.
 */
export default function CommencerEntry() {
  redirect("/commencer/compte");
}
