"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";

/**
 * Pose un bouton **vraiment** sur la fenêtre.
 *
 * `position: fixed` se calcule par rapport au premier ancêtre transformé. L'entrée de
 * page en pose un (`translate` + `filter`), donc « Réviser ce cours » restait collé au
 * bas du contenu au lieu de suivre le défilement. Le portail sort de cet arbre.
 */
export function Float({ children }: { children: React.ReactNode }) {
  const [root, setRoot] = useState<HTMLElement | null>(null);

  useEffect(() => {
    setRoot(document.body);
  }, []);

  if (!root) return null;
  return createPortal(children, root);
}

const FLOAT_DOCK = "--app-float-dock";
const reservations = new Map<symbol, number>();

function applyFloatDock() {
  const reserved = Math.max(0, ...reservations.values());
  if (reserved > 0) {
    document.documentElement.style.setProperty(FLOAT_DOCK, `${reserved}px`);
    return;
  }
  document.documentElement.style.removeProperty(FLOAT_DOCK);
}

/**
 * Réserve une bande en bas à droite pour un bouton flottant.
 *
 * La pastille « Ton offre » lit `--app-float-dock` et se pose au-dessus. Sans ça,
 * les deux pastilles se superposent : même coin, mêmes `bottom` / `right`.
 *
 * `reservePx` est la hauteur du bouton **plus** l'écart, pas le `bottom` : celui-ci
 * est déjà dans le calage de la pastille.
 */
export function useFloatDock(reservePx: number) {
  useEffect(() => {
    if (reservePx <= 0) return;
    const id = Symbol();
    reservations.set(id, reservePx);
    applyFloatDock();
    return () => {
      reservations.delete(id);
      applyFloatDock();
    };
  }, [reservePx]);
}
