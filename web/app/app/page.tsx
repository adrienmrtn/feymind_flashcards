import { currentStreak, hasUsedFreeLesson, homeStats, lessonCircles, lessonTone, migratedDone, resumeTarget } from "@micabo/core";

import { HomeScreen } from "@/components/home/HomeScreen";
import { listAllCards } from "@/lib/data/courses";
import { readEntitlement } from "@/lib/data/entitlement";
import { listLessonExamResults } from "@/lib/data/lesson-exams";
import { listLessons, listThemes } from "@/lib/data/lessons";
import { loadProfileStats } from "@/lib/data/reviews";
import { getTranslator } from "@/lib/i18n/server";
import { studyDays } from "@/lib/lesson/study-days";

/**
 * **Home** : Mika, la question, la barre et ses cinq supports, trois chiffres mesurés, et
 * « Reprendre ». Voir `docs/refonte-parcours.md` § 3. La page lit tout, calcule avec le noyau,
 * et passe à l'écran ce qu'il montre.
 */
export default async function HomePage() {
  const [{ t }, lessons, cards, right, stats, papers] = await Promise.all([
    getTranslator(),
    listLessons(),
    listAllCards(),
    readEntitlement(),
    loadProfileStats(),
    listLessonExamResults(),
  ]);
  const now = new Date();

  // « Reprendre » : la dernière leçon ouverte, et l'étape où elle attend. Les thèmes de cette
  // seule leçon suffisent à nommer l'étape.
  const latest = lessons
    .filter((lesson) => lesson.path && lesson.last_opened_at)
    .sort((a, b) => new Date(b.last_opened_at!).getTime() - new Date(a.last_opened_at!).getTime())[0];
  let resume = null;
  if (latest?.path) {
    const themes = await listThemes(latest.id);
    const circles = lessonCircles(
      latest.path,
      themes.map((theme) => ({ title: theme.title, icon: theme.icon })),
      { intro: t("lesson.circle.intro"), checkpoint: t("lesson.circle.checkpoint"), final: t("lesson.circle.final") },
    );
    const target = resumeTarget([
      {
        id: latest.id,
        title: latest.title || t("app.course.untitled"),
        lastOpenedAt: new Date(latest.last_opened_at!),
        circles,
        done: migratedDone(latest.progress.done, circles, latest.progress.finishedAt !== null),
      },
    ]);
    resume = target ? { ...target, icon: latest.icon || latest.path.icon, tone: lessonTone(latest.id, latest.tone) } : null;
  }

  return (
    <HomeScreen
      isPro={right.isPro}
      hasUsedFreeLesson={hasUsedFreeLesson(lessons.map((lesson) => ({ source: lesson.source, isFromLibrary: lesson.is_from_library })))}
      stats={homeStats(
        lessons.map((lesson) => ({ progress: lesson.progress })),
        cards.map((card) => ({ state: card.state, dueDate: new Date(card.due_date), isSuspended: card.is_suspended })),
        now,
      )}
      // La série compte les journées d'étude, pas seulement les cartes notées : la règle de
      // `StudyStreak` sur l'iPhone (voir `studyDays`).
      streak={currentStreak(
        studyDays({
          reviewDays: stats.reviewDays,
          lessons,
          paperDates: papers.map((paper) => paper.date),
        }),
        now,
      )}
      resume={resume}
    />
  );
}
