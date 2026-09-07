"use client";

import type { Route } from "next";

import { useI18n } from "./client";
import { localizedHref } from "./paths";

/** Lien public dans la langue de la page courante. */
export function useLocalizedHref(path: string): Route {
  const { locale } = useI18n();
  return localizedHref(locale, path);
}
