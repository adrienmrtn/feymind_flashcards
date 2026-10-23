import { describe, expect, it } from "vitest";

import { UI_LOCALES, UI_LOCALE_META } from "./locales";
import {
  INDEXABLE_PATHS,
  URL_PREFIX_LOCALES,
  forwardedUrlLocale,
  languageAlternatePaths,
  localeSwitchHref,
  localizedPath,
  resolveLocaleRequest,
  splitLocalePrefix,
  stripLocalePrefix,
} from "./paths";

describe("localizedPath", () => {
  it("laisse l'anglais sans préfixe", () => {
    expect(localizedPath("en", "/")).toBe("/");
    expect(localizedPath("en", "/methode")).toBe("/methode");
    expect(localizedPath("en", "/fr/methode")).toBe("/methode");
  });

  it("préfixe fr, de, es, tr", () => {
    expect(localizedPath("fr", "/")).toBe("/fr");
    expect(localizedPath("fr", "/methode")).toBe("/fr/methode");
    expect(localizedPath("tr", "/")).toBe("/tr");
    expect(localizedPath("tr", "/methode")).toBe("/tr/methode");
    expect(localizedPath("de", "/mode-examen")).toBe("/de/mode-examen");
    expect(localizedPath("es", "/confidentialite")).toBe("/es/confidentialite");
  });

  it("préfixe les vingt-cinq autres langues, en minuscules", () => {
    expect(URL_PREFIX_LOCALES).toHaveLength(25);
    expect(URL_PREFIX_LOCALES).not.toContain("en");
    expect(localizedPath("pt-BR", "/")).toBe("/pt-br");
    expect(localizedPath("pt-BR", "/methode")).toBe("/pt-br/methode");
    expect(localizedPath("es-419", "/mode-examen")).toBe("/es-419/mode-examen");
    expect(localizedPath("ar", "/conditions")).toBe("/ar/conditions");
    expect(localizedPath("it", "/pt-br/methode")).toBe("/it/methode");
    for (const locale of URL_PREFIX_LOCALES) {
      const path = localizedPath(locale, "/methode");
      expect(path, locale).toBe(`/${locale.toLowerCase()}/methode`);
      expect(splitLocalePrefix(path), locale).toEqual({ prefix: locale, rest: "/methode" });
    }
  });
});

describe("splitLocalePrefix", () => {
  it("reconnaît un préfixe et le reste", () => {
    expect(splitLocalePrefix("/tr/methode")).toEqual({ prefix: "tr", rest: "/methode" });
    expect(splitLocalePrefix("/de")).toEqual({ prefix: "de", rest: "/" });
    expect(splitLocalePrefix("/methode")).toEqual({ prefix: null, rest: "/methode" });
    expect(splitLocalePrefix("/fr/methode")).toEqual({ prefix: "fr", rest: "/methode" });
    expect(splitLocalePrefix("/en/methode")).toEqual({ prefix: "en", rest: "/methode" });
    expect(splitLocalePrefix("/pt-br/methode")).toEqual({ prefix: "pt-BR", rest: "/methode" });
    expect(splitLocalePrefix("/pt-BR")).toEqual({ prefix: "pt-BR", rest: "/" });
    expect(splitLocalePrefix("/es-419/conditions")).toEqual({ prefix: "es-419", rest: "/conditions" });
    expect(splitLocalePrefix("/pt-pt/methode")).toEqual({ prefix: null, rest: "/pt-pt/methode" });
  });
});

