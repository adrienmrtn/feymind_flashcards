/**
 * Lecture d'une vidéo YouTube : identifiant, métadonnées, pistes de sous-titres,
 * transcription.
 *
 * Micabo ne lit **que les sous-titres**. Il n'y a pas de repli sur l'audio, et c'est un
 * choix, pas une limite technique : transcrire une heure d'audio coûte cher, prend des
 * minutes, et rend un texte moins fiable que des sous-titres écrits à la main. Une vidéo
 * sans sous-titres est donc refusée, et l'utilisateur le sait avant d'attendre.
 */

export const YOUTUBE_LIMITS = {
  /** Au delà, la transcription dépasse ce qu'un seul appel de génération peut lire. */
  maxDurationSeconds: 90 * 60,
  /** En dessous, il n'y a pas de quoi écrire une fiche ni des cartes. */
  minTranscriptCharacters: 400,
} as const;

export type YouTubeErrorCode =
  | "invalid_url"
  | "unavailable"
  | "no_captions"
  | "too_short"
  | "too_long";

/**
 * Refus nommé.
 *
 * Le `code` compte plus que le message : c'est lui que l'application traduit dans ses
 * propres phrases. Reconnaître un refus à la forme de son message casserait au premier mot
 * changé ici.
 */
export class YouTubeError extends Error {
  readonly code: YouTubeErrorCode;
  readonly status: number;
  readonly details: Record<string, unknown>;

