import { describe, expect, it } from "vitest";

import {
  addXp,
  DAILY_XP_CAP,
  leagueFor,
  pruneLedger,
  weekStart,
  xpThisWeek,
  xpToday,
  xpToNextLeague,
} from "../src/xp";

describe("xp", () => {
  it("compte la semaine à partir du lundi", () => {
    // Mercredi 11 novembre 2026.
    expect(weekStart(new Date(2026, 10, 11))).toBe("2026-11-09");
    // Un dimanche appartient à la semaine commencée six jours plus tôt.
    expect(weekStart(new Date(2026, 10, 15))).toBe("2026-11-09");
    expect(weekStart(new Date(2026, 10, 9))).toBe("2026-11-09");
  });

  it("additionne le jour et la semaine", () => {
    let ledger = addXp({}, 10, new Date(2026, 10, 8)); // dimanche d'avant
    ledger = addXp(ledger, 25, new Date(2026, 10, 9));
    ledger = addXp(ledger, 15, new Date(2026, 10, 11));
    const now = new Date(2026, 10, 11, 18);
    expect(xpToday(ledger, now)).toBe(15);
    expect(xpThisWeek(ledger, now)).toBe(40);
  });

  it("plafonne un jour", () => {
    const ledger = addXp({ "2026-11-11": DAILY_XP_CAP - 5 }, 100, new Date(2026, 10, 11));
    expect(ledger["2026-11-11"]).toBe(DAILY_XP_CAP);
  });

  it("range dans la bonne ligue", () => {
    expect(leagueFor(0)).toBe("bronze");
    expect(leagueFor(199)).toBe("bronze");
    expect(leagueFor(200)).toBe("silver");
    expect(leagueFor(2500)).toBe("diamond");
    expect(xpToNextLeague(150)).toEqual({ next: "silver", missing: 50 });
    expect(xpToNextLeague(3000)).toBeNull();
  });

  it("oublie les vieux jours", () => {
    const pruned = pruneLedger({ "2026-10-01": 50, "2026-11-10": 20 }, new Date(2026, 10, 11));
    expect(pruned).toEqual({ "2026-11-10": 20 });
  });
});
