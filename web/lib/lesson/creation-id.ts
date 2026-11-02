import type { LessonCreation } from "@micabo/core";

/**
 * **L'identifiant d'une leçon en cours de création, gardé d'un chargement à l'autre.**
 *
 * Le serveur réserve la leçon offerte sous cet identifiant (`begin_lesson`) dès le premier
 * appel du plan. `LessonCreationFlow` le tirait au montage : un plan trop long, une page
 * rechargée, et le « Réessayer » partait sous un identifiant neuf — une seconde leçon, que la
 * porte refusait (`free_limit`) puisque la première était réservée. Ici, le même brouillon
 * (même sujet, même texte, mêmes supports) retrouve le même identifiant dans l'onglet, et le
 * nouvel essai reprend la réservation au lieu d'en ouvrir une autre.
 *
 * `sessionStorage` et non `localStorage` : l'identifiant ne vaut que pour cet onglet et cette
 * tentative. Il est oublié dès que la leçon est créée — le même sujet, demandé plus tard, est
 * une autre leçon — et ne survit pas plus d'une journée.
 */

export const CREATION_ID_PREFIX = "micabo.lesson-creation.";

/** Au-delà, ce n'est plus une reprise : la réservation du serveur est rendue depuis longtemps. */
export const CREATION_ID_TTL_MS = 24 * 60 * 60 * 1000;

/** Ce que lit et écrit ce module : `sessionStorage`, ou son double dans les tests. */
export type CreationStorage = Pick<Storage, "getItem" | "setItem" | "removeItem">;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * La clé du brouillon : une empreinte de ce qui part au serveur, pas le texte lui-même — un
 * polycopié collé ou des photos ne tiennent pas dans une clé de `sessionStorage`. Deux FNV-1a
 * de 32 bits côte à côte : une collision ne coûterait qu'une reprise de la mauvaise
 * réservation, dans le même onglet.
 */
export function creationKey(creation: LessonCreation): string {
  const material = JSON.stringify([
    creation.topic ?? null,
    creation.text,
    creation.source,
    creation.sourceName ?? "",
    creation.images,
  ]);
  return `${CREATION_ID_PREFIX}${fnv1a(material, 0x811c9dc5)}${fnv1a(material, 0x01000193)}`;
}

function fnv1a(text: string, seed: number): string {
  let hash = seed >>> 0;
  for (let index = 0; index < text.length; index += 1) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
}

/** `sessionStorage` quand il existe et répond ; `null` en navigation privée bloquée ou au serveur. */
export function sessionCreationStorage(): CreationStorage | null {
  try {
    return typeof window === "undefined" ? null : window.sessionStorage;
  } catch {
    return null;
  }
}

/**
 * L'identifiant de ce brouillon : celui déjà tiré dans cet onglet s'il est récent, sinon un
 * neuf, aussitôt retenu. Sans stockage, un identifiant neuf - comme avant.
 */
export function lessonIdForCreation(
  creation: LessonCreation,
  storage: CreationStorage | null = sessionCreationStorage(),
  options: { now?: number; make?: () => string } = {},
): string {
  const now = options.now ?? Date.now();
  const make = options.make ?? (() => crypto.randomUUID());
  const key = creationKey(creation);
  const kept = read(storage, key, now);
  if (kept) return kept;
  const id = make();
  try {
    storage?.setItem(key, JSON.stringify({ id, at: now }));
  } catch {
    // Un stockage plein ou refusé : l'identifiant vaut pour cette page, c'est déjà ça.
  }
  return id;
}

/** La leçon est créée : le même brouillon, plus tard, sera une autre leçon. */
export function forgetCreation(
  creation: LessonCreation,
  storage: CreationStorage | null = sessionCreationStorage(),
): void {
  try {
    storage?.removeItem(creationKey(creation));
  } catch {
    // Rien à faire : l'entrée expirera d'elle-même.
  }
}

function read(storage: CreationStorage | null, key: string, now: number): string | null {
  try {
    const raw = storage?.getItem(key);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { id?: unknown; at?: unknown };
    if (typeof parsed.id !== "string" || !UUID.test(parsed.id)) return null;
    if (typeof parsed.at !== "number" || now - parsed.at > CREATION_ID_TTL_MS) return null;
    return parsed.id;
  } catch {
    return null;
  }
}
