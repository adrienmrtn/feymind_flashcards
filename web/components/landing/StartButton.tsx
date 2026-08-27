import Link from "next/link";

import { Button } from "@/components/ui/button";

/**
 * L'entrée. **Commencer** ouvre le parcours. **J'ai déjà un compte** ouvre
 * la connexion. Si une session est déjà là, le bouton mène au tableau de bord.
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
        size={large ? "xl" : "lg"}
        className={
          large
            ? `shiny h-14 px-8 text-[16px] sm:h-14 sm:text-[16px] ${className}`
            : `shiny h-11 px-5 sm:h-11 ${className}`
        }
        render={<Link href={signedIn ? "/app" : "/commencer/pays"} />}
      >
        {signedIn ? "Dashboard" : "Commencer"}
      </Button>
      {signedIn ? null : (
        <Button
          variant="link"
          size={large ? "default" : "sm"}
          className={large ? "h-auto text-[14px] text-ink-secondary" : "h-auto text-[13px] text-ink-secondary"}
          render={<Link href={"/connexion" as never} />}
        >
          J&apos;ai déjà un compte
        </Button>
      )}
    </div>
  );
}
