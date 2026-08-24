import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { closeOpenStructures, parseModelJSON, repairModelJSON } from "./json.ts";

describe("parseModelJSON", () => {
  it("lit un JSON déjà valide", () => {
    const course = parseModelJSON<{ title: string }>(`Voici :\n{"title": "Cours"}\n`);
    assert.equal(course.title, "Cours");
  });

  it("répare le deux-points manquant après un nom de propriété", () => {
    const broken = `{
      "title": "Cours",
      "sheet": {
        "blocks": [
          {
            "type" "paragraph",
            "text": "Le cycle de l'eau."
          }
        ]
      }
    }`;

    assert.throws(() => JSON.parse(broken), /property name/);

    const parsed = parseModelJSON<{
      sheet: { blocks: Array<{ type: string; text: string }> };
    }>(broken);
    assert.equal(parsed.sheet.blocks[0].type, "paragraph");
    assert.equal(parsed.sheet.blocks[0].text, "Le cycle de l'eau.");
  });

  it("répare une virgule oubliée entre deux propriétés", () => {
    const broken = `{
      "type": "paragraph"
      "text": "Bonjour"
    }`;

    const parsed = parseModelJSON<{ type: string; text: string }>(broken);
    assert.equal(parsed.type, "paragraph");
    assert.equal(parsed.text, "Bonjour");
  });

  it("répare une virgule finale", () => {
    const broken = `{
      "type": "paragraph",
      "text": "Bonjour",
    }`;

    const parsed = parseModelJSON<{ type: string; text: string }>(broken);
    assert.equal(parsed.text, "Bonjour");
  });

  it("répare une clé non quotée", () => {
    const broken = `{ type: "paragraph", "text": "Bonjour" }`;
    const parsed = parseModelJSON<{ type: string; text: string }>(broken);
    assert.equal(parsed.type, "paragraph");
  });

  it("échappe un antislash de LaTeX invalide", () => {
    const broken = `{ "latex": "\\alpha + \\beta" }`;
    assert.throws(() => JSON.parse(broken));
    const parsed = parseModelJSON<{ latex: string }>(broken);
    assert.match(parsed.latex, /alpha/);
  });

  it("échappe un guillemet à l'intérieur d'une phrase", () => {
    const broken = `{ "text": "Il dit "bonjour" à la classe" }`;
    const parsed = parseModelJSON<{ text: string }>(broken);
    assert.match(parsed.text, /bonjour/);
  });

  it("extrait le JSON d'une clôture markdown", () => {
    const parsed = parseModelJSON<{ title: string }>("```json\n{\"title\":\"Cours\"}\n```");
    assert.equal(parsed.title, "Cours");
  });

  it("répare une virgule oubliée entre deux éléments d'un tableau", () => {
    const broken = `{
      "sheet": {
        "blocks": [
          {"type": "paragraph", "text": "Premier paragraphe assez long pour rester."}
          {"type": "heading", "level": 1, "text": "Suite"}
        ]
      }
    }`;

    assert.throws(() => JSON.parse(broken), /array element|property value|Expected/);

    const parsed = parseModelJSON<{
      sheet: { blocks: Array<{ type: string }> };
    }>(broken);
    assert.equal(parsed.sheet.blocks.length, 2);
    assert.equal(parsed.sheet.blocks[1].type, "heading");
  });

  it("referme une fiche coupée au milieu du tableau de blocs", () => {
    const truncated = `{
      "title": "Le cycle de l'eau",
      "subject": "SVT",
      "summary": "L'eau circule.",
      "sheet": {
        "blocks": [
          {"type": "paragraph", "text": "L'eau change d'état sans jamais quitter la planète et c'est tout le sujet."},
          {"type": "heading", "level": 1, "text": "Trois temps"},
          {"type": "paragraph", "text": "L'évaporation précède la condensation, puis la précipitation referme la boucle."},
          {"type": "definition", "term": "Condensation", "text":`;

    assert.throws(() => JSON.parse(truncated));

    const parsed = parseModelJSON<{
      title: string;
      sheet: { blocks: Array<{ type: string }> };
    }>(truncated);
    assert.equal(parsed.title, "Le cycle de l'eau");
    assert.ok(parsed.sheet.blocks.length >= 3);
    assert.equal(parsed.sheet.blocks[0].type, "paragraph");
  });
});

describe("repairModelJSON", () => {
  it("ne casse pas un JSON déjà valide", () => {
    const source = `{"title":"Cours","sheet":{"blocks":[{"type":"paragraph","text":"Ok"}]}}`;
    assert.deepEqual(JSON.parse(repairModelJSON(source)), JSON.parse(source));
  });
});

describe("closeOpenStructures", () => {
  it("referme un tableau coupé sans jeter les blocs déjà écrits", () => {
    const truncated =
      `{"title":"Cours","sheet":{"blocks":[{"type":"paragraph","text":"Un paragraphe assez long."},{"type":"heading"`;
    const closed = closeOpenStructures(truncated);
    const parsed = JSON.parse(closed) as {
      title: string;
      sheet: { blocks: Array<{ type: string }> };
    };
    assert.equal(parsed.title, "Cours");
    assert.equal(parsed.sheet.blocks[0].type, "paragraph");
  });
});
