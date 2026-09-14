import { describe, expect, it } from "vitest";

import { APP_STORE_URL, isIphoneUserAgent, wantsIphoneLanding } from "./iphone";

/** Les agents tels qu'ils arrivent, un par appareil qui nous intéresse. */
const AGENTS = {
  safari:
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1",
  chromeIos:
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/131.0.6778.73 Mobile/15E148 Safari/604.1",
  firefoxIos:
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/133.0 Mobile/15E148 Safari/605.1.15",
  ipad:
    "Mozilla/5.0 (iPad; CPU OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/604.1",
  mac:
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  android:
    "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36",
  applebot:
    "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1 (Applebot/0.1; +http://www.apple.com/go/applebot)",
  googlebot:
    "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
} as const;

describe("isIphoneUserAgent", () => {
  it("reconnaît l'iPhone, quel que soit le navigateur posé dessus", () => {
    expect(isIphoneUserAgent(AGENTS.safari)).toBe(true);
    expect(isIphoneUserAgent(AGENTS.chromeIos)).toBe(true);
    expect(isIphoneUserAgent(AGENTS.firefoxIos)).toBe(true);
  });

  it("laisse l'iPad, le Mac et l'Android sur la vitrine", () => {
    // Safari sur iPad se déclare `Macintosh` depuis iPadOS 13, et l'écran est celui d'un
    // bureau : les deux cas doivent retomber du même côté.
    expect(isIphoneUserAgent(AGENTS.ipad)).toBe(false);
    expect(isIphoneUserAgent(AGENTS.mac)).toBe(false);
    expect(isIphoneUserAgent(AGENTS.android)).toBe(false);
  });

  it("rend la vitrine aux robots, Applebot compris", () => {
    // Applebot explore avec un agent d'iPhone. S'il tombait sur la page de téléchargement,
    // l'adresse qui porte le référencement du site ne serait plus qu'un bouton.
    expect(isIphoneUserAgent(AGENTS.applebot)).toBe(false);
    expect(isIphoneUserAgent(AGENTS.googlebot)).toBe(false);
  });

  it("ne suppose rien quand l'agent manque", () => {
    expect(isIphoneUserAgent(null)).toBe(false);
    expect(isIphoneUserAgent(undefined)).toBe(false);
    expect(isIphoneUserAgent("")).toBe(false);
  });
});

describe("wantsIphoneLanding", () => {
  it("bascule sur la page de téléchargement depuis un iPhone", () => {
    expect(wantsIphoneLanding(AGENTS.safari, {})).toBe(true);
  });

  it("rend la vitrine complète dès que `?web` est là", () => {
    expect(wantsIphoneLanding(AGENTS.safari, { web: "1" })).toBe(false);
    expect(wantsIphoneLanding(AGENTS.safari, { web: "" })).toBe(false);
  });

  it("n'a rien à faire sur les autres appareils", () => {
    expect(wantsIphoneLanding(AGENTS.mac, {})).toBe(false);
    expect(wantsIphoneLanding(AGENTS.android, { web: "1" })).toBe(false);
  });
});

describe("l'adresse de l'app", () => {
  it("pointe la fiche App Store de Micabo, en HTTPS", () => {
    expect(APP_STORE_URL).toMatch(/^https:\/\/apps\.apple\.com\//);
    expect(APP_STORE_URL).toContain("id6806651497");
  });
});
