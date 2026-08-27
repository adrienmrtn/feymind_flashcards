/**
 * Les deux courbes de la page d'accueil.
 *
 * Ce qui est vérifié ici n'est pas la valeur d'un point, c'est la **propriété qui rend le
 * graphe lisible** : les deux tracés partent confondus, puis se séparent à la première
 * révision. Sans ça, on compare deux courbes ; avec, on regarde l'endroit où elles divergent.
 */

import { describe, expect, it } from "vitest";

import {
  HORIZON_DAYS,
  INTERVAL_LABELS,
  REVIEW_DAYS,
  curveWithMicabo,
  curveWithoutReview,
} from "../src/retention";

describe("la courbe sans révision", () => {
  it("part de 100 % et décroît toujours", () => {
    const points = curveWithoutReview();

    expect(points[0]!.y).toBeCloseTo(1, 6);
    for (let index = 1; index < points.length; index += 1) {
      expect(points[index]!.y).toBeLessThan(points[index - 1]!.y);
    }
  });

  it("tient dans l'horizon", () => {
    const points = curveWithoutReview();

    expect(points[0]!.x).toBe(0);
    expect(points[points.length - 1]!.x).toBeCloseTo(1, 6);
  });

  it("a beaucoup oublié au bout d'un mois", () => {
    const points = curveWithoutReview();

    // Une stabilité de 3,5 jours sur trente jours : il ne reste presque rien.
    expect(points[points.length - 1]!.y).toBeLessThan(0.01);
  });
});

describe("la courbe avec Micabo", () => {
  it("part confondue avec l'autre", () => {
    // La première stabilité est celle de la courbe sans révision : avant le premier rappel,
    // les deux tracés suivent la même loi. On les compare donc **à la même abscisse**, en
    // évaluant la loi, et non en cherchant le point le plus proche d'une autre grille
    // d'échantillonnage - deux courbes tracées à des pas différents ne se comparent pas point
    // à point.
    const firstReview = REVIEW_DAYS[0]! / HORIZON_DAYS;
    const early = curveWithMicabo(30).filter((point) => point.x < firstReview);

    expect(early.length).toBeGreaterThan(0);
    for (const point of early) {
      const days = point.x * HORIZON_DAYS;
      expect(point.y).toBeCloseTo(Math.exp(-days / 3.5), 10);
    }
  });

  it("et la courbe sans révision suit la même loi, à la même abscisse", () => {
    for (const point of curveWithoutReview()) {
      const days = point.x * HORIZON_DAYS;
      expect(point.y).toBeCloseTo(Math.exp(-days / 3.5), 10);
    }
  });

  it("remonte à 100 % à chaque révision", () => {
    const points = curveWithMicabo();

    for (const day of REVIEW_DAYS) {
      const atReview = points.filter((point) => Math.abs(point.x - day / HORIZON_DAYS) < 1e-9);
      expect(atReview.some((point) => Math.abs(point.y - 1) < 1e-9)).toBe(true);
    }
  });

  it("finit bien plus haut que la courbe sans révision", () => {
    const without = curveWithoutReview();
    const withMicabo = curveWithMicabo();

    expect(withMicabo[withMicabo.length - 1]!.y).toBeGreaterThan(
      without[without.length - 1]!.y * 10,
    );
  });
});

describe("les étiquettes", () => {
  it("annoncent les intervalles réels", () => {
    expect(INTERVAL_LABELS).toEqual(["1 j", "3 j", "7 j", "16 j"]);
  });
});
