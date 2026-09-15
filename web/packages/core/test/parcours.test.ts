import { describe, expect, it } from "vitest";

import {
  PARCOURS_FIRST_OFFSET,
  PARCOURS_MAX,
  PARCOURS_QUESTION_COUNT,
  PARCOURS_TIGHT_WINDOW,
  parcoursOffsets,
} from "../src/srs/parcours";

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
  });
});
