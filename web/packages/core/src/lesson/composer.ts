import type { LessonSource } from "./allowance";

/**
 * **Ce que l'élève prépare dans la barre de Home** : un sujet tapé, et jusqu'à cinq supports
 * lus dans le navigateur. Jumeau de `LessonComposer.swift` ; voir `docs/refonte-parcours.md`
 * § 3 et § 4. Tout est pur : l'écran tient l'état, le noyau dit ce qu'on peut envoyer et ce
 * qui part.
 */

export const MAX_SUPPORTS = 5;
/** La limite que le serveur lit : ce qui dépasse est coupé, et la leçon le signale. */
export const MAX_COMPOSER_CHARACTERS = 60_000;
/** Les pages envoyées à la passe visuelle. */
export const MAX_COMPOSER_IMAGES = 6;

export type SupportKind = "pdf" | "photo" | "audio" | "youtube" | "text";
export const SUPPORT_KINDS: readonly SupportKind[] = ["pdf", "photo", "audio", "youtube", "text"];

/** L'icône 3D de chaque support, sous la barre. */
export const SUPPORT_ICONS: Record<SupportKind, string> = {
  pdf: "pdf",
  photo: "photo",
  audio: "audio",
  youtube: "lien",
  text: "texte",
};

export type SupportState = "reading" | "ready" | "failed";

export interface ComposerSupport {
  id: string;
  kind: SupportKind;
  title: string;
  state: SupportState;
  text: string;
  /** Des pages en image (data URL), pour un PDF scanné ou des photos. */
  images: string[];
  /** Un PDF qui était en fait un Word : la source le dit. */
  docKind?: "pdf" | "docx" | "text";
  failure?: string;
}

/** Un texte collé est la leçon offerte ; tout le reste est un import. */
export function supportSource(support: Pick<ComposerSupport, "kind" | "docKind">): LessonSource {
  switch (support.kind) {
    case "pdf":
      return support.docKind === "docx" ? "docx" : "pdf";
    case "photo":
      return "photo";
    case "audio":
      return "audio";
    case "youtube":
      return "youtube";
    case "text":
      return "text";
  }
}

export function readySupports(supports: readonly ComposerSupport[]): ComposerSupport[] {
  return supports.filter((support) => support.state === "ready" && (support.text.length > 0 || support.images.length > 0));
}

/** D'où vient la leçon, pour la porte du gratuit et pour le serveur. */
export function composerSource(supports: readonly ComposerSupport[]): LessonSource {
  const kinds = new Set(readySupports(supports).map(supportSource));
  if (kinds.size === 0) return "topic";
  return kinds.size === 1 ? [...kinds][0]! : "mixed";
}

export function hasRoom(supports: readonly ComposerSupport[]): boolean {
  return supports.length < MAX_SUPPORTS;
}

export function isReading(supports: readonly ComposerSupport[]): boolean {
  return supports.some((support) => support.state === "reading");
}

/** On envoie un sujet d'au moins deux lettres, ou des supports lus. */
export function canSend(draft: string, supports: readonly ComposerSupport[]): boolean {
  if (isReading(supports)) return false;
  return readySupports(supports).length > 0 || draft.trim().length >= 2;
}

/** Ce qui part au serveur pour écrire le plan. */
export interface LessonCreation {
  topic?: string;
  text: string;
  images: string[];
  source: LessonSource;
  sourceName?: string;
}

/**
 * Tout ce qui part au serveur. Un sujet seul part comme sujet ; avec des supports, ce qui est
 * tapé devient la consigne de l'élève, en tête du texte (`instruction` la formule).
 */
export function composeCreation(
  draft: string,
  supports: readonly ComposerSupport[],
  instruction: (text: string) => string,
): LessonCreation {
  const topic = draft.trim();
  const ready = readySupports(supports);
  if (ready.length === 0) return { topic, text: "", images: [], source: "topic" };

  const parts: string[] = [];
  if (topic) parts.push(instruction(topic));
  for (const support of ready) {
    if (!support.text) continue;
    parts.push(ready.length > 1 ? `--- ${support.title} ---\n${support.text}` : support.text);
  }
  const text = parts.join("\n\n").slice(0, MAX_COMPOSER_CHARACTERS);
  const images = ready.flatMap((support) => support.images).slice(0, MAX_COMPOSER_IMAGES);
  return {
    text,
    images,
    source: composerSource(ready),
    ...(ready.length === 1 ? { sourceName: ready[0]!.title } : {}),
  };
}
