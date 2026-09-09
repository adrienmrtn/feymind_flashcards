/**
 * L'écriture d'une fiche : où elle s'affiche, et par où elle passe.
 *
 * Ce fichier gardait une décision qui a changé. L'écriture quittait le document App Router pour
 * afficher son pourcentage en plein écran, hors de Next, et un voile la relayait jusqu'à la fiche
 * peinte. Elle vit maintenant **dans le panneau d'import**, à la place du panneau : une attente
 * de trente secondes n'a pas besoin de l'écran entier, et la prendre en entier faisait
 * disparaître le reste de la page pour rien.
 *
 * Ce qui n'a pas changé, et qui reste testé ici : l'appel part en POST JSON hors des Server
 * Actions - c'est ce qui empêchait le pourcentage d'avancer - et il n'invalide aucune liste
 * avant que la fiche soit ouverte.
 */

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const importPanel = readFileSync(resolve(here, "../components/app/ImportPanel.tsx"), "utf8");
const generateCards = readFileSync(resolve(here, "../components/app/GenerateCards.tsx"), "utf8");
const courseActions = readFileSync(resolve(here, "./actions/course.ts"), "utf8");
const createSheet = readFileSync(resolve(here, "./import/create-sheet.ts"), "utf8");
const writeRoute = readFileSync(resolve(here, "../app/api/import-course/route.ts"), "utf8");
const openCourse = readFileSync(resolve(here, "../app/api/open-course/route.ts"), "utf8");
const handoff = readFileSync(resolve(here, "./import-handoff.ts"), "utf8");
const writeSheet = readFileSync(resolve(here, "./import/write-sheet.ts"), "utf8");
const chrome = readFileSync(resolve(here, "../components/app/AppChrome.tsx"), "utf8");
const status = readFileSync(resolve(here, "../components/app/GenerationStatus.tsx"), "utf8");

function functionBody(source: string, name: string): string {
  const start = source.indexOf(`export async function ${name}`);
  expect(start).toBeGreaterThan(-1);
  const next = source.indexOf("\nexport async function ", start + 1);
  return next === -1 ? source.slice(start) : source.slice(start, next);
}

describe("l'écriture d'une fiche ne gèle plus l'écran", () => {
  it("écrit la fiche par un POST JSON hors de /app, pas par une Server Action", () => {
    expect(importPanel).not.toMatch(/useTransition/);
    expect(importPanel).toContain("waitForPaint");
    expect(importPanel).toContain("writeSheetFromBrowser");
    expect(writeSheet).toContain("/api/import-course");
    expect(writeSheet).toContain("XMLHttpRequest");
    expect(writeRoute).toContain("export async function POST");
    expect(writeRoute).toContain("createSheetFromImport");
    expect(writeRoute).not.toContain('from "@/lib/actions/course"');
    expect(createSheet).not.toMatch(/^["']use server["']/m);
    expect(createSheet).not.toMatch(/revalidatePath\(/);
    expect(openCourse).toContain("NextResponse.redirect");
    expect(openCourse).toContain("/app/c/");
    expect(handoff).toContain("HTMLFormElement.prototype.submit");
    expect(handoff).not.toContain("/api/open-course");
    const generate = importPanel.slice(importPanel.indexOf("async function generate"));
    expect(generate).toContain("writeSheetFromBrowser");
    expect(generate).not.toMatch(/importFromText\(/);
  });

  it("n'invalide pas les listes avant d'ouvrir la fiche neuve", () => {
    expect(createSheet).not.toMatch(/revalidatePath\(/);
    expect(createSheet).not.toMatch(/revalidateUserData\(/);
    expect(createSheet).toContain('return { status: "ok", courseId: id }');
    expect(courseActions).toContain("export async function refreshLibraryAfterImport");
    expect(functionBody(courseActions, "importFromText")).toContain("createSheetFromImport");
  });

  it("attend dans le panneau, pas en plein écran", () => {
    expect(importPanel).toContain('if (phase === "ecriture")');
    expect(importPanel).toContain("data-writing-sheet");
    expect(importPanel).not.toContain("document.write");
    expect(importPanel).not.toContain("beginStandaloneWrite");
    expect(chrome).not.toContain("ImportHandoff");
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
