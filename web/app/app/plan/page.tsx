import { redirect } from "next/navigation";

/** Le plan est devenu la page centrale : il vit à la racine de l'app. */
export default function PlanMoved() {
  redirect("/app");
}
