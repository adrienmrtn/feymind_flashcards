import Link from "next/link";

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
    <div
      className={
        large
          ? "flex flex-col items-center gap-3"
          : "flex items-center gap-3.5"
      }
    >
      <Link
        href={signedIn ? "/app" : "/commencer/pays"}
        className={`pressable shiny hover-tile inline-flex items-center justify-center rounded-button bg-ink font-semibold text-on-ink ${
          large ? "h-14 px-8 text-[16px]" : "h-11 px-5 text-[14px]"
        } ${className}`}
      >
        {signedIn ? "Dashboard" : "Commencer"}
      </Link>
      {signedIn ? null : (
        <Link
          href={"/connexion" as never}
          className={`underline-draw font-medium text-ink-secondary ${
            large ? "text-[14px]" : "text-[13px]"
          }`}
        >
          J&apos;ai déjà un compte
        </Link>
      )}
    </div>
  );
}
