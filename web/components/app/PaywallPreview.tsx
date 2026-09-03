"use client";

import { useState } from "react";

import { useI18n } from "@/lib/i18n/client";

import { PaywallCard } from "./PaywallFlow";

/** Ouvre le paywall hors session, pour le relire sur `/fondations`. */
export function PaywallPreview() {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="pressable mt-5 h-11 rounded-button bg-accent px-5 text-[14px] font-semibold text-on-ink"
      >
        {t("app.paywall.preview")}
      </button>
      {open ? <PaywallCard onClose={() => setOpen(false)} /> : null}
    </>
  );
}
