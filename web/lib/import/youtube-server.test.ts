import { describe, expect, it } from "vitest";

import { previewYouTubeOnServer, readYouTubeOnServer } from "./youtube-server";

/** Les appels réels à YouTube cassent en CI (IP de datacenter). En local, on les garde. */
const live = !process.env.CI;

describe.skipIf(!live)("previewYouTubeOnServer", () => {
  it("lit le titre et les pistes d'une vidéo connue", async () => {
    const result = await previewYouTubeOnServer(
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "en",
    );
    expect(result.status).toBe("ok");
    if (result.status !== "ok") return;
    expect(result.video.title.toLowerCase()).toContain("never gonna give you up");
    expect(result.video.captionsKnown).toBe(true);
    expect(result.video.captions.length).toBeGreaterThan(0);
  }, 20_000);
});

describe.skipIf(!live)("readYouTubeOnServer", () => {
  it("assemble assez de sous-titres pour en faire une fiche", async () => {
    const result = await readYouTubeOnServer(
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      ["en"],
    );
    expect(result.status).toBe("ok");
    if (result.status !== "ok") return;
    expect(result.text.length).toBeGreaterThan(400);
    expect(result.text.toLowerCase()).toContain("never");
  }, 20_000);
});
