import { assertEquals } from "jsr:@std/assert@1";

import {
  audienceBrief,
  instructionsBrief,
  lengthBrief,
  PROMPT_VERSION,
  readingBrief,
  retryBrief,
} from "./prompt.ts";

Deno.test("la version de prompt est stable", () => {
  assertEquals(PROMPT_VERSION, "course-v1.2.0");
});

Deno.test("audienceBrief mappe lycée + France", () => {
  const brief = audienceBrief("lycee", "fr");
  assertEquals(brief.includes("SECONDAIRE"), true);
  assertEquals(brief.includes("FRANCE"), true);
});

Deno.test("lengthBrief honore un volume explicite", () => {
  const brief = lengthBrief("standard", false, 20);
  assertEquals(brief.includes("Volume visé : 20 blocs"), true);
});

Deno.test("readingBrief prévient sur un document court", () => {
  const brief = readingBrief("photo", 500);
  assertEquals(brief.includes("COURT"), true);
});

Deno.test("retryBrief nomme un volume", () => {
  assertEquals(retryBrief("brief").includes("7 blocs"), true);
});

Deno.test("instructionsBrief est vide sans texte", () => {
  assertEquals(instructionsBrief(""), "");
});

Deno.test("instructionsBrief encadre le prompt de l'étudiant", () => {
  const brief = instructionsBrief("Insiste sur les formules.");
  assertEquals(brief.includes("CONSIGNES PARTICULIÈRES"), true);
  assertEquals(brief.includes("Insiste sur les formules."), true);
  assertEquals(brief.includes("inventer"), true);
});
