"use client";

import { useLayoutEffect } from "react";

import { recoverGeneratedCourseIfAny } from "@/lib/import-handoff";

/**
 * Filet de l'import : si Next a cassé la page alors que le cours est écrit,
 * on ouvre la fiche au lieu de laisser « This page couldn't load ».
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useLayoutEffect(() => {
    if (recoverGeneratedCourseIfAny()) return;
  }, [error]);

  return (
    <html>
      <body
        style={{
          margin: 0,
          minHeight: "100vh",
          display: "grid",
          placeItems: "center",
          fontFamily: "system-ui, sans-serif",
          background: "#f6f3ee",
          color: "#1c1917",
        }}
      >
        <div style={{ maxWidth: 360, padding: 24, textAlign: "center" }}>
          <h1 style={{ fontSize: 22, fontWeight: 650, margin: 0 }}>La page n'a pas pu s'ouvrir.</h1>
          <p style={{ margin: "12px 0 20px", lineHeight: 1.45, opacity: 0.72 }}>
            Le cours est peut-être déjà prêt. Recharge, ou reviens à tes fiches.
          </p>
          <button
            type="button"
            onClick={() => reset()}
            style={{
              height: 44,
              padding: "0 18px",
              border: 0,
              borderRadius: 12,
              background: "#1c1917",
              color: "#fff",
              fontSize: 15,
              fontWeight: 600,
              cursor: "pointer",
            }}
          >
            Recharger
          </button>
        </div>
      </body>
    </html>
  );
}
