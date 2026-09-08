import { describe, expect, it } from "vitest";

import { DocxError } from "./docx";
import {
  ReadFailure,
  classifyReadFailure,
  decodeText,
  documentKind,
  failureDetail,
  looksBinary,
  readDocument,
  refusedKind,
  sniffKind,
  type PdfEngine,
} from "./read-document";

function file(name: string, content: string | Uint8Array): File {
  const part = typeof content === "string" ? content : (content as unknown as BlobPart);
  return new File([part], name);
}

/** Un pdf.js de comédie : on veut essayer la lecture, pas pdf.js. */
function fakePdf(pages: string[], fail?: { name: string; message?: string }): PdfEngine {
  return {
    getDocument() {
      return {
        promise: (async () => {
          if (fail) {
            const error = new Error(fail.message ?? fail.name);
            error.name = fail.name;
            throw error;
          }
          return {
            numPages: pages.length,
            async getPage(index: number) {
              const body = pages[index - 1] ?? "";
              return {
                getTextContent: async () => ({ items: body.split(" ").map((str) => ({ str })) }),
                getViewport: () => ({ width: 100, height: 100 }),
                render: () => ({ promise: Promise.resolve() }),
              } as never;
            },
          };
        })(),
      };
    },
  };
}

/**
 * Le pdf.js de WebKit : ses pages n'offrent que le flux, et ce flux n'a pas
 * `Symbol.asyncIterator`. `getTextContent` lève, comme sur un iPhone, pour qu'un retour à
 * cette méthode se voie tout de suite ici.
 */
function webkitPdf(pages: string[]): PdfEngine {
  return {
    getDocument() {
      return {
        promise: Promise.resolve({
          numPages: pages.length,
          async getPage(index: number) {
            const body = pages[index - 1] ?? "";
            return {
              streamTextContent() {
                const stream = new ReadableStream({
                  start(controller) {
                    controller.enqueue({ items: body.split(" ").map((str) => ({ str })) });
                    controller.close();
                  },
                });
                Object.defineProperty(stream, Symbol.asyncIterator, { value: undefined });
                return stream;
              },
              getTextContent: async () => {
                throw new TypeError("iterable should have an iterator symbol");
              },
              getViewport: () => ({ width: 100, height: 100 }),
              render: () => ({ promise: Promise.resolve() }),
            } as never;
          },
        }),
      };
    },
  };
}

/** Un PDF qui s'ouvre, et dont aucune page ne se laisse lire. */
function brokenPagesPdf(error: Error): PdfEngine {
  return {
    getDocument() {
      return {
        promise: Promise.resolve({
          numPages: 3,
          async getPage() {
            throw error;
          },
        }),
      };
    },
  };
}

describe("documentKind", () => {
  it("reconnaît les trois formats qu'on lit", () => {
    expect(documentKind("cours.pdf")).toBe("pdf");
    expect(documentKind("COURS.PDF")).toBe("pdf");
    expect(documentKind("notes.docx")).toBe("docx");
    expect(documentKind("notes.txt")).toBe("text");
    expect(documentKind("notes.md")).toBe("text");
  });

  it("ne tranche pas sur une extension inconnue", () => {
    expect(documentKind("memoire.tex")).toBeNull();
    expect(documentKind("sans-extension")).toBeNull();
  });
});

describe("refusedKind", () => {
  it("nomme les formats qu'on sait refuser", () => {
    for (const name of ["diapos.pptx", "tableau.xlsx", "photo.HEIC", "cours.odt", "notes.rtf"]) {
      expect(refusedKind(name)).toBe("unsupported");
    }
  });

  it("distingue l'ancien Word", () => {
    expect(refusedKind("cours.doc")).toBe("legacyWord");
    expect(refusedKind("cours.docx")).toBeNull();
  });

  it("laisse passer ce qu'on lit", () => {
    expect(refusedKind("cours.pdf")).toBeNull();
    expect(refusedKind("cours.txt")).toBeNull();
  });
});

describe("looksBinary", () => {
  it("accepte du vrai texte, accents et ponctuation compris", () => {
    expect(looksBinary("Le système nerveux central comprend l'encéphale.\n\tEt la moelle.")).toBe(
      false,
    );
    expect(looksBinary("")).toBe(false);
  });

  it("refuse un octet nul", () => {
    expect(looksBinary("cours\u0000binaire")).toBe(true);
  });

  it("refuse une chaîne criblée de caractères de remplacement", () => {
    expect(looksBinary(`PK\u0003\u0004${"\ufffd".repeat(200)}`)).toBe(true);
  });

  it("tolère un caractère de remplacement isolé dans une longue page", () => {
    expect(looksBinary(`${"Le cours de biologie cellulaire. ".repeat(40)}\ufffd`)).toBe(false);
  });
});

