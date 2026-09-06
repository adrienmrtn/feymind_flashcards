import { describe, expect, it } from "vitest";

import {
  APPEARANCES,
  DEFAULT_APPEARANCE,
  appearanceFromUnknown,
  appearanceIsDark,
  isAppearance,
} from "./appearance";

describe("l'apparence", () => {
  it("n'accepte que jour, nuit et crépuscule", () => {
    expect(APPEARANCES).toEqual(["day", "night", "twilight"]);
    expect(isAppearance("day")).toBe(true);
    expect(isAppearance("night")).toBe(true);
    expect(isAppearance("twilight")).toBe(true);
    expect(isAppearance("dark")).toBe(false);
    expect(isAppearance("")).toBe(false);
  });

  it("retombe sur le jour", () => {
    expect(appearanceFromUnknown(undefined)).toBe(DEFAULT_APPEARANCE);
    expect(appearanceFromUnknown("sepia")).toBe("day");
    expect(appearanceFromUnknown("twilight")).toBe("twilight");
  });

  it("tient la nuit et le crépuscule pour sombres", () => {
    expect(appearanceIsDark("day")).toBe(false);
    expect(appearanceIsDark("night")).toBe(true);
    expect(appearanceIsDark("twilight")).toBe(true);
  });
});
