import { describe, expect, it } from "vitest";

import { isHardPaywall, shouldOpenPaywall } from "./paywall";

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

  it("s'ouvre en débogage, même pour un abonné qui a fermé l'offre", () => {
    expect(
      shouldOpenPaywall({
        ...base,
        isPaid: true,
        dismissed: true,
        debug: true,
      }),
    ).toBe(true);
  });
});

describe("isHardPaywall", () => {
  it("ne se referme pas quand il clôt l'accueil", () => {
    expect(isHardPaywall({ force: false })).toBe(true);
  });

  it("garde sa croix sur une demande explicite de l'offre", () => {
    expect(isHardPaywall({ force: true })).toBe(false);
  });

  it("garde sa croix sur une porte fermée en cours d'usage", () => {
    expect(isHardPaywall({ force: false, demand: true })).toBe(false);
  });

  it("laisse le rejeu de démonstration se refermer", () => {
    expect(isHardPaywall({ force: false, debug: true })).toBe(false);
    // Le rejeu prime, même sur une porte.
    expect(isHardPaywall({ force: false, demand: true, debug: true })).toBe(false);
  });

  it("ne dépend pas du stockage local, qui se vide", () => {
    // Ni `pending` ni `welcome` n'entrent dans la décision : les lire aurait
    // laissé une sortie triviale.
    expect(isHardPaywall({ force: false })).toBe(true);
    expect(isHardPaywall({ force: false })).toBe(true);
  });
});
