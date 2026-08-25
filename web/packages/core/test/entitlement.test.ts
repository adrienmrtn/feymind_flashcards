/**
 * Le verrou du gratuit, et le fait qu'il **n'est pas armé**.
 *
 * Le premier test est le plus important du fichier : tant que l'étape 5 n'a pas posé la table
 * `entitlements` et l'encaissement, tout le monde doit être Pro. Livrer un site qui floute des
 * fiches avant qu'on puisse les déverrouiller en payant serait livrer une panne.
 *
 * Les autres tests décrivent le verrou tel qu'il fonctionnera, en forçant le droit à la main :
 * ils valent spécification, et ils passeront tels quels le jour où `ARMED` deviendra vrai.
 */

import { describe, expect, it } from "vitest";

import {
  ARMED,
  FREE,
  FREE_LIMITS,
  PRO,
  cardLock,
  examModeLock,
  resolve,
  sheetLock,
  visibleBlockCount,
} from "../src/entitlement";

describe("le verrou n'est pas armé", () => {
  it("laisse tout ouvert tant que l'encaissement n'existe pas", () => {
    expect(ARMED).toBe(false);
    expect(resolve(FREE).isPro).toBe(true);
    expect(resolve(null, undefined).isPro).toBe(true);
  });
});

describe("les fiches", () => {
  it("la première est entière, les suivantes se referment", () => {
    expect(sheetLock(FREE, 0).locked).toBe(false);
    expect(sheetLock(FREE, 1)).toEqual({ locked: true, reason: "sheetBeyondFree" });
    expect(sheetLock(PRO, 12).locked).toBe(false);
  });

  it("laisse lire le début d'une fiche verrouillée", () => {
    // Le chapeau et les trois premiers blocs : assez pour donner envie, pas assez pour réviser.
    expect(visibleBlockCount(FREE, 3, 40)).toBe(FREE_LIMITS.visibleBlocks);
    expect(visibleBlockCount(FREE, 0, 40)).toBe(40);
    expect(visibleBlockCount(PRO, 3, 40)).toBe(40);
  });

  it("ne prétend pas montrer plus de blocs qu'il n'y en a", () => {
    expect(visibleBlockCount(FREE, 3, 2)).toBe(2);
  });
});

describe("les cartes", () => {
  it("ouvre les dix premières d'un cours", () => {
    expect(cardLock(FREE, 0).locked).toBe(false);
    expect(cardLock(FREE, FREE_LIMITS.cardsPerCourse - 1).locked).toBe(false);
    expect(cardLock(FREE, FREE_LIMITS.cardsPerCourse)).toEqual({
      locked: true,
      reason: "cardBeyondFree",
    });
    expect(cardLock(PRO, 500).locked).toBe(false);
  });
});

describe("le mode examen", () => {
  it("est réservé, et c'est ce que le parcours d'accueil vend", () => {
    expect(examModeLock(FREE)).toEqual({ locked: true, reason: "examMode" });
    expect(examModeLock(PRO).locked).toBe(false);
  });
});

describe("l'arbitrage entre deux sources", () => {
  it("prend la plus généreuse", () => {
    // Le SDK et la table doivent s'accorder ; quand ils divergent, enfermer dehors un étudiant
    // qui paye est pire qu'une minute offerte.
    expect(resolve(FREE, PRO).isPro).toBe(true);
    expect(resolve(PRO, FREE).isPro).toBe(true);
  });
});