describe("classifyReadFailure", () => {
  it("traduit les exceptions de pdf.js", () => {
    expect(classifyReadFailure(named("PasswordException"))).toBe("locked");
    expect(classifyReadFailure(named("InvalidPDFException"))).toBe("damaged");
    expect(classifyReadFailure(named("MissingPDFException"))).toBe("unreachable");
  });

  it("traduit un fichier hors de portée du navigateur", () => {
    expect(classifyReadFailure(named("NotReadableError"))).toBe("unreachable");
    expect(classifyReadFailure(named("NotFoundError"))).toBe("unreachable");
  });

  it("reconnaît un module qui n'a pas pu être chargé", () => {
    expect(
      classifyReadFailure(new Error("Failed to fetch dynamically imported module: /_next/x.js")),
    ).toBe("engine");
    expect(classifyReadFailure(new Error("Loading chunk 42 failed."))).toBe("engine");
  });

  it("reprend les codes de Word", () => {
    expect(classifyReadFailure(new DocxError("empty"))).toBe("wordEmpty");
    expect(classifyReadFailure(new DocxError("missingDocument"))).toBe("wordUnreadable");
    expect(classifyReadFailure(new DocxError("notDocx"))).toBe("unsupported");
  });

  it("garde son propre code", () => {
    expect(classifyReadFailure(new ReadFailure("locked"))).toBe("locked");
  });

  it("ne prétend rien quand il ne sait pas", () => {
    expect(classifyReadFailure(new Error("boom"))).toBe("unknown");
    expect(classifyReadFailure("boom")).toBe("unknown");
  });
});

describe("failureDetail", () => {
  it("rend de quoi écrire un rapport", () => {
    expect(failureDetail(named("PasswordException", "No password given"))).toBe(
      "PasswordException: No password given",
    );
  });

  it("ne rend rien pour un échec sans détail", () => {
    expect(failureDetail(new ReadFailure("empty"))).toBeUndefined();
  });
});

describe("readDocument", () => {
  it("lit un fichier texte", async () => {
    const read = await readDocument(file("cours.txt", "Le cours de géographie physique."));
    expect(read.kind).toBe("text");
    expect(read.text).toContain("géographie");
  });

  it("refuse un format nommé, sans lire les octets", async () => {
    await expect(readDocument(file("diapos.pptx", "PK\u0003\u0004"))).rejects.toMatchObject({
      code: "unsupported",
    });
  });

  it("refuse l'ancien Word", async () => {
    await expect(readDocument(file("cours.doc", "binaire"))).rejects.toMatchObject({
      code: "legacyWord",
    });
  });

  /** Le bug qui envoyait des octets de ZIP au modèle comme s'ils étaient un cours. */
  it("refuse un binaire déguisé en extension inconnue", async () => {
    const junk = `PK\u0003\u0004${"\ufffd".repeat(400)}`;
    await expect(readDocument(file("cours.inconnu", junk))).rejects.toMatchObject({
      code: "unsupported",
    });
  });

  it("laisse passer une extension inconnue qui est vraiment du texte", async () => {
    const read = await readDocument(file("memoire.tex", "\\section{Les fonctions affines}"));
    expect(read.kind).toBe("text");
    expect(read.text).toContain("fonctions affines");
  });

  it("lit le texte d'un PDF", async () => {
    const read = await readDocument(
      file("cours.pdf", "%PDF-1.4"),
      async () => fakePdf(["La photosynthèse convertit la lumière", "en énergie chimique"]),
    );
    expect(read.kind).toBe("pdf");
    expect(read.text).toContain("photosynthèse");
    expect(read.text).toContain("énergie chimique");
  });

  it("nomme un PDF verrouillé", async () => {
    await expect(
      readDocument(file("cours.pdf", "%PDF"), async () =>
        fakePdf([], { name: "PasswordException" }),
      ),
    ).rejects.toMatchObject({ code: "locked" });
  });

  it("nomme un PDF cassé", async () => {
    await expect(
      readDocument(file("cours.pdf", "%PDF"), async () =>
        fakePdf([], { name: "InvalidPDFException", message: "Invalid PDF structure." }),
      ),
    ).rejects.toMatchObject({ code: "damaged" });
  });

  it("nomme un moteur qui ne se charge pas", async () => {
    await expect(
      readDocument(file("cours.pdf", "%PDF"), async () => {
        throw new Error("Failed to fetch dynamically imported module");
      }),
    ).rejects.toMatchObject({ code: "engine" });
  });

  it("signale un PDF sans rien à lire", async () => {
    await expect(
      readDocument(file("cours.pdf", "%PDF"), async () => fakePdf([""])),
    ).rejects.toMatchObject({ code: "empty" });
  });

  /**
   * La panne de Safari, celle qui perdait chaque document sur le site ouvert à l'iPhone :
   * les pages de pdf.js n'offrent qu'un flux que `for await` ne sait pas parcourir dans
   * WebKit. La lecture doit passer par le `reader`, et `getTextContent` ne doit pas servir.
   */
  it("lit un PDF dont les pages ne se parcourent pas avec for await", async () => {
    const read = await readDocument(file("cours.pdf", "%PDF"), async () =>
      webkitPdf(["La mitose", "en quatre phases"]),
    );
    expect(read.kind).toBe("pdf");
    expect(read.text).toContain("La mitose");
    expect(read.text).toContain("en quatre phases");
  });

  it("nomme la panne quand aucune page n'a pu être lue, au lieu de dire « pas de texte »", async () => {
    await expect(
      readDocument(file("cours.pdf", "%PDF"), async () => brokenPagesPdf(named("NotReadableError"))),
    ).rejects.toMatchObject({ code: "unreachable" });
  });

  it("reconnaît un PDF que l'iPhone livre sans extension", async () => {
    const read = await readDocument(file("cours", "%PDF-1.7"), async () =>
      fakePdf(["Le théorème de Thalès"]),
    );
    expect(read.kind).toBe("pdf");
    expect(read.text).toContain("Thalès");
  });

  it("refuse une photo, quel que soit son nom", async () => {
    const jpeg = new Uint8Array(64);
    jpeg.set([0xff, 0xd8, 0xff, 0xe0]);
    await expect(readDocument(file("cours.txt", jpeg))).rejects.toMatchObject({
      code: "unsupported",
    });
  });

  it("renvoie vers le nuage un fichier qui se lit vide", async () => {
    await expect(readDocument(file("cours.pdf", new Uint8Array(0)))).rejects.toMatchObject({
      code: "unreachable",
    });
  });

  it("relit par FileReader ce que arrayBuffer refuse", async () => {
    const original = globalThis.FileReader;
    class StubFileReader {
      result: ArrayBuffer | null = null;
      onload: (() => void) | null = null;
      onerror: (() => void) | null = null;
      readAsArrayBuffer() {
        this.result = new TextEncoder().encode("Le cours qu'arrayBuffer refusait.").slice().buffer;
        this.onload?.();
      }
    }
    globalThis.FileReader = StubFileReader as unknown as typeof FileReader;

    const refusing = {
      name: "cours.txt",
      arrayBuffer: async () => {
        throw named("NotReadableError");
      },
    } as unknown as File;

    try {
      const read = await readDocument(refusing);
      expect(read.text).toContain("arrayBuffer refusait");
    } finally {
      globalThis.FileReader = original;
    }
  });
});

