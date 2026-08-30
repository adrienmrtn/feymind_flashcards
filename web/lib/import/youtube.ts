/**
 * Lecture YouTube **dans le navigateur**.
 *
 * L'Edge Function parle à YouTube depuis une IP de datacenter. YouTube répond
 * alors `LOGIN_REQUIRED` et retire les pistes. L'onglet de l'utilisateur n'est
 * pas un datacenter : c'est le même chemin que l'iPhone — InnerTube d'abord,
 * `timedtext` ensuite, Invidious en dernier. Le serveur ne sert que de repli.
 *
 * L'aperçu ne télécharge pas la transcription. On montre la vidéo, puis on
 * lit les sous-titres seulement quand on écrit la fiche.
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
const INNERTUBE_KEY = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";
const INVIDIOUS_HOSTS = [
  "https://invidious.flokinet.to",
  "https://inv.nadeko.net",
  "https://invidious.privacyredirect.com",
];

export const MIN_CAPTION_CHARS = 400;
export const MAX_DURATION_SECONDS = 90 * 60;

export interface YouTubeCaption {
  code: string;
  name: string;
  isAutomatic: boolean;
  baseUrl?: string;
}

export interface YouTubePreview {
  id: string;
  title: string;
  author: string;
  thumbnailUrl: string;
  durationSeconds: number;
  captions: YouTubeCaption[];
  /**
   * Vrai quand on a vraiment interrogé les pistes. Un aperçu oEmbed
   * sans liste ne veut pas dire « pas de sous-titres ».
   */
  captionsKnown?: boolean;
}

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

export function isYouTubeUrl(raw: string): boolean {
  return extractVideoId(raw) !== null;
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

export function youtubeDurationLabel(seconds: number): string | null {
  if (seconds <= 0) return null;
  const total = Math.round(seconds);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  if (hours > 0) return `${hours} h ${minutes.toString().padStart(2, "0")}`;
  return `${Math.max(1, minutes)} min`;
}

export function youtubeBlockingReason(video: YouTubePreview): string | null {
  if (video.captionsKnown && video.captions.length === 0) {
    return "Cette vidéo n'a pas de piste de sous-titres.";
  }
  if (video.durationSeconds > 0 && video.durationSeconds > MAX_DURATION_SECONDS) {
    return `Cette vidéo dure ${youtubeDurationLabel(video.durationSeconds)}, au-delà de 90 min.`;
  }
  return null;
}

/** L'aperçu : titre, chaîne, durée, vignette. Aucune transcription. */
export async function previewYouTubeInBrowser(
  url: string,
): Promise<{ status: "ok"; video: YouTubePreview } | { status: "error"; message: string }> {
  const id = extractVideoId(url);
  if (!id) {
    return { status: "error", message: "Ce lien n'est pas une vidéo YouTube." };
  }

  const language = preferredLanguages()[0] ?? "fr";
  const fromPlayer = await withTimeout(previewFromInnerTube(id, language), 2_500);
  if (fromPlayer) return { status: "ok", video: { ...fromPlayer, captionsKnown: true } };

  const fromInvidious = await withTimeout(previewFromInvidious(id, language), 2_500);
  if (fromInvidious) return { status: "ok", video: { ...fromInvidious, captionsKnown: true } };

  const oembed = await fetchOEmbed(id);
  if (oembed) {
    const listed = await listCaptionLanguages(id);
    return {
      status: "ok",
      video: {
        id,
        title: oembed.title,
        author: oembed.author,
        thumbnailUrl: oembed.thumbnailUrl,
        durationSeconds: 0,
        captions: listed.map((code) => ({ code, name: code, isAutomatic: false })),
        captionsKnown: listed.length > 0,
      },
    };
  }

  return { status: "error", message: "La page de la vidéo n'a pas pu être lue." };
}

export async function readYouTubeInBrowser(
  url: string,
): Promise<{ status: "ok"; text: string; title: string } | { status: "error"; message: string }> {
  const id = extractVideoId(url);
  if (!id) {
    return { status: "error", message: "Ce lien n'est pas une vidéo YouTube." };
  }

  const languages = preferredLanguages();
  const preview = await previewYouTubeInBrowser(url);
  const title = preview.status === "ok" ? preview.video.title : "Vidéo YouTube";

  if (preview.status === "ok") {
    const blocked = youtubeBlockingReason(preview.video);
    if (blocked && preview.video.captions.length === 0) {
      // On tente quand même les autres pistes : l'aperçu n'a pas toujours la liste.
    } else if (blocked) {
      return { status: "error", message: blocked };
    }

    const fromTracks = await transcriptFromTracks(preview.video.captions, languages, id);
    if (fromTracks && fromTracks.length >= MIN_CAPTION_CHARS) {
      return { status: "ok", text: fromTracks, title };
    }
  }

  const timed = await fetchCaptionText(id, languages);
  if (timed && timed.length >= MIN_CAPTION_CHARS) {
    return { status: "ok", text: timed, title };
  }

  const invidious = await transcriptFromInvidious(id, languages);
  if (invidious && invidious.length >= MIN_CAPTION_CHARS) {
    return { status: "ok", text: invidious, title };
  }

  const longest = [timed, invidious].filter((text): text is string => Boolean(text))
    .sort((a, b) => b.length - a.length)[0];
  if (longest && longest.length > 0) {
    return {
      status: "error",
      message: "Cette vidéo n'a pas assez de sous-titres exploitables.",
    };
  }

  return {
    status: "error",
    message: "Cette vidéo n'a pas assez de sous-titres exploitables.",
  };
}

async function previewFromInnerTube(
  videoId: string,
  language: string,
): Promise<YouTubePreview | null> {
  const player = await fetchPlayer(videoId, language);
  const details = asRecord(player?.videoDetails);
  if (!details || typeof details.title !== "string") return null;

  return {
    id: videoId,
    title: details.title,
    author: typeof details.author === "string" ? details.author : "",
    thumbnailUrl: bestThumbnail(details, videoId),
    durationSeconds: Number.parseInt(String(details.lengthSeconds ?? "0"), 10) || 0,
    captions: captionTracks(player),
  };
}

async function fetchPlayer(
  videoId: string,
  language: string,
): Promise<Record<string, unknown> | null> {
  const clients = [
    {
      clientName: "WEB",
      clientVersion: "2.20240827.00.00",
    },
    {
      clientName: "IOS",
      clientVersion: "20.10.38",
      deviceMake: "Apple",
      deviceModel: "iPhone16,2",
      osName: "iPhone",
      osVersion: "18.3.2.22D82",
    },
  ];

  for (const client of clients) {
    try {
      const response = await fetch(
        `https://www.youtube.com/youtubei/v1/player?key=${INNERTUBE_KEY}&prettyPrint=false`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            videoId,
            contentCheckOk: true,
            racyCheckOk: true,
            context: { client: { ...client, hl: language, gl: "FR" } },
          }),
        },
      );
      if (!response.ok) continue;
      const parsed = asRecord(await response.json());
      if (!parsed) continue;
      const status = asRecord(parsed.playabilityStatus);
      const playable = typeof status?.status === "string" ? status.status : "OK";
      if (playable === "LOGIN_REQUIRED") continue;
      if (asRecord(parsed.videoDetails)) return parsed;
    } catch {
      continue;
    }
  }
  return null;
}

