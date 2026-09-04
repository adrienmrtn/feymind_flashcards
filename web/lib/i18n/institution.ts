/**
 * Le libellé d'un type d'établissement, dans la langue de l'interface.
 *
 * La table porte `university` / `lycee` : ce n'est pas un texte à afficher.
 */
export function institutionKindLabel(kind: string, t: (key: string) => string): string {
  switch (kind) {
    case "university":
      return t("app.institution.university");
    case "grande_ecole":
      return t("app.institution.grandeEcole");
    case "lycee":
      return t("app.institution.lycee");
    default:
      return t("app.institution.other");
  }
}
