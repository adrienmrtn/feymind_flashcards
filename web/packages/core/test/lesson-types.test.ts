/**
 * Les formats JSON de la leçon : ce que le serveur écrit, l'app le lit, et le site aussi.
 * Les cas sont ceux de `LessonFormatTests` dans `MicaboTests/LessonModelTests.swift`.
 */

import { describe, expect, it } from "vitest";

import {
  addTime,
  answerText,
  averageQuizPercent,
  blockIsBoxed,
  emptyProgress,
  finalQuestion,
  inlineSteps,
  markDone,
  noteMissed,
  noteRight,
  notesPlainText,
  questionIsValid,
  readLessonPath,
  readLessonProgress,
  readQuizQuestion,
  readThemeNotes,
  readThemeQuiz,
  reserveQuestions,
  resetProgress,
  totalSeconds,
} from "../src/lesson/types";

describe("les notes d'un thème", () => {
  it("lisent chaque bloc que le serveur écrit, et un bloc inconnu comme un paragraphe", () => {
    const notes = readThemeNotes({
      oneLiner: "Deux blocs s'opposent sans guerre directe.",
      blocks: [
        { type: "subtitle", text: "Deux camps" },
        { type: "paragraph", text: "Les **États-Unis** et l'**URSS** s'opposent." },
        { type: "list", items: ["Plan Marshall", "Doctrine Truman", "Kominform"] },
        { type: "definition", term: "Endiguement", text: "Contenir l'expansion soviétique." },
        { type: "dates", items: [{ date: "1947", text: "Doctrine Truman" }, { date: "1989", text: "Chute du Mur" }] },
        { type: "formula", latex: "E = mc^2", caption: "Einstein" },
        { type: "example", text: "Berlin, 1948." },
        { type: "carousel", text: "Un bloc d'une version future." },
      ],
      takeaways: ["Un", "Deux", "Trois"],
    })!;
    expect(notes.blocks).toHaveLength(8);
    expect(notes.blocks[0]).toEqual({ type: "subtitle", text: "Deux camps" });
    expect(notes.blocks[3]).toEqual({ type: "definition", term: "Endiguement", text: "Contenir l'expansion soviétique." });
    expect(notes.blocks[7]).toEqual({ type: "paragraph", text: "Un bloc d'une version future." });
    expect(blockIsBoxed(notes.blocks[5]!)).toBe(true);
    expect(notesPlainText(notes)).not.toContain("**");
    expect(readThemeNotes(JSON.stringify(notes))).toEqual(notes);
  });

  it("lisent les étapes, les tableaux et les citations dans leurs propres champs", () => {
    const notes = readThemeNotes({
      oneLiner: "Une idée.",
      blocks: [
        { type: "steps", items: ["Lire l'énoncé", "Poser $x^2 = 4$"], text: "1. Lire 2. Poser" },
        { type: "table", columns: ["Pays", "Capitale"], rows: [["France", "Paris"], ["Italie", "Rome"]], text: "France : Paris" },
        { type: "quote", text: "Je pense, donc je suis.", author: "Descartes" },
        { type: "quote", text: "Sans auteur.", author: "  " },
        { type: "steps", items: [], text: "Repli lisible." },
      ],
      takeaways: ["Un"],
    })!;
    expect(notes.blocks).toEqual([
      { type: "steps", items: ["Lire l'énoncé", "Poser $x^2 = 4$"] },
      { type: "table", columns: ["Pays", "Capitale"], rows: [["France", "Paris"], ["Italie", "Rome"]] },
      { type: "quote", text: "Je pense, donc je suis.", author: "Descartes" },
      { type: "quote", text: "Sans auteur.", author: null },
      { type: "paragraph", text: "Repli lisible." },
    ]);
    expect(notesPlainText(notes)).toContain("2. Poser");
    expect(notesPlainText(notes)).toContain("France | Paris");
  });

  it("lisent le genre et le titre d'un encadré ; un genre inconnu est une astuce, sans texte il disparaît", () => {
    const notes = readThemeNotes({
      oneLiner: "Une idée.",
      blocks: [
        { type: "callout", kind: "mistake", title: "Le piège du signe", text: "On oublie le **signe moins**." },
        { type: "callout", kind: "why", text: "Parce que la vitesse change." },
        { type: "callout", kind: "remember", title: "  ", text: "Toujours l'unité." },
        { type: "callout", kind: "carousel", text: "Un genre d'une version future." },
        { type: "callout", text: "Sans genre." },
        { type: "callout", kind: "tip", title: "Sans texte" },
        { type: "callout", kind: "tip", text: "   " },
      ],
      takeaways: [],
    })!;
    expect(notes.blocks).toEqual([
      { type: "callout", kind: "mistake", title: "Le piège du signe", text: "On oublie le **signe moins**." },
      { type: "callout", kind: "why", title: null, text: "Parce que la vitesse change." },
      { type: "callout", kind: "remember", title: null, text: "Toujours l'unité." },
      { type: "callout", kind: "tip", title: null, text: "Un genre d'une version future." },
      { type: "callout", kind: "tip", title: null, text: "Sans genre." },
    ]);
    expect(notes.blocks.every(blockIsBoxed)).toBe(true);
    expect(notesPlainText(notes)).toContain("Le piège du signe : On oublie le signe moins.");
  });

  it("retirent un bloc illisible plutôt que de montrer un trou", () => {
    const notes = readThemeNotes({
      oneLiner: "Une idée.",
      blocks: [
        { type: "carousel" },
        { type: "paragraph", text: "  " },
        { type: "table", columns: ["A"], text: "" },
        { type: "definition", term: "Sans texte" },
        { type: "paragraph", text: "Reste." },
      ],
      takeaways: [],
    })!;
    expect(notes.blocks).toEqual([{ type: "paragraph", text: "Reste." }]);
    expect(readThemeNotes(null)).toBeNull();
    expect(readThemeNotes("{")).toBeNull();
  });

  it("relisent des étapes écrites d'une traite comme des étapes ; une date n'en fait pas", () => {
    const notes = readThemeNotes({
      oneLiner: "Une idée.",
      blocks: [
        { type: "paragraph", text: "La photosynthèse se déroule en étapes : 1. La lumière est absorbée par la chlorophylle. 2. L'eau est décomposée ; 3. Le dioxygène est libéré." },
        { type: "paragraph", text: "La guerre s'achève en 1945. Elle a duré 6 ans." },
        { type: "paragraph", text: "1. Poser. 2. Calculer. 3. Vérifier." },
      ],
      takeaways: [],
    })!;
    expect(notes.blocks).toEqual([
      { type: "paragraph", text: "La photosynthèse se déroule en étapes :" },
      { type: "steps", items: ["La lumière est absorbée par la chlorophylle.", "L'eau est décomposée", "Le dioxygène est libéré."] },
      { type: "paragraph", text: "La guerre s'achève en 1945. Elle a duré 6 ans." },
      { type: "steps", items: ["Poser.", "Calculer.", "Vérifier."] },
    ]);
    expect(inlineSteps("1. Une. 2. Deux étapes seulement.")).toBeNull();
  });

  it("ramènent la flèche étiquetée d'amsmath à une flèche, son étiquette en légende", () => {
    const notes = readThemeNotes({
      oneLiner: "Une idée.",
      blocks: [
        { type: "formula", latex: "6CO_2 + 6H_2O \\xrightarrow{Énergie lumineuse} C_6H_{12}O_6 + 6O_2" },
        { type: "formula", latex: "A xrightarrow{Lumière} B", caption: "La réaction" },
      ],
      takeaways: [],
    })!;
    expect(notes.blocks).toEqual([
      { type: "formula", latex: "6CO_2 + 6H_2O \\rightarrow C_6H_{12}O_6 + 6O_2", caption: "Énergie lumineuse" },
      { type: "formula", latex: "A \\rightarrow B", caption: "La réaction · Lumière" },
    ]);
  });
});

