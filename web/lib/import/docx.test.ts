import { describe, expect, it } from "vitest";

import { DocxError, extractDocxText, looksLikeZip, wordXmlToText } from "./docx";

const SAMPLE = `<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Les fonctions affines</w:t></w:r></w:p>
    <w:p><w:r><w:t>Une fonction</w:t><w:tab/><w:t>s'écrit f(x)</w:t><w:br/><w:t>ax + b</w:t></w:r></w:p>
  </w:body>
</w:document>`;

describe("wordXmlToText", () => {
  it("joint les paragraphes, les tabulations et les sauts", () => {
    const text = wordXmlToText(SAMPLE);
    expect(text).toContain("Les fonctions affines");
    expect(text).toContain("Une fonction");
    expect(text).toContain("s'écrit f(x)");
    expect(text).toContain("ax + b");
    expect(text).toContain("\n");
  });

  it("lit aussi les balises sans préfixe w:", () => {
    const text = wordXmlToText(
      `<document><p><r><t>Un cours de géographie</t></r></p><p><r><t>sur les reliefs.</t></r></p></document>`,
    );
    expect(text).toContain("Un cours de géographie");
    expect(text).toContain("sur les reliefs.");
  });
});

describe("extractDocxText", () => {
  it("lit un ZIP stocké qui porte word/document.xml", async () => {
    const zip = storedZip({ "word/document.xml": SAMPLE });
    expect(looksLikeZip(zip)).toBe(true);
    const text = await extractDocxText(zip);
    expect(text).toContain("fonctions affines");
    expect(text.length).toBeGreaterThanOrEqual(20);
  });

  it("refuse un ZIP sans document", async () => {
    const zip = storedZip({ "word/styles.xml": "<w/>" });
    await expect(extractDocxText(zip)).rejects.toBeInstanceOf(DocxError);
  });

  it("refuse des octets qui ne sont pas un ZIP", async () => {
    await expect(extractDocxText(new TextEncoder().encode("pas un zip"))).rejects.toMatchObject({
      code: "notDocx",
    });
  });

  it("lit un ZIP compressé en DEFLATE", async () => {
    const { deflateRawSync } = await import("node:zlib");
    const zip = storedZip({ "word/document.xml": SAMPLE }, (bytes) => deflateRawSync(bytes));
    const text = await extractDocxText(zip);
    expect(text).toContain("fonctions affines");
  });
});

function storedZip(
  files: Record<string, string>,
  compress?: (bytes: Uint8Array) => Uint8Array,
): Uint8Array {
  const encoder = new TextEncoder();
  const locals: Uint8Array[] = [];
  const centrals: Uint8Array[] = [];
  let offset = 0;

  for (const [name, content] of Object.entries(files)) {
    const nameBytes = encoder.encode(name);
    const raw = encoder.encode(content);
    const data = compress ? new Uint8Array(compress(raw)) : raw;
    const method = compress ? 8 : 0;
    const local = new Uint8Array(30 + nameBytes.length + data.length);
    writeU32(local, 0, 0x04034b50);
    writeU16(local, 8, method);
    writeU16(local, 26, nameBytes.length);
    writeU32(local, 18, data.length);
    writeU32(local, 22, raw.length);
    local.set(nameBytes, 30);
    local.set(data, 30 + nameBytes.length);
    locals.push(local);

    const central = new Uint8Array(46 + nameBytes.length);
    writeU32(central, 0, 0x02014b50);
    writeU16(central, 10, method);
    writeU32(central, 20, data.length);
    writeU32(central, 24, raw.length);
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
  for (const part of locals) {
    out.set(part, at);
    at += part.length;
  }
  for (const part of centrals) {
    out.set(part, at);
    at += part.length;
  }
  out.set(eocd, at);
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
