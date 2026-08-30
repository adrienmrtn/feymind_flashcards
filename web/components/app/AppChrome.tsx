"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  BookOpen,
  CalendarDays,
  House,
  Layers,
  LogOut,
  Menu,
  Settings,
  Upload,
  UserRound,
  Users,
  X,
} from "lucide-react";

import { BrandMark } from "@/components/BrandMark";
import { Button } from "@/components/ui/button";
import { signOut } from "@/lib/actions/profile";
import { requestPaywall } from "@/lib/paywall";
import {
  OPEN_COURSES_EVENT,
  readOpenCourses,
  unpinOpenCourse,
  type OpenCourseTab,
} from "@/lib/open-courses";

/**
 * Le chrome de l'app : celui de micabo OS.
 *
 * Sidebar 256 px, en-tête flou, tiroir à gauche sur téléphone. Pas de pastille
 * en bas d'écran : on travaille, on ne balaye pas cinq onglets.
 */

const GROUPS = [
  {
    title: "Étudier",
    items: [
      { href: "/app", label: "Accueil", icon: House, prefetch: true },
      { href: "/app/reviser", label: "Réviser", icon: Layers, prefetch: false },
    ],
  },
  {
    title: "Bibliothèque",
    items: [
      { href: "/app/cours", label: "Cours", icon: BookOpen, prefetch: true },
      { href: "/app/examens", label: "Examens", icon: CalendarDays, prefetch: true },
    ],
  },
  {
    title: "Compte",
    items: [
      { href: "/app/amis", label: "Amis", icon: Users, prefetch: true },
      { href: "/app/profil", label: "Profil", icon: UserRound, prefetch: true },
      { href: "/app/reglages", label: "Réglages", icon: Settings, prefetch: true },
    ],
  },
] as const;

function sectionLabel(pathname: string): string {
  if (pathname.startsWith("/app/importer")) return "Importer";
  if (pathname.startsWith("/app/reviser")) return "Réviser";
  if (pathname.startsWith("/app/examens")) return "Examens";
  if (pathname.startsWith("/app/amis") || pathname.startsWith("/app/u/")) return "Amis";
  if (pathname.startsWith("/app/profil")) return "Profil";
  if (pathname.startsWith("/app/reglages")) return "Réglages";
  if (
    pathname.startsWith("/app/cours") ||
    pathname.startsWith("/app/c/") ||
    pathname.startsWith("/app/b/")
  ) {
    return "Cours";
  }
  return "Accueil";
}

function isCurrent(pathname: string, href: string): boolean {
  if (href === "/app") return pathname === "/app";
  if (href === "/app/cours") {
    return (
      pathname === "/app/cours" ||
      pathname.startsWith("/app/c/") ||
      pathname.startsWith("/app/b/")
    );
  }
  if (href === "/app/profil") return pathname.startsWith("/app/profil");
  if (href === "/app/amis") {
    return pathname.startsWith("/app/amis") || pathname.startsWith("/app/u/");
  }
  return pathname.startsWith(href);
}

export function AppChrome({
  children,
  userName,
  userInitial,
  canImport = true,
}: {
  children: React.ReactNode;
  userName: string;
  userInitial: string;
  canImport?: boolean;
}) {
  const [drawer, setDrawer] = useState(false);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    if (!drawer) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [drawer]);

  async function leave() {
    if (leaving) return;
    setLeaving(true);
    await signOut();
  }

  return (
    <div className="app-shell flex min-h-svh bg-background">
      <Sidebar userName={userName} userInitial={userInitial} canImport={canImport} />
      {drawer ? (
        <MobileDrawer
          userName={userName}
          userInitial={userInitial}
          canImport={canImport}
          onClose={() => setDrawer(false)}
        />
      ) : null}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 border-b border-border/80 bg-background/85 backdrop-blur-md">
          <div className="flex h-14 items-center justify-between gap-3 px-4 lg:px-8">
            <div className="flex min-w-0 items-center gap-2">
              <Button
                variant="ghost"
                size="icon"
                className="lg:hidden"
                onClick={() => setDrawer(true)}
                aria-label="Ouvrir le menu"
              >
                <Menu />
              </Button>
              <HeaderTitle />
            </div>
            <Button variant="ghost" size="sm" onClick={() => void leave()} disabled={leaving}>
              <LogOut />
              <span className="hidden sm:inline">{leaving ? "Déconnexion…" : "Se déconnecter"}</span>
            </Button>
          </div>
        </header>

        <main className="flex-1 px-4 py-5 lg:px-8 lg:py-6">
          <div className="mx-auto w-full max-w-6xl space-y-5">{children}</div>
        </main>
      </div>
    </div>
  );
}

function HeaderTitle() {
  const pathname = usePathname();
  return (
    <span className="truncate text-sm font-semibold tracking-tight">{sectionLabel(pathname)}</span>
  );
}

function Sidebar({
  userName,
  userInitial,
  canImport,
}: {
  userName: string;
  userInitial: string;
  canImport: boolean;
}) {
  return (
    <aside
      aria-label="Navigation"
      className="sticky top-0 hidden h-svh w-64 shrink-0 flex-col self-start border-r border-sidebar-border bg-sidebar lg:flex"
      data-print="hide"
    >
      <Brand />
      <div className="mx-3 h-px bg-sidebar-border" />
      <div className="flex-1 overflow-y-auto">
        <NavList />
        <OpenCourses />
      </div>
      <div className="space-y-3 border-t border-sidebar-border p-3">
        <ImportLink canImport={canImport} />
        <UserBlock name={userName} initial={userInitial} />
      </div>
    </aside>
  );
}

