/**
 * L'apparence du site : le marine par défaut (`night`), le clair en option (`day`).
 *
 * Direction artistique V3.3 : comme l'app, le site s'ouvre en marine pour qui n'a rien
 * choisi, et un choix explicite du clair est gardé. Le crépuscule, ancien thème chaud,
 * n'existe plus dans l'app : la valeur reste lisible (un cookie ancien ne casse rien) et
 * s'affiche en marine.
 *
 * Cookie, pas colonne : l'iPhone n'en sait rien encore, et un réglage écrit
 * dans `profiles` se synchroniserait là-bas sans rien à afficher.
 *
 * Le pastel de l'app ne passe pas par ici : landing et onboarding gardent
 * le papier gris, et `AppChrome` pose `data-pastel` seulement sur `/app`.
 */

export const APPEARANCES = ["day", "night", "twilight"] as const;
export type Appearance = (typeof APPEARANCES)[number];

export const DEFAULT_APPEARANCE: Appearance = "night";
export const APPEARANCE_COOKIE = "micabo.appearance";
export const APPEARANCE_STORAGE = "micabo.appearance";

/** Le fond de chaque mode, comme `--color-canvas` : le marine, et le clair teinté. */
export const APPEARANCE_THEME_COLOR: Record<Appearance, string> = {
  day: "#eef1f8",
  night: "#0b0f1c",
  twilight: "#0b0f1c",
};

export const APPEARANCE_SHADER: Record<
  Appearance,
  { mesh: string[]; grain: string[]; back: string }
> = {
  day: {
    mesh: ["#e4ecff", "#eef1f8", "#3870fe", "#2d62ee"],
    grain: ["#e4ecff", "#eef1f8", "#3870fe"],
    back: "#eef1f8",
  },
  night: {
    mesh: ["#18224a", "#0b0f1c", "#5c88ff", "#3f6be8"],
    grain: ["#18224a", "#0b0f1c", "#5c88ff"],
    back: "#0b0f1c",
  },
  twilight: {
    mesh: ["#18224a", "#0b0f1c", "#5c88ff", "#3f6be8"],
    grain: ["#18224a", "#0b0f1c", "#5c88ff"],
    back: "#0b0f1c",
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
    var a = raw === "night" || raw === "twilight" || raw === "day" ? raw : "night";
    var root = document.documentElement;
    root.setAttribute("data-appearance", a);
    root.classList.toggle("dark", a !== "day");
    root.style.colorScheme = a === "day" ? "light" : "dark";
    var meta = document.querySelector('meta[name="theme-color"]');
    var colors = { day: "#eef1f8", night: "#0b0f1c", twilight: "#0b0f1c" };
    if (meta) meta.setAttribute("content", colors[a]);
  } catch (e) {}
})();`;
