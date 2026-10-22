import { normalizeIcon } from "./icons";
import { uniqueSymbols } from "./symbols";
import type { LessonPath } from "./types";

/**
 * **Le plan rendu par `generate-lesson` (stage `plan`)**, lu sans jamais faire confiance au
 * réseau, et le chemin qu'on en écrit. Jumeau de `LessonPlanResult` et de
 * `LessonBuilder.insertLesson` côté Swift.
 */

export interface PlanTheme {
  title: string;
  icon: string;
  symbol: string;
  points: string[];
}

export interface LessonPlanPayload {
  title: string;
  subject: string;
  icon: string;
  themes: PlanTheme[];
  groups: { name: string; themes: number[] }[];
  intro: { lines: string[]; minutes: number };
  takeaways: string[];
  shortened: boolean;
  singleQuiz: boolean;
  /** Le texte de référence des thèmes, rendu avec le plan ; vide pour un sujet. */
  contextText: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string" && item.trim().length > 0) : [];
}

/** Le corps de la réponse du serveur : `{ plan, contextText }`. `null` sans plan lisible. */
export function readPlanResponse(raw: unknown): LessonPlanPayload | null {
  if (!isRecord(raw) || !isRecord(raw.plan)) return null;
  const plan = raw.plan;
  const themes: PlanTheme[] = (Array.isArray(plan.themes) ? plan.themes : [])
    .filter(isRecord)
    .map((theme) => ({
      title: typeof theme.title === "string" ? theme.title.trim() : "",
      icon: normalizeIcon(theme.icon),
      symbol: typeof theme.symbol === "string" ? theme.symbol : "",
      points: strings(theme.points),
    }))
    .filter((theme) => theme.title.length > 0);
  if (themes.length === 0 || typeof plan.title !== "string") return null;

  const groups = (Array.isArray(plan.groups) ? plan.groups : [])
    .filter(isRecord)
    .map((group) => ({
      name: typeof group.name === "string" ? group.name.trim() : "",
      themes: (Array.isArray(group.themes) ? group.themes : []).filter((index): index is number => Number.isInteger(index) && index >= 0 && index < themes.length),
    }))
    .filter((group) => group.themes.length > 0);
  const intro = isRecord(plan.intro) ? plan.intro : {};
  return {
    title: plan.title.trim(),
    subject: typeof plan.subject === "string" ? plan.subject.trim() : "",
    icon: normalizeIcon(plan.icon),
    themes,
    groups,
    intro: {
      lines: strings(intro.lines),
      minutes: typeof intro.minutes === "number" && Number.isFinite(intro.minutes) ? Math.max(0, Math.round(intro.minutes)) : 0,
    },
    takeaways: strings(plan.takeaways),
    shortened: plan.shortened === true,
    singleQuiz: plan.singleQuiz === true,
    contextText: typeof raw.contextText === "string" ? raw.contextText : "",
  };
}

/** Le chemin d'une leçon qui vient d'être planifiée : ses thèmes s'écrivent encore. */
export function pathFromPlan(plan: LessonPlanPayload): LessonPath {
  return {
    version: 1,
    icon: plan.icon,
    intro: plan.intro,
    takeaways: plan.takeaways,
    groups: plan.groups,
    shortened: plan.shortened,
    singleQuiz: plan.singleQuiz,
    status: "generating",
    symbols: uniqueSymbols(plan.themes.map((theme) => theme.symbol)),
    points: plan.themes.map((theme) => theme.points),
  };
}

/** Les quatre étapes de l'écran de génération, reliées au vrai travail. */
export type GenerationStage = "reading" | "cutting" | "writing" | "questions";
export const GENERATION_STAGES: readonly GenerationStage[] = ["reading", "cutting", "writing", "questions"];
