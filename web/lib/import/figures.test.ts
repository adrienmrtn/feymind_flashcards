import { describe, expect, it } from "vitest";
import { Image } from "imagescript";

import { attachFigureImages } from "./figures";

async function pageJpeg(): Promise<string> {
  const image = new Image(80, 40);
  image.fill(0xff0000ff);
  const jpeg = await image.encodeJPEG(80);
  return `data:image/jpeg;base64,${Buffer.from(jpeg).toString("base64")}`;
}

describe("attachFigureImages", () => {
  it("ne touche pas une fiche sans figure à recadrer", async () => {
    const blocks = await attachFigureImages(
      [{ type: "paragraph", text: "Le cycle de Krebs oxyde l'acétyl-CoA dans la matrice." }],
      [],
    );
    expect(blocks).toHaveLength(1);
    expect(blocks[0]?.type).toBe("paragraph");
  });

  it("recadre la page dans le bloc figure", async () => {
    const page = await pageJpeg();
    const blocks = await attachFigureImages(
      [
        { type: "paragraph", text: "Le cycle de Krebs oxyde l'acétyl-CoA dans la matrice." },
        {
          type: "figure",
          caption: "Solution et indicateurs de sécurité CI/CD",
          page: 1,
          crop: { x: 0, y: 0, w: 0.5, h: 1 },
        },
      ],
      [page],
    );
    const figure = blocks.find((block) => block.type === "figure");
    expect(figure?.type === "figure" ? figure.image : undefined).toMatch(/^data:image\/jpeg;base64,/);
    expect(figure?.type === "figure" ? (figure.image?.length ?? 0) : 0).toBeGreaterThan(32);
  });
});
