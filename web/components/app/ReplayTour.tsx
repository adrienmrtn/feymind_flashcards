"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";

import { resetTour } from "@/lib/actions/tour";
import { useI18n } from "@/lib/i18n/client";

/**
 * Refaire la visite guidée, depuis les réglages.
 *
 * Posé à côté de « Refaire l'accueil », et pour la même raison : ce qui ne se
 * présente qu'une fois doit pouvoir se redemander. La différence est qu'ici ce
 * n'est pas un outil de mise au point mais une entrée normale du produit, donc
 * elle ne dit pas « pour déboguer ».
 *
 * On repart sur l'accueil : c'est la première page de la visite, et rester sur
 * les réglages ferait commencer la découverte par son écran le plus aride.
 */
export function ReplayTour() {
  const { t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={pending}
      onClick={() => {
        startTransition(async () => {
          await resetTour();
          router.push("/app");
        });
      }}
      className="pressable hover-row w-full px-7 py-5 text-left"
    >
      <p className="text-[15px] font-semibold text-ink">{t("app.settings.replayTour.title")}</p>
      <p className="mt-1 text-[13px] leading-relaxed text-ink-tertiary">
        {pending ? t("app.settings.replayTour.pending") : t("app.settings.replayTour.body")}
      </p>
    </button>
  );
}
