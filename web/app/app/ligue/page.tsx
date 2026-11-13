import { redirect } from "next/navigation";

import { LeagueScreen } from "@/components/xp/LeagueScreen";
import { readProfile } from "@/lib/data/profile";
import { currentUser } from "@/lib/data/user";
import { getTranslator } from "@/lib/i18n/server";

/**
 * **La ligue de la semaine** (`docs/refonte-knowunity.md` § 3), depuis la pastille XP de Home,
 * la tuile « Ligue » et le Profil. Le classement se lit dans le navigateur (`friends_league`),
 * à côté de l'XP qui y est gardée.
 */
export default async function LeaguePage() {
  const [user, profile, { t }] = await Promise.all([currentUser(), readProfile(), getTranslator()]);
  if (!user) redirect("/commencer/compte?suite=%2Fapp%2Fligue");
  const myName = profile?.display_name?.trim() || (profile?.username ? `@${profile.username}` : user.email?.split("@")[0] || t("app.auth.accountFallback"));
  return <LeagueScreen userId={user.id} myName={myName} />;
}
