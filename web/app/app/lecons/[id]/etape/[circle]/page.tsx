import { notFound, redirect } from "next/navigation";

import { randomSeed } from "@micabo/core";

import { StepScreen } from "@/components/lesson/StepScreen";
import { lessonPath } from "@/lib/lesson/routes";
import { lessonTakeaways, loadLessonContext, stepTheme } from "@/lib/lesson/load";

/**
 * **Une étape du chemin**, ouverte en plein écran : l'Intro, des Notes, un Checkpoint ou le
 * Quiz final. La page lit la leçon et ses thèmes, trouve l'étape, et passe à l'écran ce
 * qu'elle a besoin de savoir. Une étape qui n'existe pas ramène au chemin.
 */
export default async function StepPage({ params }: { params: Promise<{ id: string; circle: string }> }) {
  const { id, circle: rawCircle } = await params;
  const context = await loadLessonContext(id);
  if (!context) notFound();

  const circleId = decodeURIComponent(rawCircle);
  const circle = context.circles.find((entry) => entry.id === circleId);
  if (!circle) redirect(lessonPath(context.lesson.id));

  const { lesson, themes } = context;
  const theme = circle.kind.type === "notes" ? themes[circle.kind.theme] : null;
  if (circle.kind.type === "notes" && !theme) redirect(lessonPath(lesson.id));

  return (
    <StepScreen
      lessonId={lesson.id}
      tone={context.tone}
      circle={circle}
      progress={{ ...lesson.progress, done: context.done }}
      intro={
        circle.kind.type === "intro"
          ? { lines: lesson.path.intro.lines, minutes: lesson.path.intro.minutes, themes: themes.map((entry) => ({ title: entry.title, icon: entry.icon })) }
          : null
      }
      theme={theme ? stepTheme(theme) : null}
      quizzes={circle.kind.type === "quiz" || circle.kind.type === "final" ? themes.map((entry) => entry.quiz) : []}
      takeaways={circle.kind.type === "final" ? lessonTakeaways(context) : []}
      seed={randomSeed().toString()}
    />
  );
}
