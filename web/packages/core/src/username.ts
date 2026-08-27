/**
 * Le nom d'utilisateur : ce qui permet de se retrouver sans échanger d'adresse.
 *
 * Porté depuis `Micabo/Services/Social/Username.swift`. Les règles sont aussi dans
 * `profiles_username_shape` : la base est la seule qui tranche, celle-ci refuse tout
 * de suite au lieu d'attendre un aller-retour.
 */

export const USERNAME_MIN = 3;
export const USERNAME_MAX = 20;
export const USERNAME_SHAPE = /^[a-z0-9][a-z0-9_-]{2,19}$/;

export type UsernameProblem = "empty" | "tooShort" | "tooLong" | "invalid";

export const USERNAME_MESSAGES: Record<UsernameProblem, string> = {
  empty: "Choisis un nom d'utilisateur.",
  tooShort: "Trois caractères au minimum.",
  tooLong: "Vingt caractères au maximum.",
  invalid: "Lettres, chiffres, tirets ou soulignés.",
};

/**
 * Ramène ce qui a été tapé à la forme que la base accepte, sans jamais jeter
 * ce qui peut être sauvé. « Adrien Martinot » devient « adrien-martinot ».
 */
export function normalizeUsername(raw: string): string {
  const folded = raw
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .replace(/ı/g, "i")
    .replace(/ß/g, "ss")
    .toLowerCase();

  let result = "";
  let pendingSeparator = false;

  for (const character of folded) {
    if (/[a-z0-9_]/.test(character)) {
      if (pendingSeparator && result.length > 0) result += "-";
      pendingSeparator = false;
      result += character;
    } else {
      pendingSeparator = true;
    }
  }

  return result.replace(/^[^a-z0-9]+/, "").slice(0, USERNAME_MAX);
}

export function validateUsername(
  raw: string,
): { ok: true; value: string } | { ok: false; problem: UsernameProblem } {
  const normalized = normalizeUsername(raw);

  if (normalized.length === 0) {
    return { ok: false, problem: raw.trim().length === 0 ? "empty" : "tooShort" };
  }
  if (normalized.length < USERNAME_MIN) return { ok: false, problem: "tooShort" };
  if (normalized.length > USERNAME_MAX) return { ok: false, problem: "tooLong" };
  if (!USERNAME_SHAPE.test(normalized)) return { ok: false, problem: "invalid" };

  return { ok: true, value: normalized };
}

/** Le nom précédé de son arobase, comme on l'écrit partout. */
export function displayUsername(username: string): string {
  const trimmed = username.trim();
  if (!trimmed) return "";
  return trimmed.startsWith("@") ? trimmed : `@${trimmed}`;
}
