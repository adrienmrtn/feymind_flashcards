import type { Catalog } from "./fr";
import { fr } from "./fr";
import { de } from "./de";
import { es } from "./es";
import { tr } from "./tr";
import type { UiLocale } from "../locales";

export { fr, de, es, tr };
export type { Catalog };

export const CATALOGS: Record<UiLocale, Catalog> = { fr, de, es, tr };

export function catalogFor(locale: UiLocale): Catalog {
  return CATALOGS[locale] ?? fr;
}
