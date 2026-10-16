import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  answerIndex,
  clampParagraph,
  cleanInline,
  cleanText,
  estimateMinutes,
  fairShares,
  finalFirst,
  GAP,
  givesAway,
  groupThemes,
  LIMITS,
  nameGroups,
  type NoteBlock,
  readFlashcards,
  readNotes,
  readPlan,
  readQuestion,
  readQuestions,
  readTrueFalse,
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
  assertEquals(readQuestions([raw, raw, raw], "t").length, 1, "deux énoncés identiques n'en font qu'un");
  const many = Array.from({ length: 10 }, (_, i) => ({ ...raw, prompt: `Question ${i} ?` }));
  assertEquals(readQuestions(many, "t").length, LIMITS.questionsPerTheme);
  assertEquals(readQuestions(many, "t", { max: 5 }).length, 5);
});

Deno.test("les cinq formes de question, et seulement celles que l'app sait afficher", () => {
  const all = ["choice", "truefalse", "gap", "order", "match"] as const;
  const tf = readQuestion({ kind: "truefalse", prompt: "Le plan Marshall date de 1947.", answer: true, why: "." }, "s", { kinds: all, language: "de" });
  assertEquals(tf?.kind, "truefalse");
  assertEquals(tf?.choices, ["Richtig", "Falsch"]);
  assertEquals(tf?.answer, 0);
  const tfOld = readQuestion({ kind: "truefalse", prompt: "Faux ?", answer: false, why: "." }, "s");
  assertEquals(tfOld?.kind, "choice", "une app sans vrai/faux le lit comme un QCM à deux choix");
  assertEquals(tfOld?.answer, 1);

  const gap = readQuestion({ kind: "gap", prompt: "La ___ est la capitale.", choices: ["Paris", "Lyon", "Nice"], answer: 0, why: "." }, "s", { kinds: all });
  assertEquals(gap?.kind, "gap");
  assert(gap?.prompt.includes(GAP));
  assertEquals(gap?.choices[gap.answer], "Paris");
  const noGap = readQuestion({ kind: "gap", prompt: "Sans trou ?", choices: ["a", "b", "c"], answer: 0, why: "." }, "s", { kinds: all });
  assertEquals(noGap?.kind, "choice", "une phrase à trou sans trou redevient un QCM");

  const order = readQuestion({ kind: "order", prompt: "Dans l'ordre", items: ["1947", "1949", "1961", "1989"], why: "." }, "s", { kinds: all });
  assertEquals(order?.kind, "order");
  assertEquals(order?.choices, ["1947", "1949", "1961", "1989"], "l'ordre reste le bon : l'app mélange");
  assertEquals(readQuestion({ kind: "order", prompt: "Dans l'ordre", items: ["a", "b"] }, "s", { kinds: all }), null, "deux éléments ne font pas un ordre");
  assertEquals(readQuestion({ kind: "order", prompt: "Dans l'ordre", items: ["a", "b", "c"] }, "s"), null, "une app sans ordre n'en reçoit pas");

  const match = readQuestion({ kind: "match", prompt: "Associe", pairs: [["CO2", "dioxyde de carbone"], ["H2O", "eau"], ["NaCl", "sel"], ["H2O", "doublon"]], why: "." }, "s", { kinds: all });
  assertEquals(match?.kind, "match");
  assertEquals(match?.choices, ["CO2", "H2O", "NaCl"]);
  assertEquals(match?.matches, ["dioxyde de carbone", "eau", "sel"]);

  const hard = readQuestion({ prompt: "Q ?", choices: ["a", "b", "c"], answer: 0, why: ".", difficulty: 9 }, "s");
  assertEquals(hard?.difficulty, 3, "la difficulté reste entre 1 et 3");
});

Deno.test("les questions déjà posées ne reviennent pas", () => {
  const questions = readQuestions([
    { prompt: "Qui lance le plan Marshall ?", choices: ["a", "b", "c"], answer: 0, why: "." },
    { prompt: "Quand tombe le mur ?", choices: ["a", "b", "c"], answer: 0, why: ".", theme: 2 },
  ], "s", { avoid: ["qui lance le Plan Marshall"] });
  assertEquals(questions.map((q) => q.prompt), ["Quand tombe le mur ?"]);
  assertEquals(questions[0]?.theme, 2);
});

Deno.test("des flashcards remplies, sans doublon, et des cartes à trou", () => {
  const cards = readFlashcards([
    { front: "Q1", back: "R1" },
    { front: "", back: "R2" },
    { front: "Q3", back: "R3" },
    { front: "q1", back: "doublon" },
    { kind: "cloze", front: "La ___ produit du dioxygène.", back: "photosynthèse" },
    { kind: "cloze", front: "Sans trou", back: "x" },
  ], 3);
  assertEquals(cards.map((c) => c.front), ["Q1", "Q3", `La ${GAP} produit du dioxygène.`]);
  assertEquals(cards[2]?.kind, "cloze");
  assertEquals(readFlashcards([{ kind: "cloze", front: "Sans trou", back: "x" }])[0]?.kind, "basic");
});

