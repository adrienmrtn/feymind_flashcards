import { assertEquals, assertRejects } from "jsr:@std/assert@1";

import { CallerError } from "../_shared/caller.ts";
import { admitThemeCall, beginLesson, LessonGateError, releaseLesson } from "./gate.ts";

/**
 * La porte, vue de la fonction : ce qu'elle fait d'une base qui dit non, qui ne dit rien, ou
 * qui ne répond pas. Avant, une base muette laissait passer : une panne suffisait à ouvrir la
 * leçon offerte autant de fois qu'on voulait.
 */

const LESSON = "6f9619ff-8b86-d011-b42d-00c04fc964ff";
const someone = { userId: "abc-123", legacy: false };

async function withGateServer(
  answer: (url: string) => Response,
  run: () => Promise<void>,
): Promise<void> {
  const original = globalThis.fetch;
  const previousUrl = Deno.env.get("SUPABASE_URL");
  const previousKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.set("SUPABASE_URL", "https://projet.test");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service");
  globalThis.fetch = ((input: string | URL | Request) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    return Promise.resolve(answer(url));
  }) as typeof fetch;
  try {
    await run();
  } finally {
    globalThis.fetch = original;
    if (previousUrl === undefined) Deno.env.delete("SUPABASE_URL");
    else Deno.env.set("SUPABASE_URL", previousUrl);
    if (previousKey === undefined) Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
    else Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", previousKey);
  }
}

const options = { lessonId: LESSON, kind: "create" as const, source: "topic", themes: 0 };

Deno.test("la porte", async (t) => {
  await t.step("ouvre quand la base dit oui", async () => {
    await withGateServer(() => new Response(JSON.stringify("ok")), async () => {
      await beginLesson(someone, options);
    });
  });

  await t.step("ferme en 503 quand la base ne répond pas", async () => {
    await withGateServer(() => new Response("panne", { status: 500 }), async () => {
      const error = await assertRejects(() => beginLesson(someone, options), CallerError);
      assertEquals(error.status, 503);
    });
  });

  await t.step("ferme quand la réponse n'est pas un verdict connu", async () => {
    await withGateServer(() => new Response(JSON.stringify("peut-être")), async () => {
      const error = await assertRejects(() => beginLesson(someone, options), CallerError);
      assertEquals(error.status, 503);
    });
  });

  await t.step("dit d'attendre la synchro pour un cours inconnu, sans ouvrir le paywall", async () => {
    // RevenueCat (relu sur ce refus) ne répond pas : la base reste la règle.
    await withGateServer(
      (url) =>
        url.includes("revenuecat")
          ? new Response("", { status: 503 })
          : new Response(JSON.stringify("course_unknown")),
      async () => {
        const error = await assertRejects(
          () => beginLesson(someone, { ...options, kind: "convert" }),
          LessonGateError,
        );
        assertEquals(error.status, 409);
        assertEquals(error.code, "course_unknown");
      },
    );
  });

  await t.step("refuse un thème que la base refuse, et ferme quand elle se tait", async () => {
    await withGateServer(() => new Response(JSON.stringify(false)), async () => {
      const error = await assertRejects(() => admitThemeCall(someone, LESSON), LessonGateError);
      assertEquals(error.code, "forbidden");
    });
    await withGateServer(() => new Response("panne", { status: 502 }), async () => {
      const error = await assertRejects(() => admitThemeCall(someone, LESSON), CallerError);
      assertEquals(error.status, 503);
    });
  });

  await t.step("rend une leçon sans lever, même quand la base ne répond pas", async () => {
    // Le retour s'exécute dans un `catch` : il ne doit pas masquer l'erreur qui l'a appelé.
    await withGateServer(() => new Response("panne", { status: 500 }), async () => {
      await releaseLesson(someone, LESSON);
    });
  });
});
