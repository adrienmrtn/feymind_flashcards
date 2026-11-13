"use client";

import { StoreBadges } from "@/components/landing/StoreBadges";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Le pied de l'offre tant que le paiement web est fermé** (`CHECKOUT_MAINTENANCE`).
 *
 * Le bouton « Commencer mon essai » restait là, et répondait « Site en maintenance » à qui
 * avait lu les quatre arguments et choisi sa formule : la dernière marche de l'entonnoir
 * finissait sur un refus. Pro s'achète pourtant déjà, au même prix, dans l'app : l'offre le
 * dit, montre l'App Store et Google Play, et rappelle que c'est le même compte - un achat
 * dans l'app s'ouvre aussi sur le site (RevenueCat porte l'identifiant Supabase).
 *
 * Le second bouton laisse entrer dans l'app web, où la leçon offerte attend : on ne bloque
 * pas quelqu'un qui n'a encore rien essayé derrière un achat qu'il ne peut pas faire ici.
 */
export function StoreCheckout({
  onContinue,
  tone = "accent",
}: {
  /** Entrer dans l'app web. Absent : pas de bouton (la croix de la carte suffit). */
  onContinue?: () => void;
  /** La couleur du bouton : celle du paywall, ou le bleu de l'offre cadeau. */
  tone?: "accent" | "offer";
}) {
  const { t } = useI18n();
  return (
    <div className="flex flex-col items-center text-center">
      <p className="text-[16px] font-bold text-ink">{t("app.paywall.storeTitle")}</p>
      <p className="mt-1 text-[13.5px] leading-snug text-ink-secondary">
        {t("app.paywall.storeBody")}
      </p>
      <StoreBadges size="small" className="mt-3 justify-center" />
      {onContinue ? (
        <button
          type="button"
          onClick={onContinue}
          className={`pressable shiny mt-4 flex h-14 w-full items-center justify-center rounded-button text-[16px] font-semibold ${
            tone === "offer" ? "bg-yellow text-on-yellow" : "bg-accent text-on-ink"
          }`}
        >
          {t("app.paywall.continueFree")}
        </button>
      ) : null}
    </div>
  );
}
