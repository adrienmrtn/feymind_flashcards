import Link from "next/link";

import { Button } from "@/components/ui/button";

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
  return (
    <div className={large ? "flex flex-col items-center gap-3" : "flex items-center gap-3.5"}>
      <Button
        variant="outline"
        size={large ? "xl" : "lg"}
        className={
          large
            ? `btn-rise shiny h-14 px-8 pe-7 text-[16px] hover:bg-transparent sm:h-14 sm:text-[16px] ${className}`
            : `btn-rise shiny h-11 px-5 pe-4 hover:bg-transparent sm:h-11 ${className}`
        }
        render={<Link href={signedIn ? "/app" : "/commencer/pays"} />}
      >
        {signedIn ? "Dashboard" : "Commencer"}
        <ArrowIcon />
      </Button>
      {signedIn ? null : (
        <Button
          variant="link"
          size={large ? "default" : "sm"}
          className={
            large
              ? "underline-draw h-auto text-[14px] font-medium text-ink-secondary hover:no-underline"
              : "underline-draw h-auto text-[13px] font-medium text-ink-secondary hover:no-underline"
          }
          render={<Link href={"/connexion" as never} />}
        >
          J&apos;ai déjà un compte
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
