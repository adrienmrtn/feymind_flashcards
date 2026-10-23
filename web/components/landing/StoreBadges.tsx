"use client";

import { useI18n } from "@/lib/i18n/client";
import { APP_STORE_URL, PLAY_STORE_URL } from "@/lib/stores";

/**
 * **Les deux boutons des boutiques**, App Store et Google Play.
 *
 * Dessinés en HTML et non posés en image : le libellé se traduit dans les cinq langues, il
 * reste net à toutes les tailles, et il suit le focus du site. La forme est celle que tout le
 * monde reconnaît — un bouton noir, le logo, deux lignes — sans recopier les fichiers des
 * marques, qu'on n'a pas le droit de redessiner à la main.
 */
export function StoreBadges({
  size = "default",
  className = "",
}: {
  size?: "default" | "small";
  className?: string;
}) {
  const { t } = useI18n();
  const small = size === "small";
  return (
    <div className={`flex flex-wrap items-center gap-2.5 ${className}`}>
      <StoreLink
        href={APP_STORE_URL}
        aria={t("landing.appStoreAria")}
        line1={t("landing.appStoreLine1")}
        line2="App Store"
        small={small}
        logo={
          <svg aria-hidden viewBox="0 0 24 24" className={small ? "size-[18px]" : "size-[22px]"} fill="currentColor">
            <path d="M16.5 12.6c0-2 1.6-3 1.7-3.1-.9-1.4-2.4-1.5-2.9-1.6-1.2-.1-2.4.7-3 .7-.6 0-1.6-.7-2.6-.7-1.3 0-2.6.8-3.3 2-1.4 2.4-.4 6 1 7.9.7.9 1.5 2 2.5 2 1 0 1.3-.6 2.5-.6s1.5.6 2.5.6 1.7-.9 2.4-1.9c.5-.7.7-1.1.9-1.6-2.3-.9-2.2-3.6-2.2-3.7zM14.6 5.9c.5-.6.9-1.5.8-2.4-.8 0-1.7.5-2.3 1.2-.5.6-.9 1.5-.8 2.3.9.1 1.8-.4 2.3-1.1z" />
          </svg>
        }
      />
      <StoreLink
        href={PLAY_STORE_URL}
        aria={t("landing.playAria")}
        line1={t("landing.playLine1")}
        line2="Google Play"
        small={small}
        logo={
          <svg aria-hidden viewBox="0 0 24 24" className={small ? "size-[17px]" : "size-[20px]"}>
            <path fill="#00d7fe" d="M3.6 2.3c-.3.3-.4.7-.4 1.3v16.8c0 .6.1 1 .4 1.3l9.4-9.7z" />
            <path fill="#ffce00" d="m16.2 15.3-3.2-3.3 3.2-3.3 3.7 2.1c1.1.6 1.1 1.6 0 2.3z" />
            <path fill="#ff3a44" d="M16.2 15.3 13 12l-9.4 9.7c.4.4.9.4 1.6.1z" />
            <path fill="#00f076" d="M16.2 8.7 5.2 2.2c-.7-.4-1.2-.3-1.6.1L13 12z" />
          </svg>
        }
      />
    </div>
  );
}

function StoreLink({
  href,
  aria,
  line1,
  line2,
  logo,
  small,
}: {
  href: string;
  aria: string;
  line1: string;
  line2: string;
  logo: React.ReactNode;
  small: boolean;
}) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={aria}
      className={`lp-card inline-flex items-center gap-2.5 bg-[#0b0b0d] text-white shadow-[inset_0_0_0_1px_rgb(255_255_255/0.14)] ${
        small ? "h-10 rounded-[11px] px-3" : "h-[52px] rounded-[14px] px-4"
      }`}
    >
      {logo}
      <span className="flex flex-col items-start leading-none">
        <span className={small ? "text-[8.5px] font-semibold opacity-80" : "text-[10px] font-semibold opacity-80"}>{line1}</span>
        <span className={small ? "mt-0.5 text-[14px] font-bold tracking-[-0.01em]" : "mt-1 text-[17px] font-bold tracking-[-0.01em]"}>{line2}</span>
      </span>
    </a>
  );
}
