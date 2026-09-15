import { describe, expect, it } from "vitest";

import { addDays, startOfDay } from "../src/srs/exam";
import {
  examReadiness,
  MOCK_READING_WEIGHT,
  PARCOURS_READING_WEIGHT,
} from "../src/srs/mock";
import {
  PARCOURS_FIRST_OFFSET,
  PARCOURS_MAX,
  PARCOURS_QUESTION_COUNT,
  PARCOURS_TIGHT_WINDOW,
  parcoursOffsets,
  parcoursQuota,
} from "../src/srs/parcours";

const TODAY = startOfDay(new Date(2026, 8, 1));

describe("la cadence des tests de parcours", () => {
  it("se resserre dans les dix derniers jours", () => {
    // Deux régimes, et non une moyenne : trois jours pendant qu'on construit la base, deux
    // quand ce qu'on rate coûte cher et se corrige encore.
    const offsets = parcoursOffsets(30);

    const tight = offsets.filter((offset) => offset < PARCOURS_TIGHT_WINDOW);
    for (const [index, offset] of tight.slice(1).entries()) {
      expect(offset - tight[index]!).toBe(2);
    }

    const loose = offsets.filter((offset) => offset >= PARCOURS_TIGHT_WINDOW);
    for (const [index, offset] of loose.slice(1).entries()) {
      expect(offset - loose[index]!).toBe(3);
    }
  });

  it("commence à J-2 et ne touche ni la veille ni le jour J", () => {
    // J-1 et le jour J appartiennent aux révisions : y poser une mesure ne laisse plus le
    // temps d'en faire quoi que ce soit.
    expect(parcoursOffsets(30)[0]).toBe(PARCOURS_FIRST_OFFSET);
    expect(parcoursOffsets(30).every((offset) => offset >= 2)).toBe(true);
  });

  it("compte depuis l'épreuve, pas depuis aujourd'hui", () => {
    // Un test posé à J-13 y reste tant que l'examen ne bouge pas : ouvrir l'app trois jours
    // plus tard ne doit pas redistribuer les rendez-vous déjà annoncés.
    const long = parcoursOffsets(40);
    const shorter = parcoursOffsets(20);
    expect(long.slice(0, shorter.length)).toEqual(shorter);
  });

  it("s'arrête à huit, quelle que soit la fenêtre", () => {
    // Une échéance à deux mois ne mérite pas vingt tests : elle mérite les mêmes huit, posés
    // là où ils servent.
    expect(parcoursOffsets(60).length).toBe(PARCOURS_MAX);
    expect(parcoursOffsets(365).length).toBe(PARCOURS_MAX);
    expect(parcoursOffsets(60)).toEqual(parcoursOffsets(365));
  });

  it("ne dépasse jamais la fenêtre disponible", () => {
    for (const window of [0, 1, 2, 3, 5, 9, 12, 25]) {
      for (const offset of parcoursOffsets(window)) {
        expect(offset).toBeLessThanOrEqual(window);
      }
    }
  });

  it("ne pose rien quand l'épreuve est demain ou déjà passée", () => {
    expect(parcoursOffsets(1)).toEqual([]);
    expect(parcoursOffsets(0)).toEqual([]);
    expect(parcoursOffsets(-4)).toEqual([]);
    expect(parcoursOffsets(Number.NaN)).toEqual([]);
  });

  it("pose un seul test sur une fenêtre de deux ou trois jours", () => {
    expect(parcoursOffsets(2)).toEqual([2]);
    expect(parcoursOffsets(3)).toEqual([2]);
    expect(parcoursOffsets(4)).toEqual([2, 4]);
  });

  it("garde le format fixe : cinq QCM et cinq questions orales", () => {
    // C'est ce qui rend deux tests comparables d'une semaine à l'autre.
    expect(PARCOURS_QUESTION_COUNT).toBe(10);
    expect(parcoursQuota(true)).toEqual({ choice: 5, truefalse: 0, gap: 0, feynman: 5 });
  });

  it("remplace les orales par des QCM quand il n'y a pas de micro, sans rien perdre", () => {
    // Dix questions notées valent mieux qu'une mesure amputée de moitié : un test à cinq
    // questions ne se compare à aucun autre. Ce n'est pas tout à fait la même mesure - un QCM
    // se devine, une explication non - mais c'en est une.
    const sansMicro = parcoursQuota(false);
    expect(sansMicro.feynman).toBe(0);
    expect(
      sansMicro.choice + sansMicro.truefalse + sansMicro.gap + sansMicro.feynman,
    ).toBe(PARCOURS_QUESTION_COUNT);
  });

  it("ne demande ni vrai-faux ni texte à trou", () => {
    // Le parcours mesure deux choses : reconnaître, et expliquer. Un texte à trou mesure la
    // mémoire d'un mot, ce que les cartes font déjà mieux et tous les jours.
    for (const quota of [parcoursQuota(true), parcoursQuota(false)]) {
      expect(quota.truefalse).toBe(0);
      expect(quota.gap).toBe(0);
    }
  });
});

describe("le poids d'un parcours dans la préparation", () => {
  const base = { masteryPercent: 80, projectedPercent: 80, examId: "e1", now: TODAY };
  const result = (kind: "mock" | "parcours", correct: number, day: number) => ({
    id: `${kind}-${day}`,
    examId: "e1",
    kind,
    questionCount: kind === "mock" ? 20 : 10,
    correctCount: correct,
    finishedAt: addDays(TODAY, -day),
  });

  it("pèse moitié moins qu'un blanc", () => {
    // Il mesure pour de vrai - dix questions notées - mais il mesure moins large. Une
    // mauvaise après-midi sur dix questions ne doit pas effacer un blanc entier.
    expect(PARCOURS_READING_WEIGHT * 2).toBe(MOCK_READING_WEIGHT);

    const withMock = examReadiness({ ...base, mocks: [result("mock", 10, 0)] });
    const withParcours = examReadiness({ ...base, mocks: [result("parcours", 5, 0)] });

    // Les deux scores valent 50 % ; le blanc tire la lecture deux fois plus bas.
    expect(80 - withMock.percent).toBeGreaterThan(80 - withParcours.percent);
  });

  it("ne laisse pas un parcours effacer le blanc de la veille", () => {
    // Les parcours sont fréquents et les blancs rares : ne garder que la mesure la plus
    // récente remplacerait la mesure large par l'étroite.
    const both = examReadiness({ ...base, mocks: [result("mock", 8, 2), result("parcours", 9, 0)] });
    const onlyParcours = examReadiness({ ...base, mocks: [result("parcours", 9, 0)] });

    expect(both.percent).toBeLessThan(onlyParcours.percent);
    expect(both.measured).toBe(true);
  });

  it("annonce le score du blanc quand il y en a un", () => {
    // Un parcours ne s'annonce pas comme une note d'examen blanc : ce n'est pas la mesure que
    // l'étudiant reconnaît.
    const both = examReadiness({ ...base, mocks: [result("mock", 12, 1), result("parcours", 3, 0)] });
    expect(both.mockScore).toBe(60);
  });

  it("traite une session sans sorte comme un blanc", () => {
    // Tout ce qui existait en base en est un, et aucune ligne n'a été réécrite.
    const legacy = examReadiness({
      ...base,
      mocks: [{ id: "x", examId: "e1", questionCount: 20, correctCount: 10, finishedAt: TODAY }],
    });
    expect(legacy.percent).toBe(examReadiness({ ...base, mocks: [result("mock", 10, 0)] }).percent);
  });
});
