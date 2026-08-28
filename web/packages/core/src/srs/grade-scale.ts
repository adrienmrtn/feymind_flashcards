/**
 * La note qu'on vise, à la place d'une intensité abstraite.
 *
 * Le curseur est **fluide** : 10, 11, 12… jusqu'à 20, ou l'équivalent du
 * bulletin local. L'intensité (deux, trois ou quatre passages) se déduit
 * ensuite : 10–13 léger, 14–17 standard, au-delà intensif.
 */

import { countryFor, type CountryCode } from "../onboarding/countries";
import type { ExamIntensity } from "./exam";

export const TARGET_SCORE_MIN = 10;
export const TARGET_SCORE_MAX = 20;
export const DEFAULT_TARGET_SCORE = 15;

export interface DesiredGradeScale {
  min: string;
  mid: string;
  max: string;
}

/** Une position du curseur : le score canonique 10–20, et ce qu'on lit. */
export interface GradeTick {
  score: number;
  label: string;
}

export function clampTargetScore(score: number): number {
  const rounded = Number.isFinite(score) ? Math.round(score) : DEFAULT_TARGET_SCORE;
  return Math.min(TARGET_SCORE_MAX, Math.max(TARGET_SCORE_MIN, rounded));
}

/**
 * 10–13 : deux passages. 14–17 : trois. Au-delà : quatre.
 *
 * Les autres systèmes se ramènent à cette même droite : le curseur a onze
 * crans partout, c'est le libellé qui change.
 */
export function intensityFromTargetScore(score: number): ExamIntensity {
  const n = clampTargetScore(score);
  if (n <= 13) return "light";
  if (n <= 17) return "standard";
  return "intense";
}

/** Quand on n'a que l'ancien palier, on reprend le milieu de sa bande. */
export function targetScoreFromIntensity(intensity: ExamIntensity): number {
  if (intensity === "light") return 12;
  if (intensity === "intense") return 19;
  return 15;
}

export function desiredGradeScale(country?: string | null): DesiredGradeScale {
  const ticks = gradeTicks(country);
  return {
    min: ticks[0]!.label,
    mid: ticks[5]!.label,
    max: ticks[ticks.length - 1]!.label,
  };
}

export function gradeTicks(country?: string | null): GradeTick[] {
  const labels = labelsFor(countryFor(country).code);
  return labels.map((label, index) => ({
    score: TARGET_SCORE_MIN + index,
    label,
  }));
}

export function desiredGradeLabel(
  scoreOrIntensity: number | ExamIntensity,
  country?: string | null,
): string {
  const score =
    typeof scoreOrIntensity === "number"
      ? clampTargetScore(scoreOrIntensity)
      : targetScoreFromIntensity(scoreOrIntensity);
  return gradeTicks(country)[score - TARGET_SCORE_MIN]!.label;
}

export function gradeIndexFor(intensity: ExamIntensity): number {
  return targetScoreFromIntensity(intensity) - TARGET_SCORE_MIN;
}

export function intensityFromGradeIndex(index: number): ExamIntensity {
  return intensityFromTargetScore(TARGET_SCORE_MIN + index);
}

function labelsFor(code: CountryCode): string[] {
  switch (code) {
    case "fr":
    case "be":
    case "ma":
    case "dz":
    case "tn":
    case "sn":
    case "ci":
    case "pt":
    case "gr":
      return range(10, 20).map((n) => `${n}/20`);
    case "us":
    case "other":
      return ["C-", "C-", "C", "C+", "B-", "B", "B+", "A-", "A", "A", "A+"];
    case "uk":
      return ["C", "C", "C", "B", "B", "B", "A", "A", "A", "A*", "A*"];
    case "se":
      return ["E", "E", "D", "D", "C", "C", "B", "B", "A", "A", "A"];
    case "ca":
    case "tr":
      return range(10, 20).map((n) => `${60 + (n - 10) * 4} %`);
    case "de":
      return ["4,0", "3,7", "3,3", "3,0", "2,7", "2,3", "2,0", "1,7", "1,3", "1,0", "1,0"];
    case "ch":
      return ["4", "4", "4,5", "4,5", "5", "5", "5,5", "5,5", "6", "6", "6"];
    case "it":
    case "es":
      return ["6/10", "6/10", "7/10", "7/10", "8/10", "8/10", "9/10", "9/10", "10/10", "10/10", "10/10"];
    case "lu":
      return range(10, 20).map((n) => `${30 + (n - 10) * 3}/60`);
    case "cz":
      return ["4", "4", "3", "3", "3", "2", "2", "2", "1", "1", "1"];
    case "nl":
      return ["6", "6", "7", "7", "8", "8", "9", "9", "10", "10", "10"];
    case "hu":
    case "pl":
      return ["3", "3", "3", "3", "4", "4", "4", "4", "5", "5", "5"];
    case "ro":
      return ["5", "5", "6", "6", "7", "8", "8", "9", "9", "10", "10"];
  }
}

function range(from: number, to: number): number[] {
  return Array.from({ length: to - from + 1 }, (_, index) => from + index);
}
