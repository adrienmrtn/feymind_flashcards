import { countryFor, entitlement, isStudyLevel, resolveStage } from "@micabo/core";

import { ProfileScreen } from "@/components/profile/ProfileScreen";
import { readEntitlement } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";
import { listSocialGraph, listWeekReviewRanking } from "@/lib/data/social";
import { currentUser } from "@/lib/data/user";
import { canReadInbox } from "@/lib/feedback";
import { getTranslator } from "@/lib/i18n/server";

/**
 * **Profil** (`docs/refonte-parcours.md` § 12) : la carte profil et son détail, « Passer en
 * Pro », les amis et le classement de la semaine, les réglages, le support. La page lit,
 * l'écran montre.
 */
export default async function ProfilePage() {
  const [user, profile, right, graph, ranking, { t }] = await Promise.all([currentUser(), readProfile(), readEntitlement(), listSocialGraph(), listWeekReviewRanking(), getTranslator()]);
  const country = countryFor(profile?.country_code);
  const level = profile?.study_level ?? null;
  const stage = level ? resolveStage(country.code, { id: level, level: isStudyLevel(level) ? level : null }) : null;
  const name = profile?.display_name?.trim() || t("lesson.profile.me");
  const email = user?.email ?? "";

  return (
    <ProfileScreen
      name={name}
      identity={profile?.username ? `@${profile.username}` : email || null}
      studies={stage ? `${stage.emoji} ${stage.title}` : null}
      email={email}
      isPaid={entitlement.isPaid(right)}
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
        school: profile?.institution_name ?? "",
        schoolId: profile?.institution_id ?? null,
        subjects: Array.isArray(profile?.subjects) ? profile.subjects : [],
      }}
    />
  );
}