Deno.test("jamais deux fois la même icône ni le même pictogramme sur un chemin", () => {
  const plan = readPlan({
    title: "La guerre froide",
    icon: "globe",
    themes: [
      { title: "Un", icon: "globe", symbol: "flag", points: ["a", "b"] },
      { title: "Deux", icon: "parchemin", symbol: "flag" },
      { title: "Trois", icon: "parchemin", symbol: "inconnu" },
      { title: "Quatre", icon: "drapeau", symbol: "map" },
    ],
  }, { shortSource: false, shortened: false, fallbackTitle: "x" });
  assert(plan);
  const icons = plan.themes.map((t) => t.icon);
  assertEquals(new Set([plan.icon, ...icons]).size, icons.length + 1);
  const symbols = plan.themes.map((t) => t.symbol);
  assertEquals(new Set(symbols).size, symbols.length);
  assertEquals(symbols[0], "flag");
  assertEquals(plan.themes[0]?.points, ["a", "b"]);
  const capped = readPlan({
    title: "T",
    themes: Array.from({ length: 12 }, (_, i) => ({ title: `Thème ${i}` })),
  }, { shortSource: false, shortened: false, fallbackTitle: "x", maxThemes: 8 });
  assertEquals(capped?.themes.length, 8, "le plafond de la marche tient");
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

Deno.test("la bonne réponse se lit en nombre, en texte, ou par la proposition elle-même", () => {
  const choices = ["Paris", "Lyon", "Nice"];
  assertEquals(answerIndex(1, choices), 1);
  assertEquals(answerIndex("2", choices), 2);
  assertEquals(answerIndex("lyon", choices), 1);
  assertEquals(answerIndex("Marseille", choices), -1);
  assertEquals(answerIndex(null, choices), -1);
  const question = readQuestion({ prompt: "La capitale ?", choices, answer: "Paris", why: "." }, "s");
  assertEquals(question?.choices[question.answer], "Paris");
});

Deno.test("un vrai/faux : la réponse dans toutes les langues, « vrai » toujours au rang 0", () => {
  assertEquals(readTrueFalse(true), true);
  assertEquals(readTrueFalse("True"), true);
  assertEquals(readTrueFalse("Faux"), false);
  assertEquals(readTrueFalse("falsch"), false);
  assertEquals(readTrueFalse("1"), false);
  assertEquals(readTrueFalse("peut-être"), null);
  const all = ["choice", "truefalse"] as const;
  // Le modèle commence par « Faux » : la langue est connue, les libellés sont les nôtres.
  const known = readQuestion({ kind: "truefalse", prompt: "Le mur tombe en 1989.", choices: ["Faux", "Vrai"], answer: true, why: "." }, "s", { kinds: all, language: "fr" });
  assertEquals(known?.choices, ["Vrai", "Faux"]);
  assertEquals(known?.answer, 0);
  // Langue du document : les libellés du modèle, remis dans l'ordre.
  const source = readQuestion({ kind: "truefalse", prompt: "Il muro cade nel 1989.", choices: ["Falso", "Vero"], answer: false, why: "." }, "s", { kinds: all, language: "source" });
  assertEquals(source?.choices, ["Vero", "Falso"]);
  assertEquals(source?.answer, 1);
  const arabic = readQuestion({ kind: "truefalse", prompt: "سقط الجدار عام 1989.", answer: true, why: "." }, "s", { kinds: all, language: "ar" });
  assertEquals(arabic?.choices, ["صحيح", "خطأ"]);
  const brazil = readQuestion({ kind: "truefalse", prompt: "O muro caiu em 1989.", answer: true, why: "." }, "s", { kinds: all, language: "pt-BR" });
  assertEquals(brazil?.choices, ["Verdadeiro", "Falso"]);
});

Deno.test("une phrase à trou ne donne pas sa réponse, et garde son trou au-delà de 30 mots", () => {
  const all = ["choice", "gap"] as const;
  assert(givesAway("Paris, la … de la France, compte deux millions d'habitants : Paris.", "Paris"));
  assert(!givesAway("La … est la capitale de la France.", "Paris"));
  assert(!givesAway("Le … de l'eau", "H"), "une réponse trop courte ne se cherche pas");
  assertEquals(
    readQuestion({ kind: "gap", prompt: "La mitochondrie produit l'… : la mitochondrie produit l'ATP.", choices: ["ATP", "ADN", "ARN"], answer: 0, why: "." }, "s", { kinds: all }),
    null,
  );
  const long = `${Array.from({ length: 32 }, (_, i) => `mot${i}`).join(" ")} … fin.`;
  const kept = readQuestion({ kind: "gap", prompt: long, choices: ["juste", "faux", "leurre"], answer: 0, why: "." }, "s", { kinds: all });
  assertEquals(kept?.kind, "gap");
  assert(kept?.prompt.includes(GAP));
});

Deno.test("la question de fin d'un thème est une question simple", () => {
  const questions = readQuestions([
    { kind: "order", prompt: "Dans l'ordre", items: ["a", "b", "c"], why: ".", difficulty: 3 },
    { prompt: "Difficile ?", choices: ["a", "b", "c"], answer: 0, why: ".", difficulty: 3 },
    { prompt: "Simple ?", choices: ["a", "b", "c"], answer: 0, why: ".", difficulty: 1 },
  ], "s", { kinds: ["choice", "order"] });
  assertEquals(finalFirst(questions).map((q) => q.prompt), ["Simple ?", "Dans l'ordre", "Difficile ?"]);
  const hardOnly = questions.slice(0, 2);
  assertEquals(finalFirst(hardOnly).map((q) => q.prompt), ["Difficile ?", "Dans l'ordre"]);
  assertEquals(finalFirst([]), []);
});

Deno.test("le budget des notes se partage entre tous les thèmes", () => {
  assertEquals(fairShares([2_000, 2_000, 2_000, 2_000], 4_000), [1_000, 1_000, 1_000, 1_000]);
  assertEquals(fairShares([100, 5_000, 5_000], 3_100), [100, 1_500, 1_500], "un thème court garde tout");
  assertEquals(fairShares([10, 20], 1_000), [10, 20]);
  assertEquals(fairShares([], 1_000), []);
  const shares = fairShares([7, 7, 7], 10);
  assertEquals(shares.reduce((a, b) => a + b, 0), 10);
});
