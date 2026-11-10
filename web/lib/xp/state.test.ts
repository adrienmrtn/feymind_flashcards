import { DAILY_XP_CAP, DAILY_XP_GOAL, XP_REWARDS } from "@micabo/core";
import { describe, expect, it } from "vitest";

import { CATALOGS } from "@/lib/i18n/catalogs";
import { lookup, type MessageTree } from "@/lib/i18n/format";
import { UI_LOCALE_META, UI_LOCALES } from "@/lib/i18n/locales";
import { makeTranslator } from "@/lib/i18n/translate";

import { applyAward, daysUntilWeekEnd, emptyXpState, isMissingXpColumn, mergeRemote, readXpState, xpSnapshot, XP_WEEK_MAX } from "./state";

/** Mardi 10 novembre 2026, 15 h, heure locale : la semaine a commencé lundi 9. */
const TUESDAY = new Date(2026, 10, 10, 15, 0, 0);

describe("l'XP du site", () => {
  it("compte un geste au jour local, au total et dans ce qui reste à monter", () => {
    const award = applyAward(emptyXpState(TUESDAY), "correctAnswer", TUESDAY);
    expect(award.gained).toBe(XP_REWARDS.correctAnswer);
    expect(award.state.ledger).toEqual({ "2026-11-10": 10 });
    expect(award.state.total).toBe(10);
    expect(award.state.pending).toEqual({ total: 10, week: 10, weekStart: "2026-11-09" });
    expect(xpSnapshot(award.state, TUESDAY)).toEqual({ today: 10, week: 10, total: 10, league: "bronze" });
  });

  it("fête l'objectif du jour une seule fois", () => {
    let state = emptyXpState(TUESDAY);
    const celebrations: boolean[] = [];
    for (let index = 0; index < 8; index += 1) {
      const award = applyAward(state, "correctAnswer", TUESDAY);
      state = award.state;
      celebrations.push(award.reachedGoal);
    }
    // 10, 20, 30, 40, 50 : l'objectif tombe à la cinquième bonne réponse, et pas après.
    expect(DAILY_XP_GOAL).toBe(50);
    expect(celebrations).toEqual([false, false, false, false, true, false, false, false]);
    expect(state.celebrated).toBe("2026-11-10");
    // Le lendemain, la fête peut revenir.
    const wednesday = new Date(2026, 10, 11, 9);
    let next = state;
    let celebrated = false;
    for (let index = 0; index < 5; index += 1) {
      const award = applyAward(next, "correctAnswer", wednesday);
      next = award.state;
      celebrated ||= award.reachedGoal;
    }
    expect(celebrated).toBe(true);
  });

  it("s'arrête au plafond du jour", () => {
    const capped = { ...emptyXpState(TUESDAY), ledger: { "2026-11-10": DAILY_XP_CAP } };
    const award = applyAward(capped, "mockExamFinished", TUESDAY);
    expect(award.gained).toBe(0);
    expect(award.state).toBe(capped);
  });

  it("relit un état abîmé sans tomber", () => {
    expect(readXpState("n'importe quoi", TUESDAY)).toEqual(emptyXpState(TUESDAY));
    const state = readXpState({ ledger: { "2026-11-10": 12, bad: 4, "2026-11-09": -3 }, total: "x", pending: { total: 5 } }, TUESDAY);
    expect(state.ledger).toEqual({ "2026-11-10": 12 });
    expect(state.total).toBe(0);
    expect(state.pending).toEqual({ total: 5, week: 0, weekStart: "2026-11-09" });
  });

  it("ajoute ce qui reste à monter à la ligne lue, sans jamais descendre sous ce que le navigateur sait", () => {
    const state = { ...emptyXpState(TUESDAY), ledger: { "2026-11-09": 40, "2026-11-10": 30 }, total: 300, pending: { total: 30, week: 30, weekStart: "2026-11-09" } };
    // Le téléphone a écrit 500 au total et 100 cette semaine.
    expect(mergeRemote({ xp_total: 500, xp_week: 100, xp_week_start: "2026-11-09" }, state, TUESDAY)).toEqual({ xp_total: 530, xp_week: 130, xp_week_start: "2026-11-09" });
    // Une semaine finie compte zéro ; la semaine du navigateur (70) l'emporte.
    expect(mergeRemote({ xp_total: 500, xp_week: 900, xp_week_start: "2026-11-02" }, state, TUESDAY)).toEqual({ xp_total: 530, xp_week: 70, xp_week_start: "2026-11-09" });
    // Pas de ligne lisible : ce que le navigateur sait.
    expect(mergeRemote(null, state, TUESDAY)).toEqual({ xp_total: 300, xp_week: 70, xp_week_start: "2026-11-09" });
    // Les bornes de la contrainte `profiles_xp_bounds`.
    expect(mergeRemote({ xp_total: 0, xp_week: XP_WEEK_MAX, xp_week_start: "2026-11-09" }, state, TUESDAY).xp_week).toBe(XP_WEEK_MAX);
  });

  it("reconnaît une colonne `xp_*` qui n'existe pas encore", () => {
    expect(isMissingXpColumn({ code: "42703", message: "column profiles.xp_total does not exist" })).toBe(true);
    expect(isMissingXpColumn({ code: "PGRST204", message: "Could not find the 'xp_week' column of 'profiles' in the schema cache" })).toBe(true);
    expect(isMissingXpColumn({ code: "42501", message: "permission denied" })).toBe(false);
    expect(isMissingXpColumn(null)).toBe(false);
  });

  it("compte les jours jusqu'à lundi minuit", () => {
    expect(daysUntilWeekEnd(TUESDAY)).toBe(6);
    expect(daysUntilWeekEnd(new Date(2026, 10, 15, 22))).toBe(1);
    expect(daysUntilWeekEnd(new Date(2026, 10, 9, 0, 1))).toBe(7);
  });
});

describe("les textes du lot « Knowunity »", () => {
  it("se forment dans chaque langue, pluriels compris", () => {
    const keys: [string, Record<string, number | string>][] = [
      ["app.kx.today.cardsDue", { count: 1 }],
      ["app.kx.today.cardsDue", { count: 3 }],
      ["app.kx.today.cardsDue", { count: 25 }],
      ["app.kx.league.endsIn", { days: 1 }],
      ["app.kx.league.endsIn", { days: 6 }],
      ["app.kx.tools.quizSub", { n: 5 }],
      ["app.kx.timer.doneBody", { n: 25 }],
      ["app.kx.league.toNext", { n: 120, league: "Silver" }],
      ["app.kx.xpGain", { n: 10 }],
    ];
    for (const locale of UI_LOCALES) {
      const tree = CATALOGS[locale] as unknown as MessageTree;
      const t = makeTranslator(locale, tree, CATALOGS.en as unknown as MessageTree);
      for (const [key, values] of keys) {
        expect(lookup(tree, key), `${locale}:${key}`).toBeTruthy();
        const text = t(key, values);
        expect(text, `${locale}:${key}`).not.toMatch(/[{}]/);
        const number = Object.values(values).find((value) => typeof value === "number") as number;
        if (number > 2) expect(text, `${locale}:${key}`).toContain(new Intl.NumberFormat(UI_LOCALE_META[locale].bcp47).format(number));
      }
    }
  });
});
