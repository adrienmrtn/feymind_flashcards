import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  cleanTranscript,
  extractVideoId,
  parseCaptionXml,
  parseVtt,
  selectCaptionTrack,
  withCaptionFormat,
  type CaptionTrack,
} from "./youtube.ts";

describe("extractVideoId", () => {
  it("reconnaît les formes courantes", () => {
    assert.equal(extractVideoId("https://www.youtube.com/watch?v=dQw4w9WgXcQ"), "dQw4w9WgXcQ");
    assert.equal(extractVideoId("https://youtu.be/dQw4w9WgXcQ"), "dQw4w9WgXcQ");
    assert.equal(extractVideoId("https://www.youtube.com/shorts/dQw4w9WgXcQ"), "dQw4w9WgXcQ");
    assert.equal(extractVideoId("youtube.com/watch?v=dQw4w9WgXcQ&t=12s"), "dQw4w9WgXcQ");
  });

  it("refuse ce qui n'est pas une vidéo", () => {
    assert.equal(extractVideoId("https://www.youtube.com/@unechaine"), null);
    assert.equal(extractVideoId("https://vimeo.com/123"), null);
    assert.equal(extractVideoId("dQw4w9WgXcQ"), null);
  });
});

describe("withCaptionFormat", () => {
  it("remplace un fmt déjà présent, il ne s'ajoute pas", () => {
    const url = withCaptionFormat(
      "https://www.youtube.com/api/timedtext?v=abc&fmt=srv3&lang=en",
      "json3",
    );
    assert.match(url, /fmt=json3/);
    assert.doesNotMatch(url, /fmt=srv3/);
    assert.equal((url.match(/fmt=/g) ?? []).length, 1);
  });
});

describe("parseCaptionXml", () => {
  it("lit le XML historique", () => {
    const lines = parseCaptionXml(
      `<transcript><text start="0">Bonjour</text><text start="1">le monde</text></transcript>`,
    );
    assert.deepEqual(lines, ["Bonjour", "le monde"]);
  });

  it("lit le srv3 actuel, y compris les s imbriqués", () => {
    const lines = parseCaptionXml(
      `<?xml version="1.0"?><timedtext format="3"><body><p t="0">Nous</p><p t="1"><s>sommes </s><s>là</s></p></body></timedtext>`,
    );
    assert.deepEqual(lines, ["Nous", "sommes là"]);
  });

  it("ignore le HTML d'erreur de Google, qui a aussi des p", () => {
    const lines = parseCaptionXml(
      `<html><body><h1>We're sorry...</h1><p>... but your computer or network may be sending automated queries.</p></body></html>`,
    );
    assert.deepEqual(lines, []);
  });
});

describe("selectCaptionTrack", () => {
  const tracks: CaptionTrack[] = [
    {
      languageCode: "en",
      languageName: "English",
      isAutomatic: false,
      isDefault: true,
      baseUrl: "https://example.com/en",
    },
    {
      languageCode: "fr",
      languageName: "français",
      isAutomatic: true,
      isDefault: false,
      baseUrl: "https://example.com/fr",
    },
  ];

  it("préfère la langue demandée, même automatique", () => {
    assert.equal(selectCaptionTrack(tracks, ["fr"])?.languageCode, "fr");
  });
});

describe("parseVtt", () => {
  it("garde les phrases, jette les horodatages", () => {
    const lines = parseVtt(`WEBVTT
Kind: captions
Language: en

00:00:04.220 --> 00:00:05.400
This is a 3.

00:00:06.000 --> 00:00:08.000
A neural network.
`);
    assert.deepEqual(lines, ["This is a 3.", "A neural network."]);
  });
});

describe("cleanTranscript", () => {
  it("ôte les annotations sonores et les doublons", () => {
    assert.equal(
      cleanTranscript(["[Musique]", "Bonjour", "Bonjour", "le cours."]),
      "Bonjour le cours.",
    );
  });
});
