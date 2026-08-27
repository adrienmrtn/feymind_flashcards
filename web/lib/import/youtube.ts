/**
 * Lecture des sous-titres YouTube **dans le navigateur**.
 *
 * L'Edge Function parle à YouTube depuis une IP de datacenter. YouTube répond
 * alors `LOGIN_REQUIRED` (« confirme que tu n'es pas un robot ») et retire
 * les pistes. L'onglet de l'utilisateur n'est pas un datacenter : `timedtext`
 * y autorise le CORS, et oEmbed y rend le titre.
 *
 * Le serveur reste un repli, pour les vidéos qu'il arrive encore à ouvrir.
 */

const ID_PATTERN = /^[A-Za-z0-9_-]{11}$/;
const ALLOWED_HOSTS = new Set([
  "youtube.com",
  "m.youtube.com",
  "music.youtube.com",
  "youtube-nocookie.com",
  "youtu.be",
]);
const PATH_PREFIXES = new Set(["shorts", "embed", "live", "v"]);

export const MIN_CAPTION_CHARS = 400;

export function extractVideoId(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;

  let url: URL;
  try {
    url = new URL(/^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`);
  } catch {
    return null;
  }

  const host = url.hostname.toLowerCase().replace(/^www\./, "");
  if (!ALLOWED_HOSTS.has(host)) return null;

  const segments = url.pathname.split("/").filter(Boolean);
  if (host === "youtu.be") return valid(segments[0]);
  if (segments[0] === "watch") return valid(url.searchParams.get("v"));
  if (segments.length >= 2 && PATH_PREFIXES.has(segments[0] ?? "")) {
    return valid(segments[1] ?? null);
  }
  return valid(url.searchParams.get("v"));
}

function valid(candidate: string | null | undefined): string | null {
  return typeof candidate === "string" && ID_PATTERN.test(candidate) ? candidate : null;
}

export function preferredLanguages(): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const raw of [...(navigator.languages ?? []), navigator.language, "fr", "en"]) {
    const code = raw.split(/[-_]/)[0]?.toLowerCase();
    if (!code || seen.has(code)) continue;
    seen.add(code);
    result.push(code);
  }
  return result;
}

export async function readYouTubeInBrowser(
  url: string,
): Promise<
  | { status: "ok"; text: string; title: string }
  | { status: "error"; message: string }
> {
  const id = extractVideoId(url);
  if (!id) {
    return { status: "error", message: "Ce lien n'est pas une vidéo YouTube." };
  }

  const [title, text] = await Promise.all([
    fetchOEmbedTitle(id),
    fetchCaptionText(id, preferredLanguages()),
  ]);

  if (!text || text.length < MIN_CAPTION_CHARS) {
    return {
      status: "error",
      message: "Cette vidéo n'a pas assez de sous-titres exploitables.",
    };
  }

  return { status: "ok", text, title: title ?? "Vidéo YouTube" };
}

async function fetchOEmbedTitle(videoId: string): Promise<string | null> {
  try {
    const response = await fetch(
      `https://www.youtube.com/oembed?url=${
        encodeURIComponent(`https://www.youtube.com/watch?v=${videoId}`)
      }&format=json`,
    );
    if (!response.ok) return null;
    const parsed = (await response.json()) as { title?: unknown };
    return typeof parsed.title === "string" && parsed.title.length > 0 ? parsed.title : null;
  } catch {
    return null;
  }
}

async function fetchCaptionText(videoId: string, languages: string[]): Promise<string | null> {
  const listed = await listCaptionLanguages(videoId);
  const codes = [...languages, ...listed].filter((code, index, all) => all.indexOf(code) === index);

  let longest = "";
  for (const language of codes) {
    for (const kind of ["", "asr"]) {
      const text = await fetchTimedText(videoId, language, kind);
      if (text && text.length >= MIN_CAPTION_CHARS) return text;
      if (text && text.length > longest.length) longest = text;
    }
  }
  return longest.length > 0 ? longest : null;
}

async function listCaptionLanguages(videoId: string): Promise<string[]> {
  try {
    const response = await fetch(
      `https://www.youtube.com/api/timedtext?type=list&v=${encodeURIComponent(videoId)}`,
    );
    if (!response.ok) return [];
    const xml = await response.text();
    if (looksLikeHtml(xml)) return [];
    return [...xml.matchAll(/lang_code="([^"]+)"/g)]
      .map((match) => match[1])
      .filter((code): code is string => typeof code === "string" && code.length > 0);
  } catch {
    return [];
  }
}

