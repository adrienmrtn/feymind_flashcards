import { redirect } from "next/navigation";

import { LESSONS_PATH } from "@/lib/lesson/routes";

/** La bibliothèque et les cours à reprendre ont disparu (refonte « parcours ») : l'adresse mène aux leçons. */
export default function Moved() {
  redirect(LESSONS_PATH);
}
