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
const startWrite = readFileSync(resolve(here, "./import/start-write.ts"), "utf8");
const writerPage = readFileSync(resolve(here, "./import/writer-page.ts"), "utf8");
const writeSheet = readFileSync(resolve(here, "./import/write-sheet.ts"), "utf8");
const handoffUi = readFileSync(resolve(here, "../components/app/ImportHandoff.tsx"), "utf8");
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
    expect(startWrite).toContain("document.write");
    expect(startWrite).toContain("WRITER_ROOT_ID");
    expect(writerPage).toContain("XMLHttpRequest");
    expect(writerPage).toContain("IMPORT_WRITE_PATH");
    expect(handoff).toContain("HTMLFormElement.prototype.submit");
    expect(handoff).not.toContain("/api/open-course");
    const generate = importPanel.slice(importPanel.indexOf("async function generate"));
    expect(generate).toContain("beginStandaloneWrite");
    expect(generate).toContain("writeSheetFromBrowser");
    expect(generate).not.toMatch(/importFromText\(/);
  });

  it("n'invalide pas les listes avant d'ouvrir la fiche neuve", () => {
    expect(createSheet).not.toMatch(/revalidatePath\(/);
    expect(createSheet).not.toMatch(/revalidateUserData\(/);
    expect(createSheet).toContain("return { status: \"ok\", courseId: id }");
    expect(courseActions).toContain("export async function refreshLibraryAfterImport");
    expect(functionBody(courseActions, "importFromText")).toContain("createSheetFromImport");
  });

  it("rafraîchit les listes une fois la fiche peinte, sans Server Action", () => {
    expect(handoffUi).not.toMatch(/refreshLibraryAfterImport/);
    expect(handoffUi).not.toMatch(/refreshLibraryInBackground/);
    expect(handoffUi).toContain("releaseImportHandoff");
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

  it("garde le voile jusqu'à la fiche peinte", () => {
    const finish = importPanel.slice(importPanel.indexOf("function finish"));
    const success = finish.slice(0, finish.indexOf("openGeneratedPage"));
    expect(success).toContain("rememberWrittenCourse");
    expect(success).toContain("releaseImportHandoff");
  });
});
