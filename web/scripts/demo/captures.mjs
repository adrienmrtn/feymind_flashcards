// Les captures de la démonstration, prises par le protocole DevTools de Chrome : la même
// séquence à chaque fois, donc les images de `docs/captures/web/` se refont en une commande
// quand un écran bouge. Il faut le faux Supabase et le site en route (voir web/README.md) :
//
//   node scripts/demo/server.mjs
//   NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54329 pnpm dev
//   node scripts/demo/captures.mjs [dossier]      # ../docs/captures/web par défaut
//
// `CHROME` désigne le binaire (Chromium, Chrome ou le headless shell de Playwright) ; `BASE`
// l'adresse du site. Node 22 ou plus : le script n'a aucune dépendance, il parle WebSocket.
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const BASE = process.env.BASE ?? "http://localhost:3000";
const OUT = resolve(process.argv[2] ?? "../docs/captures/web");
/** La leçon au nouveau format du jeu de démonstration (`fixtures.mjs`). */
const LESSON = "b54cda26-0000-4000-8000-b54cda26b54c";
const LOGIN = `${BASE}/auth/dev?email=camille@micabo.test&password=demo`;
const PORT = 9333;

function findChrome() {
  if (process.env.CHROME) return process.env.CHROME;
  const root = process.env.PLAYWRIGHT_BROWSERS_PATH ?? "/opt/pw-browsers";
  if (existsSync(root)) {
    const shell = readdirSync(root).find((name) => name.startsWith("chromium_headless_shell"));
    if (shell) return join(root, shell, "chrome-linux", "headless_shell");
  }
  return "chromium";
}

const profile = join(tmpdir(), "micabo-captures-profile");
rmSync(profile, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
const chrome = spawn(
  findChrome(),
  ["--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars", `--remote-debugging-port=${PORT}`, `--user-data-dir=${profile}`, "about:blank"],
  { stdio: "ignore" },
);

async function json(path, init) {
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      const response = await fetch(`http://127.0.0.1:${PORT}${path}`, init);
      return await response.json();
    } catch {
      await new Promise((r) => setTimeout(r, 150));
    }
  }
  throw new Error("Chrome ne répond pas");
}

const target = await json("/json/new?about:blank", { method: "PUT" });
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((open) => (ws.onopen = open));
let nextId = 1;
const pending = new Map();
ws.onmessage = (message) => {
  const data = JSON.parse(message.data);
  if (data.id && pending.has(data.id)) {
    pending.get(data.id)(data);
    pending.delete(data.id);
  }
};
function send(method, params = {}) {
  const id = nextId++;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((done) => pending.set(id, done));
}
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function goto(url) {
  await send("Page.navigate", { url });
  for (let i = 0; i < 40; i++) {
    const { result } = await send("Runtime.evaluate", { expression: "document.readyState", returnByValue: true });
    if (result?.result?.value === "complete") break;
    await wait(100);
  }
  await wait(1800);
}
async function size(width, height) {
  await send("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: 1, mobile: width < 600 });
}
async function appearance(value) {
  await send("Runtime.evaluate", {
    expression: `localStorage.setItem("micabo.appearance", ${JSON.stringify(value)}); document.cookie = "micabo.appearance=${value}; path=/"`,
  });
}
async function shot(name, full = false) {
  // Le badge des outils de développement de Next n'est pas l'app.
  await send("Runtime.evaluate", { expression: "document.querySelector('nextjs-portal')?.remove()" });
  const params = { format: "png" };
  if (full) {
    const { result } = await send("Runtime.evaluate", { expression: "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)", returnByValue: true });
    params.captureBeyondViewport = true;
    params.clip = { x: 0, y: 0, width: 800, height: Math.min(result.result.value, 4000), scale: 1 };
  }
  const { result } = await send("Page.captureScreenshot", params);
  writeFileSync(join(OUT, `${name}.png`), Buffer.from(result.data, "base64"));
  console.log(`capture ${name}`);
}
async function series(width, height, pages) {
  await size(width, height);
  for (const [name, path] of pages) {
    await goto(`${BASE}${path}`);
    await shot(name);
  }
}

await send("Page.enable");
await send("Runtime.enable");
await size(390, 844);
await goto(LOGIN);

await appearance("day");
await series(390, 844, [
  ["home", "/app"],
  ["lecons", "/app/lecons"],
  ["chemin", `/app/lecons/${LESSON}`],
  ["etape-notes", `/app/lecons/${LESSON}/etape/notes:1`],
  ["quiz", `/app/lecons/${LESSON}/quiz`],
  ["examen", "/app/examen"],
  ["profil", "/app/profil"],
  ["flashcards", `/app/lecons/${LESSON}/flashcards`],
  ["accueil", "/?web"],
]);
await appearance("night");
await series(390, 844, [
  ["home-sombre", "/app"],
  ["chemin-sombre", `/app/lecons/${LESSON}`],
]);
await appearance("day");
await series(1280, 800, [
  ["accueil-bureau", "/?web"],
  ["home-bureau", "/app"],
  ["chemin-bureau", `/app/lecons/${LESSON}`],
  ["notes-bureau", `/app/lecons/${LESSON}/notes`],
]);
await size(800, 1000);
await goto(`${BASE}/app/lecons/${LESSON}/notes`);
await send("Runtime.evaluate", { expression: "window.dispatchEvent(new Event('beforeprint'))" });
await send("Emulation.setEmulatedMedia", { media: "print" });
await wait(400);
await shot("notes-impression", true);

ws.close();
chrome.kill();
rmSync(profile, { recursive: true, force: true });
