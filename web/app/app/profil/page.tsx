import { redirect } from "next/navigation";

/**
 * Le profil n'est plus une page : ses chiffres vivent sur Progrès, son identité dans les
 * réglages. Le lien reste, pour les favoris et l'app.
 */
export default function ProfileMoved() {
  redirect("/app/reglages");
}
