/**
 * Ouvrir la page qu'on vient d'écrire, sans passer par le routeur.
 *
 * Ce fichier portait un relais bien plus gros : l'écriture d'une fiche quittait le document
 * App Router pour une page réécrite à la volée, affichait son pourcentage en plein écran hors
 * de Next, et un voile relayait l'attente jusqu'à la fiche peinte. C'était la réponse à un vrai
 * problème - React gelait le compteur pendant l'appel - mais le remède coûtait l'écran entier
 * pour une attente qui tient dans un panneau.
 *
 * L'attente vit maintenant là où elle a commencé, dans le panneau d'import. Il ne reste ici que
 * la dernière étape : partir vers la page écrite. Un `router.push` la rendrait depuis un cache
 * client qui ne connaît pas encore la fiche, donc on force une vraie navigation, par un GET de
 * formulaire natif que Next n'intercepte pas.
 */

/** Attend que l'attente soit réellement peinte avant d'appeler le serveur. */
export function waitForPaint(): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  return new Promise((resolve) => {
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        window.setTimeout(resolve, 80);
      });
    });
  });
}

const GENERATED_PAGE = /^\/app\/(c\/[0-9a-f-]{36}(\/cartes)?|paquets\/[0-9a-f-]{36})$/i;

export function isGeneratedPagePath(pathname: string): boolean {
  return GENERATED_PAGE.test(pathname);
}

function nativeGet(absoluteUrl: string): void {
  const form = document.createElement("form");
  form.method = "GET";
  form.action = absoluteUrl;
  form.style.display = "none";
  document.body.appendChild(form);
  HTMLFormElement.prototype.submit.call(form);
}

/**
 * Ouvre la fiche par un GET de formulaire natif : `submit()` ne déclenche
 * pas l'événement que Next intercepte.
 */
export function openGeneratedPage(href: string): void {
  if (typeof window === "undefined") return;
  const url = new URL(href, window.location.origin);
  if (!isGeneratedPagePath(url.pathname)) {
    nativeGet(new URL("/app", window.location.origin).href);
    return;
  }
  nativeGet(`${window.location.origin}${url.pathname}${url.search}`);
}
