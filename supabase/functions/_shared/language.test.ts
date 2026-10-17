import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { isSourceLanguage, languageBrief, languageName, resolveLanguage } from "./language.ts";

describe("resolveLanguage", () => {
  it("lit les deux langues connues", () => {
    assert.equal(resolveLanguage("fr"), "fr");
    assert.equal(resolveLanguage("en"), "en");
  });

  it("tolère la casse et les espaces", () => {
    assert.equal(resolveLanguage(" EN "), "en");
  });

  it("ne garde que les deux premières lettres d'une étiquette longue", () => {
    assert.equal(resolveLanguage("en-GB"), "en");
    assert.equal(resolveLanguage("fr_CA"), "fr");
  });

  it("distingue le Brésil du Portugal et l'Amérique latine de l'Espagne", () => {
    assert.equal(resolveLanguage("pt-BR"), "pt-BR");
    assert.equal(resolveLanguage("pt"), "pt");
    assert.equal(resolveLanguage("es-419"), "es-419");
    assert.equal(resolveLanguage("es-MX"), "es-419");
    assert.equal(resolveLanguage("es"), "es");
    assert.equal(resolveLanguage("ar"), "ar");
    assert.equal(resolveLanguage("ru"), "ru");
    assert.ok(languageBrief("pt-BR").includes("BRÉSIL"));
  });

  // Une version de l'application antérieure à la question n'envoie rien : les fiches déjà
  // écrites ne doivent pas changer de langue.
  it("retombe sur le français quand rien n'est demandé", () => {
    assert.equal(resolveLanguage(undefined), "fr");
    assert.equal(resolveLanguage(""), "fr");
    assert.equal(resolveLanguage("zz"), "fr");
  });

  it("reconnaît la demande de rester dans la langue du document", () => {
    assert.equal(isSourceLanguage("source"), true);
    assert.equal(isSourceLanguage("auto"), true);
    assert.equal(isSourceLanguage("fr"), false);
  });
});

describe("languageBrief", () => {
  it("dit franchement sa langue", () => {
    assert.ok(languageBrief("fr").includes("FRANÇAIS"));
    assert.ok(languageBrief("en").includes("ANGLAIS"));
  });

  // Le prompt système répète « en français » : sans cette priorité affichée, le modèle suit
  // le système et ignore la demande.
  it("annonce qu'elle passe devant le prompt système", () => {
    assert.ok(languageBrief("en").includes("l'emporte"));
  });

  it("nomme la langue pour les consignes", () => {
    assert.equal(languageName("en"), "anglais");
    assert.equal(languageName(undefined), "français");
  });

  it("reste dans la langue du document quand on le demande", () => {
    assert.ok(languageBrief("source").includes("CELLE DU DOCUMENT"));
    assert.ok(languageBrief("source").includes("l'emporte"));
    assert.ok(!languageBrief("source").includes("FRANÇAIS."));
  });
});
