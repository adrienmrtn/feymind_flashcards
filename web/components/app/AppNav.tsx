"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import {
  OPEN_COURSES_EVENT,
  readOpenCourses,
  unpinOpenCourse,
  type OpenCourseTab,
} from "@/lib/open-courses";

/**
 * La navigation de l'app.
 *
 * Sur un grand écran c'est une colonne à gauche, toujours visible : sur un bureau, cacher la
 * navigation derrière un bouton fait cliquer deux fois pour changer d'écran. Sous `lg`, elle
 * redevient une barre en bas — là, la largeur est le bien rare, et le pouce est en bas.
 *
 * **Les cours ouverts restent dans la barre jusqu'à ce qu'on les ferme.** C'est ce qui
 * manquait : on ouvrait une fiche, on allait voir ses cartes ou sa session, et il
 * fallait repasser par la liste pour la retrouver. Chaque fiche a son onglet, avec sa
 * croix — comme un navigateur. On peut en tenir plusieurs à la fois.
 *
 * Ils vivent dans `sessionStorage` et non dans l'URL : ils survivent à un changement
 * d'écran, pas à la fermeture de l'onglet. Un cours épinglé retrouvé trois jours plus
 * tard serait un souvenir dont personne n'a besoin.
 */

const LINKS = [
  { href: "/app", label: "Accueil", icon: "home", prefetch: true },
  { href: "/app/cours", label: "Cours", icon: "shelf", prefetch: true },
  { href: "/app/reviser", label: "Réviser", icon: "cards", prefetch: false },
  { href: "/app/examens", label: "Examens", icon: "calendar", prefetch: true },
  { href: "/app/profil", label: "Profil", icon: "person", prefetch: true },
] as const;

export function AppNav() {
  const pathname = usePathname();
  const [open, setOpen] = useState<OpenCourseTab[]>([]);

  // Les cours viennent du stockage au montage, et de l'événement quand on en ouvre un :
  // la mise en page de l'app n'a pas à savoir lesquels sont ouverts pour les faire
  // descendre en props.
  useEffect(() => {
    setOpen(readOpenCourses());

    function adopt(event: Event) {
      const detail = (event as CustomEvent<OpenCourseTab[]>).detail;
      if (Array.isArray(detail)) setOpen(detail);
    }

    window.addEventListener(OPEN_COURSES_EVENT, adopt);
    return () => window.removeEventListener(OPEN_COURSES_EVENT, adopt);
  }, []);

  function close(id: string) {
    setOpen(unpinOpenCourse(id));
  }

  const isCurrent = (href: string) => {
    if (href === "/app") return pathname === "/app";
    if (href === "/app/cours") {
      return (
        pathname === "/app/cours" ||
        pathname.startsWith("/app/c/") ||
        pathname.startsWith("/app/b/")
      );
    }
    if (href === "/app/profil") {
      return pathname.startsWith("/app/profil") || pathname.startsWith("/app/amis") || pathname.startsWith("/app/u/");
    }
    return pathname.startsWith(href);
  };

  const isOpenCourse = (id: string) => pathname.startsWith(`/app/c/${id}`);

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
              href={link.href as never}
              prefetch={link.prefetch}
              aria-current={isCurrent(link.href) ? "page" : undefined}
              className={`nav-link flex items-center gap-3 rounded-button px-3 py-2.5 text-[15px] transition-colors duration-hover ${
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

        {open.length > 0 ? (
          <div className="mt-6">
            <p className="eyebrow mb-2 px-3 text-ink-tertiary">
              {open.length === 1 ? "Ouvert" : "Ouverts"}
            </p>
            <div className="max-h-56 space-y-0.5 overflow-y-auto">
              {open.map((course) => {
                const current = isOpenCourse(course.id);
                return (
                  <div
                    key={course.id}
                    className={`group flex items-center gap-2 rounded-button pr-1 transition-colors duration-hover ${
                      current ? "bg-accent-soft" : "hover:bg-surface"
                    }`}
                  >
                    <Link
                      href={`/app/c/${course.id}` as never}
                      className="flex min-w-0 flex-1 items-center gap-2.5 px-3 py-2.5"
                    >
                      <span aria-hidden className="emoji text-[15px]">
                        {course.emoji}
                      </span>
                      <span
                        className={`min-w-0 flex-1 truncate text-[14px] ${
                          current ? "font-semibold text-accent" : "text-ink-secondary"
                        }`}
                      >
                        {course.title}
                      </span>
                    </Link>
                    <button
                      type="button"
                      onClick={() => close(course.id)}
                      aria-label={`Fermer ${course.title}`}
                      className="pressable shrink-0 rounded-full px-2 py-1 text-[13px] text-ink-tertiary opacity-0 transition-opacity duration-hover group-hover:opacity-100 focus-visible:opacity-100"
                    >
                      ✕
                    </button>
                  </div>
                );
              })}
            </div>
          </div>
        ) : null}

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
        {open.length > 0 ? (
          <div className="mx-auto mb-2 flex max-w-[420px] gap-2 overflow-x-auto pb-0.5">
            {open.map((course) => (
              <div
                key={course.id}
                className={`flex shrink-0 items-center gap-1.5 rounded-pill border px-3 py-2 shadow-floating backdrop-blur-xl ${
                  isOpenCourse(course.id)
                    ? "border-accent/40 bg-accent-soft"
                    : "border-stroke bg-surface/90"
                }`}
              >
                <Link
                  href={`/app/c/${course.id}` as never}
                  className="flex max-w-[10rem] items-center gap-1.5"
                >
                  <span aria-hidden className="emoji text-[14px]">
                    {course.emoji}
                  </span>
                  <span className="truncate text-[13px] font-medium text-ink">{course.title}</span>
                </Link>
                <button
                  type="button"
                  onClick={() => close(course.id)}
                  aria-label={`Fermer ${course.title}`}
                  className="pressable shrink-0 px-1 text-[13px] text-ink-tertiary"
                >
                  ✕
                </button>
              </div>
            ))}
          </div>
        ) : null}

        <div className="mx-auto flex max-w-[420px] items-center justify-around rounded-sheet border border-stroke bg-surface/80 p-1.5 shadow-floating backdrop-blur-xl">
          {LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href as never}
              prefetch={link.prefetch}
              aria-current={isCurrent(link.href) ? "page" : undefined}
              className={`nav-link flex flex-1 flex-col items-center gap-1 rounded-button py-2 text-[10.5px] font-medium transition-colors duration-hover ${
                isCurrent(link.href) ? "text-accent" : "text-ink-tertiary hover:text-ink-secondary"
              }`}
            >
              <Icon name={link.icon} filled={isCurrent(link.href)} />
              {link.label}
            </Link>
          ))}
          <Link
            href="/app/importer"
            className="flex flex-1 flex-col items-center gap-1 rounded-button py-2 text-[10.5px] font-medium text-ink"
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
      {name === "home" ? (
        <>
          <path d="M3.5 9.2L10 3.6l6.5 5.6" />
          <path d="M5.2 8.4V16h9.6V8.4" fill={filled ? "currentColor" : "none"} />
        </>
      ) : null}
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
      {name === "calendar" ? (
        <>
          <rect x="3" y="4.5" width="14" height="12.5" rx="2" fill={filled ? "currentColor" : "none"} />
          <path d="M3 8.5h14M7 3v3M13 3v3" />
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
