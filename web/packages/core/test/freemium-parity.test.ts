/**
 * **Le test qui empêche les deux clients de dire deux choses.**
 *
 * Le verrou du gratuit existe deux fois : `src/entitlement.ts` pour le web,
 * `Micabo/Services/ProAccess.swift` pour l'app. Les tests de chacun vérifient déjà leurs
 * propres nombres — mais ils les vérifient **séparément**, donc rien n'empêchait le web de
 * passer à `false` et l'iPhone de rester à `true`. C'est exactement ce qui est arrivé, et le
 * symptôme n'a rien d'évident : le même cours est flouté sur le site et entier sur le
 * téléphone, et personne ne signale un bug qui lui donne plus.
 *
 * Ici on relit le Swift et on compare. Une divergence tombe au prochain `pnpm test`.
 */

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { ASSUME_PRO_WITHOUT_ROW, ENTITLEMENT_ID, FREE_TIER } from "../src/entitlement";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../../..");

const proAccess = readFileSync(resolve(repoRoot, "Micabo/Services/ProAccess.swift"), "utf8");
const purchases = readFileSync(
  resolve(repoRoot, "Micabo/Features/Paywall/PaywallPurchases.swift"),
  "utf8",
);

/** La valeur d'un `static let` Swift, telle qu'elle est écrite. */
function swiftConstant(source: string, name: string): string {
  const found = source.match(new RegExp(`static let ${name}\\s*=\\s*([^\\n]+)`));
  if (!found?.[1]) throw new Error(`\`${name}\` introuvable dans le Swift`);
  return found[1].trim().replace(/\s*\/\/.*$/, "");
}

describe("le gratuit, des deux côtés", () => {
  it("traite pareil quelqu'un sans ligne dans entitlements", () => {
    // **La divergence la plus coûteuse du produit.** À `true` d'un côté et `false` de
    // l'autre, le site fait payer et le téléphone offre.
    expect(swiftConstant(proAccess, "assumeProWithoutRow")).toBe(String(ASSUME_PRO_WITHOUT_ROW));
  });

  it("compte le même nombre de cours, de cartes et la même coupure", () => {
    expect(swiftConstant(proAccess, "courses")).toBe(String(FREE_TIER.courses));
    expect(swiftConstant(proAccess, "cardsPerSession")).toBe(String(FREE_TIER.cardsPerSession));
    expect(swiftConstant(proAccess, "readableSheetRatio")).toBe(
      String(FREE_TIER.readableSheetRatio),
    );
    expect(swiftConstant(proAccess, "allowsPractice")).toBe(String(FREE_TIER.allowsPractice));
  });

  it("lit le même entitlement RevenueCat", () => {
    // Trois endroits nomment cette chaîne : ici, le Swift, et le webhook. Un nom qui
    // diverge donne un abonné que personne ne reconnaît.
    expect(swiftConstant(purchases, "id")).toBe(`"${ENTITLEMENT_ID}"`);
  });
});

describe("le branchement RevenueCat de l'app", () => {
  it("n'ouvre Pro que sur un achat confirmé", () => {
    // `unavailable` veut dire « je n'ai pas pu vendre ». L'accepter comme un achat ferait
    // de chaque panne de réseau un abonnement gratuit — c'est ce que faisaient les deux
    // paywalls tant qu'aucune boutique n'existait.
    for (const file of ["Features/Paywall/PaywallFlowView.swift", "Features/Paywall/SessionPaywallView.swift"]) {
      const source = readFileSync(resolve(repoRoot, "Micabo", file), "utf8");
      expect(source).not.toContain("case .purchased, .unavailable:");
    }
  });

  it("compile sans le paquet, et s'allume avec", () => {
    // Le paquet s'ajoute dans Xcode. Sans ce garde, le dépôt ne compilerait plus entre
    // l'écriture de ce fichier et l'ouverture de Xcode.
    expect(purchases).toContain("#if canImport(RevenueCat)");
  });

  it("identifie par l'auth.users.id de Supabase, jamais un anonyme", () => {
    // C'est **la** ligne du droit multiplateforme : un achat parti sous un
    // `$RCAnonymousID` se fait refuser par le webhook (422).
    expect(purchases).toContain("Purchases.shared.logIn(wanted)");
    expect(purchases).toContain("uuidString.lowercased()");
  });
});
