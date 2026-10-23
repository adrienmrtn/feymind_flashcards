import { redirect } from "next/navigation";

import { PROFILE_PATH } from "@/lib/lesson/routes";

/** Les progrès se lisent sur Home (les trois chiffres) et dans Profil. L'adresse mène au Profil. */
export default function Moved() {
  redirect(PROFILE_PATH);
}
