"use client";

import { useEffect, type ReactNode } from "react";
import { X } from "lucide-react";

import { useI18n } from "@/lib/i18n/client";

/**
 * **Une feuille modale**, basse sur téléphone et centrée sur grand écran : un titre, une croix,
 * ce qu'on y met. Échap et un appui à côté la ferment. Jumelle des `.sheet` de l'app.
 */
export function Sheet({ title, onClose, children, wide = false }: { title: string; onClose: () => void; children: ReactNode; wide?: boolean }) {
  const { t } = useI18n();
  useEffect(() => {
    function escape(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    document.addEventListener("keydown", escape);
    return () => document.removeEventListener("keydown", escape);
  }, [onClose]);
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 sm:items-center sm:p-6" role="dialog" aria-modal="true" aria-label={title} onClick={onClose}>
      <div
        className={`score-in flex max-h-[92svh] w-full flex-col gap-4 overflow-y-auto rounded-t-[28px] bg-canvas p-5 pb-[max(1.25rem,env(safe-area-inset-bottom))] sm:rounded-[28px] ${wide ? "max-w-[600px]" : "max-w-[480px]"}`}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h2 className="text-[20px] font-extrabold text-ink">{title}</h2>
          <button type="button" onClick={onClose} aria-label={t("app.a11y.close")} className="pressable flex size-9 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted">
            <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
