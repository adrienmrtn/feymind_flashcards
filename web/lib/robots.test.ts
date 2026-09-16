import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { NextConfig } from "next";

/**
 * **Le test qui empêche de refermer la porte sur un `noindex`.**
 *
 * `Disallow` et `noindex` ne s'additionnent pas, ils se contrarient : un chemin interdit
 * d'exploration n'est jamais lu, donc son en-tête `X-Robots-Tag` n'est jamais vu, donc la
 * page ne sort pas de l'index — elle y reste en adresse nue. `robots.txt` avait quatre
 * lignes `Disallow` qui visaient exactement les chemins que `next.config.ts` marque
 * `noindex`. C'est ce couple-là qu'on verrouille ici.
 *
 * `IS_INDEXABLE` est lu au chargement du module (`VERCEL_ENV === "production"`), d'où
 * l'import dynamique après `resetModules` : on veut le `robots.txt` de la production, pas
 * celui d'une prévisualisation, qui lui ferme tout et a raison de le faire.
 */
async function robotsIn(env: string | undefined) {
  vi.resetModules();
  if (env === undefined) vi.stubEnv("VERCEL_ENV", "");
  else vi.stubEnv("VERCEL_ENV", env);
  const mod = await import("../app/robots");
  return mod.default();
}

/** Les `source` des règles qui posent `X-Robots-Tag: noindex`, tels quels. */
async function noindexSources(): Promise<string[]> {
  vi.resetModules();
  const mod = (await import("../next.config")) as { default: NextConfig };
  const rules = (await mod.default.headers?.()) ?? [];
  return rules
    .filter((rule) =>
      rule.headers.some(
        (header) =>
          header.key.toLowerCase() === "x-robots-tag" && header.value.includes("noindex"),
      ),
    )
    .map((rule) => rule.source);
}

/** `/app/:path*` → `/app/`, `/connexion` → `/connexion`. De quoi comparer à un `Disallow`. */
function literalPrefix(source: string): string {
  const cut = source.indexOf("/:");
  return cut === -1 ? source : `${source.slice(0, cut)}/`;
}

function disallowList(rules: unknown): string[] {
  const all = Array.isArray(rules) ? rules : [rules];
  return all.flatMap((rule) => {
    const value = (rule as { disallow?: string | string[] }).disallow;
    if (!value) return [];
    return Array.isArray(value) ? value : [value];
  });
}

beforeEach(() => {
  vi.stubEnv("NEXT_PUBLIC_SITE_URL", "");
});

afterEach(() => {
  vi.unstubAllEnvs();
  vi.resetModules();
});

describe("robots.txt", () => {
  it("n'interdit rien en production : les écrans privés doivent pouvoir lire leur noindex", async () => {
    const robots = await robotsIn("production");
    expect(disallowList(robots.rules)).toEqual([]);
  });

  it("annonce le sitemap et ouvre le site", async () => {
    const robots = await robotsIn("production");
    const rules = Array.isArray(robots.rules) ? robots.rules[0] : robots.rules;
    expect(rules?.allow).toBe("/");
    expect(robots.sitemap).toBe("https://www.micabo.app/sitemap.xml");
  });

  it("ferme tout hors production : une prévisualisation ne s'indexe pas", async () => {
    const robots = await robotsIn("preview");
    expect(disallowList(robots.rules)).toEqual(["/"]);
    expect(robots.sitemap).toBeUndefined();
  });

  // L'invariant, celui qui valait le bug : aucun chemin marqué `noindex` ne doit être
  // interdit d'exploration. Ajouter une ligne `Disallow` sur `/app/` ou `/commencer/`
  // fait échouer ce test, et c'est le but.
  it("n'interdit aucun chemin que next.config marque noindex", async () => {
    const disallowed = disallowList((await robotsIn("production")).rules);
    const sources = await noindexSources();
    expect(sources.length).toBeGreaterThan(0);

    for (const source of sources) {
      const prefix = literalPrefix(source);
      for (const blocked of disallowed) {
        expect(
          prefix.startsWith(blocked) || blocked.startsWith(prefix),
          `${source} est noindex et ${blocked} l'empêche d'être lu`,
        ).toBe(false);
      }
    }
  });
});
