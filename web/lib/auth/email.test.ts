import { describe, expect, it } from "vitest";

import { inspectAddress, isSendableAddress, normalizeAddress } from "./email";

function suggestionFor(raw: string): string | null {
  const verdict = inspectAddress(raw);
  return verdict.kind === "suspicious" ? verdict.suggestion : null;
}

describe("normalizeAddress", () => {
  it("range l'adresse comme GoTrue la rangera", () => {
    expect(normalizeAddress("  Eleve@Gmail.COM ")).toBe("eleve@gmail.com");
    expect(normalizeAddress(null)).toBe("");
    expect(normalizeAddress(undefined)).toBe("");
  });
});

describe("inspectAddress", () => {
  it("laisse passer une adresse ordinaire", () => {
    expect(inspectAddress("eleve@gmail.com")).toEqual({ kind: "ok", address: "eleve@gmail.com" });
    expect(inspectAddress("  Eleve.Martin@Orange.fr  ")).toEqual({
      kind: "ok",
      address: "eleve.martin@orange.fr",
    });
  });

  it("laisse passer un domaine d'école qu'on ne connaît pas", () => {
    expect(inspectAddress("p.martin@ac-versailles.fr").kind).toBe("ok");
    expect(inspectAddress("eleve@lycee-carnot.education").kind).toBe("ok");
    expect(inspectAddress("ogrenci@bogazici.edu.tr").kind).toBe("ok");
  });

  it("refuse ce que GoTrue refuserait", () => {
    for (const bad of [
      "",
      "   ",
      "eleve",
      "@gmail.com",
      "eleve@",
      "eleve@lycee",
      "eleve@.fr",
      "eleve@lycee.",
      "eleve@lycee..fr",
      "eleve @gmail.com",
      "eleve@gmail com",
      "deux@arobases@gmail.com",
      ".eleve@gmail.com",
      "eleve.@gmail.com",
      "el..eve@gmail.com",
      "eleve@-gmail.com",
      "eleve@gmail-.com",
      "eleve@gmail.c",
      "eleve@gmail.c0m",
    ]) {
      expect(inspectAddress(bad), bad).toEqual({ kind: "malformed" });
    }
  });

  it("refuse les domaines que l'IETF a réservés, parce qu'ils rebondissent toujours", () => {
    for (const reserved of [
      "essai.web@micabo.test",
      "quelquun@example.com",
      "quelquun@example.org",
      "moi@monsite.invalid",
      "root@machine.localhost",
      "imprimante@bureau.local",
      "service@cluster.internal",
    ]) {
      expect(inspectAddress(reserved), reserved).toEqual({ kind: "undeliverable" });
    }
  });

  it("propose la bonne boîte quand deux lettres ont été échangées", () => {
    expect(inspectAddress("eleve@gmial.com")).toEqual({
      kind: "suspicious",
      address: "eleve@gmial.com",
      suggestion: "eleve@gmail.com",
    });
    expect(inspectAddress("eleve@hotmial.fr")).toEqual({
      kind: "suspicious",
      address: "eleve@hotmial.fr",
      suggestion: "eleve@hotmail.fr",
    });
  });

  it("rattrape une extension ratée de trois millimètres", () => {
    expect(suggestionFor("eleve@gmail.con")).toBe("eleve@gmail.com");
    expect(suggestionFor("eleve@gmail.co")).toBe("eleve@gmail.com");
    expect(suggestionFor("eleve@orange.fe")).toBe("eleve@orange.fr");
  });

  it("garde l'adresse d'origine à côté de sa correction, pour pouvoir passer outre", () => {
    const verdict = inspectAddress("  Eleve@Gmial.com ");
    expect(verdict).toEqual({
      kind: "suspicious",
      address: "eleve@gmial.com",
      suggestion: "eleve@gmail.com",
    });
  });

  it("ne propose rien quand l'adresse est déjà bonne", () => {
    for (const good of [
      "eleve@gmail.com",
      "eleve@mail.com",
      "eleve@free.fr",
      "eleve@gmx.de",
      "eleve@icloud.com",
      "eleve@yandex.com",
      "eleve@hotmail.co.uk",
    ]) {
      expect(inspectAddress(good).kind, good).toBe("ok");
    }
  });

  it("se resserre sur les domaines courts, où deux lettres font un autre domaine", () => {
    // Une lettre de `free.fr` : c'est presque sûrement une faute de frappe.
    expect(suggestionFor("eleve@bree.fr")).toBe("eleve@free.fr");
    // Deux lettres : sur sept caractères, ce n'est plus une faute, c'est un autre nom.
    expect(inspectAddress("eleve@bnee.fr").kind).toBe("ok");
  });

  it("s'autorise deux lettres quand le domaine est long", () => {
    expect(suggestionFor("eleve@gmaul.cm")).toBe("eleve@gmail.com");
    expect(suggestionFor("eleve@protonmial.com")).toBe("eleve@protonmail.com");
  });
});

describe("isSendableAddress", () => {
  it("n'est vrai que pour ce qui part sans question", () => {
    expect(isSendableAddress("eleve@gmail.com")).toBe(true);
    expect(isSendableAddress("eleve@gmial.com")).toBe(false);
    expect(isSendableAddress("eleve@micabo.test")).toBe(false);
    expect(isSendableAddress("eleve")).toBe(false);
  });
});
