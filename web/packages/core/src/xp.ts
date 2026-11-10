/**
 * **L'XP, l'objectif du jour et la ligue de la semaine** (`docs/refonte-knowunity.md`).
 *
 * L'XP récompense l'effort, pas la réussite seule : une mauvaise réponse rapporte un peu, pour
 * qu'un élève en difficulté voie quand même sa barre monter. Elle se compte **sur l'appareil**,
 * jour par jour, et monte dans `profiles` (`xp_total`, `xp_week`, `xp_week_start`) à chaque
 * synchronisation ; la ligue lit celle des amis par `friends_league()`.
 *
 * Les mêmes nombres vivent dans `Micabo/Services/XP/XPRules.swift` et
 * `android/.../data/Xp.kt` : `test/xp-parity.test.ts` relit le Swift et le Kotlin et tombe si
 * un chiffre diverge.
 */

/** Ce que rapporte chaque geste. */
export const XP_REWARDS = {
  /** Une bonne réponse dans un quiz, un entraînement ou une carte « Je savais ». */
  correctAnswer: 10,
  /** Une mauvaise réponse : l'effort compte. */
  wrongAnswer: 2,
  /** Une flashcard révisée, quelle que soit la note. */
  cardReviewed: 3,
  /** Un cercle du parcours terminé. */
  circleCompleted: 25,
  /** Une leçon créée et livrée. */
  lessonCreated: 30,
  /** Un examen blanc rendu. */
  mockExamFinished: 60,
  /** Une réponse de Mika, dans une leçon. */
  mikaAnswer: 5,
  /** Un exercice scanné que Mika a expliqué. */
  exerciseSolved: 15,
  /** Une séance du minuteur menée à son terme. */
  focusSession: 40,
} as const;

export type XpReason = keyof typeof XP_REWARDS;

/** L'objectif du jour, en XP : l'anneau de « Aujourd'hui » se remplit jusque-là. */
export const DAILY_XP_GOAL = 50;

/** La durée d'une séance du minuteur, en minutes. */
export const FOCUS_MINUTES = 25;

/** Un plafond par jour, contre un compteur qui s'emballe (et ce que le serveur accepte). */
export const DAILY_XP_CAP = 5000;

/** Les ligues, par XP gagnée **cette semaine**. Le seuil est le plancher de la ligue. */
export const LEAGUES = [
  { id: "bronze", floor: 0 },
  { id: "silver", floor: 200 },
  { id: "gold", floor: 500 },
  { id: "sapphire", floor: 1000 },
  { id: "diamond", floor: 2000 },
] as const;

export type LeagueId = (typeof LEAGUES)[number]["id"];

export function leagueFor(weeklyXp: number): LeagueId {
  let current: LeagueId = "bronze";
  for (const league of LEAGUES) {
    if (weeklyXp >= league.floor) current = league.id;
  }
  return current;
}

/** Ce qui manque pour la ligue suivante, ou `null` en Diamant. */
export function xpToNextLeague(weeklyXp: number): { next: LeagueId; missing: number } | null {
  const next = LEAGUES.find((league) => league.floor > weeklyXp);
  return next ? { next: next.id, missing: next.floor - weeklyXp } : null;
}

/** La date `AAAA-MM-JJ` d'un jour local. */
export function dayKey(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** Le lundi de la semaine de `date`, en jour local : la semaine de la ligue commence là. */
export function weekStart(date: Date): string {
  const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const offset = (monday.getDay() + 6) % 7;
  monday.setDate(monday.getDate() - offset);
  return dayKey(monday);
}

/** Le journal : XP par jour local, `{ "2026-11-10": 120 }`. */
export type XpLedger = Record<string, number>;

/** Ajoute `amount` au jour de `at`, sans dépasser le plafond du jour. */
export function addXp(ledger: XpLedger, amount: number, at: Date): XpLedger {
  const key = dayKey(at);
  const today = ledger[key] ?? 0;
  const next = Math.min(DAILY_XP_CAP, today + Math.max(0, Math.round(amount)));
  return { ...ledger, [key]: next };
}

export function xpToday(ledger: XpLedger, now: Date): number {
  return ledger[dayKey(now)] ?? 0;
}

/** L'XP de la semaine en cours (du lundi à aujourd'hui). */
export function xpThisWeek(ledger: XpLedger, now: Date): number {
  const start = weekStart(now);
  const end = dayKey(now);
  return Object.entries(ledger)
    .filter(([day]) => day >= start && day <= end)
    .reduce((sum, [, xp]) => sum + xp, 0);
}

export function xpTotal(ledger: XpLedger): number {
  return Object.values(ledger).reduce((sum, xp) => sum + xp, 0);
}

/** Le journal ne garde que les quinze derniers jours ; le total vit à part. */
export function pruneLedger(ledger: XpLedger, now: Date, keepDays = 15): XpLedger {
  const limit = new Date(now.getFullYear(), now.getMonth(), now.getDate() - keepDays);
  const floor = dayKey(limit);
  return Object.fromEntries(Object.entries(ledger).filter(([day]) => day > floor));
}
