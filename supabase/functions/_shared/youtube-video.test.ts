import { assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert@1";

import { readingText, readTranscript, stripPreamble } from "./youtube-video.ts";
import { type CaptionTrack, YouTubeError } from "./youtube.ts";

function track(overrides: Partial<CaptionTrack> = {}): CaptionTrack {
  return {
    languageCode: "fr",
    languageName: "français",
    isAutomatic: false,
    isDefault: true,
    baseUrl: "https://www.youtube.com/api/timedtext?v=abc&lang=fr",
    ...overrides,
  };
}

/** Une réponse Gemini vidéo dont le texte fait plus que le minimum exigé. */
function geminiReading(text = "Un neurone porte un nombre. ".repeat(40)): Response {
  return new Response(
    JSON.stringify({ candidates: [{ finishReason: "STOP", content: { parts: [{ text }] } }] }),
    { status: 200 },
  );
}

/**
 * Des sous-titres json3 assez longs pour passer `minTranscriptCharacters`.
 *
 * Chaque ligne est distincte : `cleanTranscript` réduit à une seule les lignes répétées à
 * l'identique, si bien que quarante fois la même phrase ne font pas quarante phrases.
 */
function captionsJson3(): Response {
  const events = Array.from({ length: 40 }, (_, index) => ({
    tStartMs: index * 1000,
    segs: [{ utf8: `Phrase numéro ${index} des sous-titres, assez longue pour compter. ` }],
  }));
  return new Response(JSON.stringify({ events }), { status: 200 });
}

async function withFetch(
  handler: (url: string) => Response,
  geminiKey: string | null,
  run: (calls: string[]) => Promise<void>,
): Promise<void> {
  if (geminiKey) Deno.env.set("GEMINI_API_KEY", geminiKey);
  else Deno.env.delete("GEMINI_API_KEY");

  const originalFetch = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = (input) => {
    const url = String(input);
    calls.push(url);
    return Promise.resolve(handler(url));
  };

  try {
    await run(calls);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("GEMINI_API_KEY");
  }
}

const isGemini = (url: string) => url.includes("generativelanguage.googleapis.com");

/** Les sous-titres sont exacts et gratuits : ils passent devant, et le modèle n'est pas appelé. */
Deno.test("readTranscript garde les sous-titres quand ils répondent", async () => {
  await withFetch(
    (url) => (isGemini(url) ? geminiReading() : captionsJson3()),
    "gemini-test",
    async (calls) => {
      const transcript = await readTranscript("abc", [track()], ["fr"]);
      assertEquals(transcript.source, "captions");
      assertEquals(transcript.languageCode, "fr");
      assertEquals(calls.some(isGemini), false);
    },
  );
});

/**
 * Le cas du 8 septembre 2026 : depuis l'exécution edge, YouTube ne rend aucune piste. La
 * fonction refusait alors en 422. Elle doit maintenant lire la vidéo par le modèle.
 */
Deno.test("readTranscript lit la vidéo quand aucune piste n'est disponible", async () => {
  await withFetch(
    (url) => (isGemini(url) ? geminiReading() : new Response("nope", { status: 403 })),
    "gemini-test",
    async (calls) => {
      const transcript = await readTranscript("abc", [], ["fr"]);
      assertEquals(transcript.source, "model");
      assertEquals(transcript.isAutomatic, true);
      assertStringIncludes(transcript.text, "Un neurone porte un nombre.");
      assertEquals(calls.filter(isGemini).length, 1);
    },
  );
});

Deno.test("readTranscript lit la vidéo quand la piste annoncée ne rend rien", async () => {
  await withFetch(
    (url) => (isGemini(url) ? geminiReading() : new Response("", { status: 404 })),
    "gemini-test",
    async (calls) => {
      const transcript = await readTranscript("abc", [track()], ["fr"]);
      assertEquals(transcript.source, "model");
      assertEquals(calls.filter(isGemini).length, 1);
    },
  );
});

/** Sans clé, il n'y a pas de second chemin : le refus des sous-titres est la réponse. */
Deno.test("readTranscript rend le refus des sous-titres sans clé Gemini", async () => {
  await withFetch(
    () => new Response("", { status: 404 }),
    null,
    async (calls) => {
      const error = await assertRejects(() => readTranscript("abc", [track()], ["fr"]));
      assertEquals(error instanceof YouTubeError, true);
      assertEquals((error as YouTubeError).code, "no_captions");
      assertEquals(calls.some(isGemini), false);
    },
  );
});

/** `RECITATION` rend 200 avec zéro part : le second modèle doit être essayé. */
Deno.test("readTranscript essaie le second modèle quand le premier coupe", async () => {
  let geminiCalls = 0;
  await withFetch(
    (url) => {
      if (!isGemini(url)) return new Response("", { status: 403 });
      geminiCalls += 1;
      return geminiCalls === 1
        ? new Response(JSON.stringify({ candidates: [{ finishReason: "RECITATION" }] }), { status: 200 })
        : geminiReading();
    },
    "gemini-test",
    async () => {
      const transcript = await readTranscript("abc", [], ["fr"]);
      assertEquals(transcript.source, "model");
      assertEquals(geminiCalls, 2);
    },
  );
});

Deno.test("readTranscript refuse quand les deux modèles coupent", async () => {
  await withFetch(
    (url) =>
      isGemini(url)
        ? new Response(JSON.stringify({ candidates: [{ finishReason: "RECITATION" }] }), { status: 200 })
        : new Response("", { status: 403 }),
    "gemini-test",
    async () => {
      const error = await assertRejects(() => readTranscript("abc", [], ["fr"]));
      assertEquals((error as YouTubeError).code, "no_captions");
    },
  );
});

Deno.test("readingText recolle les parts de la réponse", () => {
  const raw = JSON.stringify({
    candidates: [{ content: { parts: [{ text: "Un neurone " }, { text: "porte un nombre." }] } }],
  });
  assertEquals(readingText(raw), "Un neurone porte un nombre.");
});

/**
 * Google coupe la réponse avec `finishReason: RECITATION` et **aucune part** quand on lui
 * demande de restituer une œuvre mot à mot. Ce n'est pas une erreur HTTP : sans ce cas, on
 * rendrait une transcription vide comme si elle était bonne.
 */
Deno.test("readingText rend une chaîne vide sur une réponse coupée ou illisible", () => {
  assertEquals(readingText(JSON.stringify({ candidates: [{ finishReason: "RECITATION" }] })), "");
  assertEquals(readingText(JSON.stringify({ candidates: [] })), "");
  assertEquals(readingText("<html>Sorry…</html>"), "");
  assertEquals(readingText(""), "");
});

Deno.test("stripPreamble ôte la phrase d'annonce, pas la première notion", () => {
  assertEquals(
    stripPreamble("Voici le compte rendu complet de la vidéo :\nUn neurone porte un nombre."),
    "Un neurone porte un nombre.",
  );
  assertEquals(
    stripPreamble("Here is the full account of the video:\nA neuron holds a number."),
    "A neuron holds a number.",
  );

  // Une première phrase qui commence par « voici » mais enseigne quelque chose reste.
  const lesson = "Voici pourquoi un réseau apprend : chaque poids se corrige.\nEnsuite, on itère.";
  assertEquals(stripPreamble(lesson), lesson);

  // Un texte d'une seule ligne n'a pas de préambule à retirer.
  assertEquals(stripPreamble("Voici le compte rendu."), "Voici le compte rendu.");
});
