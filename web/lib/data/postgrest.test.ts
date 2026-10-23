import { describe, expect, it } from "vitest";

import { escapeLikePattern, ilikeContains, isUuid, quoteFilterValue } from "./postgrest";

describe("ilikeContains", () => {
  it("garde une recherche avec des parenthèses dans sa condition", () => {
    // « Chimie (L1) » fermait une parenthèse du `.or()` : PostgREST refusait la requête.
    expect(ilikeContains("Chimie (L1)")).toBe('"%Chimie (L1)%"');
    expect(`title.ilike.${ilikeContains("a,b.c:d")}`).toBe('title.ilike."%a,b.c:d%"');
  });

  it("échappe les jokers de LIKE puis la grammaire de PostgREST", () => {
    expect(escapeLikePattern("100%_sûr\\")).toBe("100\\%\\_sûr\\\\");
    // `\%` pour Postgres, transporté en `\\%` dans les guillemets de PostgREST.
    expect(ilikeContains("100%")).toBe('"%100\\\\%%"');
    expect(quoteFilterValue('dit "bonjour"')).toBe('"dit \\"bonjour\\""');
  });
});

describe("isUuid", () => {
  it("n'accepte qu'un identifiant", () => {
    expect(isUuid("5f0c1c1e-8a4b-4c47-9d1e-2b7a3c4d5e6f")).toBe(true);
    expect(isUuid("5F0C1C1E-8A4B-4C47-9D1E-2B7A3C4D5E6F")).toBe(true);
    expect(isUuid("x),and(requester_id.neq.0")).toBe(false);
    expect(isUuid("")).toBe(false);
    expect(isUuid(null)).toBe(false);
  });
});
