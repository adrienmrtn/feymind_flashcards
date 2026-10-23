import { redirect } from "next/navigation";

import { EXAMS_PATH } from "@/lib/lesson/routes";

/** Les examens ont leur onglet. Les anciens liens y arrivent. */
export default function Moved() {
  redirect(EXAMS_PATH);
}
