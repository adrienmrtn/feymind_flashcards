import { redirect } from "next/navigation";

import { LESSONS_PATH } from "@/lib/lesson/routes";

/** L'ancienne liste des cours mène à l'onglet Leçons. L'adresse reste pour les liens déjà envoyés. */
export default function CoursesRedirect() {
  redirect(LESSONS_PATH);
}
