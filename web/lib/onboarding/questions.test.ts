import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { COUNTRIES, stagesFor } from "@micabo/core";

import { cleanWorries, DAILY_MINUTES, isDailyMinutes, isExamDate, WORRY_IDS } from "./questions";
import { isDetailedCountry, stageOfTrack, trackById, tracksFor, trackTier, yearById } from "./school-system";

describe("les freins", () => {
  it("sont exactement ceux que generate-lesson connaît", () => {
    // Un frein que le serveur ne connaît pas est jeté en silence : la question ne servirait à rien.
    const server = readFileSync(join(process.cwd(), "..", "supabase", "functions", "_shared", "learner.ts"), "utf8");
    const declared = /export type Worry = ([^;]+);/.exec(server)?.[1] ?? "";
    const known = [...declared.matchAll(/"(\w+)"/g)].map((match) => match[1]);
    expect([...WORRY_IDS].sort()).toEqual(known.sort());
  });

  it("se nettoient : sans doublon, sans inconnu, dans l'ordre de la liste", () => {
    expect(cleanWorries(["motivation", "examStress", "motivation", "nope", 3])).toEqual(["examStress", "motivation"]);
    expect(cleanWorries(undefined)).toEqual([]);
  });
});

describe("le temps par jour", () => {
  it("garde les quatre crans de l'iPhone, et rien d'autre", () => {
    expect(DAILY_MINUTES.map((choice) => choice.minutes)).toEqual([5, 10, 15, 30]);
    expect(isDailyMinutes(15)).toBe(true);
    expect(isDailyMinutes(20)).toBe(false);
    expect(isDailyMinutes("15")).toBe(false);
  });
});

describe("la date d'examen", () => {
  const today = new Date("2026-10-23T10:00:00Z");

  it("accepte aujourd'hui et les trois années qui suivent", () => {
    expect(isExamDate("2026-10-23", today)).toBe(true);
    expect(isExamDate("2027-06-15", today)).toBe(true);
    // Un jour de marge : le soir à l'ouest, UTC est déjà au lendemain.
    expect(isExamDate("2026-10-22", today)).toBe(true);
  });

  it("refuse le passé, le trop lointain et ce qui n'est pas une date", () => {
    expect(isExamDate("2026-10-01", today)).toBe(false);
    expect(isExamDate("2031-01-01", today)).toBe(false);
    expect(isExamDate("2027-02-30", today)).toBe(false);
    expect(isExamDate("demain", today)).toBe(false);
    expect(isExamDate(undefined, today)).toBe(false);
  });
});

describe("les filières et les années", () => {
  it("décrivent les quatre pays de l'iPhone, et eux seuls", () => {
    const detailed = COUNTRIES.map((country) => country.code).filter(isDetailedCountry);
    expect(detailed.sort()).toEqual(["de", "es", "fr", "tr"]);
  });

  it("ont des identifiants préfixés par leur pays, uniques, et des années partout", () => {
    for (const code of ["fr", "tr", "de", "es"]) {
      const tracks = tracksFor(code);
      const ids = tracks.flatMap((track) => [track.id, ...track.years.map((year) => year.id)]);
      expect(new Set(ids).size).toBe(ids.length);
      expect(ids.every((id) => id.startsWith(`${code}.`))).toBe(true);
      expect(tracks.every((track) => track.years.length > 0)).toBe(true);
    }
  });

  it("ne se lisent que dans leur pays", () => {
    expect(trackById("fr.prepa", "fr")?.title).toBe("Prépa");
    expect(trackById("fr.prepa", "tr")).toBeNull();
    expect(yearById("fr.terminale", trackById("fr.lyceeGeneral", "fr"))?.title).toBe("Terminale");
    expect(yearById("fr.terminale", trackById("fr.prepa", "fr"))).toBeNull();
  });

  it("donnent la marche de l'année : un master reste un master, un collège un collège", () => {
    const universite = trackById("fr.universite", "fr")!;
    expect(trackTier(universite, yearById("fr.m1", universite))).toBe("graduate");
    expect(trackTier(universite, yearById("fr.l2", universite))).toBe("undergraduate");
    expect(trackTier(trackById("fr.college", "fr")!, null)).toBe("lowerSecondary");
  });

  it("retombent sur un palier du pays pour study_level et schoolStage", () => {
    const stage = stageOfTrack("fr", trackById("fr.lyceeTechno", "fr")!);
    expect(stage?.id).toBe("fr.lycee");
    expect(stagesFor("fr").some((candidate) => candidate.id === stage?.id)).toBe(true);
    expect(stageOfTrack("de", trackById("de.gymnasium", "de")!)?.id).toBe("de.abitur");
  });
});
