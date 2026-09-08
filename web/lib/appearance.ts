/**
 * L'apparence du site : jour, nuit, crépuscule.
 *
 * Cookie, pas colonne : l'iPhone n'en sait rien encore, et un réglage écrit
 * dans `profiles` se synchroniserait là-bas sans rien à afficher.
 *
 * Le pastel de l'app ne passe pas par ici : landing et onboarding gardent
 * le papier gris, et `AppChrome` pose `data-pastel` seulement sur `/app`.
 */

export const APPEARANCES = ["day", "night", "twilight"] as const;
export type Appearance = (typeof APPEARANCES)[number];

export const DEFAULT_APPEARANCE: Appearance = "day";
export const APPEARANCE_COOKIE = "micabo.appearance";
export const APPEARANCE_STORAGE = "micabo.appearance";

export const APPEARANCE_THEME_COLOR: Record<Appearance, string> = {
  day: "#f6f7f9",
  night: "#101216",
  twilight: "#1c1612",
};

export const APPEARANCE_SHADER: Record<
  Appearance,
  { mesh: string[]; grain: string[]; back: string }
> = {
  day: {
    mesh: ["#dbeafe", "#f6f7f9", "#3b82f6", "#2563eb"],
    grain: ["#dbeafe", "#f6f7f9", "#3b82f6"],
    back: "#f6f7f9",
  },
  night: {
    mesh: ["#1e3a5f", "#121418", "#3b82f6", "#1d4ed8"],
    grain: ["#1e3a5f", "#121418", "#3b82f6"],
    back: "#101216",
  },
  twilight: {
    mesh: ["#3a2e48", "#1c1612", "#8bb0ff", "#c4a574"],
    grain: ["#3a2e48", "#1c1612", "#c4a574"],
    back: "#1c1612",
  },
};

export function isAppearance(value: string | undefined | null): value is Appearance {
  return APPEARANCES.includes(value as Appearance);
}

export function appearanceFromUnknown(value: string | undefined | null): Appearance {
  return isAppearance(value) ? value : DEFAULT_APPEARANCE;
}

export function appearanceIsDark(value: Appearance): boolean {
  return value !== "day";
}

export const APPEARANCE_BOOT_SCRIPT = `(function(){
  try {
    var fromCookie = document.cookie.match(/(?:^|; )${APPEARANCE_COOKIE}=([^;]*)/);
    var raw = fromCookie ? decodeURIComponent(fromCookie[1]) : localStorage.getItem(${JSON.stringify(APPEARANCE_STORAGE)});
    var a = raw === "night" || raw === "twilight" || raw === "day" ? raw : "day";
    var root = document.documentElement;
    root.setAttribute("data-appearance", a);
    root.classList.toggle("dark", a !== "day");
    root.style.colorScheme = a === "day" ? "light" : "dark";
    var meta = document.querySelector('meta[name="theme-color"]');
    var colors = { day: "#f6f7f9", night: "#101216", twilight: "#1c1612" };
    if (meta) meta.setAttribute("content", colors[a]);
  } catch (e) {}
})();`;
