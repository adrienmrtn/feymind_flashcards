import { assert, assertEquals } from "jsr:@std/assert@1";
import { applicationShare, assessmentBrief, disciplineName, hasVariedKinds } from "./assessment.ts";

Deno.test("la consigne nomme chaque matière une fois, avec ses formes", () => {
  const brief = assessmentBrief({ tier: "upperSecondary", disciplines: ["history", "mathematics", "history"], count: 20 });
  assertEquals(brief.split("En histoire-géographie").length - 1, 1);
  assert(brief.includes("En mathématiques"));
  assert(brief.includes("order"));
  assert(brief.includes("Au moins 7 questions d'application"));
});

Deno.test("le niveau change la part de raisonnement et le ton", () => {
  assert(applicationShare("graduate") > applicationShare("lowerSecondary"));
  const college = assessmentBrief({ tier: "lowerSecondary", disciplines: ["biology"], count: 12 });
  assert(college.includes("20 mots au plus"));
  const master = assessmentBrief({ tier: "graduate", disciplines: ["law"], count: 12 });
  assert(master.includes("Rarement une définition seule"));
  assert(master.includes("cas pratique"));
});

Deno.test("une matière inconnue garde une consigne générale", () => {
  const brief = assessmentBrief({ tier: "other", disciplines: ["general"], count: 8 });
  assert(brief.includes("Pour ces leçons"));
  assertEquals(disciplineName("general"), "");
});

Deno.test("une copie qui ne fait que des QCM ne varie pas assez", () => {
  assertEquals(hasVariedKinds(Array(12).fill("choice"), 5), false);
  assertEquals(hasVariedKinds([...Array(9).fill("choice"), "gap", "order", "match"], 5), false);
  assertEquals(hasVariedKinds(["choice", "gap", "order", "choice", "truefalse", "match", "choice", "gap", "choice", "order"], 5), true);
  assertEquals(hasVariedKinds(["choice", "truefalse", "choice", "truefalse"], 2), true, "l'app n'en connaît que deux");
  assertEquals(hasVariedKinds([], 5), false);
});
