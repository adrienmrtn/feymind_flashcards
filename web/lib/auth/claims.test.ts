import { describe, expect, it, vi } from "vitest";

import { userFromToken } from "./claims";

function source(overrides: {
  claims?: () => Promise<{ data: { claims: { sub?: string; email?: unknown } } | null; error: unknown }>;
  user?: () => Promise<{ data: { user: { id: string; email?: string | null } | null }; error: unknown }>;
}) {
  return {
    getClaims: overrides.claims ?? (async () => ({ data: null, error: "absent" })),
    getUser: overrides.user ?? (async () => ({ data: { user: null }, error: "absent" })),
  };
}

describe("l'identité tirée d'un jeton", () => {
  it("sort de la signature vérifiée, sans appeler GoTrue", async () => {
    const getUser = vi.fn();
    const auth = source({
      claims: async () => ({ data: { claims: { sub: "u-1", email: "moi@micabo.app" } }, error: null }),
      user: getUser,
    });

    expect(await userFromToken(auth, "jeton")).toEqual({ id: "u-1", email: "moi@micabo.app" });
    expect(getUser).not.toHaveBeenCalled();
  });

  it("ne donne personne quand la signature est refusée, et ne redemande pas", async () => {
    const getUser = vi.fn();
    const auth = source({
      claims: async () => ({ data: null, error: "Invalid JWT signature" }),
      user: getUser,
    });

    expect(await userFromToken(auth, "bricolé")).toBeNull();
    expect(getUser).not.toHaveBeenCalled();
  });

  it("ne donne personne quand les claims n'ont pas de sujet", async () => {
    const auth = source({ claims: async () => ({ data: { claims: {} }, error: null }) });
    expect(await userFromToken(auth, "jeton")).toBeNull();
  });

  it("laisse GoTrue trancher quand la vérification locale ne peut pas conclure", async () => {
    const auth = source({
      claims: async () => {
        throw new TypeError("jwks injoignable");
      },
      user: async () => ({ data: { user: { id: "u-2", email: null } }, error: null }),
    });

    expect(await userFromToken(auth, "jeton")).toEqual({ id: "u-2", email: null });
  });

  it("ne donne personne si GoTrue refuse à son tour", async () => {
    const auth = source({
      claims: async () => {
        throw new TypeError("jwks injoignable");
      },
    });

    expect(await userFromToken(auth, "jeton")).toBeNull();
  });
});
