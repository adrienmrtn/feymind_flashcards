import { describe, expect, it } from "vitest";

import {
  displayUsername,
  normalizeUsername,
  validateUsername,
} from "../src/username";

describe("le nom d'utilisateur", () => {
  it("plie les accents et les espaces", () => {
    expect(normalizeUsername("Adrien Martinot")).toBe("adrien-martinot");
    expect(normalizeUsername("Zoé_92")).toBe("zoe_92");
    expect(normalizeUsername("Çağrı")).toBe("cagri");
    expect(normalizeUsername("_-_martin")).toBe("martin");
  });

  it("refuse ce qui est trop court une fois normalisé", () => {
    expect(validateUsername("ab").ok).toBe(false);
    expect(validateUsername("   ").ok).toBe(false);
  });

  it("accepte un nom déjà propre", () => {
    expect(validateUsername("adrien")).toEqual({ ok: true, value: "adrien" });
  });

  it("précède le nom d'une arobase", () => {
    expect(displayUsername("adrien")).toBe("@adrien");
    expect(displayUsername("@adrien")).toBe("@adrien");
  });
});
