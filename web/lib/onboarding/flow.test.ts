import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { STEPS } from "./steps";

/**
 * **L'ordre du parcours vit dans `STEPS`, et nulle part ailleurs.**
 *
 * Ce test existe pour une panne précise, et elle a coûté une version. Chaque écran nommait sa
 * suite en dur dans son `ContinueButton`. Quatre écrans se sont insérés après les matières ;
 * l'écran des matières, lui, a continué d'appeler le chargement. Les quatre existaient, se
 * routaient, s'affichaient au retour arrière - et personne ne les voyait jamais à l'aller.
 *
 * Rien dans les types ne pouvait le dire : une chaîne littérale reste un chemin valide même
 * quand l'ordre a changé sous elle. Il fallait donc un test qui lise le code, et il ne
 * cherche qu'une chose : un écran de parcours qui décide de sa suite tout seul.
 */

const SCREENS = join(process.cwd(), "app", "commencer");

/**
 * Les pages qui ont le droit de nommer un chemin, et pourquoi.
 *
 * Ce ne sont pas des écrans du parcours : ce sont d'anciennes adresses qui redirigent, l'entrée
 * du tunnel, et la page de compte qui renvoie en arrière plutôt qu'en avant.
 */
const ALLOWED = new Set([
  "bienvenue", // l'entrée : elle ouvre le tunnel depuis la vitrine
  "cartes",
  "comment",
  "compte",
  "demo",
  "fiches",
  "parcours", // le chargement décide entre le compte et l'app, selon la session
  "retention",
  "reussir",
]);

describe("l'ordre du parcours", () => {
  it("n'est écrit que dans STEPS", () => {
    const guilty: string[] = [];

    for (const entry of readdirSync(SCREENS, { withFileTypes: true })) {
      if (!entry.isDirectory() || ALLOWED.has(entry.name)) continue;
      const source = readFileSync(join(SCREENS, entry.name, "page.tsx"), "utf8");
      if (/\b(href|next)=["{]\s*"?\/commencer\//.test(source)) guilty.push(entry.name);
    }

    expect(guilty).toEqual([]);
  });

  it("couvre tous les écrans qui existent", () => {
    const onDisk = readdirSync(SCREENS, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => `/commencer/${entry.name}`);
    const known = new Set<string>(STEPS.map((step) => step.path));

    // Un écran sur le disque qui n'est pas une étape est soit une redirection, soit un écran
    // qu'on a écrit et oublié de brancher - ce qui vient d'arriver quatre fois d'un coup.
    const orphans = onDisk.filter((path) => !known.has(path));
    for (const path of orphans) {
      const source = readFileSync(join(SCREENS, path.split("/").pop()!, "page.tsx"), "utf8");
      expect(source, `${path} n'est pas une étape et ne redirige pas`).toMatch(/redirect\(/);
    }
  });
});
