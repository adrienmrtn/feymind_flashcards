import { notFound, redirect } from "next/navigation";

import { masteryForCourses } from "@micabo/core";

import { MockRun, type MockQuestion } from "@/components/app/plan/MockRun";
import { listCardSnapshots, listCards, listCourses, listExams } from "@/lib/data/courses";
import { loadCardDifficulty } from "@/lib/data/difficulty";
import { readMockSession } from "@/lib/data/mocks";

/**
 * La passation d'un examen blanc.
 *
 * Le tirage a été posé par l'action à l'ouverture ; cette page ne fait que servir les cartes
 * qu'il désigne, **dans son ordre**. Elle ne choisit rien : recharger au milieu de l'épreuve
 * doit rendre exactement les mêmes questions, sinon la mesure ne vaut plus rien.
 */
export default async function MockRunPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const session = await readMockSession(id);
  if (!session) notFound();
  // Une session finie n'est pas rejouable : son score est posé.
  if (session.finished_at) redirect(`/app/plan/${session.exam_id ?? ""}`);

  const [exams, courses, snapshots, difficulties] = await Promise.all([
    listExams(),
    listCourses(),
    listCardSnapshots(),
    loadCardDifficulty(),
  ]);

  const exam = exams.find((row) => row.id === session.exam_id);
  if (!exam) notFound();

  const courseIds = exam.course_ids ?? [];
  const titles = new Map(courses.map((course) => [course.id, course.title]));

  // Les recto-verso complets, pour les seules cartes du tirage.
  const wanted = new Set((session.answers ?? []).map((entry) => entry.card));
  const loaded = (
    await Promise.all(courseIds.map((courseId) => listCards(courseId)))
  ).flat();

  const byId = new Map(loaded.map((card) => [card.id, card]));
  const questions: MockQuestion[] = (session.answers ?? [])
    .map((entry) => byId.get(entry.card))
    .filter((card): card is NonNullable<typeof card> => Boolean(card) && wanted.has(card!.id))
    .map((card) => ({
      id: card.id,
      front: card.front,
      back: card.back,
      courseTitle: card.course_id ? (titles.get(card.course_id) ?? null) : null,
    }));

  if (questions.length === 0) notFound();

  const mastery = masteryForCourses(
    snapshots.map((card) => ({
      id: card.id,
      courseId: card.course_id,
      state: card.state,
      intervalDays: card.interval_days,
      isSuspended: card.is_suspended,
    })),
    difficulties,
    courseIds,
  );

  return (
    <MockRun
      sessionId={session.id}
      examId={exam.id}
      examName={exam.name}
      minutes={session.minutes}
      questions={questions}
      masteryPercent={mastery.percent}
    />
  );
}
