import { resolveEmoji } from "@micabo/core";

import { ExamWorkspace } from "@/components/app/exams/ExamWorkspace";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";

/**
 * Les examens, **sur un calendrier.**
 *
 * Cliquer un jour ouvre la feuille : nom, cours, curseur d'intensité. C'est le même geste
 * qu'iOS — une date, les cours de l'épreuve, un palier — sauf que le palier est un curseur
 * avec un emoji qui change, parce que trois pastilles se lisent moins bien à la souris.
 */
export default async function ExamsPage() {
  const [exams, courses, cards] = await Promise.all([
    listExams(),
    listCourses(),
    listCardSnapshots(),
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
        <p className="eyebrow text-ink-tertiary">Mode examen</p>
        <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">Examens</h1>
      </header>

      <div className="mt-8">
        <ExamWorkspace
          exams={exams.map((exam) => ({
            id: exam.id,
            name: exam.name,
            examDate: exam.exam_date,
            intensity: exam.intensity,
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
