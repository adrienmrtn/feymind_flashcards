/**
 * La copie d'examen blanc.
 *
 * Ce qui se teste ici est le **socle** : la correction des questions fermées, qui ne passe par
 * aucun modèle et doit donner deux fois le même résultat sur la même copie. C'est elle qui
 * fait que « 54 puis 71 » veut dire quelque chose.
 */

import { describe, expect, it } from "vitest";

import {
  MOCK_PAPER_SIZE,
  clampScore,
  correctCount,
  gradeClosed,
  isClosedQuestion,
  isMockDebrief,
  normalizeAnswer,
  paperMinutes,
  paperQuota,
  paperScore,
  quotaSize,
  sameAnswer,
  type MockChoiceQuestion,
  type MockFeynmanQuestion,
  type MockGapQuestion,
  type MockQuestion,
  type MockTrueFalseQuestion,
} from "../src/index";

const choice: MockChoiceQuestion = {
  kind: "choice",
  id: "q1",
  prompt: "Quelle part de l'eau terrestre est dans les océans ?",
  choices: ["50 %", "72 %", "97 %", "99 %"],
  answerIndex: 2,
  why: "Les océans portent 97 % de l'eau de la planète.",
};

const truefalse: MockTrueFalseQuestion = {
  kind: "truefalse",
  id: "q2",
  prompt: "La quantité totale d'eau sur Terre augmente chaque année.",
  answer: false,
  why: "Elle ne change pas : elle change d'état et de réservoir.",
};

const gap: MockGapQuestion = {
  kind: "gap",
  id: "q3",
  prompt: "Le passage de l'eau liquide à l'état gazeux s'appelle l'…",
  answer: "évaporation",
  accepts: ["vaporisation"],
  why: "C'est la première étape du cycle.",
};

const feynman: MockFeynmanQuestion = {
  kind: "feynman",
  id: "q4",
  prompt: "Explique le cycle de l'eau à quelqu'un qui ne l'a jamais vu.",
  expected: "Évaporation, condensation, précipitations, ruissellement.",
};

describe("les familles de questions", () => {
  it("sépare ce qui se corrige sans modèle de ce qui en demande un", () => {
    expect([choice, truefalse, gap].every(isClosedQuestion)).toBe(true);
    expect(isClosedQuestion(feynman)).toBe(false);
  });
});

describe("la correction des questions fermées", () => {
  it("note un QCM sur la case cochée, et rien d'autre", () => {
    expect(gradeClosed(choice, { id: "q1", choiceIndex: 2 }).score).toBe(100);
    expect(gradeClosed(choice, { id: "q1", choiceIndex: 0 }).score).toBe(0);
    expect(gradeClosed(choice, undefined).score).toBe(0);
  });

  it("ne confond pas une case non cochée avec « faux »", () => {
    // `truth: false` est une réponse ; `undefined` est une question blanche. Les deux valent
    // zéro ici, mais seule la première peut valoir cent.
    expect(gradeClosed(truefalse, { id: "q2", truth: false }).score).toBe(100);
    expect(gradeClosed(truefalse, { id: "q2", truth: true }).score).toBe(0);
    expect(gradeClosed(truefalse, { id: "q2" }).score).toBe(0);
  });

  it("corrige le cours et non la frappe", () => {
    expect(gradeClosed(gap, { id: "q3", text: "  L'Évaporation. " }).score).toBe(100);
    expect(gradeClosed(gap, { id: "q3", text: "evaporation" }).score).toBe(100);
    expect(gradeClosed(gap, { id: "q3", text: "vaporisation" }).score).toBe(100);
    expect(gradeClosed(gap, { id: "q3", text: "condensation" }).score).toBe(0);
    expect(gradeClosed(gap, { id: "q3", text: "   " }).score).toBe(0);
  });

  it("n'accepte pas le vide comme réponse identique au vide", () => {
    expect(sameAnswer("", "")).toBe(false);
    expect(normalizeAnswer("Les Océans !")).toBe("oceans");
  });

  it("rend le pourquoi, pour que la correction apprenne quelque chose", () => {
    expect(gradeClosed(choice, { id: "q1", choiceIndex: 0 }).comment).toBe(choice.why);
  });
});

describe("la note de la copie", () => {
  it("est la moyenne des questions, sur cent", () => {
    expect(
      paperScore([
        { id: "a", score: 100 },
        { id: "b", score: 0 },
        { id: "c", score: 50 },
      ]),
    ).toBe(50);
    expect(paperScore([])).toBe(0);
  });

  it("compte comme acquise une explication à moitié juste seulement au-dessus du seuil", () => {
    expect(
      correctCount([
        { id: "a", score: 100 },
        { id: "b", score: 60 },
        { id: "c", score: 59 },
      ]),
    ).toBe(2);
  });

  it("borne une note venue du modèle", () => {
    expect(clampScore(140)).toBe(100);
    expect(clampScore(-3)).toBe(0);
    expect(clampScore(Number.NaN)).toBe(0);
  });
});

describe("la composition", () => {
  it("garde vingt questions avec ou sans micro", () => {
    const withAudio = paperQuota(true);
    const without = paperQuota(false);

    expect(quotaSize(withAudio)).toBe(MOCK_PAPER_SIZE);
    expect(quotaSize(without)).toBe(MOCK_PAPER_SIZE);
    expect(withAudio.feynman).toBeGreaterThan(0);
    expect(without.feynman).toBe(0);
  });

  it("ne demande d'explication orale que si le micro est là", () => {
    expect(paperQuota(false).feynman).toBe(0);
    expect(paperQuota(true, 8).feynman).toBeGreaterThan(0);
  });

  it("accorde deux minutes à une explication, une à une question fermée", () => {
    const closed: MockQuestion[] = [choice, truefalse, gap];
    expect(paperMinutes(closed)).toBe(5);
    expect(paperMinutes([...closed, ...Array(17).fill(choice)])).toBe(20);
    expect(paperMinutes([...Array(17).fill(choice), feynman, feynman, feynman])).toBe(23);
  });
});

describe("le débriefing", () => {
  it("n'est retenu que s'il a la forme attendue", () => {
    expect(isMockDebrief({ headline: "x", strengths: [], gaps: [], advice: "y" })).toBe(true);
    expect(isMockDebrief({ headline: "x" })).toBe(false);
    expect(isMockDebrief(null)).toBe(false);
  });
});
