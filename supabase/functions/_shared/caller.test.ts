import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { CallerError, readCaller, withCors } from "./caller.ts";

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
    const caller = readCaller(request({ Authorization: `Bearer ${token({ role: "anon" })}` }));

    assertEquals(caller.userId, null);
    assertEquals(caller.legacy, true);
  });

  await t.step("ne prend pas un rôle de service pour un utilisateur", () => {
    const caller = readCaller(
      request({ Authorization: `Bearer ${token({ role: "service_role" })}` }),
    );
    assertEquals(caller.userId, null);
  });

  await t.step("exige un sujet, pas seulement le bon rôle", () => {
    const caller = readCaller(
      request({ Authorization: `Bearer ${token({ role: "authenticated" })}` }),
    );
    assertEquals(caller.userId, null);
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