describe("le plan", () => {
  it("se lit et se relit", () => {
    const path = readLessonPath({
      icon: "globe",
      intro: { lines: ["Un", "Deux", "Trois"], minutes: 25 },
      takeaways: ["A", "B", "C", "D", "E"],
      groups: [{ name: "Les causes", themes: [0, 1] }],
      status: "ready",
    });
    expect(path).toEqual({
      version: 1,
      icon: "globe",
      intro: { lines: ["Un", "Deux", "Trois"], minutes: 25 },
      takeaways: ["A", "B", "C", "D", "E"],
      groups: [{ name: "Les causes", themes: [0, 1] }],
      shortened: false,
      singleQuiz: false,
      status: "ready",
    });
    expect(readLessonPath(JSON.stringify(path))).toEqual(path);
    expect(readLessonPath(null)).toBeNull();
    expect(readLessonPath("{")).toBeNull();
    expect(readLessonPath({ icon: "globe" })).toBeNull();
    expect(readLessonPath({ icon: "globe", intro: {}, status: "licorne" })?.status).toBe("generating");
  });
});

describe("les questions", () => {
  const questions = Array.from({ length: 4 }, (_, index) => ({
    id: `t:${index}`, prompt: `Q${index}`, choices: ["a", "b", "c", "d"], answer: 1, why: "parce que",
  }));

  it("séparent la question de fin de la réserve", () => {
    const quiz = readThemeQuiz({ questions })!;
    expect(finalQuestion(quiz)?.id).toBe("t:0");
    expect(reserveQuestions(quiz).map((question) => question.id)).toEqual(["t:1", "t:2", "t:3"]);
    expect(quiz.questions[0]).toMatchObject({ kind: "choice", difficulty: 2, matches: [] });
    expect(questionIsValid(quiz.questions[0]!)).toBe(true);
    expect(questionIsValid(readQuizQuestion({ id: "x", prompt: "Q", choices: ["a"], answer: 3, why: "" })!)).toBe(false);
    expect(readQuizQuestion({ prompt: "sans id" })).toBeNull();
    expect(readQuizQuestion({ prompt: "avec repli" }, "t:9")?.id).toBe("t:9");
  });

  it("écrivent la bonne réponse en clair selon la forme", () => {
    expect(answerText(readQuizQuestion({ id: "a", kind: "gap", prompt: "x", choices: ["un", "deux"], answer: 1, why: "" })!)).toBe("deux");
    expect(answerText(readQuizQuestion({ id: "b", kind: "order", prompt: "x", choices: ["un", "deux", "trois"], answer: 0, why: "" })!)).toBe("un → deux → trois");
    expect(answerText(readQuizQuestion({ id: "c", kind: "match", prompt: "x", choices: ["A", "B"], matches: ["1", "2"], answer: 0, why: "" })!)).toBe("A : 1 · B : 2");
    expect(readQuizQuestion({ id: "d", kind: "licorne", prompt: "x", choices: ["a", "b"], answer: 0, why: "", difficulty: 9 })).toMatchObject({ kind: "choice", difficulty: 3 });
  });
});

