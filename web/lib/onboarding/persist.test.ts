import { describe, expect, it } from "vitest";

import { shouldOpenPaywall } from "./paywall";

describe("shouldOpenPaywall", () => {
  const base = {
    isPaid: false,
    force: false,
    welcome: false,
    pending: false,
    dismissed: false,
    onHome: false,
  };

  it("ne s'ouvre pas pour un abonné payé", () => {
    expect(shouldOpenPaywall({ ...base, isPaid: true, force: true, onHome: true })).toBe(
      false,
    );
  });

  it("s'ouvre sur le tableau de bord, même sans parcours", () => {
    expect(shouldOpenPaywall({ ...base, onHome: true })).toBe(true);
  });

  it("respecte la croix, sauf si on force l'offre", () => {
    expect(shouldOpenPaywall({ ...base, onHome: true, dismissed: true })).toBe(false);
    expect(shouldOpenPaywall({ ...base, dismissed: true, force: true })).toBe(true);
  });

  it("s'ouvre après le parcours ou un drapeau en attente", () => {
    expect(shouldOpenPaywall({ ...base, welcome: true })).toBe(true);
    expect(shouldOpenPaywall({ ...base, pending: true })).toBe(true);
  });
});
