"use client";

import Link from "next/link";

import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";

/**
 * L'entrée. **Commencer** ouvre le parcours. **J'ai déjà un compte** ouvre
 * la connexion. Si une session est déjà là, le bouton mène au tableau de bord.
 *
 * Le primaire reprend Colorion : remplissage qui monte, reflet au survol,
 * flèche qui avance. Le secondaire reste un lien, sans graisse qui saute.
 */
export function StartButton({
  signedIn = false,
  size = "large",
  className = "",
}: {
  signedIn?: boolean;
  size?: "large" | "compact";
  className?: string;
}) {
  const large = size === "large";
  const { t } = useI18n();
  return (
    <div className={large ? "flex flex-col items-center gap-3" : "flex min-w-0 items-center gap-2.5 sm:gap-3.5"}>
      <Button
        size={large ? "xl" : "lg"}
        className={
          large
            ? `h-14 px-8 pe-7 text-[16px] sm:h-14 sm:text-[16px] ${className}`
            : `h-11 max-w-full px-4 pe-3 sm:h-11 sm:px-5 sm:pe-4 ${className}`
        }
        render={<Link href={signedIn ? "/app" : "/commencer"} />}
      >
        {signedIn ? t("common.openApp") : t("common.start")}
        <ArrowIcon />
      </Button>
      {signedIn ? null : (
        <Button
          variant="link"
          size={large ? "default" : "sm"}
          className={
            large
              ? "underline-draw h-auto text-[14px] font-medium text-ink-secondary hover:no-underline"
              : "underline-draw hidden h-auto text-[13px] font-medium text-ink-secondary hover:no-underline md:inline-flex"
          }
          render={<Link href={"/connexion" as never} />}
        >
          {t("common.alreadyAccount")}
        </Button>
      )}
    </div>
  );
}

function ArrowIcon() {
  return (
    <svg
      aria-hidden
      viewBox="0 0 20 20"
      className="btn-arrow h-4 w-4"
    >
      <path
        d="M4 10h11M11 5l5 5-5 5"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
