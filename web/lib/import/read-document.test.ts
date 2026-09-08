import { describe, expect, it } from "vitest";

import { DocxError } from "./docx";
import {
  ReadFailure,
  classifyReadFailure,
  documentKind,
  failureDetail,
  looksBinary,
  readDocument,
  refusedKind,
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
});

function named(name: string, message = name): Error {
  const error = new Error(message);
  error.name = name;
  return error;
}
