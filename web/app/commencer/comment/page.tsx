import { redirect } from "next/navigation";

/** Cet écran a quitté le parcours. Les anciens liens tombent sur l'école. */
export default function RemovedHowItWorksStep() {
  redirect("/commencer/ecole");
}
