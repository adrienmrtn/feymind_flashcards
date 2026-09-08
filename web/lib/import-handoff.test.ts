import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { isGeneratedPagePath, parseImportHandoff } from "./import-handoff";

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

  it("n'ouvre que les pages de fiche, cartes ou paquet", () => {
    expect(isGeneratedPagePath("/app/c/47ef38c8-368b-4545-8330-c85cd2f7231a")).toBe(true);
    expect(isGeneratedPagePath("/app/c/47ef38c8-368b-4545-8330-c85cd2f7231a/cartes")).toBe(
      true,
    );
    expect(isGeneratedPagePath("/app/paquets/47ef38c8-368b-4545-8330-c85cd2f7231a")).toBe(
      true,
    );
    expect(isGeneratedPagePath("/app/importer")).toBe(false);
    expect(isGeneratedPagePath("/app")).toBe(false);
  });

  it("ouvre la fiche en quittant le document App Router", () => {
    expect(handoff).toContain("HTMLFormElement.prototype.submit");
    expect(handoff).toContain("waitForPaint");
    expect(handoff).toContain("LAST_WRITTEN_COURSE_KEY");
    expect(handoff).toContain("beginStandaloneWrite");
    expect(handoff).not.toMatch(/window\.location\.href\s*=/);
    expect(handoff).not.toContain("/api/open-course");
  });
});
