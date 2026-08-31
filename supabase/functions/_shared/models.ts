/**
 * Le modèle est décidé ici, pas par le client.
 *
 * Un identifiant de modèle qui arrive dans le corps de la requête est une invitation à
 * facturer le plus cher. La liste ci-dessous est la seule que fal.ai a le droit de voir.
 */

export const DEFAULT_MODEL = "google/gemini-flash-1.5";

const ALLOWED = new Set([
  "google/gemini-flash-1.5",
  "google/gemini-flash-1.5-8b",
  "google/gemini-2.0-flash-001",
  "google/gemini-2.5-flash-lite",
  "openai/gpt-4o-mini",
]);

/** Un identifiant connu, sinon le modèle par défaut. Tout le reste est ignoré. */
export function resolveModel(requested?: string): string {
  const normalized = (requested ?? "").trim();
  if (normalized.length > 0 && ALLOWED.has(normalized)) return normalized;
  return DEFAULT_MODEL;
}

export function isAllowedModel(requested: string): boolean {
  return ALLOWED.has(requested.trim());
}
