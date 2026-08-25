import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { detectDiscipline, disciplineBrief } from "./discipline.ts";

describe("detectDiscipline", () => {
  it("reconnaît un cours de philosophie à ses auteurs", () => {
    const text = "La conscience chez Descartes et Kant suppose une distinction " +
      "métaphysique entre le sujet et l'objet, que Hegel reprendra autrement.";
    assert.equal(detectDiscipline(text), "philosophy");
  });

  it("reconnaît un cours d'économie à ses théories", () => {
    const text = "Keynes s'oppose à Ricardo sur le chômage : la demande effective " +
      "détermine la production, et l'inflation dépend de la monnaie en circulation.";
    assert.equal(detectDiscipline(text), "economics");
  });

  it("reconnaît un cours de droit à ses sources", () => {
    const text = "L'article 1240 du code civil fonde la responsabilité civile. " +
      "La jurisprudence de la Cour de cassation précise la notion de faute.";
    assert.equal(detectDiscipline(text), "law");
  });

  it("reconnaît un cours de santé à sa nomenclature", () => {
    const text = "L'anatomie du muscle cardiaque et la physiologie de la contraction : " +
      "le diagnostic clinique repose sur le symptôme et la sémiologie.";
    assert.equal(detectDiscipline(text), "medicine");
  });

  it("préfère la matière déclarée par l'application aux mots comptés", () => {
    // Le texte parle de marchés, mais l'app sait que le cours est un cours d'histoire.
    const text = "Le marché de Bruges, la monnaie et la consommation au XVe siècle.";
    assert.equal(detectDiscipline(text, undefined, "Histoire"), "history");
  });

  it("se sert du titre quand le texte est avare", () => {
    assert.equal(
      detectDiscipline("Chapitre 3, suite du cours.", "Philosophie : la conscience"),
      "philosophy",
    );
  });

  /// Un seul mot ne décide de rien : sinon un cours d'histoire qui parle de marchés
  /// deviendrait un cours d'économie.
  it("ne tranche pas sur un seul mot", () => {
    assert.equal(detectDiscipline("Le marché de Rungis ouvre à quatre heures."), "general");
  });

  it("laisse un document quelconque sans matière", () => {
    assert.equal(detectDiscipline("Notes diverses prises pendant la réunion de rentrée."), "general");
  });
});

describe("disciplineBrief", () => {
  it("réclame les auteurs et les œuvres en philosophie", () => {
    assert.match(disciplineBrief("philosophy"), /auteurs/);
    assert.match(disciplineBrief("philosophy"), /œuvres/);
  });

  it("réclame les visions opposées en économie, et le prérequis de première", () => {
    assert.match(disciplineBrief("economics"), /écoles/);
    assert.match(disciplineBrief("economics"), /première/);
  });

  it("réclame la source de la règle en droit", () => {
    assert.match(disciplineBrief("law"), /article/);
    assert.match(disciplineBrief("law"), /Constitution/);
  });

  it("ne dit rien quand la matière est inconnue", () => {
    assert.equal(disciplineBrief("general"), "");
  });
});
