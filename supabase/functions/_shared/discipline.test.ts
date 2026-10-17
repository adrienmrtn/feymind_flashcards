import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { detectDiscipline, disciplineBrief, fromSubject, lessonShapesBrief } from "./discipline.ts";

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

describe("detectDiscipline dans les autres langues", () => {
  it("reconnaît les mathématiques en anglais, en allemand et en turc", () => {
    assert.equal(detectDiscipline("The derivative of a polynomial is found with this theorem."), "mathematics");
    assert.equal(detectDiscipline("Die Ableitung einer Funktion und die Gleichung der Tangente."), "mathematics");
    assert.equal(detectDiscipline("Türev ve integral: denklem çözümü, olasılık hesabı."), "mathematics");
  });

  it("reconnaît l'histoire en espagnol, en italien et en portugais", () => {
    assert.equal(detectDiscipline("La guerra civil y el imperio en el siglo XIX."), "history");
    assert.equal(detectDiscipline("Il Medioevo e la rivoluzione: un secolo di guerra."), "history");
    assert.equal(detectDiscipline("A revolução e o império no século XVIII."), "history");
  });

  it("sépare la chimie de la physique", () => {
    assert.equal(detectDiscipline("Chemistry: a covalent bond, the periodic table and a titration."), "chemistry");
    assert.equal(detectDiscipline("L'équation de la réaction chimique, la molécule et l'acide."), "chemistry");
    assert.equal(detectDiscipline("Die Geschwindigkeit, die Beschleunigung und die kinetische Energie."), "physics");
  });

  it("reconnaît la géographie", () => {
    assert.equal(detectDiscipline("Urbanisation, mondialisation et littoral : la métropole française."), "geography");
    assert.equal(detectDiscipline("Population density and climate across the continent."), "geography");
  });

  it("reconnaît la biologie, l'économie et les langues ailleurs qu'en français", () => {
    assert.equal(detectDiscipline("Photosynthesis happens in the ecosystem; DNA and chromosomes."), "biology");
    assert.equal(detectDiscipline("Inflation, unemployment and the central bank in the economy."), "economics");
    assert.equal(detectDiscipline("Vocabulario y gramática: la conjugación del verbo irregular."), "language");
  });

  it("ne compte pas un mot courant comme indice", () => {
    // « ses » ne signe plus l'économie, « onde » portugais n'est pas la physique.
    assert.equal(detectDiscipline("Il range ses classes et ses affaires."), "general");
    assert.equal(detectDiscipline("Onde fica a escola? Perto da praça."), "general");
  });
});

describe("la matière déclarée, dans toutes les langues", () => {
  const cases: [string, string][] = [
    ["Mathematics", "mathematics"],
    ["Matemáticas", "mathematics"],
    ["Mathe", "mathematics"],
    ["Matematik", "mathematics"],
    ["History", "history"],
    ["Geschichte", "history"],
    ["Histoire-géographie", "history"],
    ["Geografía", "geography"],
    ["Erdkunde", "geography"],
    ["Biology", "biology"],
    ["SVT", "biology"],
    ["Chemistry", "chemistry"],
    ["Química", "chemistry"],
    ["Physik", "physics"],
    ["Physique-chimie", "physics"],
    ["Economics", "economics"],
    ["SES", "economics"],
    ["Philosophy", "philosophy"],
    ["Felsefe", "philosophy"],
    ["Literature", "literature"],
    ["English literature", "literature"],
    ["English", "language"],
    ["Spanish", "language"],
    ["İngilizce", "language"],
    ["Informatik", "computing"],
    ["NSI", "computing"],
    ["Tıp", "medicine"],
  ];
  for (const [subject, expected] of cases) {
    it(`« ${subject} » → ${expected}`, () => {
      assert.equal(fromSubject(subject), expected);
      assert.equal(detectDiscipline("", undefined, subject), expected);
    });
  }

  it("« Passé composé » n'est pas une matière de santé", () => {
    assert.notEqual(fromSubject("Passé composé"), "medicine");
  });
});

describe("lessonShapesBrief", () => {
  it("donne à chaque matière ses formes de bloc", () => {
    assert.match(lessonShapesBrief("mathematics"), /"steps"/);
    assert.match(lessonShapesBrief("mathematics"), /"formula"/);
    assert.match(lessonShapesBrief("philosophy"), /"quote"/);
    assert.match(lessonShapesBrief("philosophy"), /"table"/);
    assert.match(lessonShapesBrief("language"), /traduction/);
    assert.match(lessonShapesBrief("history"), /"dates"/);
    assert.match(lessonShapesBrief("chemistry"), /\\ce/);
    assert.ok(lessonShapesBrief("general").length > 0);
  });

  it("les consignes de fond ne nomment aucun bloc", () => {
    for (const discipline of ["computing", "philosophy", "law", "medicine", "history"] as const) {
      assert.doesNotMatch(disciplineBrief(discipline), /"steps"|"table"|tableau/);
    }
    assert.match(disciplineBrief("chemistry"), /équilibrée/);
    assert.match(disciplineBrief("geography"), /échelle/);
  });
});
