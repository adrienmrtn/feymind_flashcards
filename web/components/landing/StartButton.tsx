import Link from "next/link";

/**
 * L'entrée dans le parcours. Un seul libellé, partout : **Commencer**.
 *
 * La landing explique. Elle ne pose aucune question. Ce bouton ouvre le premier
 * écran du parcours (`/commencer/pays`), puis les suivants s'enchaînent un par un.
 * Le compte n'arrive qu'à la fin.
 */
export function StartButton({
  size = "large",
  className = "",
}: {
  size?: "large" | "compact";
  className?: string;
}) {
  const large = size === "large";
  return (
    <Link
      href="/commencer/pays"
      className={`pressable inline-flex items-center justify-center rounded-button bg-ink font-semibold text-on-ink ${
        large ? "h-14 px-8 text-[16px]" : "h-11 px-5 text-[14px]"
      } ${className}`}
    >
      Commencer
    </Link>
  );
}
