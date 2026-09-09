/**
 * Ce qui reste du relais : l'ouverture de la page écrite.
 *
 * Le voile plein écran et son magasin de session sont partis avec l'écriture hors de Next, donc
 * les tests qui lisaient un état relayé n'ont plus d'objet. Restent les deux choses qui, elles,
 * cassent l'ouverture si on les touche : la liste des pages qu'on accepte d'ouvrir, et le fait
 * qu'on ouvre par un formulaire natif plutôt que par le routeur.
 */

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { isGeneratedPagePath } from "./import-handoff";

const here = dirname(fileURLToPath(import.meta.url));
const handoff = readFileSync(resolve(here, "./import-handoff.ts"), "utf8");

describe("le relais d'import", () => {
  it("n'ouvre que les pages de fiche, cartes ou paquet", () => {
    expect(isGeneratedPagePath("/app/c/47ef38c8-368b-4545-8330-c85cd2f7231a")).toBe(true);
    expect(isGeneratedPagePath("/app/c/47ef38c8-368b-4545-8330-c85cd2f7231a/cartes")).toBe(true);
    expect(isGeneratedPagePath("/app/paquets/47ef38c8-368b-4545-8330-c85cd2f7231a")).toBe(true);
    expect(isGeneratedPagePath("/app/importer")).toBe(false);
    expect(isGeneratedPagePath("/app")).toBe(false);
  });

  it("ouvre la fiche par une vraie navigation, pas par le routeur", () => {
    expect(handoff).toContain("HTMLFormElement.prototype.submit");
    expect(handoff).toContain("waitForPaint");
    expect(handoff).not.toMatch(/window\.location\.href\s*=/);
    expect(handoff).not.toContain("/api/open-course");
  });

  it("ne relaie plus rien par le stockage de session", () => {
    expect(handoff).not.toContain("sessionStorage");
    expect(handoff).not.toContain("document.write");
  });
});