describe("sniffKind", () => {
  it("reconnaît un PDF, même précédé de quelques octets", () => {
    expect(sniffKind(new TextEncoder().encode("%PDF-1.7"))).toBe("pdf");
    expect(sniffKind(new Uint8Array([0x0a, 0x0d, ...new TextEncoder().encode("%PDF-1.4")]))).toBe("pdf");
  });

  it("reconnaît un Word à l'entrée word/document.xml, et pas un autre ZIP", () => {
    expect(sniffKind(storedZip({ "word/document.xml": "<w/>" }))).toBe("docx");
    expect(sniffKind(storedZip({ "collection.anki2": "sqlite" }))).toBeNull();
  });

  it("reconnaît une photo, HEIC compris", () => {
    expect(sniffKind(new Uint8Array([0xff, 0xd8, 0xff, 0xe0]))).toBe("image");
    expect(sniffKind(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))).toBe("image");
    const heic = new Uint8Array(16);
    heic.set([...new TextEncoder().encode("ftypheic")], 4);
    expect(sniffKind(heic)).toBe("image");
  });

  it("reconnaît l'ancien Word à sa signature OLE", () => {
    expect(sniffKind(new Uint8Array([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]))).toBe("legacyWord");
  });

  it("laisse le nom décider quand les octets ne disent rien", () => {
    expect(sniffKind(new TextEncoder().encode("Un cours écrit à la main."))).toBeNull();
  });
});

describe("decodeText", () => {
  it("retire la marque d'ordre d'un UTF-8", () => {
    const bytes = new Uint8Array([0xef, 0xbb, 0xbf, ...new TextEncoder().encode("Le théorème")]);
    expect(decodeText(bytes)).toBe("Le théorème");
  });

  it("lit un texte UTF-16 sans marque, qu'un décodage UTF-8 aurait rendu binaire", () => {
    const text = "Un octet nul sur deux, et pas de marque d'ordre au début";
    const bytes = new Uint8Array(text.length * 2);
    for (let index = 0; index < text.length; index += 1) {
      bytes[index * 2] = text.charCodeAt(index) & 0xff;
    }
    expect(decodeText(bytes)).toBe(text);
    expect(looksBinary(decodeText(bytes))).toBe(false);
  });

  it("normalise les fins de ligne de Windows", () => {
    expect(decodeText(new TextEncoder().encode("une\r\ndeux\rtrois"))).toBe("une\ndeux\ntrois");
  });
});

function named(name: string, message = name): Error {
  const error = new Error(message);
  error.name = name;
  return error;
}

/** Un ZIP « stocké », le plus court qui se lise : de quoi essayer la reconnaissance. */
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
