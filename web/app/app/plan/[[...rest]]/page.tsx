import { redirect } from "next/navigation";

import { EXAMS_PATH } from "@/lib/lesson/routes";

/** Le plan de la période a laissé place à l'onglet Examen. Les anciens liens y arrivent. */
export default function Moved() {
  redirect(EXAMS_PATH);
}
