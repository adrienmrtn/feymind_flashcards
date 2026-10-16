import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  clampParagraph,
  cleanInline,
  cleanText,
  estimateMinutes,
  groupThemes,
  nameGroups,
  type NoteBlock,
  readFlashcards,
  readNotes,
  readPlan,
  readQuestion,
  readQuestions,
  separateBoxes,
  words,
} from "./schema.ts";

Deno.test("le découpage des paliers est celui de l'app", () => {
  const sizes = (n: number) => groupThemes(n).map((g) => g.length);
  assertEquals(sizes(4), [2, 2]);
  assertEquals(sizes(5), [2, 3]);
  assertEquals(sizes(6), [2, 2, 2]);
  assertEquals(sizes(7), [2, 2, 3]);
  assertEquals(sizes(9), [3, 3, 3]);
  assertEquals(sizes(10), [3, 3, 2, 2]);
  assertEquals(sizes(11), [3, 3, 3, 2]);
  assertEquals(sizes(12), [3, 3, 3, 3]);
  assertEquals(groupThemes(4, true), [[0, 1, 2, 3]]);
  for (let n = 1; n <= 30; n += 1) {
    assertEquals(groupThemes(n).flat(), Array.from({ length: n }, (_, i) => i));
  }
});

Deno.test("pas d'emoji ni de tiret cadratin dans le texte", () => {
  assertEquals(cleanText("La photosynthèse 🌿 — en bref ✨"), "La photosynthèse, en bref");
  assertEquals(cleanText("  deux\n  lignes "), "deux lignes");
  assertEquals(cleanText(42), "");
});

Deno.test("le balisage ne garde que les mots-clés et le LaTeX", () => {
  assertEquals(cleanInline("Le ==jaune|chloroplaste== capte la *lumière*."), "Le chloroplaste capte la lumière.");
  assertEquals(cleanInline("Les **États-Unis** et l'**URSS**"), "Les **États-Unis** et l'**URSS**");
  assertEquals(cleanInline("Un **mot orphelin"), "Un mot orphelin");
  assertEquals(cleanInline("**a** **b**"), "**a** **b**", "deux mots-clés voisins ne fusionnent pas");
  assertEquals(cleanInline("$E = mc^2$ et ~~faux~~"), "$E = mc^2$ et faux");
});

Deno.test("un paragraphe tient en 60 mots, ses phrases en 25", () => {
  const long = Array.from({ length: 40 }, (_, i) => `mot${i}`).join(" ") + ".";
  const clamped = clampParagraph(long);
  assert(words(clamped).length <= 25);
  const many = Array.from({ length: 10 }, (_, i) => `Phrase numéro ${i} assez courte pour tenir ici.`).join(" ");
  assert(words(clampParagraph(many)).length <= 60);
  assertEquals(clampParagraph("Une phrase. Deux phrases."), "Une phrase. Deux phrases.");
});

Deno.test("jamais deux encadrés de suite", () => {
  const blocks: NoteBlock[] = [
    { type: "paragraph", text: "A." },
    { type: "definition", term: "T", text: "D." },
    { type: "example", text: "E." },
    { type: "paragraph", text: "B." },
  ];
  assertEquals(separateBoxes(blocks).map((b) => b.type), ["paragraph", "definition", "paragraph", "example"]);

  const tail: NoteBlock[] = [
    { type: "definition", term: "T", text: "D." },
    { type: "example", text: "E." },
  ];
  assertEquals(separateBoxes(tail).map((b) => b.type), ["definition", "paragraph"]);

  const formulas: NoteBlock[] = [
    { type: "formula", latex: "a" },
    { type: "formula", latex: "b" },
  ];
  assertEquals(separateBoxes(formulas).length, 1);
});

Deno.test("les notes d'un thème sont remises aux règles", () => {
  const notes = readNotes({
    oneLiner: "La guerre froide oppose deux blocs 🌍 sans conflit direct.",
    blocks: [
      { type: "subtitle", text: "Deux camps" },
      { type: "list", items: ["Un", "Deux", "Trois", "Quatre", "Cinq", "Six", "Sept"] },
      { type: "list", items: ["Seul"] },
      { type: "definition", term: "**Endiguement**", text: "Contenir l'URSS." },
      { type: "dates", items: [{ date: "1947", text: "Truman" }] },
      { type: "mystery", text: "?" },
      { type: "subtitle", text: "Orphelin" },
    ],
    takeaways: ["Un", "Deux", "Trois", "Quatre"],
  });
  assert(notes);
  assert(!notes.oneLiner.includes("🌍"));
  const list = notes.blocks.find((b) => b.type === "list");
  assertEquals(list?.type === "list" ? list.items.length : 0, 5, "cinq puces au plus");
  assert(notes.blocks.some((b) => b.type === "paragraph" && b.text === "Seul"), "une liste d'un point devient une phrase");
  assert(!notes.blocks.some((b) => b.type === "dates"), "une frise d'une seule date n'en est pas une");
  assertEquals(notes.blocks.at(-1)?.type !== "subtitle", true, "un sous-titre ne termine pas les notes");
  const definition = notes.blocks.find((b) => b.type === "definition");
  assertEquals(definition?.type === "definition" ? definition.term : "", "Endiguement");
  assertEquals(notes.takeaways.length, 3);
  assertEquals(readNotes({ oneLiner: "", blocks: [] }), null);
});

