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