function captionTracks(player: Record<string, unknown> | null): YouTubeCaption[] {
  const renderer = asRecord(asRecord(player?.captions)?.playerCaptionsTracklistRenderer);
  const raw = Array.isArray(renderer?.captionTracks) ? renderer.captionTracks : [];
  const tracks: YouTubeCaption[] = [];

  for (const entry of raw) {
    const track = asRecord(entry);
    if (!track) continue;
    const baseUrl = typeof track.baseUrl === "string" ? track.baseUrl : "";
    const languageCode = typeof track.languageCode === "string" ? track.languageCode : "";
    if (languageCode.length === 0) continue;
    const name = asRecord(track.name);
    tracks.push({
      code: languageCode,
      name: typeof name?.simpleText === "string" ? name.simpleText : languageCode,
      isAutomatic: track.kind === "asr",
      baseUrl: baseUrl.length > 0 ? baseUrl : undefined,
    });
  }
  return tracks;
}

function bestThumbnail(details: Record<string, unknown>, videoId: string): string {
  const container = asRecord(details.thumbnail);
  const thumbnails: unknown[] = Array.isArray(container?.thumbnails) ? container.thumbnails : [];
  let best = "";
  let bestWidth = 0;
  for (const entry of thumbnails) {
    const thumbnail = asRecord(entry);
    const url = typeof thumbnail?.url === "string" ? thumbnail.url : "";
    const width = typeof thumbnail?.width === "number" ? thumbnail.width : 0;
    if (url.length > 0 && width > bestWidth && width <= 1280) {
      best = url;
      bestWidth = width;
    }
  }
  return best.length > 0 ? best : `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
}

async function transcriptFromTracks(
  tracks: YouTubeCaption[],
  languages: string[],
  videoId: string,
): Promise<string | null> {
  const ordered = orderTracks(tracks, languages);
  let longest = "";

  for (const track of ordered) {
    const text = track.baseUrl
      ? await captionTextFromUrl(track.baseUrl)
      : await fetchTimedText(videoId, track.code, track.isAutomatic ? "asr" : "");
    if (text && text.length >= MIN_CAPTION_CHARS) return text;
    if (text && text.length > longest.length) longest = text;
  }
  return longest.length > 0 ? longest : null;
}

function orderTracks(tracks: YouTubeCaption[], languages: string[]): YouTubeCaption[] {
  const seen = new Set<string>();
  const result: YouTubeCaption[] = [];
  const key = (track: YouTubeCaption) => track.baseUrl ?? `${track.code}:${track.isAutomatic}`;

  for (const language of languages) {
    const manual = tracks.find((track) => !track.isAutomatic && sameLanguage(track.code, language));
    const automatic = tracks.find((track) => track.isAutomatic && sameLanguage(track.code, language));
    for (const track of [manual, automatic]) {
      if (!track) continue;
      const id = key(track);
      if (seen.has(id)) continue;
      seen.add(id);
      result.push(track);
    }
  }
  for (const track of tracks) {
    const id = key(track);
    if (seen.has(id)) continue;
    seen.add(id);
    result.push(track);
  }
  return result;
}

function sameLanguage(a: string, b: string): boolean {
  return a.toLowerCase().split(/[-_]/)[0] === b.toLowerCase().split(/[-_]/)[0];
}

async function captionTextFromUrl(baseUrl: string): Promise<string | null> {
  for (const format of ["json3", "srv3", "vtt"] as const) {
    const url = withCaptionFormat(baseUrl, format);
    try {
      const response = await fetch(url);
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

function withCaptionFormat(baseUrl: string, format: string): string {
  try {
    const url = new URL(baseUrl);
    url.searchParams.delete("fmt");
    url.searchParams.set("fmt", format);
    return url.toString();
  } catch {
    const stripped = baseUrl.replace(/([?&])fmt=[^&]*/g, "$1").replace(/[?&]$/, "");
    const separator = stripped.includes("?") ? "&" : "?";
    return `${stripped}${separator}fmt=${format}`;
  }
}

function withTimeout<T>(promise: Promise<T | null>, ms: number): Promise<T | null> {
  return Promise.race([
    promise,
    new Promise<null>((resolve) => {
      setTimeout(() => resolve(null), ms);
    }),
  ]);
}

async function previewFromInvidious(
  videoId: string,
  _language: string,
): Promise<YouTubePreview | null> {
  for (const host of INVIDIOUS_HOSTS) {
    try {
      const response = await fetch(`${host}/api/v1/videos/${videoId}`, {
        headers: { Accept: "application/json" },
      });
      if (!response.ok) continue;
      const parsed = asRecord(await response.json());
      if (!parsed || typeof parsed.title !== "string") continue;

      const rawCaptions = Array.isArray(parsed.captions) ? parsed.captions : [];
      const captions: YouTubeCaption[] = [];
      for (const entry of rawCaptions) {
        const track = asRecord(entry);
        if (!track) continue;
        const code = typeof track.languageCode === "string"
          ? track.languageCode
          : typeof track.language_code === "string"
            ? track.language_code
            : "";
        if (!code) continue;
        const label = typeof track.label === "string" ? track.label : code;
        captions.push({
          code,
          name: label,
          isAutomatic: /auto/i.test(label),
          baseUrl: `${host}/api/v1/captions/${videoId}?lang=${encodeURIComponent(code)}`,
        });
      }

      return {
        id: videoId,
        title: parsed.title,
        author: typeof parsed.author === "string" ? parsed.author : "",
        thumbnailUrl: `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
        durationSeconds: Number.parseInt(String(parsed.lengthSeconds ?? "0"), 10) || 0,
        captions,
      };
    } catch {
      continue;
    }
  }
  return null;
}

async function transcriptFromInvidious(
  videoId: string,
  languages: string[],
): Promise<string | null> {
  const preview = await previewFromInvidious(videoId, languages[0] ?? "fr");
  if (!preview) return null;
  return transcriptFromTracks(preview.captions, languages, videoId);
}

async function fetchOEmbed(
  videoId: string,
): Promise<{ title: string; author: string; thumbnailUrl: string } | null> {
  try {
    const response = await fetch(
      `https://www.youtube.com/oembed?url=${
        encodeURIComponent(`https://www.youtube.com/watch?v=${videoId}`)
      }&format=json`,
    );
    if (!response.ok) return null;
    const parsed = (await response.json()) as {
      title?: unknown;
      author_name?: unknown;
      thumbnail_url?: unknown;
    };
    if (typeof parsed.title !== "string" || parsed.title.length === 0) return null;
    return {
      title: parsed.title,
      author: typeof parsed.author_name === "string" ? parsed.author_name : "",
      thumbnailUrl: typeof parsed.thumbnail_url === "string"
        ? parsed.thumbnail_url
        : `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
    };
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
  if (!videoId || !language) return null;
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

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}