  constructor(
    code: YouTubeErrorCode,
    message: string,
    status = 422,
    details: Record<string, unknown> = {},
  ) {
    super(message);
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

// MARK: - Identifiant

const ALLOWED_HOSTS = new Set([
  "youtube.com",
  "m.youtube.com",
  "music.youtube.com",
  "youtube-nocookie.com",
  "youtu.be",
]);

/** Les chemins qui portent l'identifiant dans leur second segment. */
const PATH_PREFIXES = new Set(["shorts", "embed", "live", "v"]);

const ID_PATTERN = /^[A-Za-z0-9_-]{11}$/;

/**
 * L'identifiant de la vidéo, ou `null` si ce n'est pas un lien YouTube.
 *
 * Un identifiant collé seul n'est pas accepté : onze caractères alphanumériques peuvent
 * être n'importe quoi, et l'utilisateur croirait avoir collé un lien.
 */
export function extractVideoId(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;

  let url: URL;
  try {
    url = new URL(/^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`);
  } catch {
    return null;
  }

  const host = url.hostname.toLowerCase().replace(/^www\./, "");
  if (!ALLOWED_HOSTS.has(host)) return null;

  const segments = url.pathname.split("/").filter((segment) => segment.length > 0);

  if (host === "youtu.be") {
    return valid(segments[0]);
  }

  if (segments[0] === "watch") {
    return valid(url.searchParams.get("v"));
  }

  if (segments.length >= 2 && PATH_PREFIXES.has(segments[0])) {
    return valid(segments[1]);
  }

  // `youtube.com/oembed?url=…` et compagnie : l'identifiant peut rester dans `v`.
  return valid(url.searchParams.get("v"));
}

function valid(candidate: string | null | undefined): string | null {
  if (typeof candidate !== "string") return null;
  return ID_PATTERN.test(candidate) ? candidate : null;
}

// MARK: - Métadonnées

export interface CaptionTrack {
  languageCode: string;
  languageName: string;
  /** Sous-titres générés par reconnaissance automatique, et non écrits à la main. */
  isAutomatic: boolean;
  isDefault: boolean;
  baseUrl: string;
}

export interface VideoMetadata {
  id: string;
  title: string;
  author: string;
  /** 0 quand la durée est inconnue, ce qui est le cas d'un direct. */
  durationSeconds: number;
  thumbnailUrl: string;
  captions: CaptionTrack[];
}

/** Clé publique du client web, celle qu'utilise la page youtube.com elle-même. */
const INNERTUBE_KEY = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";

/**
 * Le client WEB exige désormais un jeton d'origine (PO / BotGuard). Depuis un
 * serveur, la réponse est `UNPLAYABLE` et **sans pistes**. iOS et Android, eux,
 * rendent encore les sous-titres. On les essaie dans cet ordre, puis la page.
 */
interface InnerTubeClient {
  headers: Record<string, string>;
  context: Record<string, unknown>;
}

const IOS_CLIENT: InnerTubeClient = {
  headers: {
    "User-Agent":
      "com.google.ios.youtube/20.10.38 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
    "X-YouTube-Client-Name": "5",
    "X-YouTube-Client-Version": "20.10.38",
  },
  context: {
    clientName: "IOS",
    clientVersion: "20.10.38",
    deviceMake: "Apple",
    deviceModel: "iPhone16,2",
    osName: "iPhone",
    osVersion: "18.3.2.22D82",
  },
};

const ANDROID_CLIENT: InnerTubeClient = {
  headers: {
    "User-Agent": "com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip",
  },
  context: {
    clientName: "ANDROID",
    clientVersion: "20.10.38",
    androidSdkVersion: 34,
  },
};

const BROWSER_HEADERS: Record<string, string> = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36",
  // Sans ce cookie, une adresse européenne reçoit le mur de consentement au lieu de la page.
  "Cookie": "CONSENT=YES+cb; SOCS=CAI",
};

/**
 * Les métadonnées et les pistes de sous-titres d'une vidéo.
 *
 * iOS d'abord, Android ensuite, la page HTML en dernier. Un client qui répond
 * `UNPLAYABLE` ou `LOGIN_REQUIRED` n'est pas une réponse : on passe au suivant.
 * Sans ce garde, le client WEB — encore le premier jusqu'ici — faisait échouer
 * **toutes** les vidéos alors que iOS les ouvrait.
 */
export async function fetchVideoMetadata(videoId: string, language: string): Promise<VideoMetadata> {
  const player = await fetchPlayer(videoId, language);
  const details = asRecord(player.videoDetails);
  if (!details) {
    throw new YouTubeError("unavailable", "La page de la vidéo n'a pas pu être lue.");
  }

  return {
    id: videoId,
    title: typeof details.title === "string" ? details.title : "Vidéo YouTube",
    author: typeof details.author === "string" ? details.author : "",
    durationSeconds: Number.parseInt(String(details.lengthSeconds ?? "0"), 10) || 0,
    thumbnailUrl: bestThumbnail(details, videoId),
    captions: captionTracks(player),
  };
}

async function fetchPlayer(videoId: string, language: string): Promise<Record<string, unknown>> {
  const attempts = [
    () => fetchFromInnerTube(videoId, language, IOS_CLIENT),
    () => fetchFromInnerTube(videoId, language, ANDROID_CLIENT),
    () => fetchFromWatchPage(videoId, language),
  ];

  let blocked = false;

  for (const attempt of attempts) {
    const player = await attempt();
    if (!player) continue;

    const state = playability(player);
    if (state === "LOGIN_REQUIRED") {
      blocked = true;
      continue;
    }
    if (usable(player)) return player;
  }

  if (blocked) {
    throw new YouTubeError(
      "unavailable",
      "YouTube a refusé la lecture (contrôle anti-robot). Réessaie dans un instant.",
    );
  }

  throw new YouTubeError("unavailable", "La page de la vidéo n'a pas pu être lue.");
}

function playability(player: Record<string, unknown>): string {
  const status = asRecord(player.playabilityStatus);
  return typeof status?.status === "string" ? status.status : "OK";
}

/** Une réponse n'est exploitable que si le lecteur **joue** et décrit la vidéo. */
function usable(player: Record<string, unknown> | null): Record<string, unknown> | null {
  if (!player || !asRecord(player.videoDetails)) return null;
  return playability(player) === "OK" ? player : null;
}

async function fetchFromInnerTube(
  videoId: string,
  language: string,
  client: InnerTubeClient,
): Promise<Record<string, unknown> | null> {
  try {
    const response = await fetch(
      `https://www.youtube.com/youtubei/v1/player?key=${INNERTUBE_KEY}&prettyPrint=false`,
      {
        method: "POST",
        headers: { ...client.headers, "Content-Type": "application/json" },
        body: JSON.stringify({
          videoId,
          contentCheckOk: true,
          racyCheckOk: true,
          context: {
            client: {
              ...client.context,
              hl: language,
              gl: "FR",
            },
          },
        }),
      },
    );

    if (!response.ok) return null;
    const parsed = await response.json();
    return asRecord(parsed);
  } catch {
    return null;
  }
}

async function fetchFromWatchPage(
  videoId: string,
  language: string,
): Promise<Record<string, unknown> | null> {
  try {
    const response = await fetch(
      `https://www.youtube.com/watch?v=${videoId}&hl=${encodeURIComponent(language)}&has_verified=1`,
      { headers: { ...BROWSER_HEADERS, "Accept-Language": `${language},en;q=0.8` } },
    );
    if (!response.ok) return null;

    const html = await response.text();
    for (const marker of ["ytInitialPlayerResponse =", 'ytInitialPlayerResponse":']) {
      const parsed = jsonAfter(html, marker);
      if (parsed) return parsed;
    }
    return null;
  } catch {
    return null;
  }
}

/** Extrait l'objet JSON qui suit un marqueur, en comptant les accolades. */
function jsonAfter(html: string, marker: string): Record<string, unknown> | null {
  const markerIndex = html.indexOf(marker);
  if (markerIndex === -1) return null;

  const start = html.indexOf("{", markerIndex + marker.length);
  if (start === -1) return null;

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = start; index < html.length; index += 1) {
    const character = html[index];

    if (inString) {
      if (escaped) escaped = false;
      else if (character === "\\") escaped = true;
      else if (character === '"') inString = false;
      continue;
    }

    if (character === '"') inString = true;
    else if (character === "{") depth += 1;
    else if (character === "}") {
      depth -= 1;
      if (depth === 0) {
        try {
          return asRecord(JSON.parse(html.slice(start, index + 1)));
        } catch {
          return null;
        }
      }
    }
  }

  return null;
}

function captionTracks(player: Record<string, unknown>): CaptionTrack[] {
  const renderer = asRecord(asRecord(player.captions)?.playerCaptionsTracklistRenderer);
  const raw = Array.isArray(renderer?.captionTracks) ? renderer.captionTracks : [];
  const defaultIndex = typeof renderer?.defaultCaptionTrackIndex === "number"
    ? renderer.defaultCaptionTrackIndex
    : 0;

  const tracks: CaptionTrack[] = [];

  for (const [index, entry] of raw.entries()) {
    // Le refus se fait ici, et pas piste par piste sur chaque champ : sans lui, `track`
    // reste nullable jusqu'au bout de la boucle, et c'est ce qui empêchait la fonction de
    // se déployer. Une Edge Function qui ne compile pas n'est pas déployée, et l'app
    // répondait « Fonction Supabase introuvable » à chaque import de vidéo.
    const track = asRecord(entry);
    if (!track) continue;

    const baseUrl = typeof track.baseUrl === "string" ? track.baseUrl : "";
    const languageCode = typeof track.languageCode === "string" ? track.languageCode : "";
    if (baseUrl.length === 0 || languageCode.length === 0) continue;

    const name = asRecord(track.name);
    tracks.push({
      languageCode,
      languageName: typeof name?.simpleText === "string"
        ? name.simpleText
        : runsText(name) || languageCode,
      isAutomatic: track.kind === "asr",
      isDefault: index === defaultIndex,
      baseUrl,
    });
  }

  return tracks;
}

function runsText(value: Record<string, unknown> | null): string {
  const runs = Array.isArray(value?.runs) ? value.runs : [];
  return runs
    .map((run) => (typeof asRecord(run)?.text === "string" ? String(asRecord(run)?.text) : ""))
    .join("")
    .trim();
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
    // On veut une vignette lisible, pas la plus grande : au delà, c'est du poids pour rien.
    if (url.length > 0 && width > bestWidth && width <= 1280) {
      best = url;
      bestWidth = width;
    }
  }

