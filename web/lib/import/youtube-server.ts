/**
 * Lecture YouTube **depuis le serveur Next**, avec le client iOS.
 *
 * L'onglet ne peut pas parler à InnerTube (CORS). L'Edge Function, elle, part
 * souvent d'une IP de datacenter que YouTube refuse. Ce module reprend le
 * client iPhone — le même que l'app — depuis la fonction serveur : c'est
 * ce qui a encore une piste, ici.
 */

import {
  MAX_DURATION_SECONDS,
  MIN_CAPTION_CHARS,
  extractVideoId,
  parseCaptionXml,
  parseJson3,
  parseVtt,
  cleanTranscript,
  type YouTubeCaption,
  type YouTubePreview,
} from "./youtube";

const INNERTUBE_KEY = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";
const IOS_UA =
  "com.google.ios.youtube/20.10.38 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)";

export async function previewYouTubeOnServer(
  url: string,
  language = "fr",
): Promise<{ status: "ok"; video: YouTubePreview } | { status: "error"; message: string }> {
  const id = extractVideoId(url);
  if (!id) {
    return { status: "error", message: "Ce lien n'est pas une vidéo YouTube." };
  }

  const player = await fetchPlayer(id, language);
  if (!player) {
    return { status: "error", message: "La page de la vidéo n'a pas pu être lue." };
  }

  const details = asRecord(player.videoDetails);
  if (!details || typeof details.title !== "string") {
    return { status: "error", message: "La page de la vidéo n'a pas pu être lue." };
  }

  return {
    status: "ok",
    video: {
      id,
      title: details.title,
      author: typeof details.author === "string" ? details.author : "",
      thumbnailUrl: `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
      durationSeconds: Number.parseInt(String(details.lengthSeconds ?? "0"), 10) || 0,
      captions: captionTracks(player),
      captionsKnown: true,
    },
  };
}

export async function readYouTubeOnServer(
  url: string,
  languages: string[] = ["fr", "en"],
): Promise<{ status: "ok"; text: string; title: string } | { status: "error"; message: string }> {
  const preview = await previewYouTubeOnServer(url, languages[0] ?? "fr");
  if (preview.status !== "ok") return preview;

  if (preview.video.durationSeconds > MAX_DURATION_SECONDS) {
    return {
      status: "error",
      message: `Cette vidéo dure plus de 90 min.`,
    };
  }

  const text = await transcriptFromTracks(preview.video.captions, languages);
  if (text && text.length >= MIN_CAPTION_CHARS) {
    return { status: "ok", text, title: preview.video.title };
  }

  return {
    status: "error",
    message: "Cette vidéo n'a pas assez de sous-titres exploitables.",
  };
}

async function fetchPlayer(
  videoId: string,
  language: string,
): Promise<Record<string, unknown> | null> {
  try {
    const response = await fetch(
      `https://www.youtube.com/youtubei/v1/player?key=${INNERTUBE_KEY}&prettyPrint=false`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "User-Agent": IOS_UA,
          "X-YouTube-Client-Name": "5",
          "X-YouTube-Client-Version": "20.10.38",
        },
        body: JSON.stringify({
          videoId,
          contentCheckOk: true,
          racyCheckOk: true,
          context: {
            client: {
              clientName: "IOS",
              clientVersion: "20.10.38",
              deviceMake: "Apple",
              deviceModel: "iPhone16,2",
              osName: "iPhone",
              osVersion: "18.3.2.22D82",
              hl: language,
              gl: "FR",
            },
          },
        }),
      },
    );
    if (!response.ok) return null;
    const parsed = asRecord(await response.json());
    if (!parsed) return null;
    const status = asRecord(parsed.playabilityStatus);
    const playable = typeof status?.status === "string" ? status.status : "OK";
    if (playable !== "OK") return null;
    return asRecord(parsed.videoDetails) ? parsed : null;
  } catch {
    return null;
  }
}

function captionTracks(player: Record<string, unknown>): YouTubeCaption[] {
  const renderer = asRecord(asRecord(player.captions)?.playerCaptionsTracklistRenderer);
  const raw = Array.isArray(renderer?.captionTracks) ? renderer.captionTracks : [];
  const tracks: YouTubeCaption[] = [];

  for (const entry of raw) {
    const track = asRecord(entry);
    if (!track) continue;
    const baseUrl = typeof track.baseUrl === "string" ? track.baseUrl : "";
    const languageCode = typeof track.languageCode === "string" ? track.languageCode : "";
    if (!languageCode) continue;
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

async function transcriptFromTracks(
  tracks: YouTubeCaption[],
  languages: string[],
): Promise<string | null> {
  const ordered = [...tracks].sort((a, b) => {
    const rank = (track: YouTubeCaption) => {
      const index = languages.findIndex((language) => sameLanguage(track.code, language));
      const languageScore = index === -1 ? 50 : index;
      return languageScore * 2 + (track.isAutomatic ? 1 : 0);
    };
    return rank(a) - rank(b);
  });

  let longest = "";
  for (const track of ordered) {
    if (!track.baseUrl) continue;
    const text = await captionTextFromUrl(track.baseUrl);
    if (text && text.length >= MIN_CAPTION_CHARS) return text;
    if (text && text.length > longest.length) longest = text;
  }
  return longest.length > 0 ? longest : null;
}

async function captionTextFromUrl(baseUrl: string): Promise<string | null> {
  for (const format of ["json3", "srv3", "vtt"] as const) {
    const url = withCaptionFormat(baseUrl, format);
    try {
      const response = await fetch(url, { headers: { "User-Agent": IOS_UA } });
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
    return `${baseUrl}${baseUrl.includes("?") ? "&" : "?"}fmt=${format}`;
  }
}

function sameLanguage(a: string, b: string): boolean {
  return a.toLowerCase().split(/[-_]/)[0] === b.toLowerCase().split(/[-_]/)[0];
}

function looksLikeHtml(raw: string): boolean {
  const start = raw.slice(0, 240).trimStart().toLowerCase();
  return start.startsWith("<!doctype") || start.startsWith("<html");
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}
