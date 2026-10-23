/**
 * Écrire une valeur dans un filtre PostgREST **sans qu'elle change le filtre**.
 *
 * `.or("title.ilike.%…%,subject.ilike.%…%")` est une petite grammaire : la virgule sépare les
 * conditions, les parenthèses les groupent, le point sépare colonne, opérateur et valeur. Une
 * recherche « Chimie (L1) » fermait donc une parenthèse qui n'était pas ouverte, et PostgREST
 * refusait toute la requête - la bibliothèque affichait « aucun cours » au lieu des résultats.
 * L'ancien correctif remplaçait `%`, `_` et `,` par des espaces ; il laissait passer `(`, `)`,
 * `"`, `\` et `:`.
 */

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Vrai pour un identifiant au format UUID - le seul qu'on interpole dans un filtre. */
export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID.test(value);
}

/**
 * Neutralise les jokers de `LIKE` : `%` et `_` cherchés sont des `%` et des `_`, pas « n'importe
 * quoi ». `\` est l'échappement par défaut de Postgres, il s'échappe lui-même.
 */
export function escapeLikePattern(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}

/**
 * Met une valeur entre guillemets pour la grammaire de PostgREST. Dans des guillemets, `,`,
 * `.`, `:`, `(` et `)` ne sont plus que des caractères ; seuls `"` et `\` s'échappent.
 */
export function quoteFilterValue(value: string): string {
  return `"${value.replace(/[\\"]/g, (char) => `\\${char}`)}"`;
}

/**
 * La valeur d'un `ilike` « contient », prête à poser dans un `.or()` :
 * `title.ilike.${ilikeContains(needle)}`.
 *
 * Deux échappements, dans cet ordre : celui de `LIKE` d'abord (le motif que Postgres lira),
 * puis celui de PostgREST (le texte qui transporte ce motif). PostgREST retire le second et
 * transmet le premier tel quel.
 */
export function ilikeContains(needle: string): string {
  return quoteFilterValue(`%${escapeLikePattern(needle)}%`);
}
