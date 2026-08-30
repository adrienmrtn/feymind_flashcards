import { describe, expect, it } from "vitest";

import {
  cleanTranscript,
  extractVideoId,
  isYouTubeUrl,
  parseCaptionXml,
  parseJson3,
  parseVtt,
  youtubeBlockingReason,
  youtubeDurationLabel,
} from "./youtube";

describe("extractVideoId", () => {
  it("reconnaît les formes courantes", () => {
    expect(extractVideoId("https://www.youtube.com/watch?v=dQw4w9WgXcQ")).toBe("dQw4w9WgXcQ");
    expect(extractVideoId("https://youtu.be/dQw4w9WgXcQ")).toBe("dQw4w9WgXcQ");
    expect(extractVideoId("youtube.com/watch?v=dQw4w9WgXcQ&t=12s")).toBe("dQw4w9WgXcQ");
  });

  it("refuse ce qui n'est pas une vidéo", () => {
    expect(extractVideoId("https://www.youtube.com/@unechaine")).toBeNull();
    expect(extractVideoId("dQw4w9WgXcQ")).toBeNull();
    expect(isYouTubeUrl("https://vimeo.com/123")).toBe(false);
    expect(isYouTubeUrl("https://youtu.be/dQw4w9WgXcQ")).toBe(true);
  });
});

describe("youtubeBlockingReason", () => {
  const base = {
    id: "dQw4w9WgXcQ",
    title: "Test",
    author: "",
    thumbnailUrl: "",
    durationSeconds: 60,
    captions: [] as { code: string; name: string; isAutomatic: boolean }[],
  };

  it("n'interdit pas une vidéo dont on n'a pas encore lu les pistes", () => {
    expect(youtubeBlockingReason(base)).toBeNull();
  });

  it("interdit seulement quand les pistes ont été lues et sont vides", () => {
    expect(youtubeBlockingReason({ ...base, captionsKnown: true })).toBe(
      "Cette vidéo n'a pas de piste de sous-titres.",
    );
  });
});

describe("youtubeDurationLabel", () => {
  it("écrit les minutes, puis les heures", () => {
    expect(youtubeDurationLabel(0)).toBeNull();
    expect(youtubeDurationLabel(90)).toBe("1 min");
    expect(youtubeDurationLabel(3720)).toBe("1 h 02");
  });
});

describe("parseCaptionXml", () => {
  it("ignore le HTML d'erreur de Google", () => {
    expect(
      parseCaptionXml(
        `<html><body><p>... but your computer or network may be sending automated queries.</p></body></html>`,
      ),
    ).toEqual([]);
  });
});

describe("parseJson3", () => {
  it("assemble les segments et saute les aAppend", () => {
    const text = parseJson3(
      JSON.stringify({
        events: [
          { segs: [{ utf8: "Bonjour " }, { utf8: "le monde" }] },
          { aAppend: 1, segs: [{ utf8: "e" }] },
        ],
      }),
    );
    expect(text).toBe("Bonjour le monde");
  });
});

describe("parseVtt", () => {
  it("garde les phrases", () => {
    expect(
      parseVtt(`WEBVTT

00:00:01.000 --> 00:00:02.000
Une phrase.
`),
    ).toEqual(["Une phrase."]);
  });
});

describe("cleanTranscript", () => {
  it("ôte les annotations et les doublons", () => {
    expect(cleanTranscript(["[Musique]", "Bonjour", "Bonjour", "le cours."])).toBe(
      "Bonjour le cours.",
    );
  });
});
