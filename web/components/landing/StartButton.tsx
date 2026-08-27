import Link from "next/link";

/**
 * L'entrée. **Commencer** ouvre le parcours. Si une session est déjà là,
 * le même bouton mène au tableau de bord — on ne refait pas le tunnel.
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
    <Link
      href={signedIn ? "/app" : "/commencer/pays"}
      className={`pressable inline-flex items-center justify-center rounded-button bg-ink font-semibold text-on-ink ${
        large ? "h-14 px-8 text-[16px]" : "h-11 px-5 text-[14px]"
      } ${className}`}
    >
      {signedIn ? "Dashboard" : "Commencer"}
    </Link>
  );
}