async function fetchTimedText(
  videoId: string,
  language: string,
  kind: string,
): Promise<string | null> {
  const query = new URLSearchParams({ v: videoId, lang: language });
  if (kind) query.set("kind", kind);

  for (const format of ["json3", "srv3", "vtt"]) {
    query.set("fmt", format);
    try {
      const response = await fetch(`https://www.youtube.com/api/timedtext?${query}`);
      if (!response.ok) continue;
      const raw = await response.text();
      if (!raw || looksLikeHtml(raw)) continue;
      const text = format === "json3"
        ? parseJson3(raw)
        : format === "vtt"
          ? cleanTranscript(parseVtt(raw))
          : cleanTranscript(parseCaptionXml(raw));
      if (text && text.length > 0) return text;
    } catch {
      continue;
    }
  }
  return null;
}

export function parseJson3(raw: string): string | null {
  if (!raw.trim().startsWith("{")) return null;
  try {
    const parsed = JSON.parse(raw) as { events?: unknown };
    const events = Array.isArray(parsed.events) ? parsed.events : [];
    const lines: string[] = [];
    for (const entry of events) {
      if (!entry || typeof entry !== "object") continue;
      const event = entry as { aAppend?: number; segs?: unknown };
      if (event.aAppend === 1) continue;
      const segments = Array.isArray(event.segs) ? event.segs : [];
      const line = segments
        .map((segment) => {
          const value = segment && typeof segment === "object"
            ? (segment as { utf8?: unknown }).utf8
            : "";
          return typeof value === "string" ? value : "";
        })
        .join("")
        .replace(/\n/g, " ")
        .trim();
      if (line) lines.push(line);
    }
    return cleanTranscript(lines);
  } catch {
    return null;
  }
}

export function parseCaptionXml(xml: string): string[] {
  if (!/<(?:timedtext|transcript|text)\b/i.test(xml)) return [];
  return [...xml.matchAll(/<(?:text|p)\b[^>]*>([\s\S]*?)<\/(?:text|p)>/g)]
    .map((match) => {
      const inner = match[1] ?? "";
      return decodeEntities(inner.replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim();
    })
    .filter(Boolean);
}

export function parseVtt(vtt: string): string[] {
  const lines: string[] = [];
  for (const block of vtt.replace(/^\uFEFF?WEBVTT[^\n]*/i, "").split(/\n\n+/)) {
    const spoken = block
      .split("\n")
      .map((line) => line.trim())
      .filter((line) =>
        line.length > 0 &&
        !line.includes("-->") &&
        !/^\d+$/.test(line) &&
        !/^kind:/i.test(line) &&
        !/^language:/i.test(line)
      )
      .join(" ")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    if (spoken) lines.push(spoken);
  }
  return lines;
}

export function cleanTranscript(lines: string[]): string {
  const kept: string[] = [];
  for (const raw of lines) {
    const line = decodeEntities(raw).replace(/\[[^\]\n]{1,25}\]/g, " ").replace(/\s+/g, " ").trim();
    if (!line) continue;
    if (kept.at(-1) === line) continue;
    kept.push(line);
  }
  return kept.join(" ").replace(/\s+([,.;:!?])/g, "$1").replace(/\s{2,}/g, " ").trim();
}

function looksLikeHtml(raw: string): boolean {
  const start = raw.slice(0, 240).trimStart().toLowerCase();
  return (
    start.startsWith("<!doctype") ||
    start.startsWith("<html") ||
    start.includes("sorry for the interruption") ||
    start.includes("we're sorry")
  );
}

function decodeEntities(value: string): string {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number.parseInt(code, 10)));
}
