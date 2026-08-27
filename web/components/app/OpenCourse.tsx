"use client";

import { useEffect } from "react";

import { pinOpenCourse } from "@/lib/open-courses";

/**
 * Déclare le cours ouvert, pour que la barre le garde.
 *
 * Il écrit dans `sessionStorage` et prévient la barre par un événement : les deux vivent dans des
 * arbres différents, et remonter l'information par les props aurait demandé de faire passer le
 * cours par la mise en page de l'app, qui n'a rien à savoir de lui.
 *
 * **On ajoute**, on ne remplace pas : plusieurs fiches peuvent rester ouvertes en même temps,
 * comme des onglets. `sessionStorage` et non l'URL : ils survivent à un changement d'écran,
 * pas à la fermeture du navigateur.
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
    pinOpenCourse({ id, title, emoji });
  }, [id, title, emoji]);

  return null;
}
