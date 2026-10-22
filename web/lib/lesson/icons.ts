import { DEFAULT_ICON, LESSON_ICONS } from "@micabo/core";

/**
 * **Les icônes 3D de Micabo, sur le site.**
 *
 * La base vit dans l'app (`Assets.xcassets/Icon3D-<id>`) et ses images sont recopiées dans
 * `public/icons3d/<id>.png`, à la taille @3x (256 px) : assez pour un en-tête de leçon à
 * 96 px sur un écran dense, et un seul fichier par icône. L'identifiant est le nom du fichier
 * dans la base — celui que le modèle choisit (`LESSON_ICONS`) et que la base enregistre
 * (`courses.icon`, `chapters.icon`). C'est la même liste que `MicaboIcon` côté Swift.
 *
 * Quelques usages n'ont pas d'image : l'audio, les onglets, les réglages. Ils se dessinent
 * au trait (`ICON_FALLBACKS`, des icônes lucide), comme sur l'iPhone avec un SF Symbol.
 */

/** Les icônes qui ont une image dans la base, dans l'ordre de `MicaboIcon`. */
export const ICON_3D_IDS = [
  "etoile",
  "plume",
  "ampoule",
  "livre-ouvert",
  "fiole",
  "globe",
  "calculatrice",
  "sablier",
  "puzzle",
  "trophee",
  "drapeau",
  "cerveau",
  "fusee",
  "loupe",
  "cadenas",
  "coche",
  "palette",
  "diplome",
  "atome",
  "parchemin",
  "epingle",
  "reveil",
  "fiche",
  "quiz",
  "cartes",
  "mika",
  "photo",
  "pdf",
  "lien",
  "texte",
  "dossier",
  "examen",
  "flamme",
  "couronne",
] as const;

export type Icon3DId = (typeof ICON_3D_IDS)[number];

/** Les icônes sans image, dessinées au trait : le nom de l'icône lucide qui les remplace. */
export const ICON_FALLBACKS = {
  audio: "Mic",
  home: "House",
  lessons: "Library",
  profile: "UserRound",
  mail: "Mail",
  apps: "LayoutGrid",
  document: "FileText",
  language: "Languages",
  theme: "SunMoon",
  rate: "Star",
  friends: "Users",
  privacy: "Hand",
} as const;

export type IconFallbackId = keyof typeof ICON_FALLBACKS;
export type MicaboIconId = Icon3DId | IconFallbackId;

const IN_BASE = new Set<string>(ICON_3D_IDS);

export function isIcon3D(id: string | null | undefined): id is Icon3DId {
  return typeof id === "string" && IN_BASE.has(id);
}

export function isIconFallback(id: string | null | undefined): id is IconFallbackId {
  return typeof id === "string" && Object.hasOwn(ICON_FALLBACKS, id);
}

/**
 * L'identifiant d'une icône lue en base ou rendue par le modèle, ramené à ce qu'on sait
 * afficher : un nom inconnu (ou vide) devient le livre, comme `MicaboIcon(id:)` côté Swift.
 */
export function resolveIconId(id: string | null | undefined): MicaboIconId {
  const key = (id ?? "").trim().toLowerCase();
  if (isIcon3D(key) || isIconFallback(key)) return key;
  return DEFAULT_ICON as Icon3DId;
}

/** Le chemin public de l'image 3D. */
export function iconSrc(id: Icon3DId): string {
  return `/icons3d/${id}.png`;
}

/** Le catalogue que le modèle connaît doit tenir en entier dans la base d'images. */
export function missingCatalogImages(): string[] {
  return LESSON_ICONS.map((icon) => icon.id).filter((id) => !IN_BASE.has(id));
}
