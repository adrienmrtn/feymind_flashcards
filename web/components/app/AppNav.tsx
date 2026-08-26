"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

/**
 * La navigation de l'app.
 *
 * Sur un grand écran c'est une colonne à gauche, toujours visible : sur un bureau, cacher la
 * navigation derrière un bouton fait cliquer deux fois pour changer d'écran. Sous `lg`, elle
 * redevient une barre en bas — là, la largeur est le bien rare, et le pouce est en bas.
 *
 * **Contour par défaut, plein pour l'actif** : c'est déjà la règle de la barre d'onglets de l'app,
 * et c'est le seul endroit du web où l'accent sert à dire « tu es ici ».
 */

const LINKS = [
  { href: "/app", label: "Cours", icon: "shelf" },
  { href: "/app/reviser", label: "Réviser", icon: "cards" },
  { href: "/app/profil", label: "Profil", icon: "person" },
] as const;

export function AppNav() {
  const pathname = usePathname();

  const isCurrent = (href: string) =>
    href === "/app" ? pathname === "/app" || pathname.startsWith("/app/c/") : pathname.startsWith(href);

  return (
    <>
      {/* Grand écran : la colonne. */}
      <nav
        aria-label="Navigation"
        className="sticky top-0 hidden h-svh w-[232px] shrink-0 flex-col border-r border-hairline-on-canvas px-4 py-8 lg:flex"
        data-print="hide"
      >
        <Link href="/" className="mb-9 px-3 text-[17px] font-bold text-ink">
          Micabo
        </Link>

        <div className="space-y-1">
          {LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              aria-current={isCurrent(link.href) ? "page" : undefined}
              className={`flex items-center gap-3 rounded-button px-3 py-2.5 text-[15px] transition-colors duration-hover ${
                isCurrent(link.href)
                  ? "bg-accent-soft font-semibold text-accent"
                  : "text-ink-secondary hover:bg-surface"
              }`}
            >
              <Icon name={link.icon} filled={isCurrent(link.href)} />
              {link.label}
            </Link>
          ))}
        </div>

        <Link
          href="/app/importer"
          className="pressable mt-6 flex items-center justify-center gap-2 rounded-button bg-ink py-3 text-[14.5px] font-semibold text-on-ink"
        >
          <Icon name="plus" filled />
          Importer un cours
        </Link>
      </nav>

      {/* Petit écran : la barre en bas, en verre, posée à distance des bords. */}
      <nav
        aria-label="Navigation"
        className="fixed inset-x-0 bottom-0 z-20 px-4 pb-4 lg:hidden"
        data-print="hide"
      >
        <div className="mx-auto flex max-w-[420px] items-center justify-around rounded-sheet border border-stroke bg-surface/80 p-1.5 shadow-floating backdrop-blur-xl">
          {LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              aria-current={isCurrent(link.href) ? "page" : undefined}
              className={`flex flex-1 flex-col items-center gap-1 rounded-button py-2 text-[11px] font-medium ${
                isCurrent(link.href) ? "text-accent" : "text-ink-tertiary"
              }`}
            >
              <Icon name={link.icon} filled={isCurrent(link.href)} />
              {link.label}
            </Link>
          ))}
          <Link
            href="/app/importer"
            className="flex flex-1 flex-col items-center gap-1 rounded-button py-2 text-[11px] font-medium text-ink"
          >
            <Icon name="plus" filled />
            Importer
          </Link>
        </div>
      </nav>
    </>
  );
}

function Icon({ name, filled }: { name: string; filled: boolean }) {
  const stroke = filled ? 2 : 1.6;

  return (
    <svg
      aria-hidden
      viewBox="0 0 20 20"
      className="h-[18px] w-[18px] shrink-0"
      fill="none"
      stroke="currentColor"
      strokeWidth={stroke}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {name === "shelf" ? (
        <>
          <rect x="3" y="3.5" width="4.5" height="13" rx="1.2" fill={filled ? "currentColor" : "none"} />
          <rect x="9" y="3.5" width="4.5" height="13" rx="1.2" />
          <path d="M15.5 5.2l2.2 11.1" />
        </>
      ) : null}
      {name === "cards" ? (
        <>
          <rect x="2.8" y="5.5" width="11" height="11" rx="2" fill={filled ? "currentColor" : "none"} />
          <path d="M6.5 3.5h8.2a2 2 0 0 1 2 2v8" />
        </>
      ) : null}
      {name === "person" ? (
        <>
          <circle cx="10" cy="7" r="3" fill={filled ? "currentColor" : "none"} />
          <path d="M4.5 16.5a5.5 5.5 0 0 1 11 0" />
        </>
      ) : null}
      {name === "plus" ? <path d="M10 4.5v11M4.5 10h11" /> : null}
    </svg>
  );
}
