import { PATH_SYMBOLS, uniqueSymbols } from "./symbols";
import type { LessonActivity, LessonPath } from "./types";

/**
 * **Le chemin d'une leçon, toujours construit de la même façon.**
 *
 * Intro, une étape Notes par thème, un **Checkpoint** après chaque palier de thèmes (sauf le
 * dernier), puis le **Quiz final**, qui reprend toute la leçon et la conclut. Les paliers font
 * 2 thèmes, ou 3 quand la leçon en a plus de 8. Les flashcards se révisent depuis la barre du
 * bas, à leur rythme : elles ne bloquent pas le chemin.
 *
 * | Thèmes | Paliers | Étapes |
 * | --- | --- | --- |
 * | 4 | 2 · 2 | 7 |
 * | 5 | 2 · 3 | 8 |
 * | 6 | 2 · 2 · 2 | 10 |
 * | 10 | 3 · 3 · 2 · 2 | 15 |
 * | 12 | 3 · 3 · 3 · 3 | 17 |
 *
 * Jumeau de `Micabo/Models/PathLayout.swift` : une fonction pure, sans base, pour que
 * l'écran, l'app et les tests calculent le même chemin.
 */

/** Ce que le chemin a besoin de savoir d'un thème. */
export interface PathTheme {
  title: string;
  /** L'icône 3D du thème. */
  icon: string;
  /** Son pictogramme sur le chemin (`PATH_SYMBOLS`). */
  symbol: string;
}

export type PathCircleKind =
  | { type: "intro" }
  | { type: "notes"; theme: number }
  | { type: "quiz"; group: number; themes: number[] }
  | { type: "final"; themes: number[] };

export type PathCircleState = "done" | "current" | "upcoming";

/** **Une étape du chemin.** */
export interface PathCircle {
  /** Stable d'une version à l'autre : c'est la clé de la progression enregistrée. */
  id: string;
  kind: PathCircleKind;
  /** « ÉTAPE 4 » : le rang sur le chemin, à partir de 1. */
  number: number;
  title: string;
  /** L'icône 3D, pour l'en-tête de l'étape ouverte. */
  icon: string;
  /** Le pictogramme du rond, sur le chemin. */
  symbol: string;
  /** Sous le titre : le palier qu'un Checkpoint conclut. */
  subtitle: string | null;
  /** Un Checkpoint ou le Quiz final : un palier franchi, qui se fête. */
  isMilestone: boolean;
  /** L'activité que cette étape compte dans « X h de révision ». */
  activity: LessonActivity | null;
}

/** Les mots que le chemin écrit lui-même, dans la langue de l'interface. */
export interface PathLabels {
  intro: string;
  checkpoint: string;
  final: string;
}

/** Les pictogrammes des Checkpoints, un par palier : hors du catalogue des thèmes. */
export const CHECKPOINT_SYMBOLS = ["rosette", "medal", "flag.checkered", "seal", "shield.checkered", "star.circle"] as const;
export const INTRO_SYMBOL = "play.fill";
export const FINAL_SYMBOL = "trophy";
export const INTRO_ICON = "etoile";
export const QUIZ_ICON = "quiz";
export const FINAL_ICON = "trophee";

/** La taille des groupes : 2 thèmes, ou 3 au-delà de 8. */
export function groupSize(themeCount: number): number {
  return themeCount > 8 ? 3 : 2;
}

/**
 * Le découpage des thèmes en groupes, chaque groupe donnant les rangs de ses thèmes.
 *
 * Le compte ne tombe pas toujours juste : avec des groupes de 2, le dernier prend le thème en
 * trop (5 → 2 · 3) ; avec des groupes de 3, un reste de 1 coupe les quatre derniers en 2 · 2
 * (10 → 3 · 3 · 2 · 2) et un reste de 2 fait un dernier groupe de 2. Une leçon très courte n'a
 * qu'un groupe : un seul quiz pour tout.
 */
export function themeGroups(themeCount: number, singleQuiz = false): number[][] {
  if (themeCount <= 0) return [];
  if (singleQuiz) return [Array.from({ length: themeCount }, (_, index) => index)];
  const size = groupSize(themeCount);
  let sizes: number[] = Array<number>(Math.floor(themeCount / size)).fill(size);
  const rest = themeCount % size;
  if (size === 2) {
    if (rest === 1) {
      if (sizes.length === 0) sizes = [1];
      else sizes[sizes.length - 1]! += 1;
    }
  } else if (rest === 1) {
    if (sizes.length === 0) sizes = [1];
    else {
      sizes.pop();
      sizes.push(2, 2);
    }
  } else if (rest === 2) {
    sizes.push(2);
  }
  let start = 0;
  return sizes.map((count) => {
    const group = Array.from({ length: count }, (_, index) => start + index);
    start += count;
    return group;
  });
}

function circleId(kind: PathCircleKind): string {
  switch (kind.type) {
    case "intro":
      return "intro";
    case "notes":
      return `notes:${kind.theme}`;
    case "quiz":
      return `quiz:${kind.group}`;
    case "final":
      return "final";
  }
}

function activityOf(kind: PathCircleKind): LessonActivity | null {
  switch (kind.type) {
    case "notes":
      return "notes";
    case "quiz":
    case "final":
      return "quiz";
    case "intro":
      return null;
  }
}

