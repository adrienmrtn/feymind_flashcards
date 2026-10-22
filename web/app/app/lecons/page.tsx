import { currentCircle, lessonTone, migratedDone, pathCircles, pathProgress } from "@micabo/core";

import { LessonsScreen, type LessonListItem } from "@/components/lessons/LessonsScreen";
import { listAllCards, listExams, listFolders } from "@/lib/data/courses";
import { listLessons, listThemeCounts } from "@/lib/data/lessons";
import { getTranslator } from "@/lib/i18n/server";

/**
 * **Leçons** : toutes les leçons, les plus récentes d'abord, chacune avec où elle en est, ce
 * qu'elle a à réviser et l'examen qui l'attend. Voir `docs/refonte-parcours.md` § 8. La page
 * lit, le noyau compte, l'écran range et cherche.
 */
export default async function LessonsPage() {
  const [{ t }, lessons, counts, cards, exams, folders] = await Promise.all([getTranslator(), listLessons(), listThemeCounts(), listAllCards(), listExams(), listFolders()]);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const labels = { intro: t("lesson.circle.intro"), checkpoint: t("lesson.circle.checkpoint"), final: t("lesson.circle.final") };

  // Les cartes dues, par leçon.
  const due = new Map<string, number>();
  for (const card of cards) {
    if (card.is_suspended || !card.course_id || new Date(card.due_date).getTime() > now.getTime()) continue;
    due.set(card.course_id, (due.get(card.course_id) ?? 0) + 1);
  }

  // L'examen le plus proche de chaque leçon, s'il est à venir.
  const nextExam = new Map<string, { name: string; days: number }>();
  for (const exam of [...exams].sort((a, b) => a.exam_date.localeCompare(b.exam_date))) {
    const days = Math.round((new Date(`${exam.exam_date}T00:00:00`).getTime() - today) / 86_400_000);
    if (days < 0) continue;
    for (const id of exam.course_ids ?? []) if (!nextExam.has(id)) nextExam.set(id, { name: exam.name, days });
  }

  const items: LessonListItem[] = lessons.map((lesson) => {
    const themeCount = counts.get(lesson.id) ?? 0;
    let circleNumber: number | null = null;
    let circleTotal = 0;
    let percent = 0;
    let finished = lesson.progress.finishedAt !== null;
    if (lesson.path && themeCount > 0) {
      const circles = pathCircles(
        Array.from({ length: themeCount }, () => ({ title: "", icon: "", symbol: "" })),
        labels,
        { singleQuiz: lesson.path.singleQuiz },
      );
      const done = migratedDone(lesson.progress.done, circles, finished);
      const current = currentCircle(circles, done);
      const progress = pathProgress(circles, done);
      circleNumber = current?.number ?? null;
      circleTotal = circles.length;
      percent = progress.percent;
      finished = finished || current === null;
    }
    return {
      id: lesson.id,
      title: lesson.title || t("app.course.untitled"),
      icon: lesson.icon || lesson.path?.icon || null,
      tone: lessonTone(lesson.id, lesson.tone),
      folderId: lesson.folder_id ?? null,
      legacy: lesson.path === null,
      opened: lesson.progress.done.length > 0 || lesson.last_opened_at !== null,
      circleNumber,
      circleTotal,
      percent,
      finished,
      due: due.get(lesson.id) ?? 0,
      exam: nextExam.get(lesson.id) ?? null,
      recency: new Date(lesson.last_opened_at ?? lesson.updated_at).getTime(),
    };
  });

  return <LessonsScreen lessons={items} folders={folders.map((folder) => ({ id: folder.id, parentId: folder.parent_id, name: folder.name, emoji: folder.emoji, position: folder.position }))} />;
}
