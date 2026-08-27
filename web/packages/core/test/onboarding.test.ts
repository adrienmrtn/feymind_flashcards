/**
 * Les données du parcours d'accueil.
 *
 * Les invariants viennent de `MicaboTests/OnboardingFlowTests.swift`, et deux d'entre eux valent
 * plus que tous les autres : **une matière, un emoji**, et **un palier retrouvé quand on change de
 * pays**. Le premier tient la lisibilité d'un écran de cinquante pastilles ; le second empêche de
 * reposer à un lycéen français, devenu américain, une question à laquelle il a déjà répondu.
 */

import { describe, expect, it } from "vitest";

import { FALLBACK_EMOJI, deriveEmoji, resolveEmoji } from "../src/emoji";
import {
  COUNTRIES,
  FALLBACK_COUNTRY,
  countryFor,
  flagFor,
  guessCountry,
  languageFor,
  sheetLanguage,
} from "../src/onboarding/countries";
import {
  TIER_LADDER,
  resolveStage,
  stagesFor,
  type EducationStage,
} from "../src/onboarding/stages";
import { ALL_SUBJECTS, SUBJECT_FAMILIES, subjectEmoji } from "../src/onboarding/subjects";

describe("les matières", () => {
  it("ne partagent jamais un emoji, et aucune ne retombe sur le livre générique", () => {
    const seen = new Map<string, string>();

    for (const subject of ALL_SUBJECTS) {
      const emoji = subjectEmoji(subject);

      expect(emoji, `${subject} retombe sur le livre générique`).not.toBe(FALLBACK_EMOJI);

      const other = seen.get(emoji);
      expect(other, `${subject} et ${other} portent le même emoji ${emoji}`).toBeUndefined();
      seen.set(emoji, subject);
    }

    expect(seen.size).toBe(ALL_SUBJECTS.length);
  });

  it("sont sept familles, sans doublon d'une famille à l'autre", () => {
    expect(SUBJECT_FAMILIES).toHaveLength(7);
    expect(new Set(ALL_SUBJECTS).size).toBe(ALL_SUBJECTS.length);
  });

  it("donnent son drapeau à chaque langue vivante", () => {
    // Un drapeau se reconnaît sans lire, et c'est tout ce qu'on demande à un emoji sur une
    // pastille. Les langues anciennes n'en ont pas : le drapeau d'un pays qui n'existait pas ne
    // dirait rien.
    expect(subjectEmoji("Espagnol")).toBe("🇪🇸");
    expect(subjectEmoji("Anglais")).toBe("🇬🇧");
    expect(subjectEmoji("Allemand")).toBe("🇩🇪");
    expect(subjectEmoji("Japonais")).toBe("🇯🇵");
    expect(subjectEmoji("Latin & grec")).toBe("🏺");
  });

  it("laissent une entrée précise passer devant une entrée large", () => {
    // « Code de la route » contenait « code » et sortait un ordinateur portable.
    expect(subjectEmoji("Code de la route")).toBe("🚗");
    expect(subjectEmoji("Statistiques")).toBe("📊");
    expect(subjectEmoji("Mécanique")).toBe("⚙️");
    expect(subjectEmoji("Génie civil")).toBe("🏗️");
    expect(subjectEmoji("Théâtre")).toBe("🎭");
    expect(subjectEmoji("Photographie")).toBe("📷");
    expect(subjectEmoji("Français")).toBe("📖");
  });
});

describe("l'emoji d'un cours", () => {
  it("attrape ce qui parle de langue sans nommer laquelle", () => {
    expect(deriveEmoji("LV2", "Thème grammatical")).toBe("🗣️");
  });

  it("ignore les accents et la casse", () => {
    expect(deriveEmoji(null, "PHOTOSYNTHÈSE")).toBe("🌿");
    expect(deriveEmoji(null, "Géologie structurale")).toBe("🪨");
  });

  it("retombe sur le livre quand rien ne correspond", () => {
    expect(deriveEmoji(null, "Zzzz")).toBe(FALLBACK_EMOJI);
  });

  it("garde la proposition du modèle, sauf si elle ne dit rien", () => {
    expect(resolveEmoji("🌊", "SVT", "Le cycle de l'eau")).toBe("🌊");
    expect(resolveEmoji("📘", "SVT", "Le cycle de l'eau")).toBe("🧬");
    expect(resolveEmoji("📝", "SVT", "Le cycle de l'eau")).toBe("🧬");
    expect(resolveEmoji("  ", "Chimie", "Les acides")).toBe("🧪");
  });
});

