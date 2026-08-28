"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/**
 * Relit les données serveur à l'arrivée.
 *
 * Une session de révision invalide le cache des cartes, mais le routeur
 * client peut encore servir l'Accueil tel qu'il l'avait mémorisé. Sans ce
 * passage, les tâches du jour n'avancent qu'au rechargement dur.
 */
export function RefreshOnVisit() {
  const router = useRouter();

  useEffect(() => {
    router.refresh();
  }, [router]);

  return null;
}
