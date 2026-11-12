import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import {
  bandOf,
  blocksForShare,
  CALIBRATION,
  calibrationOf,
  FIRST_GRADE,
  gradeOf,
  sourceThemeRange,
} from "./calibration.ts";
import { learnerBrief, placeOf, programmeBrief, readLearner } from "./learner.ts";
import { planShapeBrief, themeBrief } from "../generate-lesson/prompt.ts";
import { LIMITS, noteLimits } from "../generate-lesson/schema.ts";

/** Les quatre élèves des exemples, tels que l'app iPhone les envoie. */
const SIXIEME = {
  tier: "lowerSecondary", country: "fr", track: "Collège", year: "Sixième",
  trackId: "fr.college", yearId: "fr.6e", yearRank: 1, yearCount: 4, language: "fr",
};
const TERMINALE = {
  tier: "upperSecondary", country: "fr", track: "Lycée général", year: "Terminale",
  trackId: "fr.lyceeGeneral", yearId: "fr.terminale", yearRank: 3, yearCount: 3,
  yearExams: ["Bac"], language: "fr",
};
const YEAR10 = {
  tier: "lowerSecondary", country: "uk", track: "GCSEs (Years 10–11)", year: "Year 10",
  trackId: "uk.gcse", yearId: "uk.y10", yearRank: 1, yearCount: 2, language: "en",
};
const LICENCE = {
  tier: "undergraduate", country: "fr", track: "Université", year: "Licence 2",
  trackId: "fr.universite", yearId: "fr.l2", yearRank: 2, yearCount: 5, language: "fr",
};

Deno.test("la classe internationale : la même d'un pays à l'autre", () => {
  assertEquals(gradeOf({ tier: "lowerSecondary", trackId: "fr.college", yearRank: 1, yearCount: 4 }), 6);
  assertEquals(gradeOf({ tier: "lowerSecondary", trackId: "fr.college", yearRank: 4, yearCount: 4 }), 9);
  assertEquals(gradeOf({ tier: "upperSecondary", trackId: "fr.lyceeGeneral", yearRank: 3, yearCount: 3 }), 12);
  assertEquals(gradeOf({ tier: "lowerSecondary", trackId: "uk.ks3", yearRank: 1, yearCount: 3 }), 6, "Year 7");
  assertEquals(gradeOf({ tier: "lowerSecondary", trackId: "uk.gcse", yearRank: 1, yearCount: 2 }), 9, "Year 10");
  assertEquals(gradeOf({ tier: "upperSecondary", trackId: "uk.alevels", yearRank: 2, yearCount: 2 }), 12, "Year 13");
  assertEquals(gradeOf({ tier: "lowerSecondary", trackId: "de.mittelstufe", yearRank: 1, yearCount: 6 }), 5, "5. Klasse");
  assertEquals(gradeOf({ tier: "upperSecondary", trackId: "de.gymnasium", yearRank: 3, yearCount: 3 }), 13, "Abitur");
  assertEquals(gradeOf({ tier: "lowerSecondary", trackId: "es.eso", yearRank: 1, yearCount: 4 }), 7, "1º ESO");
  assertEquals(gradeOf({ tier: "lowerSecondary", trackId: "tr.ortaokul", yearRank: 2, yearCount: 4 }), 6, "6. sınıf");
  // Une filière hors table se place depuis la fin de son cycle.
  assertEquals(gradeOf({ tier: "lowerSecondary", trackId: "pl.podstawowa", yearRank: 1, yearCount: 2 }), 8);
  assertEquals(gradeOf({ tier: "upperSecondary", trackId: "at.oberstufe", yearRank: 4, yearCount: 4 }), 12);
  // Rien d'utilisable : pas de classe.
  assertEquals(gradeOf({ tier: "lowerSecondary" }), undefined);
  assertEquals(gradeOf({ tier: "lowerSecondary", yearRank: 5, yearCount: 4 }), undefined);
  assertEquals(gradeOf({ tier: "undergraduate", yearRank: 1, yearCount: 3 }), undefined);
  for (const first of Object.values(FIRST_GRADE)) assert(first >= 5 && first <= 11);
});

Deno.test("le palier : Sixième ≠ Troisième, Seconde ≠ Terminale, et les équivalents", () => {
  const band = (body: Record<string, unknown>) => bandOf(placeOf(readLearner(body)));
  assertEquals(band(SIXIEME), "lowerEarly");
  assertEquals(band({ ...SIXIEME, yearId: "fr.3e", yearRank: 4 }), "lowerLate");
  assertEquals(band({ ...TERMINALE, yearId: "fr.seconde", yearRank: 1 }), "upperEarly");
  assertEquals(band(TERMINALE), "upperFinal");
  assertEquals(band({ tier: "lowerSecondary", country: "uk", trackId: "uk.ks3", yearRank: 1, yearCount: 3 }), "lowerEarly", "Year 7");
  assertEquals(band(YEAR10), "lowerLate");
  assertEquals(band({ tier: "upperSecondary", country: "uk", trackId: "uk.alevels", yearRank: 2, yearCount: 2 }), "upperFinal", "A-level");
  assertEquals(band({ tier: "lowerSecondary", country: "de", trackId: "de.mittelstufe", yearRank: 1, yearCount: 6 }), "lowerEarly", "5. Klasse");
  assertEquals(band({ tier: "upperSecondary", country: "de", trackId: "de.gymnasium", yearRank: 3, yearCount: 3 }), "upperFinal", "Abitur");
  assertEquals(band(LICENCE), "undergraduate");
  // Repli : une app d'avant (sans année) garde le calibrage de la marche.
  assertEquals(band({ tier: "lowerSecondary", country: "fr" }), "lowerLate");
  assertEquals(band({ tier: "upperSecondary", country: "fr" }), "upperEarly");
  assertEquals(band({ country: "fr" }), "unknown");
  assertEquals(band({ level: "lycee" }), "upperEarly");
});

