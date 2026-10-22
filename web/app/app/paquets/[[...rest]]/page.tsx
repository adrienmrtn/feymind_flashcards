import { redirect } from "next/navigation";

import { LESSONS_PATH } from "@/lib/lesson/routes";

/** Les paquets ont disparu : les flashcards vivent dans leur leçon. */
export default function Moved() {
  redirect(LESSONS_PATH);
}
