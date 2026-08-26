"use client";

import { useEffect } from "react";

/**
 * Déclare le cours ouvert, pour que la barre le garde.
 *
 * Il écrit dans `sessionStorage` et prévient la barre par un événement : les deux vivent dans des
 * arbres différents, et remonter l'information par les props aurait demandé de faire passer le
 * cours par la mise en page de l'app, qui n'a rien à savoir de lui.
 *
 * `sessionStorage` et non l'URL : l'onglet doit survivre à un changement d'écran, pas à la
 * fermeture du navigateur. Un cours épinglé retrouvé trois jours plus tard serait un souvenir dont
 * personne n'a besoin.
 */
export function OpenCourse({
  id,
  title,
  emoji,
}: {
  id: string;
  title: string;
  emoji: string;
}) {
  useEffect(() => {
    const course = { id, title, emoji };
    try {
      window.sessionStorage.setItem("micabo.app.openCourse", JSON.stringify(course));
    } catch {
      // Un stockage refusé fait perdre l'onglet, pas la navigation.
    }
    window.dispatchEvent(new CustomEvent("micabo:course-open", { detail: course }));
  }, [id, title, emoji]);

  return null;
}