describe("les pays", () => {
  it("proposent tous des paliers, terminés par une sortie", () => {
    for (const country of COUNTRIES) {
      const stages = stagesFor(country.code);
      expect(stages.length, country.name).toBeGreaterThanOrEqual(4);
      expect(stages[stages.length - 1]!.tier, country.name).toBe("other");
    }
  });

  it("portent des identifiants de palier uniques et préfixés", () => {
    const all = new Set<string>();
    for (const country of COUNTRIES) {
      for (const item of stagesFor(country.code)) {
        // Le générique est partagé par « Ailleurs » : on ne le compte qu'une fois.
        if (item.id.startsWith("generic.")) continue;
        expect(all.has(item.id), item.id).toBe(false);
        all.add(item.id);
        expect(item.id.startsWith(`${country.code}.`), item.id).toBe(true);
      }
    }
  });

  it("décident de la langue dans laquelle Micabo écrit", () => {
    expect(languageFor("fr")).toBe("fr");
    expect(languageFor("ca")).toBe("fr");
    expect(languageFor("us")).toBe("en");
    expect(languageFor("other")).toBe("en");
  });

  it("laisse un réglage de fiche gagner sur le pays", () => {
    expect(sheetLanguage("pl", "fr")).toBe("pl");
    expect(sheetLanguage(null, "us")).toBe("en");
    expect(sheetLanguage("zz", "fr")).toBe("fr");
  });

  it("retombent sur la France quand on ne sait pas", () => {
    expect(countryFor(null).code).toBe(FALLBACK_COUNTRY);
    expect(countryFor("zz").code).toBe(FALLBACK_COUNTRY);
  });

  it("commencent par les marchés visés, dans l'ordre voulu", () => {
    // L'ordre de la table **est** l'ordre d'affichage, donc il se verrouille ici : le remonter au
    // hasard casserait une intention, et une liste de pays réordonnée par erreur ne se voit pas.
    expect(COUNTRIES.slice(0, 14).map((item) => item.name)).toEqual([
      "France",
      "Royaume-Uni",
      "Allemagne",
      "Italie",
      "Espagne",
      "Portugal",
      "Tchéquie",
      "Pays-Bas",
      "Grèce",
      "Hongrie",
      "Pologne",
      "Roumanie",
      "Suède",
      "Turquie",
    ]);
  });

  it("mettent « Autre pays » en dernier, et lui seul sans code ISO", () => {
    const last = COUNTRIES[COUNTRIES.length - 1]!;
    expect(last.code).toBe("other");
    expect(COUNTRIES.filter((item) => item.iso === "")).toHaveLength(1);
  });

  it("écrivent dans la langue du pays, pas en anglais par défaut", () => {
    // C'est ce que la fonction Edge sait servir : quatorze langues, et le polonais n'est pas
    // « de l'anglais pour un Polonais ».
    expect(languageFor("de")).toBe("de");
    expect(languageFor("cz")).toBe("cs");
    expect(languageFor("gr")).toBe("el");
    expect(languageFor("se")).toBe("sv");
    expect(languageFor("pl")).toBe("pl");
  });

  it("portent chacun un drapeau qui se déduit de leur code ISO", () => {
    for (const item of COUNTRIES) {
      if (!item.iso) continue;
      expect(flagFor(item.iso), item.name).toBe(item.flag);
    }
  });

  it("rendent le globe pour un code qui n'est pas un pays", () => {
    expect(flagFor("")).toBe("🌍");
    expect(flagFor("zzz")).toBe("🌍");
    expect(flagFor("1f")).toBe("🌍");
  });
});

describe("le pays deviné depuis la locale", () => {
  it("lit la région, pas la langue", () => {
    expect(guessCountry(["fr-BE"])).toBe("be");
    expect(guessCountry(["en-GB"])).toBe("uk");
    expect(guessCountry(["fr-CA", "en-US"])).toBe("ca");
  });

  it("ignore une locale sans région et retombe sur le défaut", () => {
    expect(guessCountry(["fr"])).toBe(FALLBACK_COUNTRY);
    expect(guessCountry([])).toBe(FALLBACK_COUNTRY);
    // Un pays qu'on ne connaît pas n'est pas « Ailleurs » par défaut : on préfère la France, et
    // la question reste posée de toute façon.
    expect(guessCountry(["ja-JP"])).toBe(FALLBACK_COUNTRY);
  });
});

describe("changer de pays sans reposer la question", () => {
  function titled(stage: EducationStage | null): string | null {
    return stage?.title ?? null;
  }

  it("garde le palier quand l'identifiant vient du même pays", () => {
    expect(titled(resolveStage("fr", { id: "fr.prepa" }))).toBe("Prépa");
  });

  it("fait d'un lycéen français un high schooler américain", () => {
    // Et surtout **pas** un middle schooler : c'est l'erreur que la marche existe pour éviter.
    expect(titled(resolveStage("us", { tier: "upperSecondary" }))).toBe("High school");
  });

  it("fait retrouver la filière santé locale", () => {
    expect(titled(resolveStage("uk", { tier: "health" }))).toBe("Medicine");
    expect(titled(resolveStage("ca", { tier: "health" }))).toBe("Médecine, santé");
  });

  it("monte à la marche la plus proche quand l'équivalent exact n'existe pas", () => {
    // La prépa n'a pas d'équivalent britannique. « Undergraduate » sert mieux qu'une question
    // reposée, et on monte plutôt que de descendre : un palier au-dessus se rattrape en lisant.
    expect(titled(resolveStage("uk", { tier: "preUniversity" }))).toBe("Undergraduate");
  });

  it("ne convertit jamais une voie en marche", () => {
    // Le Luxembourg n'a ni filière santé ni concours dans la liste : plutôt qu'inventer, on
    // redemande.
    expect(resolveStage("lu", { tier: "health" })).toBeNull();
    expect(resolveStage("lu", { tier: "competitive" })).toBeNull();
  });

  it("se rabat sur le registre, seule chose que le cloud transporte", () => {
    // Le profil rendu par le cloud ne porte que `study_level`. Prendre le premier palier du
    // registre ramenait un « lycee » américain sur « Middle school », et un « lycee » québécois
    // sur « Cégep », qui est post-secondaire.
    expect(titled(resolveStage("us", { level: "lycee" }))).toBe("High school");
    expect(titled(resolveStage("ca", { level: "lycee" }))).toBe("Secondaire");
    expect(titled(resolveStage("fr", { level: "sante" }))).toBe("PASS, santé");
  });

  it("préfère l'identifiant au palier, et le palier au registre", () => {
    const stage = resolveStage("fr", { id: "fr.master", tier: "upperSecondary", level: "licence" });
    expect(titled(stage)).toBe("Master");
  });

  it("a une échelle de cinq marches, dans l'ordre", () => {
    expect(TIER_LADDER).toEqual([
      "lowerSecondary",
      "upperSecondary",
      "preUniversity",
      "undergraduate",
      "graduate",
    ]);
  });
});
