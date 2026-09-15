/**
 * **L'iPhone n'a pas besoin de la vitrine : il a l'app.**
 *
 * `docs/web.md` pose la règle dès son deuxième titre — « l'iPhone est la poche, le site est
 * le bureau ». Une vitrine qui se déroule sur 390 px pour vendre un produit qui existe déjà
 * en app native demande au visiteur de lire neuf sections avant de lui dire où appuyer.
 * Alors sur iPhone, et seulement sur iPhone, l'accueil dit la seule chose utile : voilà
 * l'app, elle est ici.
 *
 * La détection se fait sur l'agent, c'est-à-dire sur la seule chose que le serveur sache de
 * l'appareil avant d'avoir rendu quoi que ce soit. Une bascule en CSS ou en JavaScript
 * enverrait les deux pages dans le même document et ferait clignoter l'une avant l'autre.
 */

/** La fiche de Micabo sur l'App Store. Un seul endroit à changer. */
export const APP_STORE_URL = "https://apps.apple.com/my/app/micabo/id6806651497";

/**
 * Le paramètre qui redonne la vitrine complète depuis un iPhone.
 *
 * Personne ne doit se retrouver enfermé : quelqu'un qui veut lire la page d'accueil sur son
 * téléphone y a droit, et c'est le lien discret en bas de la page de téléchargement.
 */
export const FULL_SITE_PARAM = "web";

/**
 * iPhone et iPod, pas l'iPad.
 *
 * Safari sur iPad se déclare `Macintosh` depuis iPadOS 13, et quand il se déclare `iPad`
 * c'est un écran de bureau à un pouce près : la vitrine y tient très bien. Chrome, Firefox
 * et Edge sur iPhone gardent tous `iPhone` dans leur agent en plus de leur propre nom, donc
 * ce seul mot les couvre.
 */
const IPHONE = /\b(?:iphone|ipod)\b/i;

/**
 * Les robots repartent sur la vitrine, **et c'est une question d'indexation, pas de
 * politesse.**
 *
 * Applebot explore avec un agent d'iPhone. Sans cette porte, l'adresse qui porte tout le
 * référencement du site ne rendrait, pour lui, qu'un bouton de téléchargement — et les
 * pages qu'elle cite ne seraient plus citées par rien. Googlebot explore en Android, donc
 * il ne voit déjà que la vitrine : rien de ce qui est indexé ne change.
 */
const ROBOT = /bot\b|crawler|spider|slurp|lighthouse|headlesschrome|preview/i;

/** Vrai si cette requête vient d'un iPhone tenu par quelqu'un. */
export function isIphoneUserAgent(userAgent: string | null | undefined): boolean {
  if (!userAgent) return false;
  if (ROBOT.test(userAgent)) return false;
  return IPHONE.test(userAgent);
}

/**
 * Ce que l'accueil doit rendre : la page de téléchargement, ou la vitrine.
 *
 * Le paramètre l'emporte sur l'agent — c'est le sens d'une porte de sortie.
 */
export function wantsIphoneLanding(
  userAgent: string | null | undefined,
  params: Record<string, string | string[] | undefined>,
): boolean {
  if (params[FULL_SITE_PARAM] !== undefined) return false;
  return isIphoneUserAgent(userAgent);
}
