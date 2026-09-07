import { describe, expect, it } from "vitest";

import { UI_LOCALES } from "./locales";
import {
  INDEXABLE_PATHS,
  languageAlternatePaths,
  localeSwitchHref,
  localizedPath,
  resolveLocaleRequest,
  splitLocalePrefix,
  stripLocalePrefix,
} from "./paths";

describe("localizedPath", () => {
  it("laisse le français sans préfixe", () => {
    expect(localizedPath("fr", "/")).toBe("/");
    expect(localizedPath("fr", "/methode")).toBe("/methode");
    expect(localizedPath("fr", "/tr/methode")).toBe("/methode");
  });

  it("préfixe de, es, tr", () => {
    expect(localizedPath("tr", "/")).toBe("/tr");
    expect(localizedPath("tr", "/methode")).toBe("/tr/methode");
    expect(localizedPath("de", "/mode-examen")).toBe("/de/mode-examen");
    expect(localizedPath("es", "/confidentialite")).toBe("/es/confidentialite");
  });
});

describe("splitLocalePrefix", () => {
  it("reconnaît un préfixe et le reste", () => {
    expect(splitLocalePrefix("/tr/methode")).toEqual({ prefix: "tr", rest: "/methode" });
    expect(splitLocalePrefix("/de")).toEqual({ prefix: "de", rest: "/" });
    expect(splitLocalePrefix("/methode")).toEqual({ prefix: null, rest: "/methode" });
    expect(splitLocalePrefix("/fr/methode")).toEqual({ prefix: "fr", rest: "/methode" });
  });
});

describe("resolveLocaleRequest", () => {
  it("redirige /fr vers la version sans préfixe", () => {
    expect(resolveLocaleRequest("/fr")).toEqual({
      action: "redirect",
      location: "/",
      status: 301,
    });
    expect(resolveLocaleRequest("/fr/methode")).toEqual({
      action: "redirect",
      location: "/methode",
      status: 301,
    });
  });

  it("réécrit /tr/methode en /methode, langue turque", () => {
    expect(resolveLocaleRequest("/tr/methode")).toEqual({
      action: "continue",
      pathname: "/methode",
      urlLocale: "tr",
      setCookie: "tr",
    });
  });

  it("force le français sur une page publique sans préfixe", () => {
    expect(resolveLocaleRequest("/methode")).toEqual({
      action: "continue",
      pathname: "/methode",
      urlLocale: "fr",
    });
    expect(resolveLocaleRequest("/")).toEqual({
      action: "continue",
      pathname: "/",
      urlLocale: "fr",
    });
  });

  it("renvoie /tr/app vers /app et pose le cookie", () => {
    expect(resolveLocaleRequest("/tr/app")).toEqual({
      action: "redirect",
      location: "/app",
      status: 302,
      setCookie: "tr",
    });
    expect(resolveLocaleRequest("/de/commencer/bienvenue")).toEqual({
      action: "redirect",
      location: "/commencer/bienvenue",
      status: 302,
      setCookie: "de",
    });
  });

  it("laisse /app et /commencer au cookie", () => {
    expect(resolveLocaleRequest("/app")).toEqual({
      action: "continue",
      pathname: "/app",
      urlLocale: null,
    });
    expect(resolveLocaleRequest("/commencer/compte")).toEqual({
      action: "continue",
      pathname: "/commencer/compte",
      urlLocale: null,
    });
  });
});

describe("localeSwitchHref", () => {
  it("navigue sur une page indexable, reste dans l'app", () => {
    expect(localeSwitchHref("/methode", "tr")).toBe("/tr/methode");
    expect(localeSwitchHref("/tr/methode", "fr")).toBe("/methode");
    expect(localeSwitchHref("/tr", "de")).toBe("/de");
    expect(localeSwitchHref("/app", "tr")).toBeNull();
    expect(localeSwitchHref("/commencer/compte", "de")).toBeNull();
  });
});

describe("hreflang", () => {
  it("est réciproque sur chaque page indexable", () => {
    for (const path of INDEXABLE_PATHS) {
      const map = languageAlternatePaths(path);
      expect(Object.keys(map).sort()).toEqual(["de", "es", "fr", "tr", "x-default"].sort());
      expect(map["x-default"]).toBe(map.fr);
      expect(map.fr).toBe(localizedPath("fr", path));
      expect(stripLocalePrefix(map.tr)).toBe(path === "/" ? "/" : path);
      for (const locale of UI_LOCALES) {
        const again = languageAlternatePaths(localizedPath(locale, path));
        expect(again).toEqual(map);
      }
    }
  });
});
