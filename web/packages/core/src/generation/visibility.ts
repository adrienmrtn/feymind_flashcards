/**
 * Qui peut retrouver un cours.
 *
 * Port de `CourseVisibility` (`Micabo/Models/CourseVisibility.swift`). La visibilité est portée par
 * **le cours** et pas par le compte : le même étudiant partage volontiers son chapitre de SVT et
 * garde ses notes de psychanalyse pour lui. Un réglage global l'obligerait à choisir entre tout
 * ouvrir et tout fermer, c'est-à-dire à tout fermer.
 *
 * Le défaut est `public`, comme dans l'app et comme dans la base — mais le choix se fait **à
 * l'import**, jamais après : un cours qui part public le temps qu'on y pense est un cours qui a
 * été visible.
 */

export type CourseVisibility = "public" | "friends" | "private";

export const DEFAULT_VISIBILITY: CourseVisibility = "public";

export const VISIBILITIES: readonly {
  value: CourseVisibility;
  title: string;
  detail: string;
}[] = [
  {
    value: "public",
    title: "Public",
    detail: "Visible par ton école et tes amis dans la bibliothèque.",
  },
  { value: "friends", title: "Mes amis", detail: "Visible par tes amis seulement." },
  { value: "private", title: "Privé", detail: "Visible par toi seul." },
];

export function visibilityTitle(value: CourseVisibility): string {
  return VISIBILITIES.find((item) => item.value === value)?.title ?? "Public";
}

export function visibilityDetail(value: CourseVisibility): string {
  return VISIBILITIES.find((item) => item.value === value)?.detail ?? "";
}

/** Vrai quand le cours est trouvable par quelqu'un d'autre. */
export function isShared(value: CourseVisibility): boolean {
  return value !== "private";
}

export function isVisibility(value: string | null | undefined): value is CourseVisibility {
  return value === "public" || value === "friends" || value === "private";
}
