import { describe, expect, it } from "vitest";

import {
  BUBBLE_GAP,
  EDGE_MARGIN,
  HOLE_PADDING,
  bubblePlacement,
  holeAround,
} from "./place";
import { shouldOpenTour } from "./state";
import { TOURS, TOUR_IDS, isTourId, stepsForWidth, tourFor } from "./steps";

const OPEN = {
  isPaid: false,
  paywallDismissed: true,
  paywallWillOpen: false,
  offerClaimed: false,
  skipped: false,
  seen: [] as string[],
  tourId: "accueil",
};

describe("tourFor", () => {
  it("donne une visite à chacune des dix pages", () => {
    const pages = [
      "/app",
      "/app/reviser",
      "/app/cours",
      "/app/examens",
      "/app/amis",
      "/app/profil",
      "/app/reglages",
      "/app/importer",
      "/app/c/abc",
      "/app/c/abc/cartes",
    ];
    for (const pathname of pages) {
      expect(tourFor({ pathname, inSession: false })).not.toBeNull();
    }
  });

  it("sépare la session de l'écran qui la précède", () => {
    expect(tourFor({ pathname: "/app/reviser", inSession: false })?.id).toBe("reviser");
    expect(tourFor({ pathname: "/app/reviser", inSession: true })?.id).toBe("session");
  });

  it("lit l'atelier des cartes avant la fiche", () => {
    expect(tourFor({ pathname: "/app/c/abc/cartes", inSession: false })?.id).toBe("cours-cartes");
    expect(tourFor({ pathname: "/app/c/abc", inSession: false })?.id).toBe("cours-fiche");
  });

  it("supporte la barre oblique finale", () => {
    expect(tourFor({ pathname: "/app/cours/", inSession: false })?.id).toBe("cours");
  });

  it("ne visite pas le profil public d'un ami ni un cours repris", () => {
    expect(tourFor({ pathname: "/app/u/leo", inSession: false })).toBeNull();
    expect(tourFor({ pathname: "/app/b/abc", inSession: false })).toBeNull();
  });
});

describe("le catalogue des visites", () => {
  it("a des identifiants uniques, tous reconnus", () => {
    expect(new Set(TOUR_IDS).size).toBe(TOUR_IDS.length);
    for (const id of TOUR_IDS) expect(isTourId(id)).toBe(true);
    expect(isTourId("accueils")).toBe(false);
    expect(isTourId(null)).toBe(false);
  });

  it("ne montre jamais deux fois la même zone dans une visite", () => {
    for (const tour of TOURS) {
      const anchors = tour.steps.map((step) => step.anchor);
      expect(new Set(anchors).size).toBe(anchors.length);
      expect(anchors.length).toBeGreaterThan(0);
    }
  });

  it("n'écrit ni tiret cadratin ni demi-cadratin", () => {
    for (const tour of TOURS) {
      for (const step of tour.steps) {
        expect(`${step.title} ${step.body}`).not.toMatch(/[—–]/);
      }
    }
  });

  it("tutoie, comme tout le reste du produit", () => {
    for (const tour of TOURS) {
      for (const step of tour.steps) {
        expect(step.body.toLowerCase()).not.toMatch(/\bvous\b|\bvotre\b|\bvos\b/);
      }
    }
  });

  it("ne parle pas de ce que le gratuit ferme", () => {
    for (const tour of TOURS) {
      for (const step of tour.steps) {
        expect(`${step.title} ${step.body}`.toLowerCase()).not.toMatch(
          /\bpro\b|abonn|gratuit|payant|essai|limite/,
        );
      }
    }
  });

  it("garde la session sans voile, et à deux bulles", () => {
    const session = TOURS.find((tour) => tour.id === "session");
    expect(session?.mode).toBe("hint");
    expect(session?.steps).toHaveLength(2);
  });
});

describe("stepsForWidth", () => {
  it("saute la barre latérale sur téléphone", () => {
    const home = tourFor({ pathname: "/app", inSession: false })!;
    const wide = stepsForWidth(home, 1280).map((step) => step.anchor);
    const narrow = stepsForWidth(home, 420).map((step) => step.anchor);

    expect(wide).toContain("nav");
    expect(narrow).not.toContain("nav");
    expect(narrow).not.toContain("nav-importer");
    expect(narrow).toContain("taches");
  });

  it("garde toutes les bulles dès 1024 px", () => {
    const home = tourFor({ pathname: "/app", inSession: false })!;
    expect(stepsForWidth(home, 1024)).toHaveLength(home.steps.length);
  });
});

