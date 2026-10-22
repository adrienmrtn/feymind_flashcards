import { redirect } from "next/navigation";

import { HOME_PATH } from "@/lib/lesson/routes";

/** On crée depuis Home, maintenant. L'adresse reste pour les favoris et les liens envoyés. */
export default function Moved() {
  redirect(HOME_PATH);
}
