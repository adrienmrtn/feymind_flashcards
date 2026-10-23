import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";

import {
  ANON_DAILY_CEILING,
  ANON_GRACE_UNTIL,
  ANON_UPDATE_MESSAGE,
  anonGraceOpen,
  CallerError,
  consumeQuota,
  QUOTA_EXHAUSTED_MESSAGE,
  readCaller,
  requireAccount,
  withCors,
} from "./caller.ts";

/**
 * Ce fichier verrouille la partie du contrôle qui **ne dépend pas du réseau** : qui a le droit
 * d'appeler, et quelle origine a le droit de lire la réponse. Le décompte, lui, est vérifié en
 * base, où il vit.
 *
 * Les deux règles testées ici sont celles dont une régression ne se verrait sur aucun écran : une
 * fonction qui accepterait à nouveau la clé publiable, ou un CORS qui redeviendrait permissif,
 * continueraient de marcher parfaitement — pour tout le monde, y compris ceux à qui on ne veut
 * pas ouvrir.
 */

/** Un jeton non signé : la passerelle vérifie la signature, ce module ne lit que la charge. */
function token(claims: Record<string, unknown>): string {
  const encode = (value: unknown) =>
    btoa(JSON.stringify(value)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${encode({ alg: "HS256" })}.${encode(claims)}.signature`;
}

function request(headers: Record<string, string> = {}, method = "POST"): Request {
  return new Request("https://example.test/fn", { method, headers });
}

Deno.test("le refus de quota n'écrit pas le plafond", () => {
  assertEquals(/\d/.test(QUOTA_EXHAUSTED_MESSAGE), false);
});

Deno.test("l'appelant", async (t) => {
  await t.step("est reconnu quand son jeton porte un rôle authentifié et un sujet", () => {
    const caller = readCaller(
      request({ Authorization: `Bearer ${token({ role: "authenticated", sub: "abc-123" })}` }),
    );

    assertEquals(caller.userId, "abc-123");
    assertEquals(caller.legacy, false);
  });

  await t.step("est refusé sans en-tête d'autorisation", () => {
    assertThrows(() => readCaller(request()), CallerError);
  });

  await t.step("est refusé quand le jeton n'a pas trois parties", () => {
    assertThrows(() => readCaller(request({ Authorization: "Bearer pas-un-jeton" })), CallerError);
  });

  await t.step("n'est personne quand il présente la clé publiable", () => {
    // C'est le cœur du sujet : la clé publiable est un jeton **valide** du projet, donc la
    // passerelle la laisse passer. Ce qui la distingue d'un utilisateur, c'est son rôle et
    // l'absence de sujet — et rien d'autre.
    const caller = readCaller(
      request({ Authorization: `Bearer ${token({ role: "anon" })}` }),
      new Date("2026-10-23T12:00:00Z"),
    );

    assertEquals(caller.userId, null);
    assertEquals(caller.legacy, true);
  });

  await t.step("refuse la clé publiable passé la fin de la transition", () => {
    // La date n'était qu'un commentaire : rien ne la lisait. Le lendemain, la clé publiable
    // doit tomber d'elle-même, avec une phrase qui dit de mettre l'app à jour.
    const after = new Date(`${ANON_GRACE_UNTIL}T00:00:00Z`);
    const error = assertThrows(
      () => readCaller(request({ Authorization: `Bearer ${token({ role: "anon" })}` }), after),
      CallerError,
    );
    assertEquals(error.status, 401);
    assertEquals(error.message, ANON_UPDATE_MESSAGE);
  });

  await t.step("la transition est ouverte la veille et fermée le jour dit", () => {
    const until = Date.parse(`${ANON_GRACE_UNTIL}T00:00:00Z`);
    assertEquals(anonGraceOpen(new Date(until - 1)), true);
    assertEquals(anonGraceOpen(new Date(until)), false);
  });

  await t.step("une étape lourde exige un compte", () => {
    const legacy = { userId: null, legacy: true };
    const error = assertThrows(() => requireAccount(legacy), CallerError);
    assertEquals(error.status, 401);
    requireAccount({ userId: "abc-123", legacy: false });
  });

  await t.step("refuse un rôle de service", () => {
    assertThrows(
      () => readCaller(request({ Authorization: `Bearer ${token({ role: "service_role" })}` })),
      CallerError,
    );
  });

  await t.step("exige un sujet, pas seulement le bon rôle", () => {
    assertThrows(
      () => readCaller(request({ Authorization: `Bearer ${token({ role: "authenticated" })}` })),
      CallerError,
    );
  });
});

Deno.test("les origines", async (t) => {
  const ok = async (origin: string) => {
    const response = await withCors(request({ Origin: origin }), () =>
      Promise.resolve(new Response("{}")),
    );
    return response.headers.get("Access-Control-Allow-Origin");
  };

  await t.step("laissent passer le site et le développement local", async () => {
    assertEquals(await ok("https://micabo.app"), "https://micabo.app");
    assertEquals(await ok("https://www.micabo.app"), "https://www.micabo.app");
    assertEquals(await ok("http://localhost:3000"), "http://localhost:3000");
  });

  await t.step("laissent passer une prévisualisation", async () => {
    const preview = "https://micabo-git-branche-adriens-projects-145ae26c.vercel.app";
    assertEquals(await ok(preview), preview);
  });

  await t.step("refusent tout le reste", async () => {
    assertEquals(await ok("https://micabo.app.attaquant.test"), null);
    assertEquals(await ok("https://evil.test"), null);
    // Un sous-domaine de vercel.app à plusieurs segments n'est pas une prévisualisation du
    // projet : le joker est borné à un segment exprès.
    assertEquals(await ok("https://a.b.vercel.app"), null);
    // Un autre projet Vercel n'est pas le nôtre, même sur un seul segment.
    assertEquals(await ok("https://attaquant.vercel.app"), null);
    assertEquals(await ok("http://micabo.app"), null);
  });

  await t.step("n'accordent rien quand il n'y a pas d'origine", async () => {
    // C'est le cas de l'app : un client natif n'envoie pas d'`Origin` et ne lit pas ces en-têtes.
    // Ne rien accorder ne lui retire donc rien.
    const response = await withCors(request(), () => Promise.resolve(new Response("{}")));
    assertEquals(response.headers.get("Access-Control-Allow-Origin"), null);
    assertEquals(response.headers.get("Vary"), "Origin");
  });

  await t.step("écrasent une étoile posée plus bas", async () => {
    // `jsonResponse` pose encore ses propres en-têtes : l'enveloppe doit avoir le dernier mot,
    // sinon le resserrement ne sert à rien.
    const response = await withCors(request({ Origin: "https://evil.test" }), () =>
      Promise.resolve(
        new Response("{}", { headers: { "Access-Control-Allow-Origin": "*" } }),
      ),
    );
    assertEquals(response.headers.get("Access-Control-Allow-Origin"), null);
  });

  await t.step("répondent à la requête préalable sans appeler le gestionnaire", async () => {
    let called = false;
    const response = await withCors(
      request({ Origin: "https://micabo.app" }, "OPTIONS"),
      () => {
        called = true;
        return Promise.resolve(new Response("{}"));
      },
    );

    assertEquals(called, false);
    assertEquals(response.status, 200);
    assertEquals(response.headers.get("Access-Control-Allow-Origin"), "https://micabo.app");
  });
});

/**
 * Le décompte, vu de la fonction : quel RPC part, avec quoi, et ce qu'on fait de la réponse.
 * Le compteur lui-même vit en base ; ici, `fetch` est remplacé et les secrets sont posés le
 * temps du test.
 */
async function withQuotaServer(
  answer: (url: string, body: Record<string, unknown>) => Response,
  run: (calls: { url: string; body: Record<string, unknown> }[]) => Promise<void>,
): Promise<void> {
  const original = globalThis.fetch;
  const previousUrl = Deno.env.get("SUPABASE_URL");
  const previousKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const calls: { url: string; body: Record<string, unknown> }[] = [];
  Deno.env.set("SUPABASE_URL", "https://projet.test");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service");
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    const body = JSON.parse(String(init?.body ?? "{}")) as Record<string, unknown>;
    calls.push({ url, body });
    return Promise.resolve(answer(url, body));
  }) as typeof fetch;
  try {
    await run(calls);
  } finally {
    globalThis.fetch = original;
    if (previousUrl === undefined) Deno.env.delete("SUPABASE_URL");
    else Deno.env.set("SUPABASE_URL", previousUrl);
    if (previousKey === undefined) Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
    else Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", previousKey);
  }
}

const rows = (allowed: boolean) => new Response(JSON.stringify([{ allowed, used: 1, ceiling: 1 }]));

Deno.test("le décompte", async (t) => {
  const legacy = { userId: null, legacy: true };
  const someone = { userId: "abc-123", legacy: false };

  await t.step("prend l'appel sans compte sur le budget commun", async () => {
    // Avant, un appel sans compte ne décomptait rien : la clé publiable lue dans un IPA
    // ouvrait le modèle sans plafond.
    await withQuotaServer(() => rows(true), async (calls) => {
      await consumeQuota(legacy, "generate-lesson");
      assertEquals(calls.length, 1);
      assertEquals(calls[0]!.url, "https://projet.test/rest/v1/rpc/consume_anon_ai_quota");
      assertEquals(calls[0]!.body, { p_fn: "generate-lesson", p_ceiling: ANON_DAILY_CEILING, p_units: 1 });
    });
  });

  await t.step("refuse l'appel sans compte quand le budget commun est vide", async () => {
    await withQuotaServer(() => rows(false), async () => {
      const error = await assertRejects(() => consumeQuota(legacy, "generate-lesson"), CallerError);
      assertEquals(error.status, 429);
    });
  });

  await t.step("garde le plafond propre à la fonction pour le budget commun", async () => {
    await withQuotaServer(() => rows(true), async (calls) => {
      await consumeQuota(legacy, "generate-lesson-theme", 1, 60, undefined, 900);
      assertEquals(calls[0]!.body.p_ceiling, 900);
      assertEquals("p_user" in calls[0]!.body, false);
    });
  });

  await t.step("compte un utilisateur sur son propre compteur", async () => {
    await withQuotaServer(() => rows(true), async (calls) => {
      await consumeQuota(someone, "mika-chat", 1, 20, 400);
      assertEquals(calls[0]!.url, "https://projet.test/rest/v1/rpc/consume_ai_quota");
      assertEquals(calls[0]!.body, {
        p_user: "abc-123",
        p_fn: "mika-chat",
        p_ceiling: 20,
        p_units: 1,
        p_pro_ceiling: 400,
      });
    });
  });

  await t.step("ferme quand la base ne répond pas", async () => {
    await withQuotaServer(() => new Response("panne", { status: 500 }), async () => {
      const error = await assertRejects(() => consumeQuota(legacy, "generate-lesson"), CallerError);
      assertEquals(error.status, 503);
    });
  });
});