Deno.test("la table reste sous les plafonds du serveur, et elle monte avec le niveau", () => {
  for (const row of Object.values(CALIBRATION)) {
    const { volume, depth } = row;
    assert(volume.topicThemes[0] >= LIMITS.minThemes && volume.topicThemes[1] <= volume.maxThemes, row.band);
    assert(volume.maxThemes <= LIMITS.maxThemes, row.band);
    assert(volume.questions >= LIMITS.minQuestions && volume.questions <= LIMITS.questionsPerTheme, row.band);
    assert(volume.flashcards <= LIMITS.flashcardsPerTheme, row.band);
    assert(depth.blocks[0] <= depth.blocks[1] && depth.blocks[1] + 2 <= LIMITS.blocksHardMax, row.band);
    assert(depth.paragraphWords <= LIMITS.paragraphHardWords, row.band);
    assert(depth.listItems <= LIMITS.listItemsHardMax && depth.listItemWords <= LIMITS.listItemHardWords, row.band);
    for (const text of [row.label, row.prerequisites, row.vocabulary, row.exercises, row.difficulty, row.mockExam]) assert(text.length > 10, row.band);
  }
  const order = ["lowerEarly", "lowerLate", "upperEarly", "upperFinal"] as const;
  for (let i = 1; i < order.length; i++) {
    const [before, after] = [CALIBRATION[order[i - 1]!], CALIBRATION[order[i]!]];
    assert(after.depth.paragraphWords >= before.depth.paragraphWords, `${order[i]} : paragraphes`);
    assert(after.depth.blocks[1] >= before.depth.blocks[1], `${order[i]} : blocs`);
    assert(after.volume.questions >= before.volume.questions, `${order[i]} : questions`);
    assert(after.volume.flashcards >= before.volume.flashcards, `${order[i]} : cartes`);
  }
  assertEquals(CALIBRATION.lowerEarly.depth.register, "guided");
  assertEquals(CALIBRATION.upperFinal.depth.examFormat, true);
  assertEquals(CALIBRATION.undergraduate.depth.register, "fiche");
});

Deno.test("la longueur suit le support : dix pages ne font pas quatre thèmes", () => {
  assertEquals(sourceThemeRange(2_500, 10), [4, 6], "une page");
  assertEquals(sourceThemeRange(25_000, 10), [7, 9], "dix pages");
  assertEquals(sourceThemeRange(60_000, 12), [11, 12], "un long document");
  assertEquals(sourceThemeRange(60_000, 7), [6, 7], "un collégien garde son plafond");
  const [low] = sourceThemeRange(25_000, CALIBRATION.upperFinal.volume.maxThemes);
  assert(low >= 6, "un cours de dix pages en Terminale : au moins six thèmes");
  // Un thème qui couvre une grande part du support a plus de blocs, sous les plafonds.
  assertEquals(blocksForShare([4, 6], 1_000), [4, 6]);
  assertEquals(blocksForShare([4, 6], 5_000), [4, 7]);
  assertEquals(blocksForShare([4, 6], 12_000), [5, 8]);
  assertEquals(blocksForShare([6, 9], 20_000), [7, 10]);
  assert(noteLimits({ blocks: blocksForShare([6, 9], 20_000), paragraphWords: 115 }).blocksMax <= LIMITS.blocksHardMax);
});

/** Les consignes qu'un thème reçoit, comme `generate-lesson/index.ts` les assemble. */
function themePrompt(body: Record<string, unknown>, topic: string): string {
  const learner = readLearner(body);
  const calibration = calibrationOf(placeOf(learner));
  return [
    learnerBrief(learner),
    programmeBrief(learner, { fromScratch: true, subject: String(body.subject ?? "") }),
    planShapeBrief({ shortSource: false, fromScratch: true, topicThemes: calibration.volume.topicThemes, maxThemes: calibration.volume.maxThemes }),
    themeBrief({
      lessonTitle: topic,
      themeTitle: topic,
      themeIndex: 0,
      themes: [topic],
      questions: calibration.volume.questions,
      flashcards: calibration.volume.flashcards,
      kinds: ["choice", "truefalse"],
      depth: calibration.depth,
    }),
  ].join("\n\n");
}

