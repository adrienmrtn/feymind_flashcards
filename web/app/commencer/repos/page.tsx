import { redirect } from "next/navigation";

/** Les jours de repos ont rejoint le temps par jour, sur l'écran du rythme. */
export default function RetiredRestDaysStep() {
  redirect("/commencer/rythme");
}
