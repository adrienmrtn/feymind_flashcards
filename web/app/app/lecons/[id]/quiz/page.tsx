import { notFound } from "next/navigation";

import { randomSeed } from "@micabo/core";

import { LessonQuizScreen } from "@/components/lesson/LessonQuizScreen";
import { loadLessonContext } from "@/lib/lesson/load";
import { QUICK_QUIZ_QUESTIONS } from "@/lib/lesson/routes";

/**
 * **Le quiz de la leçon** : dix questions sur tout le chemin, l'entrée Quiz de la barre.
 * `?eclair=1` est le « Quiz éclair » des Outils de Home : cinq questions seulement.
 */
export default async function LessonQuizPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ eclair?: string }>;
}) {
  const [{ id }, query] = await Promise.all([params, searchParams]);
  const context = await loadLessonContext(id);
  if (!context) notFound();
  return (
    <LessonQuizScreen
      lessonId={context.lesson.id}
      tone={context.tone}
      quizzes={context.themes.map((theme) => theme.quiz)}
      progress={{ ...context.lesson.progress, done: context.done }}
      seed={randomSeed().toString()}
      limit={query.eclair === "1" ? QUICK_QUIZ_QUESTIONS : undefined}
    />
  );
}
