import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  clampParagraph,
  clampWords,
  calloutKind,
  cleanInline,
  LIMITS,
  markdownBlocks,
  noteLimits,
  type NoteBlock,
  readBlock,
  readFlashcards,
  readNotes,
  readQuestion,
  rewriteChemistry,
  sentences,
  separateBoxes,
  words,
} from "./schema.ts";
import { depthOf } from "../_shared/learner.ts";
import { PROMPT_VERSION, THEME_SYSTEM_PROMPT, themeBrief } from "./prompt.ts";

describe("les nombres décimaux et les abréviations", () => {
  it("ne coupe pas une phrase dans un nombre ni dans une formule", () => {
    assert.deepEqual(sentences("Pi vaut 3.14 environ. La suite est simple."), ["Pi vaut 3.14 environ.", "La suite est simple."]);
    assert.deepEqual(sentences("On prend $g = 9.81$ ici. Puis on calcule."), ["On prend $g = 9.81$ ici.", "Puis on calcule."]);
    assert.deepEqual(sentences("Un point $a. b$ reste. Fin."), ["Un point $a. b$ reste.", "Fin."]);
  });

  it("recolle un paragraphe sans espace parasite", () => {
    assert.equal(clampParagraph("Pi vaut 3.14 environ."), "Pi vaut 3.14 environ.");
    assert.equal(clampParagraph("On prend $g=9.81$ m/s². Et e.g. un cas."), "On prend $g=9.81$ m/s². Et e.g. un cas.");
    const notes = readNotes({ oneLiner: "La vitesse vaut 3.5 m/s.", blocks: [{ type: "paragraph", text: "Avec $g=9.81$, e.g. une chute." }] });
    assert.equal(notes?.oneLiner, "La vitesse vaut 3.5 m/s.");
    assert.equal(notes?.blocks[0]?.type === "paragraph" && notes.blocks[0].text, "Avec $g=9.81$, e.g. une chute.");
  });
});

describe("les coupes respectent le balisage", () => {
  it("une formule ou un mot-clé compte pour un seul mot", () => {
    assert.equal(clampWords("On a $a + b = c$ puis la suite", 3), "On a $a + b = c$");
    assert.equal(clampWords("Le **cycle de Krebs** produit de l'énergie", 2), "Le **cycle de Krebs**");
  });

  it("un $ ou des ** orphelins partent", () => {
    assert.equal(cleanInline("Le prix $x vaut"), "Le prix x vaut");
    assert.equal(cleanInline("Un **mot seul"), "Un mot seul");
    assert.equal(cleanInline("$a$ et $b$"), "$a$ et $b$");
  });

  it("les puces d'une liste longue gardent leur formule entière", () => {
    const [list] = readBlock({
      type: "list",
      items: ["La relation $E = m c^2$ relie masse et énergie dans un très long élément de liste qui déborde vraiment", "Deux", "Trois"],
    });
    assert.equal(list?.type, "list");
    const item = list?.type === "list" ? list.items[0]! : "";
    assert.equal((item.match(/\$/g) ?? []).length, 2);
  });

  it("les questions et les cartes sont coupées puis nettoyées", () => {
    const question = readQuestion({
      kind: "choice",
      prompt: "Que vaut $x$ quand $2x = 4$ ?",
      choices: ["$x = 2$", "$x = 4$", "$x = 1$ et $y", "8"],
      answer: 0,
      why: "On divise par $2.",
    }, "s");
    assert(question);
    for (const text of [question.prompt, question.why, ...question.choices]) {
      assert.equal((text.match(/\$/g) ?? []).length % 2, 0, text);
    }
    const [card] = readFlashcards([{ front: "La formule de $v", back: "La ==vitesse== moyenne" }]);
    assert.equal(card?.front, "La formule de v");
    assert.equal(card?.back, "La vitesse moyenne");
  });
});

describe("la formule", () => {
  it("passe par la même remise en forme que les fiches", () => {
    const [plain] = readBlock({ type: "formula", latex: "$E = mc^2$", caption: "l'énergie" });
    assert.deepEqual(plain, { type: "formula", latex: "E = mc^2", caption: "l'énergie" });
    const loop = readBlock({ type: "formula", latex: "6CO_2 + 6H_2O \\rightarrow C_6H_{12}O_6 + 6O_2 ".repeat(5) })[0];
    assert.equal(loop?.type === "formula" && loop.latex, "6CO_2 + 6H_2O \\rightarrow C_6H_{12}O_6 + 6O_2");
    const [arrow] = readBlock({ type: "formula", latex: "6CO_2 \\xrightarrow{Lumière} C_6H_{12}O_6" });
    assert.equal(arrow?.type === "formula" && arrow.latex, "6CO_2 \\rightarrow C_6H_{12}O_6");
    assert.equal(arrow?.type === "formula" && arrow.caption, "Lumière");
    assert.deepEqual(readBlock({ type: "formula", latex: Array.from({ length: 60 }, (_, i) => `a_{${i}}`).join(" + ") }), []);
  });

  it("réécrit la chimie mhchem en LaTeX ordinaire", () => {
    assert.equal(rewriteChemistry("\\ce{2H2 + O2 -> 2H2O}"), "2H_2 + O_2 \\rightarrow 2H_2O");
    assert.equal(rewriteChemistry("\\ce{C6H12O6}"), "C_6H_{12}O_6");
  });
});

