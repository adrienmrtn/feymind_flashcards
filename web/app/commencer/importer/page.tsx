import { redirect } from "next/navigation";

/**
 * Un écran de démonstration qui a quitté le parcours : l'étudiant arrive de la vitrine, il a déjà
 * vu le produit, et le parcours commence maintenant par les questions. Un ancien lien ne doit pas
 * tomber dans le vide, il rejoint la première.
 */
export default function RetiredStoryStep() {
  redirect("/commencer/pays");
}
