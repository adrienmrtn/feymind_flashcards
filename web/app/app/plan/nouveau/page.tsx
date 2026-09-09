import { redirect } from "next/navigation";

import { resolveEmoji, weeklyFromRow } from "@micabo/core";

import { NewPlan } from "@/components/app/plan/NewPlan";
import { listCardSnapshots, listCourses } from "@/lib/data/courses";
import { readProfile } from "@/lib/data/profile";
import { currentUserId } from "@/lib/data/user";
import { getTranslator } from "@/lib/i18n/server";

/**
 * Créer un plan : le parcours central du produit.
 *
 * Il commence par le matériel et non par une date, parce que c'est le premier geste réel de
 * quelqu'un qui prépare un partiel. Tout ce que l'écran a besoin de savoir est lu ici : les
 * cours déjà là, leurs cartes, et la semaine type actuelle - qu'on propose plutôt que de la
 * redemander à blanc.
 */
export default async function NewPlanPage() {
  const userId = await currentUserId();
  if (!userId) redirect("/commencer/compte?suite=%2Fapp%2Fplan%2Fnouveau");

  const [{ t }, courses, cards, profile] = await Promise.all([
    getTranslator(),
    listCourses(),
    listCardSnapshots(),
    readProfile(),
  ]);

  const counts = new Map<string, number>();
  for (const card of cards) {
    if (!card.course_id || card.is_suspended) continue;
    counts.set(card.course_id, (counts.get(card.course_id) ?? 0) + 1);
  }

  return (
    <>
      <span className="sr-only">{t("app.newPlan.materialTitle")}</span>
      <NewPlan
        countryCode={profile?.country_code}
        sheetLength={profile?.sheet_length ?? undefined}
        initialWeekly={weeklyFromRow(profile?.weekly_minutes, profile?.daily_minutes ?? undefined)}
        courses={courses
          .filter((course) => !course.is_from_library)
          .map((course) => ({
            id: course.id,
            title: course.title,
            emoji: resolveEmoji(course.emoji, course.subject, course.title),
            cardCount: counts.get(course.id) ?? 0,
          }))}
        cards={cards.map((card) => ({
          id: card.id,
          courseId: card.course_id,
          kind: card.kind,
          state: card.state,
          intervalDays: card.interval_days,
          dueDate: card.due_date,
          isSuspended: card.is_suspended,
        }))}
      />
    </>
  );
}