describe("le Markdown d'un paragraphe", () => {
  it("devient une liste, des étapes, un sous-titre et un tableau", () => {
    const blocks = markdownBlocks(
      "## Les causes\nTrois causes :\n- la crise\n- la guerre\n- la dette\n\n1. Poser\n2. Calculer\n\n| Mot | Traduction |\n|---|---|\n| dog | chien |\n| cat | chat |",
    );
    assert(blocks);
    assert.deepEqual(blocks.map((block) => block.type), ["subtitle", "paragraph", "list", "steps", "table"]);
    assert.deepEqual(blocks[0], { type: "subtitle", text: "Les causes" });
    const table = blocks[4]!;
    assert.equal(table.type === "table" && table.rows.length, 2);
  });

  it("laisse un paragraphe ordinaire tranquille", () => {
    assert.equal(markdownBlocks("Une phrase. Une autre."), null);
    assert.deepEqual(readBlock({ type: "paragraph", text: "# Titre seul" }), [{ type: "subtitle", text: "Titre seul" }]);
  });
});

describe("les nouveaux blocs", () => {
  it("les étapes portent un texte de repli numéroté", () => {
    const [steps] = readBlock({ type: "steps", items: ["1. Lire l'énoncé", "Poser l'équation", "Résoudre"] });
    assert.deepEqual(steps, {
      type: "steps",
      items: ["Lire l'énoncé", "Poser l'équation", "Résoudre"],
      text: "1. Lire l'énoncé 2. Poser l'équation 3. Résoudre",
    });
    assert.equal(readBlock({ type: "steps", items: ["Seule"] })[0]?.type, "paragraph");
    const many = readBlock({ type: "steps", items: Array.from({ length: 9 }, (_, i) => `Étape ${i}`) })[0];
    assert.equal(many?.type === "steps" && many.items.length, 6);
  });

  it("le tableau garde ses rangées bien formées et porte un texte de repli", () => {
    const [table] = readBlock({
      type: "table",
      columns: ["Mot", "Traduction"],
      rows: [["dog", "chien"], ["cat"], ["bird", "oiseau"], "x", ["fish", "poisson", "trop"]],
    });
    assert.deepEqual(table, {
      type: "table",
      columns: ["Mot", "Traduction"],
      rows: [["dog", "chien"], ["bird", "oiseau"]],
      text: "dog — chien ; bird — oiseau",
    });
  });

  it("un tableau trop maigre redevient du texte", () => {
    const blocks = readBlock({ type: "table", columns: ["A", "B"], rows: [["un", "deux"], ["trois"]] });
    assert.equal(blocks.length, 1);
    assert.equal(blocks[0]?.type, "paragraph");
    assert.deepEqual(readBlock({ type: "table", columns: ["A"], rows: [] }), []);
  });

  it("le tableau garde quatre colonnes au plus", () => {
    const [table] = readBlock({
      type: "table",
      columns: ["a", "b", "c", "d", "e"],
      rows: [["1", "2", "3", "4", "5"], ["6", "7", "8", "9", "10"]],
    });
    assert.equal(table?.type === "table" && table.columns.length, 4);
    assert.equal(table?.type === "table" && table.rows[0]!.length, 4);
  });

  it("la citation perd ses guillemets et garde son auteur", () => {
    assert.deepEqual(readBlock({ type: "quote", text: "« Je pense, donc je suis. »", author: "Descartes" }), [
      { type: "quote", text: "Je pense, donc je suis.", author: "Descartes" },
    ]);
    assert.deepEqual(readBlock({ type: "quote", text: "Sans auteur." }), [{ type: "quote", text: "Sans auteur." }]);
  });

  it("étapes, tableau et citation sont des encadrés : jamais deux de suite", () => {
    const steps: NoteBlock = { type: "steps", items: ["a", "b"], text: "1. a 2. b" };
    const quote: NoteBlock = { type: "quote", text: "Q.", author: "A" };
    const table: NoteBlock = { type: "table", columns: ["x", "y"], rows: [["1", "2"], ["3", "4"]], text: "1 — 2 ; 3 — 4" };
    assert.deepEqual(
      separateBoxes([steps, quote, { type: "paragraph", text: "P." }]).map((block) => block.type),
      ["steps", "paragraph", "quote"],
    );
    assert.deepEqual(separateBoxes([table, steps, quote]).map((block) => block.type), ["table", "paragraph", "quote"]);
    const tail = separateBoxes([table, quote]);
    assert.deepEqual(tail.map((block) => block.type), ["table", "paragraph"]);
    assert.equal(tail[1]!.type === "paragraph" && tail[1]!.text, "Q. (A)");
  });
});

