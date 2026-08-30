#!/usr/bin/env node
/**
 * Recrée les captures 6.9″ hors simulateur : écrans bruts, puis cadres
 * marketing aux dimensions App Store (1320 × 2868).
 */
import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const root = dirname(fileURLToPath(import.meta.url));
const goldie = resolve(root, "..");
const scenes = ["today", "sheet", "study", "exam", "courses"];
const origin = process.env.MOCK_ORIGIN ?? "http://127.0.0.1:8766";

const rawDir = resolve(goldie, "out/raw/iphone-6.9");
const shotDir = resolve(goldie, "screenshots/fr-FR");

await mkdir(rawDir, { recursive: true });
await mkdir(shotDir, { recursive: true });

const browser = await chromium.launch();
async function waitForPaint(page) {
  await page.evaluate(async () => {
    await document.fonts.ready;
    await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
  });
}

const phone = await browser.newContext({
  viewport: { width: 440, height: 956 },
  deviceScaleFactor: 3,
});
const frame = await browser.newContext({
  viewport: { width: 1320, height: 2868 },
  deviceScaleFactor: 1,
});

for (const id of scenes) {
  const page = await phone.newPage();
  await page.goto(`${origin}/mock/screens.html?screen=${id}`, { waitUntil: "networkidle" });
  await waitForPaint(page);
  await page.waitForTimeout(250);
  const raw = resolve(rawDir, `${id}.png`);
  await page.screenshot({ path: raw, type: "png" });
  await page.close();
  console.log("raw", id);
}

for (const id of scenes) {
  const page = await frame.newPage();
  await page.goto(`${origin}/mock/frame.html?scene=${id}`, { waitUntil: "networkidle" });
  await page.waitForFunction(() => {
    const img = document.getElementById("screen");
    return img && img.complete && img.naturalWidth > 100;
  });
  await waitForPaint(page);
  await page.waitForTimeout(300);
  const out = resolve(shotDir, `${id}.png`);
  await page.screenshot({ path: out, type: "png" });
  await page.close();
  console.log("frame", id);
}

await browser.close();

const manifest = {
  device: "iphone-6.9",
  capturedAt: new Date().toISOString(),
  screenshots: scenes.map((sceneId) => ({
    sceneId,
    file: resolve(rawDir, `${sceneId}.png`),
  })),
  preview: null,
};
await import("node:fs/promises").then(({ writeFile }) =>
  writeFile(resolve(rawDir, "manifest.json"), JSON.stringify(manifest, null, 2)),
);
console.log("done", shotDir);
