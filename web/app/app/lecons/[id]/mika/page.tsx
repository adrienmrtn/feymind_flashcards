import { notFound } from "next/navigation";

import { LessonMika } from "@/components/lesson/LessonMika";
import { readEntitlement } from "@/lib/data/entitlement";
import { loadLessonContext } from "@/lib/lesson/load";

/** **Mika, dans la leçon** : la bulle en haut du chemin. La leçon est jointe d'office. */
export default async function LessonMikaPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [context, right] = await Promise.all([loadLessonContext(id), readEntitlement()]);
  if (!context) notFound();
  return <LessonMika lessonId={context.lesson.id} title={context.lesson.title || context.t("app.course.untitled")} tone={context.tone} isPro={right.isPro} />;
}