describe("le prompt du thème", () => {
  it("décrit les nouveaux blocs et demande de varier les formes", () => {
    for (const shape of ['"type":"steps"', '"type":"table"', '"type":"quote"', "\\ce{}", "squelette"]) {
      assert(THEME_SYSTEM_PROMPT.includes(shape), shape);
    }
  });

  it("propose une ouverture différente aux thèmes voisins", () => {
    const brief = (themeIndex: number) =>
      themeBrief({ lessonTitle: "L", themeTitle: "T", themeIndex, themes: ["a", "b", "c"], questions: 5, flashcards: 4, kinds: ["choice"] });
    const opening = (text: string) => text.split("FORME DE CE THÈME\n")[1];
    assert.notEqual(opening(brief(0)), opening(brief(1)));
    assert.notEqual(opening(brief(1)), opening(brief(2)));
  });
});

describe("les encadrés (callout)", () => {
  it("garde le genre, le titre et le texte", () => {
    assert.deepEqual(
      readBlock({ type: "callout", kind: "mistake", title: "Le piège du signe.", text: "On oublie le **signe moins** devant la parenthèse." }),
      [{ type: "callout", kind: "mistake", title: "Le piège du signe", text: "On oublie le **signe moins** devant la parenthèse." }],
    );
    assert.deepEqual(readBlock({ type: "callout", kind: "why", text: "Parce que." }), [{ type: "callout", kind: "why", text: "Parce que." }]);
  });

  it("un genre inconnu devient une astuce, un alias retrouve son genre", () => {
    assert.equal(calloutKind("carousel"), "tip");
    assert.equal(calloutKind(undefined), "tip");
    assert.equal(calloutKind("constructor"), "tip");
    assert.equal(calloutKind("Pitfall"), "mistake");
    assert.equal(calloutKind("mnemonic"), "tip");
    assert.equal(calloutKind("rule"), "remember");
    const [block] = readBlock({ type: "callout", kind: "mystère", text: "Un texte." });
    assert.equal(block?.type === "callout" && block.kind, "tip");
  });

  it("un encadré écrit sous le nom de son genre reste un encadré", () => {
    assert.deepEqual(readBlock({ type: "mistake", text: "Confondre masse et poids." }), [
      { type: "callout", kind: "mistake", text: "Confondre masse et poids." },
    ]);
    assert.deepEqual(readBlock({ type: "constructor", text: "x" }), []);
  });

  it("le texte tient en 45 mots, le titre en 6, et un encadré vide part", () => {
    const long = Array.from({ length: 12 }, (_, i) => `Phrase ${i} assez courte ici.`).join(" ");
    const [block] = readBlock({ type: "callout", kind: "tip", title: "Un titre bien trop long pour un encadré", text: long });
    assert(block?.type === "callout");
    assert(words(block.text).length <= LIMITS.calloutWords);
    assert(words(block.title ?? "").length <= LIMITS.calloutTitleWords);
    assert.deepEqual(readBlock({ type: "callout", kind: "tip", title: "Seul", text: "  " }), []);
  });

  it("est un encadré : jamais deux de suite, et il se relit en texte courant", () => {
    const callout: NoteBlock = { type: "callout", kind: "mistake", title: "Piège", text: "Ne pas oublier l'unité." };
    const example: NoteBlock = { type: "example", text: "E." };
    assert.deepEqual(
      separateBoxes([example, callout, { type: "paragraph", text: "P." }]).map((block) => block.type),
      ["example", "paragraph", "callout"],
    );
    const tail = separateBoxes([example, callout]);
    assert.deepEqual(tail.map((block) => block.type), ["example", "paragraph"]);
    assert.equal(tail[1]!.type === "paragraph" && tail[1]!.text, "**Piège** : Ne pas oublier l'unité.");
  });

  it("au-delà du plafond, les encadrés de plus se lisent en paragraphe", () => {
    const blocks = Array.from({ length: 6 }, (_, i) => [
      { type: "paragraph", text: `Paragraphe ${i}.` },
      { type: "callout", kind: "tip", text: `Astuce ${i}.` },
    ]).flat();
    const notes = readNotes({ oneLiner: "Une idée.", blocks }, noteLimits(depthOf("health")));
    assert(notes);
    assert.equal(notes.blocks.filter((block) => block.type === "callout").length, LIMITS.calloutsMax);
    assert(notes.blocks.some((block) => block.type === "paragraph" && block.text === "Astuce 4."));
  });
});

