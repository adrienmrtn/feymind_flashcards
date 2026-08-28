import { resolveEmoji, targetScoreFromIntensity } from "@micabo/core";

import { ExamWorkspace } from "@/components/app/exams/ExamWorkspace";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * Les examens, **sur un calendrier.**
 *
 * Cliquer un jour ou « Ajouter un examen » ouvre trois questions, jamais plein
 * écran : le jour (celui du clic, qu'on peut changer), les cours, l'intensité.
 * Les examens déjà posés s'écrivent en pastille sur le jour, pas en point.
 */
export default async function ExamsPage() {
  const supabase = await createClient();
  const user = await currentUser();
  const [exams, courses, cards, profile] = await Promise.all([
    listExams(),
    listCourses(),
    listCardSnapshots(),
    user
      ? supabase
          .from("profiles")
          .select("country_code")
          .eq("id", user.id)
          .maybeSingle()
          .then((result) => result.data)
      : null,
  ]);

  const mine = courses.filter((course) => !course.is_from_library);
  const counts = new Map<string, number>();
  for (const card of cards) {
    if (!card.course_id || card.is_suspended) continue;
    counts.set(card.course_id, (counts.get(card.course_id) ?? 0) + 1);
  }

  return (
    <>
      <header>
        <h1 className="text-[32px] font-bold leading-tight text-ink">📅 Examens</h1>
      </header>

      <div className="mt-8">
        <ExamWorkspace
          countryCode={profile?.country_code}
          exams={exams.map((exam) => ({
            id: exam.id,
            name: exam.name,
            examDate: exam.exam_date,
            intensity: exam.intensity,
            targetScore:
              exam.target_score ??
              targetScoreFromIntensity(
                exam.intensity === "light" || exam.intensity === "intense"
                  ? exam.intensity
                  : "standard",
              ),
            courseIds: exam.course_ids ?? [],
            isPlanned: exam.is_planned,
          }))}
          courses={mine.map((course) => ({
            id: course.id,
            title: course.title,
            emoji: resolveEmoji(course.emoji, course.subject, course.title),
            cardCount: counts.get(course.id) ?? 0,
          }))}
          cards={cards.map((card) => ({
            id: card.id,
            courseId: card.course_id,
            state: card.state,
            intervalDays: card.interval_days,
            dueDate: card.due_date,
            isSuspended: card.is_suspended,
          }))}
        />
      </div>
    </>
  );
}
