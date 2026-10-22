import { notFound } from "next/navigation";

import { randomSeed } from "@micabo/core";

import { LessonQuizScreen } from "@/components/lesson/LessonQuizScreen";
import { loadLessonContext } from "@/lib/lesson/load";

/** **Le quiz de la leçon** : dix questions sur tout le chemin, l'entrée Quiz de la barre. */
export default async function LessonQuizPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const context = await loadLessonContext(id);
  if (!context) notFound();
  return (
    <LessonQuizScreen
      lessonId={context.lesson.id}
      tone={context.tone}
      quizzes={context.themes.map((theme) => theme.quiz)}
      progress={{ ...context.lesson.progress, done: context.done }}
      seed={randomSeed().toString()}
    />
  );
}
