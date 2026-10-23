import { assert, assertEquals } from "jsr:@std/assert@1";
import { COUNTRIES, depthOf, learnerBrief, readLearner, volumeOf } from "./learner.ts";
import { LIMITS } from "../generate-lesson/schema.ts";

Deno.test("la marche prime sur le registre : un collégien n'est pas un lycéen", () => {
  const learner = readLearner({ tier: "lowerSecondary", level: "lycee", country: "fr", year: "Quatrième", track: "Collège" });
  assertEquals(learner.tier, "lowerSecondary");
  const brief = learnerBrief(learner);
  assert(brief.includes("COLLÉGIEN"));
  assert(brief.includes("Collège, Quatrième"));
  assert(brief.includes("brevet"));
});

Deno.test("sans marche, le registre ancien la donne ; sans rien, un niveau neutre", () => {
  assertEquals(readLearner({ level: "prepa" }).tier, "preUniversity");
  assertEquals(readLearner({ level: "concours" }).tier, "competitive");
  assertEquals(readLearner({}).tier, "other");
  assertEquals(readLearner({ tier: "inventé", level: "master" }).tier, "graduate");
});

Deno.test("chaque pays proposé par l'app a ses examens et son barème", () => {
  const offered = ["fr", "uk", "de", "it", "es", "pt", "cz", "nl", "gr", "hu", "pl", "ro", "se", "tr", "be", "ch", "ca", "lu", "ma", "dz", "tn", "sn", "ci", "us", "other"];
  for (const code of offered) {
    const country = COUNTRIES[code];
    assert(country, `pays manquant : ${code}`);
    assert(country.exams.length > 10 && country.grading.length > 5, code);
  }
  assertEquals(readLearner({ country: "xx" }).country, "other", "un pays inconnu ne nomme aucun examen");
});

Deno.test("hors de France, jamais le bac français ; l'examen visé est repris", () => {
  const tr = learnerBrief(readLearner({ tier: "competitive", country: "tr", track: "YKS hazırlık", year: "TYT", exam: "YKS, le 2027-06-19" }));
  assert(tr.includes("YKS"));
  assert(tr.includes("Ne parle jamais du baccalauréat français"));
  assert(tr.includes("Il prépare précisément : YKS, le 2027-06-19"));
  const fr = learnerBrief(readLearner({ tier: "upperSecondary", country: "fr" }));
  assert(!fr.includes("Ne parle jamais du baccalauréat français"));
});

Deno.test("le volume suit la marche", () => {
  assert(volumeOf("lowerSecondary").questions < volumeOf("health").questions);
  assert(volumeOf("lowerSecondary").maxThemes <= 8);
  for (const tier of ["lowerSecondary", "upperSecondary", "preUniversity", "undergraduate", "graduate", "health", "competitive", "other"] as const) {
    const volume = volumeOf(tier);
    assert(volume.questions >= 5 && volume.questions <= 8, tier);
    assert(volume.flashcards >= 4 && volume.flashcards <= 8, tier);
  }
});

Deno.test("la profondeur des notes suit la marche, sous les plafonds du serveur", () => {
  const tiers = ["lowerSecondary", "upperSecondary", "preUniversity", "undergraduate", "graduate", "health", "competitive", "other"] as const;
  assertEquals(depthOf("lowerSecondary").blocks, [4, 6]);
  assertEquals(depthOf("lowerSecondary").paragraphWords, 85);
  assertEquals(depthOf("upperSecondary").blocks, [5, 8]);
  assertEquals(depthOf("upperSecondary").paragraphWords, 110);
  // Les niveaux avancés écrivent une fiche : moins de blocs, peu de prose, des puces denses.
  for (const tier of ["preUniversity", "undergraduate", "graduate", "health", "competitive"] as const) {
    assertEquals(depthOf(tier).blocks, [4, 8], tier);
    assertEquals(depthOf(tier).paragraphWords, 95, tier);
    assertEquals(depthOf(tier).register, "fiche", tier);
    assertEquals([depthOf(tier).listItems, depthOf(tier).listItemWords], [8, 28], tier);
  }
  assertEquals(depthOf("upperSecondary").register, "explained");
  assertEquals(depthOf("other").register, "explained");
  assertEquals(depthOf("lowerSecondary").register, "guided");
  assertEquals([depthOf("lowerSecondary").listItems, depthOf("lowerSecondary").listItemWords], [5, 16]);
  for (const tier of tiers) {
    const depth = depthOf(tier);
    assert(depth.blocks[0] >= 4 && depth.blocks[0] <= depth.blocks[1], tier);
    assert(depth.blocks[1] + 2 <= LIMITS.blocksHardMax, tier);
    assert(depth.paragraphWords <= LIMITS.paragraphHardWords, tier);
    assert(depth.listItems <= LIMITS.listItemsHardMax && depth.listItemWords <= LIMITS.listItemHardWords, tier);
    assert(depth.style.length > 20, tier);
  }
  assert(depthOf("lowerSecondary").style.includes("analogie"));
  assert(depthOf("health").examFormat && depthOf("competitive").examFormat && depthOf("upperSecondary").examFormat);
  assert(!depthOf("lowerSecondary").examFormat && !depthOf("graduate").examFormat);
});

Deno.test("une note envoyée sur le barème du pays se lit par son libellé, pas sur 100", () => {
  const learner = readLearner({ tier: "upperSecondary", country: "fr", currentScore: 15, scoreLabel: "15/20", targetScore: 18, targetLabel: "18/20" });
  assertEquals(learner.currentScore, 75);
  assertEquals(learner.targetScore, 90);
  assertEquals(readLearner({ currentScore: 62 }).currentScore, 62);
});
