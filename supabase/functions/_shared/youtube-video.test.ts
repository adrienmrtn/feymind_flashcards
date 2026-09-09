import { assertEquals } from "jsr:@std/assert@1";

import { readingText, stripPreamble } from "./youtube-video.ts";

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
