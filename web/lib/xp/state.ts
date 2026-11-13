import {
  addXp,
  DAILY_XP_GOAL,
  dayKey,
  leagueFor,
  pruneLedger,
  weekStart,
  XP_REWARDS,
  xpThisWeek,
  xpToday,
  type LeagueId,
  type XpLedger,
  type XpReason,
} from "@micabo/core";

/**
 * **L'XP du site, sans navigateur** (`docs/refonte-knowunity.md` § 2) : le journal par jour
 * local, le total à part, ce qui n'est pas encore monté dans `profiles`, et le jour où l'objectif
 * a déjà été fêté. Les nombres sont ceux de `@micabo/core` (`xp.ts`) ; ce fichier ne fait que
 * les tenir ensemble, et se teste sans `localStorage` (`state.test.ts`).
 */
export interface XpState {
  /** XP par jour local, quinze jours au plus (`pruneLedger`). */
  ledger: XpLedger;
  /** Le total à vie gagné sur ce navigateur ; il survit au ménage du journal. */
  total: number;
  /** Ce qui n'est pas encore monté : ajouté à la ligne `profiles` à la prochaine synchro. */
  pending: { total: number; week: number; weekStart: string };
  /** Le jour (`AAAA-MM-JJ`) où la feuille « Objectif du jour atteint » s'est déjà montrée. */
  celebrated: string | null;
}

export function emptyXpState(now: Date): XpState {
  return { ledger: {}, total: 0, pending: { total: 0, week: 0, weekStart: weekStart(now) }, celebrated: null };
}

function count(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value > 0 ? Math.floor(value) : 0;
}

/** Relit un état écrit par une version précédente, ou abîmé : ce qui ne se lit pas repart de zéro. */
export function readXpState(raw: unknown, now: Date): XpState {
  const empty = emptyXpState(now);
  if (!raw || typeof raw !== "object") return empty;
  const value = raw as Partial<Record<keyof XpState, unknown>>;
  const ledger: XpLedger = {};
  if (value.ledger && typeof value.ledger === "object") {
    for (const [day, xp] of Object.entries(value.ledger as Record<string, unknown>)) {
      if (/^\d{4}-\d{2}-\d{2}$/.test(day) && count(xp) > 0) ledger[day] = count(xp);
    }
  }
  const pending = value.pending && typeof value.pending === "object" ? (value.pending as Record<string, unknown>) : {};
  return {
    ledger: pruneLedger(ledger, now),
    total: count(value.total),
    pending: {
      total: count(pending.total),
      week: count(pending.week),
      weekStart: typeof pending.weekStart === "string" ? pending.weekStart : empty.pending.weekStart,
    },
    celebrated: typeof value.celebrated === "string" ? value.celebrated : null,
  };
}

export interface XpAward {
  state: XpState;
  /** L'XP réellement gagnée : zéro quand le plafond du jour est atteint. */
  gained: number;
  /** Vrai la première fois du jour que l'objectif est franchi : la feuille de fête s'ouvre. */
  reachedGoal: boolean;
}

/** Un geste récompensé : le journal, le total, le reste à monter, et peut-être la fête du jour. */
export function applyAward(state: XpState, reason: XpReason, now: Date): XpAward {
  const before = xpToday(state.ledger, now);
  const ledger = pruneLedger(addXp(state.ledger, XP_REWARDS[reason], now), now);
  const gained = xpToday(ledger, now) - before;
  if (gained <= 0) return { state, gained: 0, reachedGoal: false };
  const week = weekStart(now);
  const today = dayKey(now);
  const reachedGoal = before < DAILY_XP_GOAL && before + gained >= DAILY_XP_GOAL && state.celebrated !== today;
  return {
    gained,
    reachedGoal,
    state: {
      ledger,
      total: state.total + gained,
      pending: {
        total: state.pending.total + gained,
        week: (state.pending.weekStart === week ? state.pending.week : 0) + gained,
        weekStart: week,
      },
      celebrated: reachedGoal ? today : state.celebrated,
    },
  };
}

export interface XpSnapshot {
  today: number;
  week: number;
  total: number;
  league: LeagueId;
}

export function xpSnapshot(state: XpState, now: Date): XpSnapshot {
  const week = xpThisWeek(state.ledger, now);
  return { today: xpToday(state.ledger, now), week, total: state.total, league: leagueFor(week) };
}

/** Les bornes de `profiles_xp_bounds` (migration `20261110120000_xp_league.sql`). */
export const XP_TOTAL_MAX = 100_000_000;
export const XP_WEEK_MAX = 35_000;

/** La ligne `profiles` telle que la synchro la lit. */
export interface RemoteXp {
  xp_total: number | null;
  xp_week: number | null;
  xp_week_start: string | null;
}

/**
 * **Ce qui monte** : la ligne lue, plus ce que ce navigateur a gagné depuis la dernière synchro.
 * Le téléphone écrit la même ligne ; l'XP de ce navigateur n'y est jamais comptée moins que ce
 * qu'il sait lui-même (le `max`), et une semaine finie repart de zéro.
 */
export function mergeRemote(remote: RemoteXp | null, state: XpState, now: Date): { xp_total: number; xp_week: number; xp_week_start: string } {
  const week = weekStart(now);
  const local = xpSnapshot(state, now);
  const remoteWeek = remote?.xp_week_start === week ? count(remote?.xp_week) : 0;
  const pendingWeek = state.pending.weekStart === week ? state.pending.week : 0;
  return {
    xp_total: Math.min(XP_TOTAL_MAX, Math.max(count(remote?.xp_total) + state.pending.total, local.total)),
    xp_week: Math.min(XP_WEEK_MAX, Math.max(remoteWeek + pendingWeek, local.week)),
    xp_week_start: week,
  };
}

/** Une erreur de PostgREST qui dit que les colonnes `xp_*` n'existent pas encore. */
export function isMissingXpColumn(error: { code?: string | null; message?: string | null } | null | undefined): boolean {
  if (!error) return false;
  const message = error.message ?? "";
  return /xp_/i.test(message) || error.code === "42703" || error.code === "PGRST204";
}

/** Les jours qui restent avant lundi minuit, heure locale : la fin de la ligue. */
export function daysUntilWeekEnd(now: Date): number {
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const offset = (monday.getDay() + 6) % 7;
  monday.setDate(monday.getDate() - offset + 7);
  return Math.max(1, Math.ceil((monday.getTime() - now.getTime()) / 86_400_000));
}
