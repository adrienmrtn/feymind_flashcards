import { notFound } from "next/navigation";

import {
  circleReadiness,
  dayDifference,
  lessonCircles,
  lessonTone,
  migratedDone,
  pathProgress,
  type CircleReadiness,
} from "@micabo/core";

import { LessonConverting } from "@/components/lesson/LessonConverting";
import { LessonScreen } from "@/components/lesson/LessonScreen";
import { listCards, listExams } from "@/lib/data/courses";
import { getLesson, listThemes } from "@/lib/data/lessons";
import { formatDayMonth } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";

/**
 * **Le chemin d'une leçon.**
 *
 * La page lit la leçon, ses thèmes, ses cartes et ses examens, calcule le chemin avec le
 * noyau (les mêmes étapes que l'iPhone) et le passe à l'écran. Un cours sans plan est un
 * ancien cours : il se convertit à l'ouverture, puis la page se recharge.
 */
export default async function LessonPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [{ t, locale }, lesson] = await Promise.all([getTranslator(), getLesson(id)]);
  if (!lesson) notFound();

  if (!lesson.path) {
    return <LessonConverting lessonId={lesson.id} />;
  }

  const [themes, cards, exams] = await Promise.all([listThemes(lesson.id), listCards(lesson.id), listExams()]);

  const circles = lessonCircles(
    lesson.path,
    themes.map((theme) => ({ title: theme.title, icon: theme.icon })),
    { intro: t("lesson.circle.intro"), checkpoint: t("lesson.circle.checkpoint"), final: t("lesson.circle.final") },
  );
  const done = migratedDone(lesson.progress.done, circles, lesson.progress.finishedAt !== null);
  const statuses = themes.map((theme) => theme.status);
  const quizzes = themes.map((theme) => theme.quiz);
  const readiness: Record<string, CircleReadiness> = {};
  for (const circle of circles) readiness[circle.id] = circleReadiness(circle, statuses, quizzes);
  const progress = pathProgress(circles, done);

  const now = new Date();
  const dueCount = cards.filter((card) => !card.is_suspended && card.state !== "new" && new Date(card.due_date) <= now).length;

  const exam = exams
    .filter((row) => row.course_ids.includes(lesson.id))
    .map((row) => ({ ...row, days: dayDifference(now, new Date(`${row.exam_date}T12:00:00`)) }))
    .filter((row) => row.days >= 0)
    .sort((a, b) => a.days - b.days)[0];
  const examLabel = exam
    ? t("lesson.path.examPill", {
        date: formatDayMonth(`${exam.exam_date}T12:00:00`, locale) ?? exam.exam_date,
        countdown: exam.days === 0 ? t("app.exams.countdown.today") : t("lesson.path.daysLeft", { days: exam.days }),
      })
    : null;

  return (
    <LessonScreen
      lessonId={lesson.id}
      title={lesson.title || t("app.course.untitled")}
      icon={lesson.icon || lesson.path.icon}
      tone={lessonTone(lesson.id, lesson.tone)}
      circles={circles}
      done={done}
      inCircle={lesson.progress.inCircle}
      readiness={readiness}
      percent={progress.percent}
      stepsLabel={t("lesson.path.stepsDone", { done: progress.done, total: progress.total })}
      shortenedLabel={lesson.path.shortened ? t("lesson.path.shortened") : null}
      examLabel={examLabel}
      dueCount={dueCount}
      mikaLabel={t("lesson.mika.open")}
    />
  );
}
