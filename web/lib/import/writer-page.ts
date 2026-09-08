/**
 * Page d'écriture hors App Router. Tant que Next peint l'import, un vol RSC
 * avorté affiche « This page couldn't load ». Cette page vit dans le document
 * qu'on substitue : overlay, POST, puis GET de la fiche.
 */

import { IMPORT_WRITE_PATH } from "./write-sheet";

export const WRITER_ROOT_ID = "micabo-writer";

export interface WriterCopy {
  writing: string;
  waitHint: string;
}

export interface WriterInput {
  text: string;
  hintTitle?: string;
  sourceName?: string;
  source?: "text" | "pdf" | "docx" | "youtube";
  visibility?: string;
  blocks?: number;
  length?: string;
  language?: string;
  instructions?: string;
  images?: string[];
}

function embed(value: unknown): string {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}

export function buildWriterPage(input: WriterInput, copy: WriterCopy, origin: string): string {
  const destOrigin = embed(origin);
  const payload = embed(input);
  const writing = embed(copy.writing);
  const hint = embed(copy.waitHint);
  const path = embed(IMPORT_WRITE_PATH);
  return `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Micabo</title>
<style>
html,body{margin:0;height:100%;background:#F8F4F0;font-family:system-ui,-apple-system,sans-serif;color:#111}
#${WRITER_ROOT_ID}{min-height:100%;display:flex;align-items:center;justify-content:center;padding:24px}
.wrap{display:flex;flex-direction:column;align-items:center;gap:16px;text-align:center}
.pct{font-size:44px;font-weight:700;letter-spacing:-.04em;font-variant-numeric:tabular-nums}
.title{font-size:16px;font-weight:600}
.hint{font-size:13px;color:#6b7280;max-width:28rem}
.fail{max-width:28rem;line-height:1.5}
.fail a{color:#111}
</style>
</head>
<body>
<div id="${WRITER_ROOT_ID}">
  <div class="wrap">
    <p class="pct"><span id="pct">1</span> %</p>
    <p class="title" id="title"></p>
    <p class="hint" id="hint"></p>
  </div>
</div>
<script>
(function () {
  var origin = ${destOrigin};
  var input = ${payload};
  var writing = ${writing};
  var hint = ${hint};
  var path = ${path};
  document.getElementById("title").textContent = writing;
  document.getElementById("hint").textContent = hint;
  var started = Date.now();
  function fraction(ms) {
    return Math.min(0.94, 1 - Math.exp(-Math.max(0, ms) / 16000));
  }
  function paint() {
    var shown = Math.min(99, Math.max(1, Math.round(fraction(Date.now() - started) * 100)));
    document.getElementById("pct").textContent = String(shown);
  }
  paint();
  setInterval(paint, 80);
  function fail(message) {
    var root = document.getElementById("${WRITER_ROOT_ID}");
    root.innerHTML = '<div class="fail"><p>' + String(message || "error") +
      '</p><p><a href="' + origin + '/app/importer">←</a></p></div>';
  }
  var xhr = new XMLHttpRequest();
  xhr.open("POST", origin + path);
  xhr.setRequestHeader("Accept", "application/json");
  xhr.setRequestHeader("Content-Type", "application/json");
  xhr.withCredentials = true;
  xhr.timeout = 120000;
  xhr.onload = function () {
    var payload;
    try { payload = JSON.parse(xhr.responseText); } catch (e) { fail(xhr.statusText); return; }
    if (payload && payload.status === "ok" && payload.courseId) {
      location.replace(origin + "/app/c/" + payload.courseId);
      return;
    }
    if (payload && payload.status === "paywall") {
      location.replace(origin + "/app/importer?offre=1");
      return;
    }
    fail(payload && payload.message);
  };
  xhr.onerror = function () { fail("error"); };
  xhr.ontimeout = function () { fail("timeout"); };
  xhr.send(JSON.stringify(input));
})();
<\/script>
</body>
</html>`;
}
