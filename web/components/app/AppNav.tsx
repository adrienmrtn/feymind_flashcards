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
 * La navigation, **en pastilles**.
 *
 * Sur un téléphone, cinq cercles flottent dans une capsule — l'actif est plein,
 * et un triangle le relie à la page. C'est le même geste que la barre d'icônes
 * d'un produit posé, pas une rangée de libellés serrés.
 *
 * Sur un bureau, la colonne garde les mots, mais chaque destination a encore
 * son cercle : on reconnaît l'écran avant de lire.
 *
 * Les cours ouverts restent dans la barre jusqu'à ce qu'on les ferme.
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
  const importing = pathname.startsWith("/app/importer");

  return (
    <>
      <nav
        aria-label="Navigation"
        className="sticky top-0 hidden h-svh w-[248px] shrink-0 flex-col px-6 py-10 lg:flex"
        data-print="hide"
      >
        <Link href="/" className="mb-10 px-1 text-[18px] font-bold tracking-tight-title text-ink">
          Micabo
        </Link>

        <div className="space-y-1.5">
          {LINKS.map((link) => {
            const current = isCurrent(link.href);
            return (
              <Link
                key={link.href}
                href={link.href as never}
                prefetch={link.prefetch}
                aria-current={current ? "page" : undefined}
                className="group flex items-center gap-3 rounded-pill py-1 pr-3"
              >
                <Dot filled={current}>
                  <Icon name={link.icon} filled={current} />
                </Dot>
                <span
                  className={`text-[15px] ${
                    current ? "font-semibold text-ink" : "text-ink-secondary group-hover:text-ink"
                  }`}
                >
                  {link.label}
                </span>
              </Link>
            );
          })}
        </div>

        {open.length > 0 ? (
          <div className="mt-8">
            <p className="mb-2 px-1 text-[11px] font-medium uppercase tracking-caps text-ink-tertiary">
              {open.length === 1 ? "Ouvert" : "Ouverts"}
            </p>
            <div className="max-h-56 space-y-0.5 overflow-y-auto">
              {open.map((course) => {
                const current = isOpenCourse(course.id);
                return (
                  <div
                    key={course.id}
                    className="group flex items-center gap-1 rounded-pill pr-1"
                  >
                    <Link
                      href={`/app/c/${course.id}` as never}
                      className="flex min-w-0 flex-1 items-center gap-2.5 px-1 py-2"
                    >
                      <span aria-hidden className="emoji text-[15px]">
                        {course.emoji}
                      </span>
                      <span
                        className={`min-w-0 flex-1 truncate text-[13.5px] ${
                          current ? "font-semibold text-ink" : "text-ink-secondary"
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
          className={`pressable mt-auto flex items-center justify-center gap-2 rounded-pill py-3.5 text-[15px] font-semibold ${
            importing ? "bg-ink text-on-ink" : "bg-ink text-on-ink"
          }`}
        >
          Importer
        </Link>
      </nav>

      <nav
        aria-label="Navigation"
        className="fixed inset-x-0 bottom-0 z-20 px-4 pb-5 lg:hidden"
        data-print="hide"
      >
        {open.length > 0 ? (
          <div className="mx-auto mb-2 flex max-w-[440px] gap-2 overflow-x-auto pb-0.5">
            {open.map((course) => (
              <div
                key={course.id}
                className={`flex shrink-0 items-center gap-1.5 rounded-pill bg-surface px-3 py-2 shadow-floating ${
                  isOpenCourse(course.id) ? "text-ink" : "text-ink-secondary"
                }`}
              >
                <Link
                  href={`/app/c/${course.id}` as never}
                  className="flex max-w-[10rem] items-center gap-1.5"
                >
                  <span aria-hidden className="emoji text-[14px]">
                    {course.emoji}
                  </span>
                  <span className="truncate text-[13px] font-medium">{course.title}</span>
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

        <div className="mx-auto flex max-w-[440px] items-end justify-between rounded-[28px] bg-surface px-3 pb-2.5 pt-3 shadow-floating">
          {LINKS.map((link) => {
            const current = isCurrent(link.href);
            return (
              <Link
                key={link.href}
                href={link.href as never}
                prefetch={link.prefetch}
                aria-current={current ? "page" : undefined}
                aria-label={link.label}
                className="relative flex flex-1 flex-col items-center gap-1"
              >
                {current ? <Caret /> : null}
                <Dot filled={current} size="lg">
                  <Icon name={link.icon} filled={current} />
                </Dot>
                <span
                  className={`text-[10px] ${current ? "font-semibold text-ink" : "text-ink-tertiary"}`}
                >
                  {link.label}
                </span>
              </Link>
            );
          })}
          <Link
            href="/app/importer"
            aria-label="Importer un cours"
            className="relative flex flex-1 flex-col items-center gap-1"
          >
            {importing ? <Caret /> : null}
            <Dot filled>
              <Icon name="plus" filled />
            </Dot>
            <span className={`text-[10px] ${importing ? "font-semibold text-ink" : "text-ink-tertiary"}`}>
              Importer
            </span>
          </Link>
        </div>
      </nav>
    </>
  );
}

function Dot({
  filled,
  size = "md",
  children,
}: {
  filled?: boolean;
  size?: "md" | "lg";
  children: React.ReactNode;
}) {
  return (
    <span
      aria-hidden
      className={`flex shrink-0 items-center justify-center rounded-full transition-colors duration-hover ${
        size === "lg" ? "h-11 w-11" : "h-10 w-10"
      } ${filled ? "bg-ink text-on-ink" : "bg-surface-muted text-ink-secondary"}`}
    >
      {children}
    </span>
  );
}

/** Le triangle qui ancre l'onglet actif à la page, au-dessus de la capsule. */
function Caret() {
  return (
    <span aria-hidden className="pointer-events-none absolute -top-2 left-1/2 -translate-x-1/2 text-ink">
      <svg width="12" height="6" viewBox="0 0 12 6">
        <path d="M0 6L6 0l6 6" fill="currentColor" />
      </svg>
    </span>
  );
}

function Icon({ name, filled }: { name: string; filled: boolean }) {
  return (
    <svg
      aria-hidden
      viewBox="0 0 20 20"
      className="h-[18px] w-[18px] shrink-0"
      fill="none"
      stroke="currentColor"
      strokeWidth={filled ? 1.9 : 1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {name === "home" ? (
        <>
          <path d="M3.5 9.2L10 3.6l6.5 5.6" />
          <path d="M5.2 8.4V16h9.6V8.4" />
        </>
      ) : null}
      {name === "shelf" ? (
        <>
          <rect x="3" y="3.5" width="4.5" height="13" rx="1.2" />
          <rect x="9" y="3.5" width="4.5" height="13" rx="1.2" />
          <path d="M15.5 5.2l2.2 11.1" />
        </>
      ) : null}
      {name === "cards" ? (
        <>
          <rect x="2.8" y="5.5" width="11" height="11" rx="2" />
          <path d="M6.5 3.5h8.2a2 2 0 0 1 2 2v8" />
        </>
      ) : null}
      {name === "calendar" ? (
        <>
          <rect x="3" y="4.5" width="14" height="12.5" rx="2" />
          <path d="M3 8.5h14M7 3v3M13 3v3" />
        </>
      ) : null}
      {name === "person" ? (
        <>
          <circle cx="10" cy="7" r="3" />
          <path d="M4.5 16.5a5.5 5.5 0 0 1 11 0" />
        </>
      ) : null}
      {name === "plus" ? <path d="M10 4.5v11M4.5 10h11" /> : null}
    </svg>
  );
}
