/**
 * Le temps qu'on a vraiment, jour par jour.
 *
 * Le plan d'examen répartissait la charge sur une fenêtre continue, comme si chaque journée
 * valait la précédente. Ce n'est vrai de personne : il y a des mardis à deux heures de trou et
 * des samedis à zéro. Sans cette couche, la projection annonce « 24 cartes par jour » à
 * quelqu'un qui n'ouvrira pas l'app le week-end, et le plan se défait au premier samedi.
 *
 * Deux niveaux, dans cet ordre : la **semaine type** dit ce qu'un lundi vaut en général,
 * l'**exception** écrase une date précise. Un jour à zéro minute est un jour off, et c'est le
 * cas le plus fréquent.
 *
 * L'unité est la minute partout, parce que c'est la seule que l'étudiant sait estimer. Les
 * cartes s'y convertissent par `CARDS_PER_MINUTE`, déjà utilisé par le rythme quotidien.
 */

import { CARDS_PER_MINUTE, DEFAULT_DAILY_MINUTES } from "./daily-load";
import { addDays, dayDifference, startOfDay } from "./exam";

/** Sept valeurs en minutes, **lundi en premier**, comme le calendrier de l'app. */
export type WeeklyMinutes = readonly [number, number, number, number, number, number, number];

/** Une date précise qui écrase la semaine type. Zéro minute = jour off. */
export interface AvailabilityException {
  /** Jour local, au début de la journée. */
  day: Date;
  minutes: number;
}

export interface Availability {
  weekly: WeeklyMinutes;
  exceptions: readonly AvailabilityException[];
}

export const MAX_DAILY_MINUTES = 600;

/** Le libellé des sept jours, lundi en premier, dans l'ordre du tableau. */
export const WEEKDAY_ORDER: readonly number[] = [1, 2, 3, 4, 5, 6, 0];

/**
 * La semaine type d'un compte qui n'a rien réglé : le rythme quotidien, tous les jours.
 *
 * C'est le comportement d'avant cette couche, à la minute près. Personne n'a besoin de
 * remplir « Mes semaines » pour que le plan marche - le réglage sert à le rendre juste.
 */
export function uniformWeek(dailyMinutes: number = DEFAULT_DAILY_MINUTES): WeeklyMinutes {
  const value = clampMinutes(dailyMinutes);
  return [value, value, value, value, value, value, value];
}

export function clampMinutes(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(MAX_DAILY_MINUTES, Math.round(value)));
}

/** Une valeur venue de la base, qui peut être absente, trop courte ou trop longue. */
export function weeklyFromRow(
  row: readonly number[] | null | undefined,
  fallbackMinutes: number = DEFAULT_DAILY_MINUTES,
): WeeklyMinutes {
  if (!row || row.length !== 7) return uniformWeek(fallbackMinutes);
  const values = row.map(clampMinutes);
  return [
    values[0]!,
    values[1]!,
    values[2]!,
    values[3]!,
    values[4]!,
    values[5]!,
    values[6]!,
  ];
}

/** Index dans `WeeklyMinutes` d'une date : lundi vaut 0, dimanche vaut 6. */
export function weekdayIndex(date: Date): number {
  return (date.getDay() + 6) % 7;
}

/** Les minutes disponibles un jour donné : la semaine type, écrasée par l'exception. */
export function capacityFor(availability: Availability, date: Date): number {
  const day = startOfDay(date);
  for (const exception of availability.exceptions) {
    if (startOfDay(exception.day).getTime() === day.getTime()) {
      return clampMinutes(exception.minutes);
    }
  }
  return clampMinutes(availability.weekly[weekdayIndex(day)] ?? 0);
}

/**
 * Les capacités d'une fenêtre, en minutes, indexées par décalage depuis `from`.
 *
 * C'est ce que le planificateur consomme : il ne connaît ni les semaines ni les vacances, il
 * connaît un tableau de minutes.
 */
export function capacityWindow(
  availability: Availability,
  from: Date,
  days: number,
): number[] {
  const start = startOfDay(from);
  const window: number[] = [];
  for (let offset = 0; offset < Math.max(0, days); offset += 1) {
    window.push(capacityFor(availability, addDays(start, offset)));
  }
  return window;
}


/** Le temps que coûte un nombre de passages, arrondi à la minute supérieure. */
export function minutesForCards(cards: number): number {
  if (cards <= 0) return 0;
  return Math.max(1, Math.ceil(cards / CARDS_PER_MINUTE));
}

/** Le total hebdomadaire, pour l'annoncer sous les sept curseurs. */
export function weeklyTotal(weekly: WeeklyMinutes): number {
  return weekly.reduce((sum, value) => sum + clampMinutes(value), 0);
}


/**
 * Combien de jours utilisables séparent aujourd'hui d'une date.
 *
 * C'est le chiffre honnête à afficher quand quelqu'un demande « il me reste combien de temps ».
 * « 12 jours » et « 5 jours ouvrables » ne se préparent pas pareil.
 */
export function usableDaysUntil(
  availability: Availability,
  from: Date,
  to: Date,
): number {
  const span = dayDifference(from, to);
  if (span <= 0) return 0;
  return capacityWindow(availability, from, span).filter((minutes) => minutes > 0).length;
}
