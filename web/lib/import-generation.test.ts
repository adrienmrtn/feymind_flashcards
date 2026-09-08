import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const importPanel = readFileSync(resolve(here, "../components/app/ImportPanel.tsx"), "utf8");
const generateCards = readFileSync(resolve(here, "../components/app/GenerateCards.tsx"), "utf8");
const courseActions = readFileSync(resolve(here, "./actions/course.ts"), "utf8");
const handoffUi = readFileSync(resolve(here, "../components/app/ImportHandoff.tsx"), "utf8");
const status = readFileSync(resolve(here, "../components/app/GenerationStatus.tsx"), "utf8");

function functionBody(source: string, name: string): string {
  const start = source.indexOf(`export async function ${name}`);
  expect(start).toBeGreaterThan(-1);
  const next = source.indexOf("\nexport async function ", start + 1);
  return next === -1 ? source.slice(start) : source.slice(start, next);
}

describe("l'écriture d'une fiche ne gèle plus l'écran", () => {
  it("n'enveloppe plus l'import dans une transition React", () => {
    expect(importPanel).not.toMatch(/useTransition/);
    expect(importPanel).toContain("waitForPaint");
    const generate = importPanel.slice(importPanel.indexOf("async function generate"));
    const beforeCall = generate.slice(0, generate.indexOf("importFromText"));
    expect(beforeCall).toContain("waitForPaint");
    expect(beforeCall).not.toMatch(/startTransition\(/);
  });

  it("n'invalide pas les listes avant d'ouvrir la fiche neuve", () => {
    const importFromText = functionBody(courseActions, "importFromText");
    expect(importFromText).not.toMatch(/revalidatePath\(/);
    expect(importFromText).not.toMatch(/revalidateUserData\(/);
    expect(importFromText).toContain("return { status: \"ok\", courseId: id }");
    expect(courseActions).toContain("export async function refreshLibraryAfterImport");
  });

  it("rafraîchit les listes une fois la fiche peinte", () => {
    expect(handoffUi).toContain("refreshLibraryAfterImport");
    expect(handoffUi).toContain("handingOff");
  });

  it("écrit le pourcentage dans le DOM, même si React ne commit pas", () => {
    expect(status).toContain("percentRef.current.textContent");
    expect(status).toContain("stroke-dashoffset");
    expect(status).toContain("setInterval(paint");
  });

  it("n'enveloppe plus l'écriture des cartes dans une transition", () => {
    expect(generateCards).not.toMatch(/useTransition/);
    expect(generateCards).toContain("waitForPaint");
    const ask = generateCards.slice(generateCards.indexOf("async function ask"));
    const beforeCall = ask.slice(0, ask.indexOf("generateCards("));
    expect(beforeCall).toContain("waitForPaint");
    expect(beforeCall).not.toMatch(/startTransition\(/);
  });
});