describe("shouldOpenTour", () => {
  it("s'ouvre après la croix du paywall", () => {
    expect(shouldOpenTour(OPEN)).toBe(true);
  });

  it("s'ouvre aussi pour un abonné, qui n'a jamais vu de paywall", () => {
    expect(shouldOpenTour({ ...OPEN, isPaid: true, paywallDismissed: false })).toBe(true);
  });

  it("attend que le paywall soit passé", () => {
    expect(shouldOpenTour({ ...OPEN, paywallDismissed: false })).toBe(false);
    expect(shouldOpenTour({ ...OPEN, paywallWillOpen: true })).toBe(false);
  });

  it("laisse le cadeau seul à l'écran", () => {
    expect(shouldOpenTour({ ...OPEN, offerClaimed: true })).toBe(false);
  });

  it("ne repasse pas sur une page déjà vue", () => {
    expect(shouldOpenTour({ ...OPEN, seen: ["accueil"] })).toBe(false);
    expect(shouldOpenTour({ ...OPEN, seen: ["cours"] })).toBe(true);
  });

  it("respecte un refus global", () => {
    expect(shouldOpenTour({ ...OPEN, skipped: true })).toBe(false);
  });

  it("rejoue tout quand on le demande", () => {
    expect(
      shouldOpenTour({ ...OPEN, debug: true, skipped: true, seen: ["accueil"], isPaid: true }),
    ).toBe(true);
  });
});

describe("bubblePlacement", () => {
  const bubble = { width: 320, height: 150 };
  const viewport = { width: 1280, height: 800 };

  it("perce un trou un peu plus grand que la zone", () => {
    const hole = holeAround({ top: 100, left: 200, width: 300, height: 80 });
    expect(hole).toEqual({
      top: 100 - HOLE_PADDING,
      left: 200 - HOLE_PADDING,
      width: 300 + HOLE_PADDING * 2,
      height: 80 + HOLE_PADDING * 2,
    });
  });

  it("se pose sous la zone quand il y a la place", () => {
    const anchor = { top: 120, left: 400, width: 400, height: 100 };
    const placed = bubblePlacement(anchor, bubble, viewport);

    expect(placed.side).toBe("below");
    expect(placed.top).toBe(120 + 100 + HOLE_PADDING + BUBBLE_GAP);
  });

  it("passe au-dessus quand le bas de l'écran est pris", () => {
    const anchor = { top: 660, left: 400, width: 400, height: 100 };
    const placed = bubblePlacement(anchor, bubble, viewport);

    expect(placed.side).toBe("above");
    expect(placed.top).toBe(660 - HOLE_PADDING - BUBBLE_GAP - bubble.height);
  });

  it("centre la bulle sur la zone", () => {
    const anchor = { top: 120, left: 400, width: 400, height: 100 };
    expect(bubblePlacement(anchor, bubble, viewport).left).toBe(600 - bubble.width / 2);
  });

  it("ne sort pas par la gauche pour une zone collée au bord", () => {
    const anchor = { top: 120, left: 0, width: 220, height: 60 };
    expect(bubblePlacement(anchor, bubble, viewport).left).toBe(EDGE_MARGIN);
  });

  it("ne sort pas par la droite non plus", () => {
    const anchor = { top: 120, left: 1180, width: 100, height: 60 };
    const placed = bubblePlacement(anchor, bubble, viewport);
    expect(placed.left).toBe(viewport.width - bubble.width - EDGE_MARGIN);
  });

  it("reste dans l'écran même quand aucun côté ne suffit", () => {
    const tall = { width: 320, height: 700 };
    const anchor = { top: 300, left: 400, width: 400, height: 200 };
    const placed = bubblePlacement(anchor, tall, { width: 390, height: 760 });

    expect(placed.top).toBeGreaterThanOrEqual(EDGE_MARGIN);
    expect(placed.top + tall.height).toBeLessThanOrEqual(760 - EDGE_MARGIN);
    expect(placed.left).toBeGreaterThanOrEqual(EDGE_MARGIN);
  });

  it("garde le bouton à l'écran quand la zone remplit la page", () => {
    const card = { width: 336, height: 220 };
    const viewport = { width: 1280, height: 800 };
    const panel = { top: 72, left: 280, width: 720, height: 980 };
    const placed = bubblePlacement(panel, card, viewport);

    expect(placed.top).toBeGreaterThanOrEqual(EDGE_MARGIN);
    expect(placed.top + card.height).toBeLessThanOrEqual(viewport.height - EDGE_MARGIN);
  });
});
