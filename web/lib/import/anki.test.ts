import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { zstdCompressSync } from "node:zlib";

import { afterAll, describe, expect, it } from "vitest";

import {
  AnkiError,
  cleanField,
  clozeCard,
  clozeOrdinals,
  isAnkiFileName,
  notesToCards,
  readAnkiPackage,
  readAnkiTextExport,
} from "./anki";

/**
 * Les bases de test sont écrites par **le vrai SQLite**, celui de Node, et pas par un
 * générateur d'octets écrit à côté du lecteur. C'est tout l'intérêt : un lecteur de format
 * validé contre sa propre idée du format ne prouve rien.
 */

const temporary = mkdtempSync(join(tmpdir(), "micabo-anki-"));
afterAll(() => rmSync(temporary, { recursive: true, force: true }));

/** Le schéma d'avant Anki 2.1.28 : les paquets vivent dans un JSON de la table `col`. */
function legacyCollection(
  notes: { id: number; fields: string[]; deckId: number }[],
  decks: Record<number, string>,
): Uint8Array {
  const path = join(temporary, `legacy-${Math.random().toString(36).slice(2)}.anki2`);
  const database = new DatabaseSync(path);

  database.exec(`
    create table col (
      id integer primary key, crt integer not null, mod integer not null,
      conf text not null, models text not null, decks text not null
    );
    create table notes (
      id integer primary key, guid text not null, mid integer not null, mod integer not null,
      usn integer not null, tags text not null, flds text not null, sfld integer not null,
      csum integer not null, flags integer not null, data text not null
    );
    create table cards (
      id integer primary key, nid integer not null, did integer not null, ord integer not null,
      mod integer not null, usn integer not null, type integer not null, queue integer not null,
      due integer not null, ivl integer not null, factor integer not null, reps integer not null,
      lapses integer not null, left integer not null, odue integer not null, odid integer not null,
      flags integer not null, data text not null
    );
  `);

  const shape = Object.fromEntries(
    Object.entries(decks).map(([id, name]) => [id, { id: Number(id), name }]),
  );
  database
    .prepare("insert into col values (1, 0, 0, '{}', '{}', ?)")
    .run(JSON.stringify(shape));

  const note = database.prepare(
    "insert into notes values (?, ?, 1, 0, 0, ?, ?, 0, 0, 0, '')",
  );
  const card = database.prepare(
    "insert into cards values (?, ?, ?, 0, 0, 0, 0, 0, 0, 0, 2500, 0, 0, 0, 0, 0, 0, '')",
  );

  notes.forEach((entry, index) => {
    note.run(entry.id, `guid-${entry.id}`, "vocabulaire marque", entry.fields.join("\u001f"));
    card.run(9_000 + index, entry.id, entry.deckId);
  });

  database.close();
  return new Uint8Array(readFileSync(path));
}

/** Le schéma moderne : les paquets ont leur table, et le nom emboîte au caractère 0x1f. */
function modernCollection(
  notes: { id: number; fields: string[]; deckId: number }[],
  decks: Record<number, string>,
): Uint8Array {
  const path = join(temporary, `modern-${Math.random().toString(36).slice(2)}.anki21`);
  const database = new DatabaseSync(path);

  database.exec(`
    create table col (
      id integer primary key, crt integer not null, mod integer not null,
      conf text not null, models text not null, decks text not null
    );
    create table decks (
      id integer primary key not null, name text not null, mtime_secs integer not null,
      usn integer not null, common blob not null, kind blob not null
    );
    create table notes (
      id integer primary key, guid text not null, mid integer not null, mod integer not null,
      usn integer not null, tags text not null, flds text not null, sfld integer not null,
      csum integer not null, flags integer not null, data text not null
    );
    create table cards (
      id integer primary key, nid integer not null, did integer not null, ord integer not null,
      mod integer not null, usn integer not null, type integer not null, queue integer not null,
      due integer not null, ivl integer not null, factor integer not null, reps integer not null,
      lapses integer not null, left integer not null, odue integer not null, odid integer not null,
      flags integer not null, data text not null
    );
  `);

  database.prepare("insert into col values (1, 0, 0, '{}', '{}', '{}')").run();

  const deck = database.prepare("insert into decks values (?, ?, 0, 0, x'', x'')");
  for (const [id, name] of Object.entries(decks)) deck.run(Number(id), name);

  const note = database.prepare("insert into notes values (?, ?, 1, 0, 0, '', ?, 0, 0, 0, '')");
  const card = database.prepare(
    "insert into cards values (?, ?, ?, 0, 0, 0, 0, 0, 0, 0, 2500, 0, 0, 0, 0, ?, 0, '')",
  );

  notes.forEach((entry, index) => {
    note.run(entry.id, `guid-${entry.id}`, entry.fields.join("\u001f"));
    card.run(9_000 + index, entry.id, entry.deckId, 0);
  });

  database.close();
  return new Uint8Array(readFileSync(path));
}

