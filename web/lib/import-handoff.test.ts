import { describe, expect, it } from "vitest";

import { parseImportHandoff } from "./import-handoff";

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
});
