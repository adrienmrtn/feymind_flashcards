import { redirect } from "next/navigation";

/**
 * Cet écran a quitté le parcours : les six écrans de démonstration ont été refaits sur une
 * seule forme, et celui-ci n'y avait plus sa place. Un ancien lien ne doit pas tomber dans
 * le vide, il rejoint le premier écran de la nouvelle série.
 */
export default function RetiredStoryStep() {
  redirect("/commencer/examen");
}