describe("resolveLocaleRequest", () => {
  it("redirige /en vers la version sans préfixe", () => {
    expect(resolveLocaleRequest("/en")).toEqual({
      action: "redirect",
      location: "/",
      status: 301,
    });
    expect(resolveLocaleRequest("/en/methode")).toEqual({
      action: "redirect",
      location: "/methode",
      status: 301,
    });
  });

  it("sert le français sur /fr, sans rediriger", () => {
    expect(resolveLocaleRequest("/fr")).toEqual({
      action: "continue",
      pathname: "/",
      urlLocale: "fr",
      setCookie: "fr",
    });
    expect(resolveLocaleRequest("/fr/methode")).toEqual({
      action: "continue",
      pathname: "/methode",
      urlLocale: "fr",
      setCookie: "fr",
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

  it("sert les nouvelles langues sous leur préfixe en minuscules", () => {
    expect(resolveLocaleRequest("/pt-br/methode")).toEqual({
      action: "continue",
      pathname: "/methode",
      urlLocale: "pt-BR",
      setCookie: "pt-BR",
    });
    expect(resolveLocaleRequest("/ar")).toEqual({
      action: "continue",
      pathname: "/",
      urlLocale: "ar",
      setCookie: "ar",
    });
    expect(resolveLocaleRequest("/es-419/app")).toEqual({
      action: "redirect",
      location: "/app",
      status: 302,
      setCookie: "es-419",
    });
  });

  it("ramène une autre casse du préfixe à l'adresse unique", () => {
    expect(resolveLocaleRequest("/pt-BR/methode")).toEqual({
      action: "redirect",
      location: "/pt-br/methode",
      status: 301,
    });
    expect(resolveLocaleRequest("/FR")).toEqual({ action: "redirect", location: "/fr", status: 301 });
  });

  it("force l'anglais sur une page publique sans préfixe", () => {
    expect(resolveLocaleRequest("/methode")).toEqual({
      action: "continue",
      pathname: "/methode",
      urlLocale: "en",
    });
    expect(resolveLocaleRequest("/")).toEqual({
      action: "continue",
      pathname: "/",
      urlLocale: "en",
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
    expect(resolveLocaleRequest("/fr/app")).toEqual({
      action: "redirect",
      location: "/app",
      status: 302,
      setCookie: "fr",
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

describe("forwardedUrlLocale", () => {
  it("garde la langue de la première passe après la réécriture", () => {
    expect(forwardedUrlLocale("fr", "en")).toBe("fr");
    expect(forwardedUrlLocale("tr", "en")).toBe("tr");
    expect(forwardedUrlLocale(null, "en")).toBe("en");
    expect(forwardedUrlLocale(null, "fr")).toBe("fr");
    expect(forwardedUrlLocale("it", "en")).toBe("it");
    expect(forwardedUrlLocale("pt-BR", "en")).toBe("pt-BR");
    expect(forwardedUrlLocale("ja", "en")).toBe("en");
  });
});

describe("localeSwitchHref", () => {
  it("navigue sur une page indexable, reste dans l'app", () => {
    expect(localeSwitchHref("/methode", "tr")).toBe("/tr/methode");
    expect(localeSwitchHref("/methode", "fr")).toBe("/fr/methode");
    expect(localeSwitchHref("/fr/methode", "en")).toBe("/methode");
    expect(localeSwitchHref("/tr/methode", "fr")).toBe("/fr/methode");
    expect(localeSwitchHref("/tr", "de")).toBe("/de");
    expect(localeSwitchHref("/app", "tr")).toBeNull();
    expect(localeSwitchHref("/commencer/compte", "de")).toBeNull();
    expect(localeSwitchHref("/methode", "pt-BR")).toBe("/pt-br/methode");
    expect(localeSwitchHref("/pt-br/methode", "es-419")).toBe("/es-419/methode");
    expect(localeSwitchHref("/ar", "en")).toBe("/");
  });
});

describe("hreflang", () => {
  it("est réciproque sur chaque page indexable", () => {
    for (const path of INDEXABLE_PATHS) {
      const map = languageAlternatePaths(path);
      expect(Object.keys(map).sort()).toEqual(
        [...UI_LOCALES.map((locale) => UI_LOCALE_META[locale].hreflang), "x-default"].sort(),
      );
      expect(map["x-default"]).toBe(map.en);
      expect(map.en).toBe(localizedPath("en", path));
      expect(map.fr).toBe(localizedPath("fr", path));
      expect(map["pt-BR"]).toBe(localizedPath("pt-BR", path));
      expect(map["es-419"]).toBe(localizedPath("es-419", path));
      expect(map.sr).toBe(localizedPath("sr", path));
      expect(stripLocalePrefix(map.tr!)).toBe(path === "/" ? "/" : path);
      for (const locale of UI_LOCALES) {
        const again = languageAlternatePaths(localizedPath(locale, path));
        expect(again).toEqual(map);
      }
    }
  });

  it("n'annonce que les langues demandées, et toujours x-default", () => {
    expect(languageAlternatePaths("/methode", ["en", "fr"])).toEqual({
      en: "/methode",
      fr: "/fr/methode",
      "x-default": "/methode",
    });
  });
});
