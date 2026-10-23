import { lessonTone } from "@micabo/core";

import { ExamsScreen } from "@/components/exams/ExamsScreen";
import { listExams } from "@/lib/data/courses";
import { listLessonExamResults } from "@/lib/data/lesson-exams";
import { listLessons } from "@/lib/data/lessons";
import { readProfile } from "@/lib/data/profile";
import { getTranslator } from "@/lib/i18n/server";

/**
 * **Examen** : le prochain examen en grand, avec son compte à rebours et ses leçons ; un
 * examen blanc à lancer ; les autres à venir ; l'historique des copies rendues. Voir
 * `docs/refonde-parcours.md` § 9. Les notes sont dans le barème du pays du profil.
 */
export default async function ExamTabPage() {
  const [{ t }, exams, lessons, results, profile] = await Promise.all([getTranslator(), listExams(), listLessons(), listLessonExamResults(), readProfile()]);
  const known = new Set(lessons.map((lesson) => lesson.id));

  return (
    <ExamsScreen
      exams={exams.map((exam) => ({ id: exam.id, name: exam.name, examDate: exam.exam_date, courseIds: (exam.course_ids ?? []).filter((id) => known.has(id)) }))}
      lessons={lessons.map((lesson) => ({ id: lesson.id, title: lesson.title || t("app.course.untitled"), icon: lesson.icon || lesson.path?.icon || null, tone: lessonTone(lesson.id, lesson.tone) }))}
      results={results}
      country={profile?.country_code ?? null}
    />
  );
}