describe("la profondeur suit la marche", () => {
  const sentence = "Cette phrase compte exactement dix mots pour le test ici.";
  const paragraph = Array.from({ length: 12 }, () => sentence).join(" ");
  const many = (n: number) =>
    Array.from({ length: n }, (_, i) => i % 2 === 0 ? { type: "paragraph", text: `P${i}.` } : { type: "list", items: ["a", "b", `c${i}`] });

  it("les bornes viennent de depthOf, sous les plafonds durs", () => {
    assert.deepEqual(noteLimits(), { blocksMax: 7, paragraphWords: 60 });
    assert.deepEqual(noteLimits(depthOf("lowerSecondary")), { blocksMax: 8, paragraphWords: 70 });
    assert.deepEqual(noteLimits(depthOf("upperSecondary")), { blocksMax: 10, paragraphWords: 90 });
    assert.deepEqual(noteLimits(depthOf("graduate")), { blocksMax: 12, paragraphWords: 110 });
    assert.deepEqual(noteLimits({ blocks: [20, 40], paragraphWords: 500 }), { blocksMax: LIMITS.blocksHardMax, paragraphWords: LIMITS.paragraphHardWords });
    assert.deepEqual(noteLimits({ blocks: [1, 2], paragraphWords: 10 }), { blocksMax: 7, paragraphWords: 60 });
  });

  it("un étudiant garde plus de blocs et des paragraphes plus longs qu'un collégien", () => {
    const raw = { oneLiner: "Une idée.", blocks: [{ type: "paragraph", text: paragraph }, ...many(14)] };
    const young = readNotes(raw, noteLimits(depthOf("lowerSecondary")))!;
    const old = readNotes(raw, noteLimits(depthOf("undergraduate")))!;
    const before = readNotes(raw)!;
    assert.equal(before.blocks.length, 7, "sans marche, les bornes d'avant");
    assert.equal(young.blocks.length, 8);
    assert.equal(old.blocks.length, 12);
    const first = (notes: typeof young) => notes.blocks[0]!.type === "paragraph" ? words(notes.blocks[0]!.text).length : 0;
    assert.equal(first(before), 60);
    assert.equal(first(young), 70);
    assert.equal(first(old), 110);
  });

  it("la définition et l'exemple suivent la longueur de la marche", () => {
    const limits = noteLimits(depthOf("health"));
    const [example] = readBlock({ type: "example", text: paragraph }, limits);
    assert.equal(example?.type === "example" && words(example.text).length, 110);
    const [short] = readBlock({ type: "example", text: paragraph });
    assert.equal(short?.type === "example" && words(short.text).length, 60);
  });
});

describe("le fil d'enseignement du thème", () => {
  it("le prompt demande d'enseigner, pas de résumer, et décrit l'encadré", () => {
    for (const part of ["UN THÈME ENSEIGNE", "EXEMPLE TRAVAILLÉ", "PIÈGE", "parce que", '"type":"callout"', '"mistake"', '"remember"', "cas NOUVEAU", "l'idée fausse"]) {
      assert(THEME_SYSTEM_PROMPT.includes(part), part);
    }
    assert(!THEME_SYSTEM_PROMPT.includes("2 à 5 blocs"), "le nombre de blocs vient de la marche");
    assert.equal(PROMPT_VERSION, "lesson-v3.0.0");
  });

  it("le volume des notes et la question d'examen suivent la marche", () => {
    const brief = (tier: Parameters<typeof depthOf>[0]) =>
      themeBrief({ lessonTitle: "L", themeTitle: "T", themeIndex: 0, themes: ["a"], questions: 6, flashcards: 5, kinds: ["choice"], depth: depthOf(tier) });
    assert.match(brief("lowerSecondary"), /4 à 6 blocs .* 70 mots au plus/);
    assert.match(brief("graduate"), /6 à 10 blocs .* 110 mots au plus/);
    assert(brief("health").includes("format exact de son examen"));
    assert(!brief("lowerSecondary").includes("format exact de son examen"));
    assert.match(themeBrief({ lessonTitle: "L", themeTitle: "T", themeIndex: 0, themes: ["a"], questions: 6, flashcards: 5, kinds: ["choice"] }), /5 à 7 blocs/);
  });

  it("une ouverture propose de commencer par le piège", () => {
    const opening = themeBrief({ lessonTitle: "L", themeTitle: "T", themeIndex: 3, themes: ["a", "b", "c", "d"], questions: 5, flashcards: 4, kinds: ["choice"] });
    assert(opening.includes('"callout" "mistake"'));
  });
});