describe("readAnkiPackage", () => {
  it("lit un .apkg à l'ancien schéma, paquets compris", async () => {
    const collection = legacyCollection(
      [
        { id: 1_700_000_000_001, fields: ["<b>der Hund</b>", "le chien"], deckId: 5 },
        { id: 1_700_000_000_002, fields: ["die Katze", "le chat"], deckId: 7 },
      ],
      { 5: "Allemand", 7: "Allemand\u001fAnimaux" },
    );

    const parsed = await readAnkiPackage(
      apkg({ "collection.anki2": collection }),
      "Allemand L1.apkg",
    );

    expect(parsed.cards).toHaveLength(2);
    expect(parsed.cards[0]).toMatchObject({
      kind: "basic",
      front: "der Hund",
      back: "le chien",
      deck: "Allemand",
    });
    expect(parsed.cards[0]!.tags).toEqual(["vocabulaire", "marque"]);
    expect(parsed.cards[1]!.deck).toBe("Allemand::Animaux");
    // Deux paquets : le titre proposé reste celui du fichier.
    expect(parsed.title).toBe("Allemand L1");
    expect(parsed.decks.map((deck) => deck.name).sort()).toEqual([
      "Allemand",
      "Allemand::Animaux",
    ]);
  });

  it("lit un .apkg moderne, compressé en zstd", async () => {
    const collection = modernCollection(
      [{ id: 1_700_000_000_003, fields: ["Capitale du Pérou", "Lima"], deckId: 3 }],
      { 3: "Géographie" },
    );

    const parsed = await readAnkiPackage(
      apkg({ "collection.anki21b": new Uint8Array(zstdCompressSync(collection)) }),
      "export.apkg",
    );

    expect(parsed.cards).toHaveLength(1);
    expect(parsed.cards[0]).toMatchObject({ front: "Capitale du Pérou", back: "Lima" });
    // Un seul paquet : c'est son nom qui est proposé, pas celui du fichier.
    expect(parsed.title).toBe("Géographie");
  });

  it("préfère la collection récente quand l'archive porte les deux", async () => {
    const parsed = await readAnkiPackage(
      apkg({
        "collection.anki2": legacyCollection(
          [{ id: 1, fields: ["vieux", "rétrogradé"], deckId: 1 }],
          { 1: "Ancien" },
        ),
        "collection.anki21": modernCollection(
          [{ id: 2, fields: ["neuf", "à jour"], deckId: 1 }],
          { 1: "Récent" },
        ),
      }),
      "deux.apkg",
    );

    expect(parsed.cards[0]!.front).toBe("neuf");
    expect(parsed.title).toBe("Récent");
  });

  it("recoud un champ qui déborde sa page", async () => {
    const long = "Une phrase de cours qui se répète. ".repeat(400);
    const parsed = await readAnkiPackage(
      apkg({
        "collection.anki2": legacyCollection(
          [{ id: 4, fields: ["Le résumé du chapitre", long], deckId: 1 }],
          { 1: "Histoire" },
        ),
      }),
      "histoire.apkg",
    );

    expect(parsed.cards[0]!.back.length).toBeGreaterThan(1_500);
    expect(parsed.cards[0]!.back.endsWith("…")).toBe(true);
  });

  it("écarte les notes qui n'ont qu'une image, et les compte", async () => {
    const parsed = await readAnkiPackage(
      apkg({
        "collection.anki2": legacyCollection(
          [
            { id: 5, fields: ['<img src="paste-1.jpg">', ""], deckId: 1 },
            { id: 6, fields: ["Théorème de Thalès", "Rapports égaux"], deckId: 1 },
          ],
          { 1: "Maths" },
        ),
      }),
      "maths.apkg",
    );

    expect(parsed.cards).toHaveLength(1);
    expect(parsed.skipped).toBe(1);
  });

  it("refuse une archive sans collection", async () => {
    await expect(
      readAnkiPackage(apkg({ "media": new TextEncoder().encode("{}") }), "vide.apkg"),
    ).rejects.toMatchObject({ code: "noCollection" });
  });

  it("refuse des octets qui ne sont ni une archive ni une base", async () => {
    await expect(
      readAnkiPackage(new TextEncoder().encode("pas un paquet"), "x.apkg"),
    ).rejects.toBeInstanceOf(AnkiError);
  });
});

