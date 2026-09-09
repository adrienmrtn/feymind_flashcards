/**
 * Le barème montré dans les vignettes du parcours.
 *
 * Le pays n'est demandé qu'après les écrans de démonstration : on prend donc celui de la
 * langue du site, qui est le meilleur pari disponible. Un Français à qui l'on montrerait
 * « A+ » ne reconnaîtrait pas sa note, et l'écran raterait la seule chose qu'il doit faire
 * passer. Le vrai pays remplacera celui-ci partout ailleurs dans l'app.
 */
export function gradeCountry(locale: string): string {
  return locale === "en" ? "us" : locale;
}
