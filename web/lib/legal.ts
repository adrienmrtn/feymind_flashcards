/** Ce que les pages légales et l'app iOS doivent dire pareil. */

import type { Route } from "next";

/**
 * Le nom qui répond du service. C'est **la marque, pas une personne** : ces deux pages sont
 * publiques et indexées, et le nom d'un particulier n'a pas à y figurer.
 *
 * Un seul endroit à changer le jour où une société est immatriculée — les deux pages, les
 * cinq langues et le catalogue iOS lisent tous ici.
 */
export const LEGAL_EDITOR = "Micabo";
export const LEGAL_CONTACT = "team@micabo.app";
export const LEGAL_UPDATED = "2 septembre 2026";
export const LEGAL_SITE = "https://micabo.app";
export const LEGAL_IOS_BUNDLE = "com.micabo.ios";

export const PRIVACY_PATH = "/confidentialite" as Route;
export const TERMS_PATH = "/conditions" as Route;
