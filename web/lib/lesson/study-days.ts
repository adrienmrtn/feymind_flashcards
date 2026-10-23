import { totalSeconds, type LessonProgress } from "@micabo/core";

/**
 * **Les jours travaillés, comme `StudyStreak` les compte sur l'iPhone** : n'importe quel vrai
 * geste d'étude allume la journée — une carte notée, une étape cochée, une réponse de quiz,
 * une copie d'examen blanc rendue. Le site ne comptait que le journal des cartes : une soirée
 * entière sur une leçon laissait la flamme éteinte, alors que le téléphone l'allumait.
 *
 * **Ce qui se lit en base, pas un registre.** L'iPhone et Android tiennent leur registre sur
 * l'appareil (`micabo.streak.days`), et aucune table ne le partage. Le site recompose donc
 * les journées depuis ce que tous les clients écrivent déjà :
 *
 * - `review_logs.reviewed_at` : chaque carte notée, d'où qu'elle vienne ;
 * - `courses.last_opened_at` d'une leçon **déjà travaillée** (une étape cochée, du temps
 *   passé) : les gestes d'étude du site la posent, et les apps la montent à la synchro ;
 * - `courses.progress.finishedAt` : le jour où la leçon a été apprise ;
 * - `mock_sessions.finished_at` : les copies d'examen blanc rendues.
 *
 * C'est une approximation honnête : une leçon travaillée trois jours de suite ne laisse que son
 * dernier jour. La série exacte demande une table des jours (voir le rapport) ; en attendant,
 * le site n'éteint plus une flamme que le téléphone allume le même soir.
 */
export interface StudiedLesson {
  last_opened_at: string | null;
  progress: Pick<LessonProgress, "done" | "seconds" | "finishedAt">;
}

export function studyDays(input: {
  reviewDays: readonly string[];
  lessons: readonly StudiedLesson[];
  paperDates?: readonly string[];
}): Date[] {
  const stamps: string[] = [...input.reviewDays];
  for (const lesson of input.lessons) {
    const worked = lesson.progress.done.length > 0 || totalSeconds(lesson.progress as LessonProgress) > 0;
    if (worked && lesson.last_opened_at) stamps.push(lesson.last_opened_at);
    if (lesson.progress.finishedAt) stamps.push(lesson.progress.finishedAt);
  }
  stamps.push(...(input.paperDates ?? []));
  return stamps.map((stamp) => new Date(stamp)).filter((date) => !Number.isNaN(date.getTime()));
}
