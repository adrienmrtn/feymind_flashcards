/**
 * **La grille, sans réseau.** Tout ce qui décide d'un prix vit ici, en fonctions pures :
 * le script qui parle à App Store Connect ne fait que lire, appeler ces fonctions, et écrire.
 * C'est ce qui permet de tester la décision sans clé Apple.
 */

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const storeDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
export const repoRoot = resolve(storeDir, "..");

export function loadGrid(path = resolve(storeDir, "pricing.json")) {
  return JSON.parse(readFileSync(path, "utf8"));
}

/** Les clés d'offre, dans l'ordre du fichier : `weekly`, `yearly`, `discount`. */
export function planKeys(grid) {
  return Object.keys(grid.products);
}

/**
 * **La règle d'un pays.** Un pays listé dans un palier suit ce palier ; tout autre suit
 * l'équivalent Apple du prix de base (la France). Un pays listé deux fois est une erreur de
 * grille, pas un choix : on refuse plutôt que de prendre le premier.
 */
export function ruleFor(grid, territory) {
  if (territory === grid.base.territory) {
    return { tier: grid.base.tier, rule: "price", currency: grid.base.currency, prices: grid.base.prices, base: true };
  }
  const matches = grid.tiers.filter((tier) => tier.territories.includes(territory));
  if (matches.length > 1) {
    throw new Error(`${territory} est dans plusieurs paliers : ${matches.map((m) => m.label).join(" / ")}`);
  }
  if (matches.length === 1) return matches[0];
  return { tier: grid.base.tier, rule: "equalize", from: grid.base.territory, default: true };
}

/**
 * **D'où vient le prix d'une offre, dans un pays aligné sur un équivalent Apple.**
 *
 * Apple arrondit chaque offre séparément : l'équivalent de 3,99 € et celui de 23,99 € ne
 * tombent pas sur le même rapport. En Pologne, la remise du cadeau devenait −33 % ; au
 * Pakistan −29 % ; en Tchéquie −50 %. On n'aligne donc que la **première** offre
 * (l'hebdomadaire) ; chacune des suivantes se déduit de la précédente, **dans le même
 * pays**, avec le rapport du pays de référence — annuel = dix hebdomadaires, réduit = −40 %.
 *
 * Rend `null` pour un pays à prix écrits, et pour la première offre : elles s'alignent
 * directement.
 */
export function derivationFor(grid, rule, key) {
  if (rule.rule === "price") return null;
  const keys = planKeys(grid);
  const index = keys.indexOf(key);
  if (index <= 0) return null;
  const reference = rule.rule === "usd" ? rule.prices : ruleFor(grid, rule.from).prices;
  const from = keys[index - 1];
  return { from, factor: Number(reference[key]) / Number(reference[from]) };
}

/** Tous les pays nommés dans la grille, base comprise. */
export function namedTerritories(grid) {
  return [grid.base.territory, ...grid.tiers.flatMap((tier) => tier.territories)];
}

/** Vérifie la grille avant tout appel : un fichier incohérent ne doit rien écrire nulle part. */
export function validateGrid(grid) {
  const problems = [];
  const keys = planKeys(grid);
  const seen = new Map();
  for (const territory of namedTerritories(grid)) {
    if (!/^[A-Z]{3}$/.test(territory)) problems.push(`${territory} n'est pas un code pays à trois lettres`);
    seen.set(territory, (seen.get(territory) ?? 0) + 1);
  }
  for (const [territory, count] of seen) {
    if (count > 1) problems.push(`${territory} apparaît ${count} fois`);
  }
  for (const tier of [grid.base, ...grid.tiers]) {
    const rule = tier.rule ?? "price";
    if (rule === "price" || rule === "usd") {
      for (const key of keys) {
        const amount = Number(tier.prices?.[key]);
        if (!(amount > 0)) problems.push(`${tier.label} : pas de prix pour ${key}`);
      }
    }
    if (rule === "price" && !tier.currency) problems.push(`${tier.label} : devise manquante`);
    if (rule === "equalize" && !tier.from) problems.push(`${tier.label} : pays de référence manquant`);
    if (rule === "equalize" && tier.from && ruleFor(grid, tier.from).rule !== "price") {
      problems.push(`${tier.label} : ${tier.from} doit avoir un prix écrit pour servir de référence`);
    }
  }
  return problems;
}

/**
 * **Le palier Apple qui porte ce montant.** Apple ne vend qu'à des prix fixés d'avance
 * (environ 800 par devise). On prend le palier exact ; à défaut le plus proche, avec l'écart
 * en clair. Au-delà de `tolerance`, on refuse : un prix turc tombé sur le mauvais palier
 * vaudrait mieux une erreur qu'une facture.
 */
export function pickPricePoint(points, wanted, { tolerance = 0.1 } = {}) {
  const target = Number(wanted);
  let best = null;
  for (const point of points) {
    const price = Number(point.customerPrice);
    if (!Number.isFinite(price)) continue;
    const gap = Math.abs(price - target);
    if (!best || gap < best.gap) best = { point, gap, price };
  }
  if (!best) return { error: `aucun palier disponible pour ${wanted}` };
  const exact = best.gap < 0.005;
  const drift = best.gap / target;
  if (!exact && drift > tolerance) {
    return { error: `aucun palier proche de ${wanted} (le plus proche : ${best.point.customerPrice})` };
  }
  return {
    point: best.point,
    exact,
    warning: exact ? null : `${wanted} n'existe pas, palier le plus proche : ${best.point.customerPrice}`,
  };
}

/**
 * **Le prix en vigueur d'un pays**, parmi tous ceux qu'Apple garde (passés et à venir).
 * Le dernier dont la date de début est passée — ou absente, ce qui veut dire « depuis
 * toujours ». Les prix des paiements mensuels d'un annuel (`planType: MONTHLY`) ne comptent
 * pas : Micabo n'en vend pas.
 */
export function currentPrice(prices, today = new Date().toISOString().slice(0, 10)) {
  const live = prices
    .filter((price) => price.planType !== "MONTHLY")
    .filter((price) => !price.startDate || price.startDate <= today)
    .sort((a, b) => (a.startDate ?? "").localeCompare(b.startDate ?? ""));
  return live.at(-1) ?? null;
}

/** Un essai gratuit encore actif : pas de date de fin, ou une date de fin à venir. */
export function isActiveOffer(offer, today = new Date().toISOString().slice(0, 10)) {
  return !offer.endDate || offer.endDate >= today;
}

/** Ce que l'annuel fait économiser sur cinquante-deux semaines, en pourcentage entier. */
export function savingsPercent(prices) {
  const weekly = Number(prices.weekly) * 52;
  return Math.round((1 - Number(prices.yearly) / weekly) * 100);
}

/** Ce que le tarif réduit fait économiser sur l'annuel, en pourcentage entier. */
export function discountPercent(prices) {
  return Math.round((1 - Number(prices.discount) / Number(prices.yearly)) * 100);
}

/** Une ligne de tableau Markdown, pour le résumé de l'action. */
export function markdownTable(headers, rows) {
  const line = (cells) => `| ${cells.map((cell) => String(cell ?? "")).join(" | ")} |`;
  return [line(headers), line(headers.map(() => "---")), ...rows.map(line)].join("\n");
}