/** Le chemin complet, dans l'ordre. `groupNames` vient du plan : le nom de chaque palier. */
export function pathCircles(
  themes: readonly PathTheme[],
  labels: PathLabels,
  options: { groupNames?: readonly string[]; singleQuiz?: boolean } = {},
): PathCircle[] {
  if (themes.length === 0) return [];
  const circles: PathCircle[] = [];
  const add = (kind: PathCircleKind, title: string, icon: string, symbol: string, subtitle: string | null = null) => {
    circles.push({
      id: circleId(kind),
      kind,
      number: circles.length + 1,
      title,
      icon,
      symbol,
      subtitle,
      isMilestone: kind.type === "quiz" || kind.type === "final",
      activity: activityOf(kind),
    });
  };

  add({ type: "intro" }, labels.intro, INTRO_ICON, INTRO_SYMBOL);
  const groups = themeGroups(themes.length, options.singleQuiz ?? false);
  groups.forEach((group, index) => {
    for (const theme of group) {
      const entry = themes[theme]!;
      add({ type: "notes", theme }, entry.title, entry.icon, entry.symbol);
    }
    if (index < groups.length - 1) {
      const name = options.groupNames?.[index]?.trim() || null;
      add({ type: "quiz", group: index, themes: group }, labels.checkpoint, QUIZ_ICON, CHECKPOINT_SYMBOLS[index % CHECKPOINT_SYMBOLS.length]!, name);
    }
  });
  add({ type: "final", themes: themes.map((_, index) => index) }, labels.final, FINAL_ICON, FINAL_SYMBOL);
  return circles;
}

/** Le chemin d'une leçon, depuis son plan et ses thèmes. */
export function lessonCircles(
  path: LessonPath,
  themes: readonly { title: string; icon: string | null }[],
  labels: PathLabels,
): PathCircle[] {
  return pathCircles(pathThemes(path, themes), labels, {
    groupNames: path.groups.map((group) => group.name),
    singleQuiz: path.singleQuiz,
  });
}

/**
 * Les thèmes, dans l'ordre du chemin, chacun avec son pictogramme : celui du plan, sinon celui
 * qui va avec son icône 3D. Jamais deux fois le même.
 */
export function pathThemes(
  path: LessonPath | null,
  themes: readonly { title: string; icon: string | null }[],
): PathTheme[] {
  const planned = path?.symbols ?? [];
  const wanted = themes.map((theme, index) => planned[index] || symbolForIcon(theme.icon ?? ""));
  const symbols = uniqueSymbols(wanted);
  return themes.map((theme, index) => ({
    title: theme.title,
    icon: theme.icon ?? "livre-ouvert",
    symbol: symbols[index] ?? PATH_SYMBOLS[0]!.id,
  }));
}

/** Le pictogramme qui va avec une icône 3D : pour une leçon d'avant les pictogrammes. */
export function symbolForIcon(id: string): string {
  switch (id) {
    case "globe": return "globe.europe.africa";
    case "fiole": return "testtube.2";
    case "parchemin": return "scroll";
    case "calculatrice": return "function";
    case "atome": return "atom";
    case "ampoule": return "lightbulb";
    case "loupe": return "magnifyingglass";
    case "puzzle": return "puzzlepiece";
    case "cerveau": return "brain.head.profile";
    case "reveil": return "clock";
    case "sablier": return "hourglass";
    case "plume": return "pencil";
    case "palette": return "paintpalette";
    case "fusee": return "sparkles";
    case "drapeau": return "flag";
    case "diplome": return "graduationcap";
    case "epingle": return "mappin.and.ellipse";
    case "coche": return "checklist";
    case "cadenas": return "lock";
    case "etoile": return "highlighter";
    case "trophee": return "chart.bar";
    case "couronne": return "crown";
    case "flamme": return "flame";
    case "examen": return "calendar";
    default: return "book";
  }
}

/** L'étape en cours : la première qui n'est pas cochée. `null` quand tout est fait. */
export function currentCircle(circles: readonly PathCircle[], done: ReadonlySet<string> | readonly string[]): PathCircle | null {
  const set = done instanceof Set ? done : new Set(done);
  return circles.find((circle) => !set.has(circle.id)) ?? null;
}

/** L'état d'une étape. On ne saute pas : tout ce qui suit l'étape en cours est à venir. */
export function circleState(
  circle: PathCircle,
  circles: readonly PathCircle[],
  done: ReadonlySet<string> | readonly string[],
): PathCircleState {
  const set = done instanceof Set ? done : new Set(done);
  if (set.has(circle.id)) return "done";
  return currentCircle(circles, set)?.id === circle.id ? "current" : "upcoming";
}

/**
 * **Une progression d'avant le Quiz final**, relue sans rien perdre : la Conclusion ou le
 * quiz du dernier palier valaient la fin de la leçon.
 */
export function migratedDone(done: readonly string[], circles: readonly PathCircle[], finished: boolean): string[] {
  const out = new Set(done);
  const last = circles[circles.length - 1];
  if (!last || last.kind.type !== "final") return [...out];
  const quizCount = circles.filter((circle) => circle.kind.type === "quiz").length;
  const lastGroupQuiz = `quiz:${Math.max(0, quizCount)}`;
  if (finished || out.has("conclusion") || out.has(lastGroupQuiz)) out.add(last.id);
  return [...out];
}

/** « 3 sur 11 étapes · 27 % ». */
export function pathProgress(circles: readonly PathCircle[], done: readonly string[]): { done: number; total: number; percent: number } {
  const set = new Set(done);
  const count = circles.filter((circle) => set.has(circle.id)).length;
  const total = circles.length;
  return { done: count, total, percent: total === 0 ? 0 : Math.round((count / total) * 100) };
}
