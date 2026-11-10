import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { DAILY_XP_CAP, DAILY_XP_GOAL, FOCUS_MINUTES, LEAGUES, XP_REWARDS } from "../src/xp";

/**
 * **L'XP compte pareil partout.** Relit `XPRules.swift` et `Xp.kt`, et tombe si un chiffre
 * diverge de `src/xp.ts` : un élève qui passe de l'iPhone au site ne doit pas voir sa ligue
 * changer parce qu'une bonne réponse vaut 10 ici et 8 là.
 */
const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..");
const swift = readFileSync(resolve(root, "Micabo/Services/XP/XPRules.swift"), "utf8");
const kotlin = readFileSync(resolve(root, "android/app/src/main/java/com/micabo/app/data/Xp.kt"), "utf8");

const constants: Record<string, number> = {
  ...XP_REWARDS,
  dailyGoal: DAILY_XP_GOAL,
  dailyCap: DAILY_XP_CAP,
  focusMinutes: FOCUS_MINUTES,
};

function screaming(name: string): string {
  return name.replace(/([A-Z])/g, "_$1").toUpperCase();
}

describe("xp parity", () => {
  for (const [name, value] of Object.entries(constants)) {
    it(`${name} = ${value} en Swift et en Kotlin`, () => {
      expect(swift).toMatch(new RegExp(`static let ${name} = ${value}\\b`));
      expect(kotlin).toMatch(new RegExp(`const val ${screaming(name)} = ${value}\\b`));
    });
  }

  it("les mêmes ligues, dans le même ordre", () => {
    const swiftLeagues = [...swift.matchAll(/XPLeague\(id: "(\w+)", floor: (\d+)\)/g)].map((m) => [m[1], Number(m[2])]);
    const kotlinLeagues = [...kotlin.matchAll(/XpLeague\("(\w+)", (\d+)\)/g)].map((m) => [m[1], Number(m[2])]);
    const expected = LEAGUES.map((league) => [league.id, league.floor]);
    expect(swiftLeagues).toEqual(expected);
    expect(kotlinLeagues).toEqual(expected);
  });
});
