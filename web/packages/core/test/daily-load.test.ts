/**
 * Ce qui reste du module de charge : l'écriture d'une durée.
 *
 * Le plafond de cartes neuves par jour vivait ici, avec sa table de paliers et son arrondi
 * porté au plus près du Swift. Il est parti en entier : rien ne se déclare plus, donc rien ne
 * se plafonne. Ce que le produit annonce désormais est le temps que la journée demande, et
 * c'est ce format-là qui mérite encore un test.
 */

import { describe, expect, it } from "vitest";

import { CARDS_PER_MINUTE, REPETITIONS_PER_CARD, dailyMinutesLabel } from "../src/srs/daily-load";

describe("écriture d'une durée", () => {
  it("passe aux heures au-delà de soixante minutes", () => {
    expect(dailyMinutesLabel(15)).toBe("15 min");
    expect(dailyMinutesLabel(45)).toBe("45 min");
    expect(dailyMinutesLabel(60)).toBe("1 h");
    expect(dailyMinutesLabel(90)).toBe("1 h 30");
    expect(dailyMinutesLabel(120)).toBe("2 h");
  });
});

describe("les deux constantes", () => {
  it("gardent les valeurs que les pages de méthode affichent", () => {
    expect(CARDS_PER_MINUTE).toBe(4);
    expect(REPETITIONS_PER_CARD).toBe(8);
  });
});
