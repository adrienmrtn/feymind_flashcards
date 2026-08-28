import { redirect } from "next/navigation";

/**
 * L'ancien écran « Ton examen » a quitté le parcours : la préparation
 * se montre déjà sur `/commencer/reussir`.
 */
export default function RetiredExamStep() {
  redirect("/commencer/ecole");
}