Deno.test("une question a quatre propositions distinctes, et la bonne réponse suit le mélange", () => {
  const question = readQuestion({
    prompt: "Qui lance le plan Marshall ?",
    choices: ["Les États-Unis", "L'URSS", "La France", "Les États-Unis"],
    answer: 0,
    why: "Il finance la reconstruction de l'Europe de l'Ouest.",
  }, "seed");
  assert(question);
  assertEquals(question.choices.length, 3, "le doublon part");
  assertEquals(question.choices[question.answer], "Les États-Unis");
  assertEquals(readQuestion({ prompt: "Q", choices: ["a", "b"], answer: 0 }, "s"), null, "deux choix ne suffisent pas");
  assertEquals(readQuestion({ prompt: "Q", choices: ["a", "b", "c"], answer: 7 }, "s"), null);
});

Deno.test("le mélange est reproductible, et déplace la bonne réponse", () => {
  const raw = { prompt: "Q ?", choices: ["bonne", "b", "c", "d"], answer: 0, why: "." };
  assertEquals(readQuestion(raw, "x"), readQuestion(raw, "x"));
  const positions = new Set(
    Array.from({ length: 24 }, (_, i) => readQuestion(raw, `seed-${i}`)!.answer),
  );
  assert(positions.size >= 3, "la bonne réponse n'est pas toujours au même rang");
  assertEquals(readQuestions([raw, raw, raw, raw, raw], "t").length, 4);
});

Deno.test("trois flashcards, recto et verso remplis", () => {
  const cards = readFlashcards([
    { front: "Q1", back: "R1" },
    { front: "", back: "R2" },
    { front: "Q3", back: "R3" },
    { front: "Q4", back: "R4" },
    { front: "Q5", back: "R5" },
  ]);
  assertEquals(cards.map((c) => c.front), ["Q1", "Q3", "Q4"]);
});

Deno.test("les paliers prennent les noms du modèle, même quand il groupe autrement", () => {
  const groups = groupThemes(5); // [[0,1],[2,3,4]]
  assertEquals(
    nameGroups(groups, [{ name: "Les causes", themes: [0, 1] }, { name: "Les suites", themes: [2, 3, 4] }]),
    ["Les causes", "Les suites"],
  );
  assertEquals(
    nameGroups(groups, [{ name: "Début", themes: [0, 1, 2] }, { name: "Fin", themes: [3, 4] }]),
    ["Début", "Début"],
  );
  assertEquals(nameGroups(groups, null), ["", ""]);
});

Deno.test("le plan : de 4 à 12 thèmes, titres courts, icônes de la base, durée calculée", () => {
  const themes = Array.from({ length: 14 }, (_, i) => ({
    title: `Le thème numéro ${i} qui a un titre beaucoup trop long`,
    icon: i % 2 ? "globe" : "licorne",
  }));
  const plan = readPlan(
    { title: "La guerre froide", subject: "Histoire", icon: "parchemin", themes, takeaways: ["a", "b"] },
    { shortSource: false, shortened: true, fallbackTitle: "Leçon" },
  );
  assert(plan);
  assertEquals(plan.themes.length, 12);
  assert(plan.themes.every((t) => words(t.title).length <= 6));
  assertEquals(plan.themes[0]!.icon, "livre-ouvert");
  assertEquals(plan.themes[1]!.icon, "globe");
  assertEquals(plan.groups.map((g) => g.themes.length), [3, 3, 3, 3]);
  assertEquals(plan.intro.minutes, estimateMinutes(12, 4));
  assertEquals(plan.shortened, true);

  const short = readPlan(
    { themes: themes.slice(0, 6) },
    { shortSource: true, shortened: false, fallbackTitle: "Leçon" },
  );
  assert(short);
  assertEquals(short.themes.length, 4);
  assertEquals(short.groups.length, 1, "une leçon très courte n'a qu'un quiz");
  assertEquals(short.title, "Leçon");

  assertEquals(readPlan({ themes: [] }, { shortSource: false, shortened: false, fallbackTitle: "x" }), null);
});