  return best.length > 0 ? best : `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
}

// MARK: - Choix de la piste

/** Compare deux codes sur leur langue seule : « fr » vaut pour « fr-CA ». */
function sameLanguage(a: string, b: string): boolean {
  const base = (value: string) => value.toLowerCase().split(/[-_]/)[0];
  return base(a) === base(b);
}

/**
 * La piste à lire : **la langue de l'utilisateur d'abord, la piste par défaut ensuite.**
 *
 * À langue égale, les sous-titres écrits à la main passent devant ceux générés
 * automatiquement : ils sont ponctués, et un texte ponctué donne de meilleures cartes.
 */
export function selectCaptionTrack(
  tracks: CaptionTrack[],
  languages: string[],
): CaptionTrack | null {
  for (const language of languages) {
    if (typeof language !== "string" || language.length === 0) continue;

    const manual = tracks.find((track) => !track.isAutomatic && sameLanguage(track.languageCode, language));
    if (manual) return manual;

    const automatic = tracks.find((track) => track.isAutomatic && sameLanguage(track.languageCode, language));
    if (automatic) return automatic;
  }

  return tracks.find((track) => track.isDefault) ?? tracks[0] ?? null;
}

// MARK: - Transcription

export interface Transcript {
  text: string;
  languageCode: string;
  languageName: string;
  isAutomatic: boolean;
}

/**
 * Le texte de la piste choisie.
 *
 * Deux formats sont tentés : `json3`, qui est propre, puis le XML historique, qui répond
 * encore quand le premier est refusé.
 */
export async function fetchTranscript(track: CaptionTrack): Promise<Transcript> {
  const json = await fetchJson3(track.baseUrl);
  const text = json ?? (await fetchXml(track.baseUrl));

  if (!text || text.length === 0) {
    throw new YouTubeError("no_captions", "La piste de sous-titres est vide.");
  }

  return {
    text,
    languageCode: track.languageCode,
    languageName: track.languageName,
    isAutomatic: track.isAutomatic,
  };
}

/**
 * Ajoute `fmt` **à la place** de celui déjà présent.
 *
 * Les URL iOS / Android portent déjà `fmt=srv3`. En ajouter un second laisse
 * YouTube lire le premier : on reçoit du XML alors qu'on a demandé du JSON.
 */
export function withCaptionFormat(baseUrl: string, format: string): string {
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

const CAPTION_HEADERS: Record<string, string> = {
  "User-Agent": IOS_CLIENT.headers["User-Agent"],
};

async function fetchJson3(baseUrl: string): Promise<string | null> {
  try {
    const response = await fetch(withCaptionFormat(baseUrl, "json3"), { headers: CAPTION_HEADERS });
    if (!response.ok) return null;

    const raw = await response.text();
    if (!raw.trim().startsWith("{")) return null;

    const parsed = asRecord(JSON.parse(raw));
    const events = Array.isArray(parsed?.events) ? parsed.events : [];
    const lines: string[] = [];

    for (const entry of events) {
      const event = asRecord(entry);
      // Les sous-titres automatiques défilent : un événement « aAppend » réécrit la ligne
      // précédente et la reprendre doublerait tout le texte.
      if (event?.aAppend === 1) continue;

      const segments = Array.isArray(event?.segs) ? event.segs : [];
      const line = segments
        .map((segment) => {
          const value = asRecord(segment)?.utf8;
          return typeof value === "string" ? value : "";
        })
        .join("")
        .replace(/\n/g, " ")
        .trim();

      if (line.length > 0) lines.push(line);
    }

    return cleanTranscript(lines);
  } catch {
    return null;
  }
}

async function fetchXml(baseUrl: string): Promise<string | null> {
  try {
    // Sans `fmt` : le XML historique (`<text>`). Avec `srv3` : le format actuel (`<p>`).
    for (const url of [baseUrl, withCaptionFormat(baseUrl, "srv3")]) {
      const response = await fetch(url, { headers: CAPTION_HEADERS });
      if (!response.ok) continue;
      const xml = await response.text();
      const lines = parseCaptionXml(xml);
      if (lines.length > 0) return cleanTranscript(lines);
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Les deux XML que YouTube sert encore : `<text>` (srv1) et `<p>` (srv3).
 * Les `<s>` imbriqués du défilement automatique sont aplatis.
 */
export function parseCaptionXml(xml: string): string[] {
  return [...xml.matchAll(/<(?:text|p)\b[^>]*>([\s\S]*?)<\/(?:text|p)>/g)]
    .map((match) =>
      decodeEntities(match[1].replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim()
    )
    .filter((line) => line.length > 0);
}

/**
 * Assemble les lignes en un texte lisible.
 *
 * Deux nettoyages valent la peine. Les annotations sonores entre crochets, « [Musique] »,
 * « [Applaudissements] », n'apprennent rien et polluent le contexte. Et les lignes répétées
 * à l'identique, signature des sous-titres automatiques qui défilent, sont réduites à une.
 */
export function cleanTranscript(lines: string[]): string {
  const kept: string[] = [];

  for (const raw of lines) {
    const line = decodeEntities(raw)
      // Une annotation sonore tient en un ou deux mots entre crochets.
      .replace(/\[[^\]\n]{1,25}\]/g, " ")
      .replace(/\s+/g, " ")
      .trim();

    if (line.length === 0) continue;
    if (kept.length > 0 && kept[kept.length - 1] === line) continue;
    kept.push(line);
  }

  return kept
    .join(" ")
    .replace(/\s+([,.;:!?])/g, "$1")
    .replace(/\s{2,}/g, " ")
    .trim();
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
