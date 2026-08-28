/**
 * La note qu'on vise, à la place d'une intensité abstraite.
 *
 * Sous le curseur, ce sont toujours les trois paliers `light` / `standard` / `intense` :
 * deux, trois ou quatre passages. Ce qui change, c'est **ce qu'on lit** : 10/20 ou C-,
 * selon le système du pays de scolarisation. Demander une intensité, c'est demander de
 * traduire ; demander une note, c'est parler la langue du bulletin.
 */

import { countryFor, type CountryCode } from "../onboarding/countries";
import type { ExamIntensity } from "./exam";

export interface DesiredGradeScale {
  /** Le plancher du curseur : la note qu'on vise sans se forcer. */
  min: string;
  /** Le cran du milieu. */
  mid: string;
  /** Le plafond : la meilleure note du système. */
  max: string;
}

/**
 * Les trois notes du curseur, dans le système du pays.
 *
 * France et voisins : 10/20 → 20/20. États-Unis : C- → A+. Les autres pays
 * gardent leur échelle (pourcentage, lettres britanniques, notes allemandes).
 */
export function desiredGradeScale(country?: string | null): DesiredGradeScale {
  switch (countryFor(country).code as CountryCode) {
    case "fr":
    case "be":
    case "ma":
    case "dz":
    case "tn":
    case "sn":
    case "ci":
    case "pt":
    case "gr":
      return { min: "10/20", mid: "15/20", max: "20/20" };
    case "us":
    case "other":
      return { min: "C-", mid: "B", max: "A+" };
    case "uk":
      return { min: "C", mid: "B", max: "A*" };
    case "se":
      return { min: "E", mid: "C", max: "A" };
    case "ca":
    case "tr":
      return { min: "60 %", mid: "80 %", max: "100 %" };
    case "de":
      return { min: "4,0", mid: "2,3", max: "1,0" };
    case "ch":
      return { min: "4", mid: "5", max: "6" };
    case "it":
    case "es":
      return { min: "6/10", mid: "8/10", max: "10/10" };
    case "lu":
      return { min: "30/60", mid: "45/60", max: "60/60" };
    case "cz":
      return { min: "4", mid: "2", max: "1" };
    case "nl":
      return { min: "6", mid: "8", max: "10" };
    case "hu":
    case "pl":
      return { min: "3", mid: "4", max: "5" };
    case "ro":
      return { min: "5", mid: "8", max: "10" };
  }
}

export function desiredGradeLabel(
  intensity: ExamIntensity,
  country?: string | null,
): string {
  const scale = desiredGradeScale(country);
  if (intensity === "light") return scale.min;
  if (intensity === "intense") return scale.max;
  return scale.mid;
}

export function gradeIndexFor(intensity: ExamIntensity): number {
  if (intensity === "light") return 0;
  if (intensity === "intense") return 2;
  return 1;
}

export function intensityFromGradeIndex(index: number): ExamIntensity {
  if (index <= 0) return "light";
  if (index >= 2) return "intense";
  return "standard";
}
