/**
 * Qui peut retrouver un cours.
 *
 * Port de `CourseVisibility` (`Micabo/Models/CourseVisibility.swift`). La visibilité est portée par
 * **le cours** et pas par le compte : le même étudiant partage volontiers son chapitre de SVT et
 * garde ses notes de psychanalyse pour lui. Un réglage global l'obligerait à choisir entre tout
 * ouvrir et tout fermer, c'est-à-dire à tout fermer.
 *
 * On ne propose plus `public` : uniquement « Mes amis » ou privé. `public` reste une valeur
 * lue pour les cours déjà déposés, mais plus un choix. Le défaut est `private`.
 */

export type CourseVisibility = "public" | "friends" | "private";

export const DEFAULT_VISIBILITY: CourseVisibility = "private";

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

/** Les visibilités encore proposées à l'import et dans les réglages. */
export const CHOOSABLE_VISIBILITIES: readonly CourseVisibility[] = ["friends", "private"];

export function visibilityTitle(value: CourseVisibility): string {
  return VISIBILITIES.find((item) => item.value === value)?.title ?? "Privé";
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

/** Vrai quand on a encore le droit de poser cette visibilité. */
export function isChoosableVisibility(
  value: string | null | undefined,
): value is CourseVisibility {
  return value === "friends" || value === "private";
}

/**
 * Les choix affichés. Un cours déjà public garde son pictogramme jusqu'à ce
 * qu'on le referme ; on ne peut plus y revenir.
 */
export function choosableVisibilities(current?: CourseVisibility) {
  return VISIBILITIES.filter((item) => item.value !== "public" || current === "public");
}

/** Recolle une ancienne valeur `public` sur le défaut, sans l'écrire tout seul. */
export function asChoosableVisibility(value: CourseVisibility): CourseVisibility {
  return isChoosableVisibility(value) ? value : DEFAULT_VISIBILITY;
}
