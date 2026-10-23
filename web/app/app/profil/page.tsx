import { headers } from "next/headers";

import { countryFor, entitlement, isContentLanguage } from "@micabo/core";

import { ProfileScreen } from "@/components/profile/ProfileScreen";
import { storePlatform } from "@/components/profile/stores";
import { readEntitlement } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";
import { listSocialGraph, listWeekReviewRanking } from "@/lib/data/social";
import { currentUser } from "@/lib/data/user";
import { canReadInbox } from "@/lib/feedback";
import { getTranslator } from "@/lib/i18n/server";
import { learnerStage } from "@/lib/lesson/learner";
import { readLocalLearner } from "@/lib/lesson/learner-cookie";

/**
 * **Profil** (`docs/refonte-parcours.md` § 12) : la carte profil et son détail, « Passer en
 * Pro », les amis et le classement de la semaine, les réglages, le support. La page lit,
 * l'écran montre.
 *
 * Le palier se résout comme l'audience des leçons le résout (`learnerStage`) : le registre de
 * `profiles.study_level`, précisé par le palier gardé sur ce navigateur. Les deux disent donc
 * la même chose de l'élève — ce que le réglage affiche est ce que la leçon reçoit.
 */
export default async function ProfilePage() {
  const [user, profile, right, graph, ranking, { t }, agent] = await Promise.all([
    currentUser(),
    readProfile(),
    readEntitlement(),
    listSocialGraph(),
    listWeekReviewRanking(),
    getTranslator(),
    headers().then((list) => list.get("user-agent")),
  ]);
  const local = await readLocalLearner(user?.id ?? null);
  const country = countryFor(profile?.country_code);
  const { stage } = learnerStage(profile ? { study_level: profile.study_level, country_code: country.code } : null, local);
  const name = profile?.display_name?.trim() || t("lesson.profile.me");
  const email = user?.email ?? "";

  return (
    <ProfileScreen
      name={name}
      identity={profile?.username ? `@${profile.username}` : email || null}
      studies={stage ? `${stage.emoji} ${stage.title}` : null}
      email={email}
      isPaid={entitlement.isPaid(right)}
      platform={storePlatform(agent)}
      subscription={{
        paid: entitlement.isPaid(right),
        store: right.store ?? null,
        periodType: right.periodType ?? null,
        expiresAt: right.expiresAt ? right.expiresAt.toISOString() : null,
        willRenew: Boolean(right.willRenew),
        productId: right.productId ?? null,
      }}
      ranking={ranking}
      friendCount={graph.friends.length}
      requestCount={graph.incoming.length}
      showInbox={canReadInbox(user?.email)}
      detail={{
        name: profile?.display_name ?? "",
        username: profile?.username ?? "",
        countryCode: country.code,
        studyLevel: stage?.id ?? null,
        sheetLanguage: isContentLanguage(profile?.sheet_language) ? profile.sheet_language : null,
        school: profile?.institution_name ?? "",
        schoolId: profile?.institution_id ?? null,
        subjects: Array.isArray(profile?.subjects) ? profile.subjects : [],
      }}
    />
  );
}
