import { redirect } from "next/navigation";

import { LESSONS_PATH } from "@/lib/lesson/routes";

/** La révision globale a disparu : chaque leçon révise ses flashcards. L'adresse mène aux leçons. */
export default function Moved() {
  redirect(LESSONS_PATH);
}
