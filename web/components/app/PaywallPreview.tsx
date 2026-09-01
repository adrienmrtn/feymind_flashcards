"use client";

import { useState } from "react";

import { PaywallCard } from "./PaywallFlow";

/** Ouvre le paywall hors session, pour le relire sur `/fondations`. */
export function PaywallPreview() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="pressable mt-5 h-11 rounded-button bg-accent px-5 text-[14px] font-semibold text-on-ink"
      >
        Voir le paywall
      </button>
      {open ? <PaywallCard onClose={() => setOpen(false)} /> : null}
    </>
  );
}
