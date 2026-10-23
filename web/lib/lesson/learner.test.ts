import { describe, expect, it } from "vitest";

import { buildAudience, readLearnerCookie, readStudyLevel, stageAnswer, writeLearnerCookie } from "./learner";
import { studyDays } from "./study-days";

const USER = "11111111-1111-4111-8111-111111111111";

describe("pour qui la leçon s'écrit", () => {
  it("envoie le registre, le palier, la marche, les notes et la langue des fiches, comme l'iPhone", () => {
    const audience = buildAudience({
      profile: { study_level: "lycee", country_code: "fr", sheet_language: null },
      local: { userId: USER, stageId: "fr.lycee", tier: "upperSecondary", currentScore: 12, targetScore: 16 },
      uiLocale: "en",
      exam: "un examen, le 2027-06-15",
    });
    expect(audience).toEqual({
      level: "lycee",
      country: "fr",
      schoolStage: "Lycée",
      // La langue du pays, pas celle de l'interface : `OnboardingPreferences.contentLanguage`.
      language: "fr",
      kinds: ["choice", "truefalse", "gap", "order", "match"],
      tier: "upperSecondary",
      exam: "un examen, le 2027-06-15",
      currentScore: 12,
      targetScore: 16,
      scoreLabel: "12/20",
      targetLabel: "16/20",
    });
  });

  it("prend la langue des fiches choisie, dans les vingt-six de l'app", () => {
    const audience = buildAudience({ profile: { study_level: null, country_code: "fr", sheet_language: "pt-BR" }, local: null, uiLocale: "fr" });
    expect(audience.language).toBe("pt-BR");
    expect(audience.level).toBe("");
    expect(audience.schoolStage).toBe("");
    expect(audience).not.toHaveProperty("tier");
  });

  it("retombe sur l'interface seulement sans profil", () => {
    expect(buildAudience({ profile: null, local: null, uiLocale: "tr" }).language).toBe("tr");
    expect(buildAudience({ profile: null, local: null, uiLocale: "tr" }).country).toBe("fr");
  });

  it("écrit « < 10/20 » pour le cran sous le barème, et le barème du pays ailleurs", () => {
    const below = buildAudience({ profile: { study_level: "lycee", country_code: "fr", sheet_language: null }, local: { currentScore: 9 }, uiLocale: "fr" });
    expect(below.scoreLabel).toBe("< 10/20");
    const german = buildAudience({ profile: { study_level: "lycee", country_code: "de", sheet_language: null }, local: { targetScore: 20 }, uiLocale: "fr" });
    expect(german.targetLabel).toBe("1,0");
    expect(german.language).toBe("de");
  });

  it("ignore un palier local qui ne dit plus le registre du profil", () => {
    // Le registre a changé sur un autre appareil : le « Middle school » d'hier ne gagne pas.
    const audience = buildAudience({
      profile: { study_level: "master", country_code: "us", sheet_language: null },
      local: { stageId: "us.middle", tier: "lowerSecondary" },
      uiLocale: "en",
    });
    expect(audience.level).toBe("master");
    expect(audience.schoolStage).toBe("Graduate school");
    expect(audience).not.toHaveProperty("tier");
  });

  it("garde le collège quand le palier local le précise", () => {
    const audience = buildAudience({
      profile: { study_level: "lycee", country_code: "us", sheet_language: null },
      local: { stageId: "us.middle", tier: "lowerSecondary" },
      uiLocale: "en",
    });
    expect(audience.tier).toBe("lowerSecondary");
    expect(audience.schoolStage).toBe("Middle school");
  });
});