describe("notesToCards", () => {
  it("fait une carte par trou, les autres découverts", () => {
    const cards = notesToCards(
      ["La {{c1::mitochondrie}} produit l'{{c2::ATP}} de la cellule.", "Cours de SVT"],
      "Bio",
      [],
    );

    expect(cards).toHaveLength(2);
    expect(cards[0]).toMatchObject({
      kind: "cloze",
      front: "La … produit l'ATP de la cellule.",
      back: "mitochondrie",
      hint: "Cours de SVT",
    });
    expect(cards[1]!.front).toBe("La mitochondrie produit l'… de la cellule.");
    expect(cards[1]!.back).toBe("ATP");
  });

  it("prend l'indice écrit dans le trou plutôt que le champ voisin", () => {
    const [card] = notesToCards(["Capitale : {{c1::Oslo::pays nordique}}"], "Géo", []);
    expect(card).toMatchObject({ back: "Oslo", hint: "pays nordique" });
  });

  it("met les champs suivants au verso, pas dans six cartes", () => {
    const cards = notesToCards(["Osmose", "Passage du solvant", "Sans énergie"], "Bio", ["svt"]);
    expect(cards).toHaveLength(1);
    expect(cards[0]!.back).toBe("Passage du solvant\n\nSans énergie");
    expect(cards[0]!.tags).toEqual(["svt"]);
  });

  it("écarte une note sans verso", () => {
    expect(notesToCards(["Une question seule", ""], "Bio", [])).toEqual([]);
  });
});

describe("clozeCard", () => {
  it("réunit deux occurrences du même numéro", () => {
    const card = clozeCard("{{c1::Rome}} et {{c1::Rome}} et {{c2::Athènes}}", 1);
    expect(card).toMatchObject({ front: "… et … et Athènes", back: "Rome" });
  });

  it("rend les numéros dans l'ordre, sans doublon", () => {
    expect(clozeOrdinals("{{c3::a}} {{c1::b}} {{c3::c}}")).toEqual([1, 3]);
  });
});

describe("cleanField", () => {
  it("rend du texte lisible d'un champ HTML", () => {
    expect(cleanField("<div>Premier</div><div>Second</div>")).toBe("Premier\nSecond");
    expect(cleanField("a<br>b")).toBe("a\nb");
    expect(cleanField("Deux&nbsp;mots &amp; un &#39;autre&#39;")).toBe("Deux mots & un 'autre'");
  });

  it("retire les médias, qui ne sont pas importés", () => {
    expect(cleanField('Le cri <img src="a.png"> [sound:b.mp3]')).toBe("Le cri");
  });

  it("réécrit les formules dans la graphie de Micabo", () => {
    expect(cleanField("[latex]\\frac{a}{b}[/latex]")).toBe("$\\frac{a}{b}$");
    expect(cleanField("[$]x^2[/$]")).toBe("$x^2$");
    expect(cleanField("\\(e^{i\\pi}\\)")).toBe("$e^{i\\pi}$");
  });
});

