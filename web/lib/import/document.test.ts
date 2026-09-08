import { describe, expect, it } from "vitest";

import {
  EmptyFileError,
  decodeDocumentText,
  documentKind,
  looksLikeText,
  readFileBytes,
  readPdfPageText,
  type PdfTextPage,
} from "./document";

/**
 * Le flux de pdf.js **sans** `Symbol.asyncIterator`, comme dans WebKit.
 *
 * C'est tout le sujet du fichier : `page.getTextContent()` de pdf.js parcourt ce flux avec
 * `for await`, ce que Safari ne sait pas faire, et l'import d'un PDF s'arrêtait là sur
 * iPhone. Un flux privé de cette méthode reproduit la panne sous vitest.
 */
function webkitStream(chunks: unknown[]): ReadableStream<{ items: unknown[] }> {
  const stream = new ReadableStream<{ items: unknown[] }>({
    start(controller) {
      for (const chunk of chunks) controller.enqueue({ items: [chunk] });
      controller.close();
    },
  });
  Object.defineProperty(stream, Symbol.asyncIterator, { value: undefined });
  return stream;
}

describe("readPdfPageText", () => {
  it("lit le texte d'une page sur un flux que Safari ne sait pas parcourir", async () => {
    const page: PdfTextPage = {
      streamTextContent: () => webkitStream([{ str: "Les" }, { str: "fonctions" }, { str: "affines" }]),
      getTextContent: () => {
        throw new TypeError("iterable should have an iterator symbol");
      },
    };

    await expect(readPdfPageText(page)).resolves.toBe("Les fonctions affines");
  });

  it("ignore les éléments de balisage, qui n'ont pas de texte", async () => {
    const page: PdfTextPage = {
      streamTextContent: () =>
        webkitStream([{ str: "Chapitre 1" }, { type: "beginMarkedContent", id: "p1" }, { str: "la cellule" }]),
    };

    await expect(readPdfPageText(page)).resolves.toBe("Chapitre 1 la cellule");
  });

  it("resserre les espaces comme le faisait l'écran d'import", async () => {
    const page: PdfTextPage = {
      streamTextContent: () => webkitStream([{ str: "  deux \n\n mots  " }]),
    };

    await expect(readPdfPageText(page)).resolves.toBe("deux mots");
  });

  it("se replie sur getTextContent quand la page n'offre pas de flux", async () => {
    const page: PdfTextPage = {
      getTextContent: async () => ({ items: [{ str: "Une seule" }, { str: "page" }] }),
    };

    await expect(readPdfPageText(page)).resolves.toBe("Une seule page");
  });
});

describe("documentKind", () => {
  it("reconnaît un PDF à ses octets, même sans extension", () => {
    const pdf = new TextEncoder().encode("%PDF-1.7\n1 0 obj\n");
    expect(documentKind(pdf, "cours")).toBe("pdf");
    expect(documentKind(pdf, "cours.txt")).toBe("pdf");
  });

  it("tolère les octets qui précèdent l'en-tête d'un PDF", () => {
    const pdf = new Uint8Array([0x0a, 0x0d, ...new TextEncoder().encode("%PDF-1.4")]);
    expect(documentKind(pdf, "")).toBe("pdf");
  });

  it("reconnaît un Word à l'entrée word/document.xml du ZIP", () => {
    expect(documentKind(storedZip({ "word/document.xml": "<w/>" }), "cours")).toBe("docx");
  });

  it("ne prend pas un autre ZIP pour un Word", () => {
    expect(documentKind(storedZip({ "collection.anki2": "sqlite" }), "paquet")).toBe("text");
  });

  it("reconnaît une photo, que le sélecteur de l'iPhone propose en premier", () => {
    expect(documentKind(new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]), "image.jpg")).toBe("image");
    expect(documentKind(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), "")).toBe("image");
    const heic = new Uint8Array(16);
    heic.set([...new TextEncoder().encode("ftypheic")], 4);
    expect(documentKind(heic, "IMG_0042.HEIC")).toBe("image");
  });

  it("reconnaît un .doc d'avant 2007 à sa signature OLE", () => {
    const ole = new Uint8Array([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1, 0x00, 0x00]);
    expect(documentKind(ole, "memoire")).toBe("legacyDoc");
  });

  it("garde le nom comme dernier indice", () => {
    const truncated = new TextEncoder().encode("ceci n'est pas un en-tête");
    expect(documentKind(truncated, "cours.pdf")).toBe("pdf");
    expect(documentKind(truncated, "cours.docx")).toBe("docx");
    expect(documentKind(truncated, "cours.doc")).toBe("legacyDoc");
    expect(documentKind(truncated, "notes.md")).toBe("text");
  });
});