describe("ce que le parcours demande en plus : la filière, l'année, les freins", () => {
  it("envoie la filière et l'année, et leur marche l'emporte sur celle du palier", () => {
    // Un collégien français : le pays n'a que « Lycée » comme palier, la filière dit collège.
    const audience = buildAudience({
      profile: { study_level: "lycee", country_code: "fr", sheet_language: null },
      local: { stageId: "fr.lycee", tier: "upperSecondary", trackId: "fr.college", yearId: "fr.4e", worries: ["forgetting", "examStress", "inconnu"] },
      uiLocale: "fr",
    });
    expect(audience.track).toBe("Collège");
    expect(audience.year).toBe("Quatrième");
    expect(audience.tier).toBe("lowerSecondary");
    expect(audience.schoolStage).toBe("Lycée");
    expect(audience.worries).toEqual(["examStress", "forgetting"]);
  });

  it("monte au master pour une année de master rangée à l'université", () => {
    const audience = buildAudience({
      profile: { study_level: "licence", country_code: "fr", sheet_language: null },
      local: { trackId: "fr.universite", yearId: "fr.m1" },
      uiLocale: "fr",
    });
    expect(audience.tier).toBe("graduate");
    expect(audience.year).toBe("Master 1");
  });

  it("ignore une filière qui ne dit plus le registre ou le pays du profil", () => {
    const changed = buildAudience({
      profile: { study_level: "prepa", country_code: "fr", sheet_language: null },
      local: { trackId: "fr.lyceeGeneral", yearId: "fr.terminale" },
      uiLocale: "fr",
    });
    expect(changed).not.toHaveProperty("track");
    expect(changed).not.toHaveProperty("year");
    const moved = buildAudience({
      profile: { study_level: "lycee", country_code: "us", sheet_language: null },
      local: { trackId: "fr.lyceeGeneral", yearId: "fr.terminale" },
      uiLocale: "en",
    });
    expect(moved).not.toHaveProperty("track");
  });

  it("garde la filière et l'année dans le cookie", () => {
    const raw = writeLearnerCookie({ userId: USER, trackId: "tr.anadolu", yearId: "tr.anadolu.12", worries: ["noStart"] });
    expect(readLearnerCookie(raw, USER)).toEqual({ userId: USER, trackId: "tr.anadolu", yearId: "tr.anadolu.12", worries: ["noStart"] });
    expect(readLearnerCookie(JSON.stringify({ k: "pas une filière", y: 12 }), USER)).toEqual({});
  });
});

describe("profiles.study_level, quelle que soit la main", () => {
  it("lit le registre de l'iPhone, la marche d'Android et le palier de l'ancien site", () => {
    expect(readStudyLevel("prepa")).toEqual({ level: "prepa", tier: null, stageId: null });
    expect(readStudyLevel("lowerSecondary")).toEqual({ level: "lycee", tier: "lowerSecondary", stageId: null });
    expect(readStudyLevel("fr.sante")).toEqual({ level: "sante", tier: "health", stageId: "fr.sante" });
    expect(readStudyLevel("n'importe quoi")).toEqual({ level: null, tier: null, stageId: null });
    expect(readStudyLevel(null).level).toBeNull();
  });

  it("envoie la marche qu'Android a écrite", () => {
    const audience = buildAudience({ profile: { study_level: "graduate", country_code: "tr", sheet_language: null }, local: null, uiLocale: "en" });
    expect(audience.level).toBe("master");
    expect(audience.tier).toBe("graduate");
    expect(audience.language).toBe("tr");
  });

  it("ne garde un palier que dans son pays", () => {
    expect(stageAnswer("fr.prepa", "fr")?.level).toBe("prepa");
    expect(stageAnswer("us.middle", "fr")).toBeNull();
    expect(stageAnswer("generic.high", "other")?.tier).toBe("upperSecondary");
  });
});

describe("le cookie de l'appareil", () => {
  it("relit ce qu'il a écrit, et rien pour un autre compte", () => {
    const raw = writeLearnerCookie({ userId: USER, stageId: "fr.lycee", tier: "upperSecondary", currentScore: 11, targetScore: 15 });
    expect(readLearnerCookie(raw, USER)).toEqual({ userId: USER, stageId: "fr.lycee", tier: "upperSecondary", currentScore: 11, targetScore: 15 });
    expect(readLearnerCookie(raw, "22222222-2222-4222-8222-222222222222")).toBeNull();
  });

  it("jette champ par champ ce qui n'a pas la forme", () => {
    expect(readLearnerCookie("pas du json", USER)).toBeNull();
    expect(readLearnerCookie(JSON.stringify({ s: "xx.inconnu", t: "géant", c: 42, g: 15 }), USER)).toEqual({ targetScore: 15 });
  });
});

describe("les jours travaillés", () => {
  it("allument la journée d'une étape cochée, d'une leçon apprise et d'une copie rendue", () => {
    const days = studyDays({
      reviewDays: ["2026-10-20T08:00:00Z"],
      lessons: [
        { last_opened_at: "2026-10-21T18:00:00Z", progress: { done: ["intro"], seconds: {}, finishedAt: null } },
        // Ouverte, jamais travaillée : elle n'allume rien.
        { last_opened_at: "2026-10-23T09:00:00Z", progress: { done: [], seconds: {}, finishedAt: null } },
        { last_opened_at: null, progress: { done: [], seconds: { notes: 0 }, finishedAt: "2026-10-22T10:00:00Z" } },
      ],
      paperDates: ["2026-10-19T12:00:00Z"],
    });
    expect(days.map((day) => day.toISOString().slice(0, 10)).sort()).toEqual(["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22"]);
  });
});