describe("la progression", () => {
  it("garde le temps, les scores et les ratées", () => {
    let progress = emptyProgress();
    progress = markDone(progress, "intro");
    progress = markDone(progress, "notes:0");
    progress = markDone(progress, "notes:0");
    progress = addTime(progress, 120, "notes");
    progress = addTime(progress, 60, "quiz");
    progress = addTime(progress, -5, "quiz");
    progress = addTime(progress, 10 * 3600, "quiz");
    progress = { ...progress, quizScores: { "quiz:0": [4, 5], "quiz:1": [3, 5] } };
    progress = noteMissed(progress, "a");
    progress = noteMissed(progress, "b");
    progress = noteMissed(progress, "a");
    progress = noteRight(progress, "b");
    progress = { ...progress, finishedAt: "2027-01-15T08:00:00.000Z" };

    expect(progress.done).toEqual(["intro", "notes:0"]);
    expect(totalSeconds(progress)).toBe(180);
    expect(averageQuizPercent(progress)).toBe(70);
    expect(progress.missed).toEqual(["a"]);
    expect(readLessonProgress(JSON.stringify(progress))).toEqual(progress);
    expect(readLessonProgress(null)).toEqual(emptyProgress());
    expect(averageQuizPercent(emptyProgress())).toBeNull();
    expect(resetProgress(progress)).toEqual({ ...emptyProgress(), seconds: progress.seconds });
  });

  it("lit une progression écrite par l'app, avec ses dates ISO et ses clés inconnues", () => {
    const progress = readLessonProgress({
      done: ["intro", "intro", "notes:0"],
      inCircle: 1.4,
      quizScores: { "quiz:0": [4, 5], bad: [1] },
      missed: ["a"],
      seconds: { notes: 840, dessin: 3 },
      finishedAt: "2026-10-20T18:03:00Z",
      extra: true,
    });
    expect(progress.done).toEqual(["intro", "notes:0"]);
    expect(progress.inCircle).toBe(1);
    expect(progress.quizScores).toEqual({ "quiz:0": [4, 5] });
    expect(progress.seconds).toEqual({ notes: 840 });
    expect(progress.finishedAt).toBe("2026-10-20T18:03:00Z");
  });
});