describe("readAnkiTextExport", () => {
  it("lit un export en texte, séparateur et colonnes déclarés", () => {
    const parsed = readAnkiTextExport(
      [
        "#separator:tab",
        "#html:true",
        "#deck column:3",
        "#tags column:4",
        "der Baum\tl'arbre\tAllemand\tnature flore",
        "die Blume\tla fleur\tAllemand\t",
        "",
      ].join("\n"),
      "notes.txt",
    );

    expect(parsed.cards).toHaveLength(2);
    expect(parsed.cards[0]).toMatchObject({
      front: "der Baum",
      back: "l'arbre",
      deck: "Allemand",
    });
    expect(parsed.cards[0]!.tags).toEqual(["nature", "flore"]);
    expect(parsed.title).toBe("Allemand");
  });

  it("retombe sur la tabulation quand rien n'est déclaré", () => {
    const parsed = readAnkiTextExport("Ubi sunt\tOù sont-ils", "latin.txt");
    expect(parsed.cards[0]!.back).toBe("Où sont-ils");
    expect(parsed.cards[0]!.deck).toBe("latin");
  });

  it("devine la virgule quand un tableur a mangé l'en-tête", () => {
    const parsed = readAnkiTextExport(
      ["mitose,division d'une cellule", "méiose,division des gamètes"].join("\n"),
      "svt.csv",
    );
    expect(parsed.cards).toHaveLength(2);
    expect(parsed.cards[0]).toMatchObject({ front: "mitose", back: "division d'une cellule" });
  });

  it("refuse un fichier dont aucune ligne ne fait une carte", () => {
    expect(() => readAnkiTextExport("#separator:tab\nune colonne seule\n")).toThrow(AnkiError);
  });
});

describe("isAnkiFileName", () => {
  it("reconnaît les extensions d'Anki, et seulement elles", () => {
    expect(isAnkiFileName("Allemand.apkg")).toBe(true);
    expect(isAnkiFileName("sauvegarde.colpkg")).toBe(true);
    expect(isAnkiFileName("collection.anki21b")).toBe(true);
    expect(isAnkiFileName("cours.pdf")).toBe(false);
  });
});

/** Une archive « stockée » : Anki n'en produit pas d'autre pour la collection compressée. */
function apkg(files: Record<string, Uint8Array>): Uint8Array {
  const encoder = new TextEncoder();
  const locals: Uint8Array[] = [];
  const centrals: Uint8Array[] = [];
  let offset = 0;

  for (const [name, data] of Object.entries(files)) {
    const nameBytes = encoder.encode(name);
    const local = new Uint8Array(30 + nameBytes.length + data.length);
    writeU32(local, 0, 0x04034b50);
    writeU32(local, 18, data.length);
    writeU32(local, 22, data.length);
    writeU16(local, 26, nameBytes.length);
    local.set(nameBytes, 30);
    local.set(data, 30 + nameBytes.length);
    locals.push(local);

    const central = new Uint8Array(46 + nameBytes.length);
    writeU32(central, 0, 0x02014b50);
    writeU32(central, 20, data.length);
    writeU32(central, 24, data.length);
    writeU16(central, 28, nameBytes.length);
    writeU32(central, 42, offset);
    central.set(nameBytes, 46);
    centrals.push(central);
    offset += local.length;
  }

  const centralSize = centrals.reduce((sum, part) => sum + part.length, 0);
  const eocd = new Uint8Array(22);
  writeU32(eocd, 0, 0x06054b50);
  writeU16(eocd, 8, locals.length);
  writeU16(eocd, 10, locals.length);
  writeU32(eocd, 12, centralSize);
  writeU32(eocd, 16, offset);

  const out = new Uint8Array(offset + centralSize + 22);
  let at = 0;
  for (const part of [...locals, ...centrals, eocd]) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

function writeU16(target: Uint8Array, offset: number, value: number) {
  target[offset] = value & 0xff;
  target[offset + 1] = (value >> 8) & 0xff;
}

function writeU32(target: Uint8Array, offset: number, value: number) {
  target[offset] = value & 0xff;
  target[offset + 1] = (value >> 8) & 0xff;
  target[offset + 2] = (value >> 16) & 0xff;
  target[offset + 3] = (value >> 24) & 0xff;
}
