"use client";

import {
  APPEARANCE_STORAGE,
  APPEARANCE_THEME_COLOR,
  appearanceIsDark,
  type Appearance,
} from "./appearance";

/**
 * Pose l'apparence tout de suite, avant que le cookie revienne.
 *
 * Les transitions couleur/fond/ombre se déclencheraient toutes ensemble
 * et le changement bave. On les coupe le temps d'un frame.
 */
export function applyAppearance(appearance: Appearance) {
  const root = document.documentElement;
  const dark = appearanceIsDark(appearance);

  const freeze = document.createElement("style");
  freeze.append("* , *::before, *::after { transition: none !important; }");
  document.head.append(freeze);
  void root.offsetWidth;

  root.dataset.appearance = appearance;
  root.classList.toggle("dark", dark);
  root.style.colorScheme = dark ? "dark" : "light";

  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute("content", APPEARANCE_THEME_COLOR[appearance]);

  try {
    localStorage.setItem(APPEARANCE_STORAGE, appearance);
  } catch {
    /* private mode */
  }

  requestAnimationFrame(() => freeze.remove());
}
