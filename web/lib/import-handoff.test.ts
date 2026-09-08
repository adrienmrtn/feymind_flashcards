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

  it("ignore une valeur illisible", () => {
    expect(parseImportHandoff(null)).toBeNull();
    expect(parseImportHandoff("{")).toBeNull();
    expect(parseImportHandoff(JSON.stringify({ courseId: "abc" }))).toBeNull();
  });
});
