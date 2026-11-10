import { currentStreak, dueCards, hasUsedFreeLesson, homeStats, lessonCircles, lessonTone, migratedDone, resumeTarget } from "@micabo/core";

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
 * et passe à l'écran ce qu'il montre. La carte « Aujourd'hui » et les « Outils »
 * (`docs/refonte-knowunity.md` § 1) y ajoutent les cartes dues et la dernière leçon ouverte.
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

  // « {n} cartes à réviser » : les cartes dues des leçons qui ont un chemin (la révision se fait
  // dans la leçon), et la leçon qui en a le plus, que la ligne ouvre.
  const pathLessons = new Set(lessons.filter((lesson) => lesson.path).map((lesson) => lesson.id));
  const dueByLesson = new Map<string, number>();
  for (const card of dueCards(
    cards
      .filter((card) => card.course_id && pathLessons.has(card.course_id))
      .map((card) => ({
        id: card.id,
        front: card.front,
        kind: card.kind,
        isSuspended: card.is_suspended,
        state: card.state,
        dueDate: card.due_date,
        intervalDays: card.interval_days,
        position: card.position,
        lessonId: card.course_id!,
      })),
    now,
  )) {
    dueByLesson.set(card.lessonId, (dueByLesson.get(card.lessonId) ?? 0) + 1);
  }
  const dueTotal = [...dueByLesson.values()].reduce((sum, count) => sum + count, 0);
  const dueLesson = [...dueByLesson.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

  return (
    <HomeScreen
      dueCards={dueLesson ? { count: dueTotal, lessonId: dueLesson } : null}
      quizLessonId={latest?.id ?? null}
      hasLessons={lessons.length > 0}
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
