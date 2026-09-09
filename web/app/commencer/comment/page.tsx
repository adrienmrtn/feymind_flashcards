import { redirect } from "next/navigation";

/** Cet écran a quitté le parcours. Les anciens liens tombent sur le parcours. */
export default function RemovedHowItWorksStep() {
  redirect("/commencer/parcours");
}
