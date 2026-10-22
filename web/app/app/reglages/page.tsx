import { redirect } from "next/navigation";

import { PROFILE_PATH } from "@/lib/lesson/routes";

/** Les réglages vivent dans Profil. L'adresse reste pour les favoris et l'app. */
export default function SettingsMoved() {
  redirect(PROFILE_PATH);
}