function MobileDrawer({
  userName,
  userInitial,
  canImport,
  onClose,
}: {
  userName: string;
  userInitial: string;
  canImport: boolean;
  onClose: () => void;
}) {
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-40 lg:hidden" data-print="hide">
      <button
        type="button"
        aria-label="Fermer le menu"
        className="absolute inset-0 bg-ink/20"
        onClick={onClose}
      />
      <aside className="absolute inset-y-0 left-0 flex w-72 max-w-[calc(100vw-2rem)] flex-col border-r border-sidebar-border bg-sidebar">
        <div className="flex items-center justify-between pr-2">
          <Brand />
          <Button variant="ghost" size="icon" onClick={onClose} aria-label="Fermer">
            <X />
          </Button>
        </div>
        <div className="mx-3 h-px bg-sidebar-border" />
        <div className="flex-1 overflow-y-auto" onClick={onClose}>
          <NavList />
          <OpenCourses />
        </div>
        <div className="space-y-3 border-t border-sidebar-border p-3">
          <div onClick={onClose}>
            <ImportLink canImport={canImport} />
          </div>
          <UserBlock name={userName} initial={userInitial} />
        </div>
      </aside>
    </div>
  );
}

function Brand() {
  return (
    <Link href="/app" className="flex items-center gap-3 px-4 py-5" aria-label="Micabo">
      <BrandMark size={36} />
      <span className="min-w-0">
        <span className="block truncate text-base font-semibold tracking-tight text-sidebar-accent-foreground">
          micabo
        </span>
        <span className="block truncate text-[10px] uppercase tracking-[0.16em] text-sidebar-foreground">
          étudier
        </span>
      </span>
    </Link>
  );
}

function NavList() {
  const pathname = usePathname();

  return (
    <nav className="flex flex-col gap-5 px-3 py-2">
      {GROUPS.map((group) => (
        <div key={group.title} className="flex flex-col gap-0.5">
          <p className="px-2.5 pb-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-sidebar-foreground/70">
            {group.title}
          </p>
          {group.items.map((item) => {
            const current = isCurrent(pathname, item.href);
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href as never}
                prefetch={item.prefetch}
                aria-current={current ? "page" : undefined}
                className={`group flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-sm transition-colors ${
                  current
                    ? "bg-sidebar-accent font-medium text-sidebar-accent-foreground"
                    : "text-sidebar-foreground hover:bg-sidebar-accent/70 hover:text-sidebar-accent-foreground"
                }`}
              >
                <Icon
                  className={`size-4 shrink-0 ${
                    current
                      ? "text-sidebar-accent-foreground"
                      : "text-sidebar-foreground/70 group-hover:text-sidebar-accent-foreground"
                  }`}
                />
                <span className="truncate">{item.label}</span>
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );
}

function OpenCourses() {
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

  if (open.length === 0) return null;

  return (
    <div className="px-3 pb-2">
      <p className="px-2.5 pb-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-sidebar-foreground/70">
        Ouverts
      </p>
      <div className="flex max-h-48 flex-col gap-0.5 overflow-y-auto">
        {open.map((course) => {
          const current = pathname.startsWith(`/app/c/${course.id}`);
          return (
            <div key={course.id} className="group flex items-center gap-0.5">
              <Link
                href={`/app/c/${course.id}` as never}
                className={`flex min-w-0 flex-1 items-center gap-2.5 rounded-lg px-2.5 py-2 text-sm ${
                  current
                    ? "bg-sidebar-accent font-medium text-sidebar-accent-foreground"
                    : "text-sidebar-foreground hover:bg-sidebar-accent/70"
                }`}
              >
                <span aria-hidden className="emoji text-[14px]">
                  {course.emoji}
                </span>
                <span className="truncate">{course.title}</span>
              </Link>
              <button
                type="button"
                onClick={() => setOpen(unpinOpenCourse(course.id))}
                aria-label={`Fermer ${course.title}`}
                className="flex size-8 shrink-0 items-center justify-center rounded-lg text-sidebar-foreground opacity-0 hover:bg-sidebar-accent group-hover:opacity-100 focus-visible:opacity-100"
              >
                <X className="size-3.5" />
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function ImportLink({ canImport }: { canImport: boolean }) {
  const pathname = usePathname();
  const current = pathname.startsWith("/app/importer");
  const className = `flex items-center gap-2.5 rounded-lg border px-2.5 py-2 text-sm font-medium transition-[scale,background-color,border-color,color] duration-press ease-out-strong active:scale-[0.96] ${
    current
      ? "border-transparent bg-sidebar-accent text-sidebar-accent-foreground"
      : "border-input bg-background text-foreground hover:bg-sidebar-accent/70"
  }`;

  if (!canImport) {
    return (
      <button type="button" onClick={requestPaywall} className={`${className} w-full`}>
        <Upload className="size-4 shrink-0 opacity-80" />
        Importer
      </button>
    );
  }

  return (
    <Link href={"/app/importer" as never} className={className}>
      <Upload className="size-4 shrink-0 opacity-80" />
      Importer
    </Link>
  );
}

function UserBlock({ name, initial }: { name: string; initial: string }) {
  return (
    <Link href={"/app/profil" as never} className="flex items-center gap-2.5 px-1 py-1">
      <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-sidebar-accent text-[11px] font-semibold text-sidebar-accent-foreground">
        {initial}
      </span>
      <span className="min-w-0 flex-1 truncate text-sm text-sidebar-accent-foreground">{name}</span>
    </Link>
  );
}
