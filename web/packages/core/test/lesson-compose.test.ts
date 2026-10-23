/**
 * La barre de Home (`LessonComposer`) et le plan rendu par le serveur.
 */

import { describe, expect, it } from "vitest";

import {
  MAX_COMPOSER_CHARACTERS,
  MAX_COMPOSER_IMAGES,
  canSend,
  composeCreation,
  composerSource,
  hasRoom,
  supportSource,
  type ComposerSupport,
} from "../src/lesson/composer";
import { pathFromPlan, readPlanResponse } from "../src/lesson/plan";

function support(overrides: Partial<ComposerSupport> = {}): ComposerSupport {
  return { id: "s", kind: "pdf", title: "cours.pdf", state: "ready", text: "Le texte du cours.", images: [], ...overrides };
}

describe("la barre de Home", () => {
  it("envoie un sujet d'au moins deux lettres, ou des supports lus", () => {
    expect(canSend("", [])).toBe(false);
    expect(canSend("a", [])).toBe(false);
    expect(canSend("Guerre froide", [])).toBe(true);
    expect(canSend("", [support()])).toBe(true);
    expect(canSend("Sujet", [support({ state: "reading" })])).toBe(false);
    expect(canSend("", [support({ state: "failed", text: "" })])).toBe(false);
  });

  it("dit d'où vient la leçon", () => {
    expect(composerSource([])).toBe("topic");
    expect(composerSource([support({ kind: "text" })])).toBe("text");
    expect(composerSource([support(), support({ id: "t", kind: "photo", images: ["data:image/jpeg;base64,x"], text: "" })])).toBe("mixed");
    expect(supportSource({ kind: "pdf", docKind: "docx" })).toBe("docx");
    expect(supportSource({ kind: "youtube" })).toBe("youtube");
    expect(hasRoom(Array.from({ length: 5 }, (_, index) => support({ id: String(index) })))).toBe(false);
  });

  it("part comme sujet sans support, comme texte avec", () => {
    const instruction = (text: string) => `Consigne : ${text}`;
    expect(composeCreation("  La Guerre froide ", [], instruction)).toEqual({ topic: "La Guerre froide", text: "", images: [], source: "topic" });

    const one = composeCreation("Insiste sur les dates", [support()], instruction);
    expect(one.topic).toBeUndefined();
    expect(one.text).toBe("Consigne : Insiste sur les dates\n\nLe texte du cours.");
    expect(one.source).toBe("pdf");
    expect(one.sourceName).toBe("cours.pdf");

    const two = composeCreation("", [support(), support({ id: "b", title: "notes.txt", kind: "text", text: "Mes notes." })], instruction);
    expect(two.text).toBe("--- cours.pdf ---\nLe texte du cours.\n\n--- notes.txt ---\nMes notes.");
    expect(two.sourceName).toBeUndefined();
    expect(two.source).toBe("mixed");
  });

  it("borne le texte et les images", () => {
    const long = composeCreation("", [support({ text: "x".repeat(MAX_COMPOSER_CHARACTERS + 10) })], (t) => t);
    expect(long.text).toHaveLength(MAX_COMPOSER_CHARACTERS);
    const images = Array.from({ length: 9 }, (_, index) => `data:image/jpeg;base64,${index}`);
    expect(composeCreation("", [support({ kind: "photo", text: "", images })], (t) => t).images).toHaveLength(MAX_COMPOSER_IMAGES);
  });
});

describe("le plan du serveur", () => {
  const raw = {
    plan: {
      title: "La Guerre froide",
      subject: "Histoire",
      icon: "globe",
      themes: [
        { title: "1947", icon: "globe", symbol: "globe.europe.africa", points: ["Truman", "Jdanov"], role: "ground" },
        { title: "Berlin", icon: "fiole", symbol: "globe.europe.africa", points: [] },
        { title: "", icon: "x" },
        { title: "Cuba", icon: "inconnue", symbol: "flag", points: ["Kennedy"] },
      ],
      groups: [{ name: "Les causes", themes: [0, 1] }, { name: "Les crises", themes: [2, 9] }],
      intro: { lines: ["Une.", "Deux."], minutes: 24.6 },
      takeaways: ["A", "B"],
      shortened: false,
      singleQuiz: true,
    },
    contextText: "Le texte.",
  };

  it("lit ce qu'il faut et ignore le reste", () => {
    const plan = readPlanResponse(raw);
    expect(plan).not.toBeNull();
    expect(plan!.themes.map((theme) => theme.title)).toEqual(["1947", "Berlin", "Cuba"]);
    expect(plan!.themes[2]!.icon).toBe("livre-ouvert");
    expect(plan!.groups).toEqual([{ name: "Les causes", themes: [0, 1] }, { name: "Les crises", themes: [2] }]);
    expect(plan!.intro).toEqual({ lines: ["Une.", "Deux."], minutes: 25 });
    expect(plan!.singleQuiz).toBe(true);
    expect(plan!.contextText).toBe("Le texte.");
    expect(readPlanResponse({ plan: { title: "x", themes: [] } })).toBeNull();
    expect(readPlanResponse(null)).toBeNull();
  });

  it("écrit un chemin en cours d'écriture, sans deux fois le même pictogramme", () => {
    const path = pathFromPlan(readPlanResponse(raw)!);
    expect(path.status).toBe("generating");
    expect(path.symbols).toHaveLength(3);
    expect(new Set(path.symbols).size).toBe(3);
    expect(path.points).toEqual([["Truman", "Jdanov"], [], ["Kennedy"]]);
    expect(path.icon).toBe("globe");
  });
});
