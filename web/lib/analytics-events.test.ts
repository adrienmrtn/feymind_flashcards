import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

/**
 * **Le vocabulaire des événements vit dans deux fichiers, et un seul les vérifie.**
 *
 * Les noms sont écrits en Swift ; la forme qu'ils ont le droit d'avoir est une contrainte
 * de Postgres. Rien, au moment de la compilation, ne relie les deux : un nom en majuscule
 * ou trop long compile parfaitement, part avec les dix-neuf autres du lot, et fait rejeter
 * **le lot entier** par la base. L'app ne dit rien d'un envoi raté — c'est sa règle — donc
 * la panne se voit à une courbe plate, des semaines plus tard.
 *
 * Ce fichier est le lien manquant. Il lit les deux fichiers du dépôt et confronte l'un à
 * l'autre, ce qui est aussi ce que font `sheet-split` et `feedback`.
 */
const root = resolve(__dirname, "../..");
const swift = readFileSync(resolve(root, "Micabo/Services/Analytics/AnalyticsEvent.swift"), "utf8");
const migration = readFileSync(
  resolve(root, "supabase/migrations/20260917220000_app_events.sql"),
  "utf8",
);

/** Les noms tels que l'app les enverra. */
const names = [...swift.matchAll(/case \w+ = "([^"]+)"/g)]
  .map((match) => match[1])
  .filter((name): name is string => Boolean(name));

/** La contrainte telle que la base l'appliquera, tirée de la migration elle-même. */
const constraint = migration.match(/check \(name ~ '([^']+)'\)/)?.[1] ?? "";

describe("les noms d'événements", () => {
  it("existent des deux côtés", () => {
    expect(names.length).toBeGreaterThan(20);
    // Vide voudrait dire que la migration a changé de forme sans que ce fichier le
    // sache — et le test suivant passerait alors sur n'importe quoi.
    expect(constraint).not.toBe("");
  });

  it("passent tous la contrainte de la table", () => {
    const pattern = new RegExp(constraint);
    const refusés = names.filter((name) => !pattern.test(name));
    expect(refusés).toEqual([]);
  });

  it("ne se répètent pas", () => {
    expect(names.length).toBe(new Set(names).size);
  });

  /**
   * Les vues du tableau de bord nomment des événements en toutes lettres. Une vue qui
   * filtrerait sur un nom que l'app n'envoie plus rend zéro ligne sans se plaindre.
   */
  it("couvrent ce que les vues du tableau de bord attendent", () => {
    const cités = [...migration.matchAll(/name = '([a-z_]+)'/g)]
      .map((match) => match[1])
      .filter((name): name is string => Boolean(name));

    expect(cités.length).toBeGreaterThan(0);
    for (const cité of cités) {
      expect(names).toContain(cité);
    }
  });

  /** L'entonnoir du paywall groupe sur ce préfixe : sans lui il compterait zéro. */
  it("gardent le préfixe sur lequel l'entonnoir du paywall groupe", () => {
    expect(migration).toContain("name like 'paywall\\_%'");
    expect(names.filter((name) => name.startsWith("paywall_")).length).toBeGreaterThanOrEqual(6);
  });
});