describe("decodeDocumentText", () => {
  it("retire la marque d'ordre d'un UTF-8", () => {
    const bytes = new Uint8Array([0xef, 0xbb, 0xbf, ...new TextEncoder().encode("Le théorème")]);
    expect(decodeDocumentText(bytes)).toBe("Le théorème");
  });

  it("lit un texte UTF-16 exporté par Word, avec sa marque", () => {
    const text = "La mitose en quatre phases";
    const bytes = new Uint8Array(2 + text.length * 2);
    bytes[0] = 0xff;
    bytes[1] = 0xfe;
    for (let index = 0; index < text.length; index += 1) {
      bytes[2 + index * 2] = text.charCodeAt(index) & 0xff;
      bytes[3 + index * 2] = text.charCodeAt(index) >> 8;
    }
    expect(decodeDocumentText(bytes)).toBe(text);
  });

  it("lit un UTF-16 sans marque, qu'un décodage UTF-8 aurait rendu illisible", () => {
    const text = "Un octet nul sur deux, et pas de marque d'ordre au début";
    const bytes = new Uint8Array(text.length * 2);
    for (let index = 0; index < text.length; index += 1) {
      bytes[index * 2] = text.charCodeAt(index) & 0xff;
      bytes[index * 2 + 1] = 0;
    }
    expect(decodeDocumentText(bytes)).toBe(text);
  });

  it("normalise les fins de ligne de Windows", () => {
    expect(decodeDocumentText(new TextEncoder().encode("une\r\ndeux\rtrois"))).toBe("une\ndeux\ntrois");
  });
});

describe("looksLikeText", () => {
  it("accepte un cours, ses accents et ses retours à la ligne", () => {
    expect(looksLikeText("Le théorème de Thalès\n\ts'écrit ainsi :\r\nAB/AC = AD/AE")).toBe(true);
  });

  it("refuse un binaire que le décodeur a rendu lisible de force", () => {
    const binary = new Uint8Array(400);
    for (let index = 0; index < binary.length; index += 1) binary[index] = 0x80 + (index % 60);
    expect(looksLikeText(decodeDocumentText(binary))).toBe(false);
  });

  it("refuse un fichier sans rien", () => {
    expect(looksLikeText("")).toBe(false);
  });
});

describe("readFileBytes", () => {
  it("lit les octets du fichier", async () => {
    const bytes = await readFileBytes(new Blob([new Uint8Array([1, 2, 3])]));
    expect([...bytes]).toEqual([1, 2, 3]);
  });

  it("refuse un fichier qui se lit vide, plutôt que de l'accuser d'être sans texte", async () => {
    await expect(readFileBytes(new Blob([]))).rejects.toBeInstanceOf(EmptyFileError);
  });

  it("relit par FileReader quand arrayBuffer lâche, comme sur un fichier iCloud", async () => {
    const payload = new Uint8Array([0x25, 0x50, 0x44, 0x46]);
    const file = {
      arrayBuffer: async () => {
        throw new DOMException("The operation is not supported.", "NotReadableError");
      },
    } as unknown as Blob;

    const readers: unknown[] = [];
    const original = globalThis.FileReader;
    class StubFileReader {
      result: ArrayBuffer | null = null;
      onload: (() => void) | null = null;
      onerror: (() => void) | null = null;
      readAsArrayBuffer() {
        this.result = payload.slice().buffer;
        readers.push(this);
        this.onload?.();
      }
    }
    globalThis.FileReader = StubFileReader as unknown as typeof FileReader;

    try {
      const bytes = await readFileBytes(file);
      expect([...bytes]).toEqual([...payload]);
      expect(readers).toHaveLength(1);
    } finally {
      globalThis.FileReader = original;
    }
  });
});

function storedZip(files: Record<string, string>): Uint8Array {
  const encoder = new TextEncoder();
  const locals: Uint8Array[] = [];
  const centrals: Uint8Array[] = [];
  let offset = 0;

  for (const [name, content] of Object.entries(files)) {
    const nameBytes = encoder.encode(name);
    const data = encoder.encode(content);
    const local = new Uint8Array(30 + nameBytes.length + data.length);
    writeU32(local, 0, 0x04034b50);
    writeU16(local, 26, nameBytes.length);
    writeU32(local, 18, data.length);
    writeU32(local, 22, data.length);
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
