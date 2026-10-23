import { NextRequest } from "next/server";
import { afterEach, describe, expect, it, vi } from "vitest";

import { middleware } from "@/middleware";

import { userFromToken, verifyAccessToken, type ClaimsSource } from "./claims";
import { onboardingGate } from "./onboarding-gate";

/**
 * La boucle `/app` → `/commencer/compte` → `/app`, rejouée.
 *
 * Elle naissait d'un désaccord : l'app (`app/app/layout.tsx`) ne laisse entrer que sur un jeton
 * **vérifié**, le middleware renvoyait vers l'app sur un cookie **présent**. Une session révoquée
 * côté serveur (déconnexion globale depuis l'iPhone, compte supprimé, clé tournée) est présente
 * et refusée à la fois : chacun renvoyait chez l'autre.
 */

const TOKEN = "jeton-révoqué";

function source(getClaims: ClaimsSource["getClaims"]): ClaimsSource {
  return {
    getClaims,
    getUser: async () => ({ data: { user: null }, error: { status: 403 } }),
  };
}

const revoked = source(async () => ({ data: null, error: { status: 403, code: "session_not_found" } }));
const healthy = source(async () => ({ data: { claims: { sub: "u1", email: "a@b.c" } }, error: null }));
const offline = source(async () => ({ data: null, error: { status: 0, name: "AuthRetryableFetchError" } }));

/** Suit les redirections comme le ferait le navigateur, au plus dix fois. */
async function follow(start: string, auth: ClaimsSource): Promise<{ hops: string[]; looped: boolean }> {
  const hops = [start];
  let path = start;
  for (let i = 0; i < 10; i += 1) {
    if (path === "/app") {
      // `app/app/layout.tsx` : personne de vérifié, retour au compte.
      const user = await userFromToken(auth, TOKEN);
      if (user) return { hops, looped: false };
      path = "/commencer/compte";
    } else {
      const verdict = await verifyAccessToken(auth, TOKEN);
      const gate = onboardingGate({ pathname: path, replaying: false, hasSession: true, verdict });
      if (gate !== "app") return { hops, looped: false };
      path = "/app";
    }
    hops.push(path);
  }
  return { hops, looped: true };
}

describe("onboardingGate", () => {
  it("ne renvoie plus une session refusée vers l'app qui la refuse", async () => {
    const { hops, looped } = await follow("/app", revoked);
    expect(looped).toBe(false);
    expect(hops).toEqual(["/app", "/commencer/compte"]);
    expect(
      onboardingGate({
        pathname: "/commencer/compte",
        replaying: false,
        hasSession: true,
        verdict: await verifyAccessToken(revoked, TOKEN),
      }),
    ).toBe("forget");
  });

  it("envoie dans l'app une session vérifiée", async () => {
    expect(await verifyAccessToken(healthy, TOKEN)).toBe("valid");
    expect(
      onboardingGate({ pathname: "/commencer/compte", replaying: false, hasSession: true, verdict: "valid" }),
    ).toBe("app");
  });

  it("ne tranche rien sur une panne : ni redirection, ni effacement", async () => {
    expect(await verifyAccessToken(offline, TOKEN)).toBe("unknown");
    const thrower = source(async () => {
      throw new Error("réseau");
    });
    expect(await verifyAccessToken(thrower, TOKEN)).toBe("unknown");
    const { looped } = await follow("/app", offline);
    expect(looped).toBe(false);
    expect(
      onboardingGate({ pathname: "/commencer/compte", replaying: false, hasSession: true, verdict: "unknown" }),
    ).toBe("stay");
  });

  it("laisse l'offre, la relecture du parcours et le reste du site tranquilles", () => {
    const base = { replaying: false, hasSession: true, verdict: "valid" as const };
    expect(onboardingGate({ ...base, pathname: "/commencer/offre" })).toBe("stay");
    expect(onboardingGate({ ...base, pathname: "/methode" })).toBe("stay");
    expect(onboardingGate({ ...base, pathname: "/commencer/compte", replaying: true })).toBe("stay");
    expect(
      onboardingGate({ pathname: "/commencer/compte", replaying: false, hasSession: false, verdict: null }),
    ).toBe("stay");
  });
});

/**
 * Le même scénario, mais à travers le vrai middleware : un cookie de session en bonne forme,
 * non expiré, que GoTrue ne connaît plus (`session_not_found`, 403).
 */
describe("middleware, session révoquée côté serveur", () => {
  const COOKIE = "sb-khuzodsrznanzhwlbjbx-auth-token";

  function base64url(value: string): string {
    return Buffer.from(value).toString("base64url");
  }

  function sessionCookie(): string {
    const now = Math.floor(Date.now() / 1000);
    const header = base64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
    const payload = base64url(
      JSON.stringify({ sub: "u1", exp: now + 3600, iat: now, role: "authenticated", session_id: "s1" }),
    );
    const session = {
      access_token: `${header}.${payload}.${base64url("signature")}`,
      refresh_token: "rt",
      token_type: "bearer",
      expires_in: 3600,
      expires_at: now + 3600,
      user: { id: "u1", aud: "authenticated", role: "authenticated", email: "a@b.c" },
    };
    return `base64-${base64url(JSON.stringify(session))}`;
  }

  function visit(path: string): NextRequest {
    const request = new NextRequest(`https://www.micabo.app${path}`);
    request.cookies.set(COOKIE, sessionCookie());
    return request;
  }

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("efface la session et affiche la page, au lieu de renvoyer vers /app", async () => {
    const fetch = vi.fn(async () =>
      Response.json(
        { code: 403, error_code: "session_not_found", msg: "Session from session_id claim in JWT does not exist" },
        { status: 403 },
      ),
    );
    vi.stubGlobal("fetch", fetch);

    const response = await middleware(visit("/commencer/compte"));
    // C'est bien GoTrue qui a refusé, pas un jeton mal formé.
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(response.headers.get("location")).toBeNull();
    const cleared = response.cookies.get(COOKIE);
    expect(cleared?.value).toBe("");
    expect(cleared?.maxAge).toBe(0);
  });

  it("renvoie toujours vers /app une session que GoTrue reconnaît", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        Response.json({ id: "u1", aud: "authenticated", role: "authenticated", email: "a@b.c" }, { status: 200 }),
      ),
    );

    const response = await middleware(visit("/commencer/compte"));
    expect(new URL(response.headers.get("location") ?? "", "https://x").pathname).toBe("/app");
  });

  it("garde l'offre accessible avec une session", async () => {
    const fetch = vi.fn(async () => Response.json({}, { status: 500 }));
    vi.stubGlobal("fetch", fetch);

    const response = await middleware(visit("/commencer/offre"));
    expect(response.headers.get("location")).toBeNull();
    // Pas de vérification là où elle ne décide de rien.
    expect(fetch).not.toHaveBeenCalled();
  });
});
