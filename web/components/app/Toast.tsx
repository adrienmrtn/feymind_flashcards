"use client";

import { useEffect } from "react";

/**
 * Un avis discret, en bas d'écran.
 *
 * Il confirme une action déjà terminée (un examen enregistré, par exemple).
 * Rien à cliquer : il s'en va tout seul.
 */
export function Toast({
  message,
  onGone,
}: {
  message: string;
  onGone: () => void;
}) {
  useEffect(() => {
    const timer = window.setTimeout(onGone, 3400);
    return () => window.clearTimeout(timer);
  }, [message, onGone]);

  return (
    <div
      role="status"
      className="pointer-events-none fixed inset-x-0 bottom-6 z-50 flex justify-center px-4"
    >
      <p className="rounded-pill bg-ink px-4 py-2.5 text-[13.5px] font-medium text-on-ink shadow-floating">
        {message}
      </p>
    </div>
  );
}
