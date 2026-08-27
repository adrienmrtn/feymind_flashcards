import { activeExamMarks, type ExamMark } from "@micabo/core";

import type { CardRow, ExamRow } from "@/lib/data/courses";

/**
 * Par carte, l'examen planifié le plus proche qui la concerne.
 *
 * C'est la lecture dont l'UI a besoin pour poser la pastille : le planificateur
 * connaît déjà les dates ; ici on garde aussi le nom.
 */
export function examMarksFor(
  exams: ExamRow[],
  cards: Pick<CardRow, "id" | "course_id" | "is_suspended">[],
  now: Date = new Date(),
): ReadonlyMap<string, ExamMark> {
  return activeExamMarks(
    exams.map((exam) => ({
      date: new Date(`${exam.exam_date}T12:00:00`),
      isPlanned: exam.is_planned,
      courseIds: exam.course_ids ?? [],
      name: exam.name,
    })),
    cards.map((card) => ({
      id: card.id,
      courseId: card.course_id,
      isSuspended: card.is_suspended,
    })),
    now,
  );
}

/** L'examen qui commande tout un cours - le même pour chacune de ses cartes. */
export function examMarkForCourse(
  exams: ExamRow[],
  courseId: string,
  now: Date = new Date(),
): ExamMark | null {
  return examMarksFor(exams, [{ id: courseId, course_id: courseId, is_suspended: false }], now).get(
    courseId,
  ) ?? null;
}
