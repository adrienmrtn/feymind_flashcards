/**
 * **Les réponses fermées du parcours**, avec leur emoji : les mêmes que l'iPhone
 * (`StudyWorry`, `OnboardingDailyTime` dans `OnboardingModel.swift`), dans le même ordre.
 *
 * Les identifiants ne sont pas décoratifs : ce sont ceux que `generate-lesson` connaît
 * (`supabase/functions/_shared/learner.ts`, `Worry`), et une valeur qu'il ne connaît pas serait
 * jetée en silence. Le test le verrouille.
 */

export const WORRIES = [
  { id: "examStress", emoji: "😰" },
  { id: "hardLessons", emoji: "🤯" },
  { id: "homework", emoji: "⏳" },
  { id: "forgetting", emoji: "🫥" },
  { id: "noStart", emoji: "🧭" },
  { id: "motivation", emoji: "🔋" },
] as const;

export type Worry = (typeof WORRIES)[number]["id"];

export const WORRY_IDS: readonly Worry[] = WORRIES.map((worry) => worry.id);

export function isWorry(value: unknown): value is Worry {
  return typeof value === "string" && (WORRY_IDS as readonly string[]).includes(value);
}

/** Les freins cochés, sans doublon ni inconnu, dans l'ordre de la liste. */
export function cleanWorries(values: readonly unknown[] | null | undefined): Worry[] {
  const picked = new Set((values ?? []).filter(isWorry));
  return WORRY_IDS.filter((id) => picked.has(id));
}

/**
 * Le temps par jour. Quatre crans, comme l'iPhone : c'est `profiles.daily_minutes`, que l'app
 * relit pour doser les cartes neuves (`DailyLoad.newCardsPerDay`).
 */
export const DAILY_MINUTES = [
  { minutes: 5, emoji: "☕️" },
  { minutes: 10, emoji: "🚌" },
  { minutes: 15, emoji: "📖" },
  { minutes: 30, emoji: "🎯" },
] as const;

export function isDailyMinutes(value: unknown): value is number {
  return typeof value === "number" && DAILY_MINUTES.some((choice) => choice.minutes === value);
}

/** Une date d'examen recevable : `AAAA-MM-JJ`, aujourd'hui ou plus tard, à moins de trois ans. */
export function isExamDate(value: unknown, today = new Date()): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) return false;
  const start = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  // Un jour de marge en arrière : le soir à Los Angeles, UTC est déjà au lendemain, et le
  // « aujourd'hui » de l'étudiant y passerait pour hier.
  return date.getTime() >= start - 86_400_000 && date.getTime() <= start + 3 * 366 * 86_400_000;
}
