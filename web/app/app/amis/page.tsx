import { redirect } from "next/navigation";

import { FRIENDS_PATH } from "@/lib/lesson/routes";

/** Les amis vivent dans Profil. L'adresse reste pour les favoris et l'app. */
export default function FriendsMoved() {
  redirect(FRIENDS_PATH);
}