Deno.test("même sujet, quatre élèves : les consignes diffèrent comme attendu", () => {
  for (const [topic, subject] of [["la guerre froide", "Histoire"], ["les fractions", "Mathématiques"]] as const) {
    const sixieme = themePrompt({ ...SIXIEME, subject }, topic);
    const terminale = themePrompt({ ...TERMINALE, subject }, topic);
    const year10 = themePrompt({ ...YEAR10, subject }, topic);
    const licence = themePrompt({ ...LICENCE, subject }, topic);

    // Sixième : un cours court, concret, des mots simples.
    assert(sixieme.includes("début du collège"), topic);
    assert(sixieme.includes("Notes : 3 à 5 blocs"), topic);
    assert(sixieme.includes("Entre 4 et 5 thèmes"), topic);
    assert(sixieme.includes("Puis 5 questions et 4 flashcards"), topic);
    assert(sixieme.includes("acquis de l'école primaire"), topic);
    assert(sixieme.includes("en Collège, Sixième"), topic);
    assert(sixieme.includes("classe 6 sur l'échelle internationale"), topic);
    assert(!sixieme.includes("format exact de son examen"), "pas d'épreuve en Sixième");

    // Terminale : le niveau du bac, la méthode et les pièges d'épreuve.
    assert(terminale.includes("dernière année du secondaire"), topic);
    assert(terminale.includes("Notes : 6 à 9 blocs"), topic);
    assert(terminale.includes("Puis 7 questions et 6 flashcards"), topic);
    assert(terminale.includes("pièges qui coûtent des points"), topic);
    assert(terminale.includes("format exact de son examen"), topic);
    assert(terminale.includes("Examens de son année : Bac"), topic);
    assert(terminale.includes("baccalauréat") || terminale.includes("bac"), topic);

    // Year 10 au Royaume-Uni : les GCSE, jamais le bac français.
    assert(year10.includes("au Royaume-Uni, en GCSEs (Years 10–11), Year 10"), topic);
    assert(year10.includes("fin du collège"), topic);
    assert(year10.includes("GCSE"), topic);
    assert(year10.includes("Ne parle jamais du baccalauréat français"), topic);
    assert(year10.includes("classe 9 sur l'échelle internationale"), topic);

    // Université : un cours dense, en fiche.
    assert(licence.includes("premier cycle universitaire"), topic);
    assert(licence.includes("puces serrées"), topic);
    assert(licence.includes("Notes : 4 à 8 blocs"), topic);

    // Le programme officiel est demandé, sans invention, et le hors-niveau se signale.
    for (const prompt of [sixieme, terminale, year10, licence]) {
      assert(prompt.includes("PROGRAMME OFFICIEL"), topic);
      assert(prompt.includes("N'invente pas"), topic);
      assert(prompt.includes("ne le traite pas au mauvais niveau"), topic);
    }
    assert(sixieme.includes(`en ${subject}`), topic);

    // Quatre consignes différentes deux à deux.
    const all = [sixieme, terminale, year10, licence];
    for (let i = 0; i < all.length; i++) for (let j = i + 1; j < all.length; j++) assertNotEquals(all[i], all[j]);
  }
});

Deno.test("« Autre pays » : le pays est nommé, ses examens viennent du catalogue de l'app", () => {
  const austria = readLearner({
    tier: "upperSecondary", country: "other", region: "AT", track: "AHS-Oberstufe", year: "8. Klasse",
    trackId: "at.oberstufe", yearId: "at.ahs8", yearRank: 4, yearCount: 4, yearExams: ["Matura"],
  });
  assertEquals(austria.country, "other");
  assertEquals(austria.region, "at");
  const brief = learnerBrief(austria);
  assert(brief.includes("Autriche"), brief);
  assert(brief.includes("Matura"));
  assert(!brief.includes("pays non précisé"));
  assertEquals(bandOf(placeOf(austria)), "upperFinal");
  assert(programmeBrief(austria, { fromScratch: true }).includes("Autriche"));
  // Un code qui a sa ligne la prend : « Autre pays » → Royaume-Uni par son code GB.
  assertEquals(readLearner({ country: "other", region: "gb" }).country, "uk");
  // Un code invalide ne passe pas.
  assertEquals(readLearner({ country: "other", region: "<x>" }).region, undefined);
});

Deno.test("le profil transmis est nettoyé, et rien de personnel n'en sort", () => {
  const learner = readLearner({
    tier: "lowerSecondary", country: "fr", trackId: "fr.college\n<script>", yearId: "fr.6e",
    yearRank: 9, yearCount: 4, subjects: ["Maths", "Maths", "SVT", 3], targetExam: "Brevet, le 2027-06-25",
    firstName: "Léa", email: "lea@example.com",
  } as Record<string, unknown>);
  assertEquals(learner.trackId, undefined, "un identifiant hors format est jeté");
  assertEquals(learner.yearId, "fr.6e");
  assertEquals(learner.yearRank, undefined, "un rang hors filière est jeté");
  assertEquals(learner.subjects, ["Maths", "SVT"]);
  const brief = learnerBrief(learner);
  assert(brief.includes("Brevet, le 2027-06-25"));
  assert(!brief.includes("Léa") && !brief.includes("example.com"));
});
