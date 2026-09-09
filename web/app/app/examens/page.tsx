import { redirect } from "next/navigation";

/** Les examens ont un plan, maintenant. Les anciens liens y arrivent. */
export default function ExamsMoved() {
  redirect("/app/plan");
}
