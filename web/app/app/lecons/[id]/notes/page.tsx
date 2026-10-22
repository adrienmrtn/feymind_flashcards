import { notFound } from "next/navigation";

import { pathThemes } from "@micabo/core";

import { LessonNotesReader } from "@/components/lesson/LessonNotesReader";
import { lessonTakeaways, loadLessonContext, stepTheme } from "@/lib/lesson/load";

/** **Toutes les Notes** de la leçon, d'une traite : l'entrée Notes de la barre. Imprimable. */
export default async function LessonNotesPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const context = await loadLessonContext(id);
  if (!context) notFound();
  const { lesson, themes } = context;
  const symbols = pathThemes(
    lesson.path,
    themes.map((theme) => ({ title: theme.title, icon: theme.icon })),
  ).map((theme) => theme.symbol);
  return (
    <LessonNotesReader
      lessonId={lesson.id}
      title={lesson.title || context.t("app.course.untitled")}
      subject={lesson.subject}
      icon={lesson.icon || lesson.path.icon}
      tone={context.tone}
      themes={themes.map(stepTheme)}
      symbols={symbols}
      takeaways={lessonTakeaways(context)}
    />
  );
}
