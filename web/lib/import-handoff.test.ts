import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { parseImportHandoff } from "./import-handoff";

const here = dirname(fileURLToPath(import.meta.url));
const handoff = readFileSync(resolve(here, "./import-handoff.ts"), "utf8");

describe("le relais d'import", () => {
  it("lit le nom du document pendant l'écriture", () => {
    expect(parseImportHandoff(JSON.stringify({ name: "Cours.pdf" }))).toEqual({
      name: "Cours.pdf",
    });
  });

  it("garde l'identifiant du cours une fois qu'on l'a", () => {
    expect(
      parseImportHandoff(JSON.stringify({ name: "Cours.pdf", courseId: "abc" })),
    ).toEqual({ name: "Cours.pdf", courseId: "abc" });
  });

  it("garde l'instant de départ pour le pourcentage", () => {
    expect(
      parseImportHandoff(JSON.stringify({ name: "Cours.pdf", startedAt: 1_700_000_000_000 })),
    ).toEqual({ name: "Cours.pdf", startedAt: 1_700_000_000_000 });
  });

  it("ignore une valeur illisible", () => {
    expect(parseImportHandoff(null)).toBeNull();
    expect(parseImportHandoff("{")).toBeNull();
    expect(parseImportHandoff(JSON.stringify({ courseId: "abc" }))).toBeNull();
  });

  it("ouvre la fiche par un chargement complet, hors du routeur", () => {
    expect(handoff).toContain("HTMLFormElement.prototype.submit.call(form)");
    expect(handoff).toContain("/api/open-course");
    expect(handoff).toContain("waitForPaint");
    expect(handoff).toContain("recoverGeneratedCourseIfAny");
    expect(handoff).not.toMatch(/window\.stop\(\)/);
    expect(handoff).not.toMatch(/location\.assign\(/);
    expect(handoff).not.toMatch(/window\.location\.href\s*=/);
  });
});
