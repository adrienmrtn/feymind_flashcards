"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  BookOpen,
  CalendarDays,
  Inbox,
  Repeat,
  Settings,
  Sun,
  TrendingUp,
  Upload,
  Users,
  X,
} from "lucide-react";

import { PastelWash } from "@/components/atmosphere/PastelWash";
import { BrandMark } from "@/components/BrandMark";
import { useI18n } from "@/lib/i18n/client";
import { requestPaywall } from "@/lib/paywall";
import { OPEN_COURSES_EVENT, readOpenCourses, unpinOpenCourse, type OpenCourseTab } from "@/lib/open-courses";
import { WEBSITE_PASTEL } from "@/lib/pastel";

/**
 * La charpente de l'app : une barre latérale, la page.
 *
 * Cinq destinations, dans l'ordre où la journée se passe : ce qu'il y a à faire aujourd'hui,
 * réviser, les cours, les épreuves, et ce que ça donne. Le compte (amis, réglages) vit en
 * dessous, à part. Il n'y a plus d'en-tête sur grand écran : la page porte son propre titre,
 * et une barre qui répète le nom de l'onglet courant ne disait rien de plus que la barre
 * latérale juste à côté.
 */

const DESTINATIONS = [
  { href: "/app", labelKey: "nav.today", icon: Sun },
  { href: "/app/reviser", labelKey: "nav.review", icon: Repeat },
  { href: "/app/cours", labelKey: "nav.courses", icon: BookOpen },
  { href: "/app/plan", labelKey: "nav.exams", icon: CalendarDays },
  { href: "/app/progres", labelKey: "nav.progress", icon: TrendingUp },
] as const;

const ACCOUNT_LINKS = [
  { href: "/app/amis", labelKey: "nav.friends", icon: Users },
  { href: "/app/reglages", labelKey: "nav.settings", icon: Settings },
] as const;

function sectionLabel(pathname: string, t: (key: string) => string): string {
  if (pathname.startsWith("/app/importer")) return t("nav.import");
  if (pathname.startsWith("/app/reviser")) return t("nav.review");
  if (pathname.startsWith("/app/paquet")) return t("nav.decks");
  if (pathname.startsWith("/app/plan/nouveau")) return t("app.newPlan.title");
  if (pathname.startsWith("/app/plan") || pathname.startsWith("/app/examens")) {
    return t("nav.exams");
  }
  if (pathname.startsWith("/app/progres")) return t("nav.progress");
  if (pathname.startsWith("/app/retours")) return t("nav.feedback");
  if (pathname.startsWith("/app/amis") || pathname.startsWith("/app/u/")) return t("nav.friends");
  if (pathname.startsWith("/app/profil") || pathname.startsWith("/app/reglages")) {
    return t("nav.settings");
  }
  if (
    pathname.startsWith("/app/cours") ||
    pathname.startsWith("/app/c/") ||
    pathname.startsWith("/app/b/")
  ) {
    return t("nav.courses");
  }
  return t("nav.today");
}

function isCurrent(pathname: string, href: string): boolean {
  const path = pathname.replace(/\/+$/, "") || "/app";
  if (href === "/app") return path === "/app";
  if (href === "/app/plan") {
    return path.startsWith("/app/plan") || path.startsWith("/app/examens");
  }
  if (href === "/app/cours") {
    return (
      path === "/app/cours" ||
      path.startsWith("/app/c/") ||
      path.startsWith("/app/b/") ||
      path.startsWith("/app/paquet")
    );
  }
  if (href === "/app/reglages") {
    return path.startsWith("/app/reglages") || path.startsWith("/app/profil");
  }
  if (href === "/app/amis") {
    return path.startsWith("/app/amis") || path.startsWith("/app/u/");
  }
  return path.startsWith(href);
}

export function AppChrome({
  children,
  userName,
  userInitial,
  canImport = true,
  canReadInbox = false,
}: {
  children: React.ReactNode;
  userName: string;
  userInitial: string;
  canImport?: boolean;
  canReadInbox?: boolean;
}) {
  const { t } = useI18n();

  return (
    <div
      className="app-shell relative isolate flex min-h-svh bg-background"
      {...(WEBSITE_PASTEL ? { "data-pastel": "on" } : {})}
    >
      {WEBSITE_PASTEL ? <PastelWash /> : null}
      <a
        href="#main-content"
        className="sr-only focus-visible:not-sr-only focus-visible:absolute focus-visible:left-4 focus-visible:top-3 focus-visible:z-50 focus-visible:rounded-button focus-visible:bg-accent focus-visible:px-3 focus-visible:py-2 focus-visible:text-[13px] focus-visible:font-medium focus-visible:text-on-ink"
      >
        {t("app.a11y.skipToContent")}
      </a>

      <Sidebar
        userName={userName}
        userInitial={userInitial}
        canImport={canImport}
        canReadInbox={canReadInbox}
      />

      <div className="flex min-w-0 flex-1 flex-col">
        <MobileHeader userInitial={userInitial} canImport={canImport} />
        <main id="main-content" className="flex-1 px-4 pb-8 pt-5 lg:px-10 lg:pt-8">
          <div className="mx-auto w-full max-w-[1040px] space-y-6">{children}</div>
        </main>
        <TabBar />
      </div>

    </div>
  );
}

/** Sous `lg` : le titre de la section, l'import, le compte. Rien d'autre. */
function MobileHeader({ userInitial, canImport }: { userInitial: string; canImport: boolean }) {
  const pathname = usePathname();
  const { t } = useI18n();

  return (
    <header className="sticky top-0 z-30 border-b border-border bg-background/95 backdrop-blur-sm lg:hidden">
      <div className="flex h-13 items-center justify-between gap-3 px-4">
        <span className="truncate text-[15px] font-semibold tracking-tight text-ink">
          {sectionLabel(pathname, t)}
        </span>
        <div className="flex shrink-0 items-center gap-1">
          {canImport ? (
            <Link
              href={"/app/importer" as never}
              aria-label={t("nav.import")}
              className="pressable flex h-9 w-9 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted"
            >
              <Upload className="size-[18px]" />
            </Link>
          ) : (
            <button
              type="button"
              onClick={requestPaywall}
              aria-label={t("nav.import")}
              className="pressable flex h-9 w-9 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted"
            >
              <Upload className="size-[18px]" />
            </button>
          )}
          <Link
            href={"/app/reglages" as never}
            aria-label={t("nav.settings")}
            className="pressable flex h-8 w-8 items-center justify-center rounded-full bg-surface-sunken text-[12px] font-semibold text-ink"
          >
            {userInitial}
          </Link>
        </div>
      </div>
    </header>
  );
}

function Sidebar({
  userName,
  userInitial,
  canImport,
  canReadInbox,
}: {
  userName: string;
  userInitial: string;
  canImport: boolean;
  canReadInbox: boolean;
}) {
  const { t } = useI18n();

  return (
    <aside
      aria-label={t("app.a11y.navigation")}
      className="sticky top-0 hidden h-svh w-60 shrink-0 flex-col self-start border-r border-sidebar-border bg-sidebar lg:flex"
      data-print="hide"
    >
      <Brand />
      <div className="px-3 pb-2">
        <ImportLink canImport={canImport} />
      </div>
      <div className="flex-1 overflow-y-auto">
        <NavList canReadInbox={canReadInbox} />
        <OpenCourses />
      </div>
      <div className="border-t border-sidebar-border p-3">
        <UserBlock name={userName} initial={userInitial} />
      </div>
    </aside>
  );
}

function Brand() {
  return (
    <Link href="/app" className="flex items-center gap-2.5 px-5 pb-4 pt-5" aria-label="Micabo">
      <BrandMark size={28} />
      <span className="text-[15px] font-semibold tracking-tight text-sidebar-accent-foreground">
        micabo
      </span>
    </Link>
  );
}

function NavList({ canReadInbox }: { canReadInbox: boolean }) {
  const pathname = usePathname();
  const { t } = useI18n();

  return (
    <nav className="flex flex-col gap-6 px-3 pt-3" data-tour="nav">
      <div className="flex flex-col gap-0.5">
        {DESTINATIONS.map((item) => (
          <NavRow
            key={item.href}
            href={item.href}
            label={t(item.labelKey)}
            icon={item.icon}
            current={isCurrent(pathname, item.href)}
          />
        ))}
      </div>
      <div className="flex flex-col gap-0.5">
        <p className="px-2.5 pb-1.5 text-[11px] font-medium uppercase tracking-[0.08em] text-ink-tertiary">
          {t("nav.account")}
        </p>
        {ACCOUNT_LINKS.map((item) => (
          <NavRow
            key={item.href}
            href={item.href}
            label={t(item.labelKey)}
            icon={item.icon}
            current={isCurrent(pathname, item.href)}
          />
        ))}
        {canReadInbox ? (
          <NavRow
            href="/app/retours"
            label={t("nav.feedback")}
            icon={Inbox}
            current={pathname.startsWith("/app/retours")}
          />
        ) : null}
      </div>
    </nav>
  );
}

function NavRow({
  href,
  label,
  icon: Icon,
  current,
}: {
  href: string;
  label: string;
  icon: typeof BookOpen;
  current: boolean;
}) {
  return (
    <Link
      href={href as never}
      prefetch
      aria-current={current ? "page" : undefined}
      className={`group flex h-9 items-center gap-2.5 rounded-lg px-2.5 text-[13.5px] transition-colors duration-hover ${
        current
          ? "bg-sidebar-accent font-medium text-sidebar-accent-foreground"
          : "text-sidebar-foreground hover:bg-sidebar-accent/60 hover:text-sidebar-accent-foreground"
      }`}
    >
      <Icon
        className={`size-4 shrink-0 ${
          current ? "text-sidebar-accent-foreground" : "text-sidebar-foreground/80"
        }`}
        strokeWidth={current ? 2.1 : 1.8}
      />
      <span className="truncate">{label}</span>
    </Link>
  );
}

function TabBar() {
  const pathname = usePathname();
  const { t } = useI18n();

  return (
    <nav
      aria-label={t("app.a11y.navigation")}
      data-print="hide"
      className="sticky bottom-0 z-30 flex border-t border-border bg-background/95 backdrop-blur-sm lg:hidden"
    >
      {DESTINATIONS.map((item) => {
        const current = isCurrent(pathname, item.href);
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href as never}
            prefetch
            aria-current={current ? "page" : undefined}
            className={`flex min-w-0 flex-1 flex-col items-center gap-1 px-1 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-2 text-[10.5px] ${
              current ? "font-semibold text-ink" : "text-ink-tertiary"
            }`}
          >
            <Icon className="size-[19px] shrink-0" strokeWidth={current ? 2.1 : 1.8} />
            <span className="w-full truncate text-center">{t(item.labelKey)}</span>
          </Link>
        );
      })}
    </nav>
  );
}

function OpenCourses() {
  const pathname = usePathname();
  const { t } = useI18n();
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
    <div className="px-3 pt-6">
      <p className="px-2.5 pb-1.5 text-[11px] font-medium uppercase tracking-[0.08em] text-ink-tertiary">
        {t("nav.openCourses")}
      </p>
      <div className="flex max-h-48 flex-col gap-0.5 overflow-y-auto">
        {open.map((course) => {
          const current = pathname.startsWith(`/app/c/${course.id}`);
          return (
            <div key={course.id} className="group flex items-center gap-0.5">
              <Link
                href={`/app/c/${course.id}` as never}
                className={`flex h-9 min-w-0 flex-1 items-center gap-2.5 rounded-lg px-2.5 text-[13.5px] ${
                  current
                    ? "bg-sidebar-accent font-medium text-sidebar-accent-foreground"
                    : "text-sidebar-foreground hover:bg-sidebar-accent/60"
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
                aria-label={t("app.a11y.closeCourse", { title: course.title })}
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
  const { t } = useI18n();
  const current = pathname.startsWith("/app/importer");
  const className = `flex h-9 w-full items-center justify-center gap-2 rounded-lg border text-[13.5px] font-medium transition-[background-color,border-color,color] duration-hover ${
    current
      ? "border-ink bg-ink text-on-ink"
      : "border-stroke-strong bg-surface text-ink hover:bg-surface-muted"
  }`;

  if (!canImport) {
    return (
      <button type="button" onClick={requestPaywall} className={className} data-tour="nav-importer">
        <Upload className="size-4 shrink-0" strokeWidth={1.9} />
        {t("nav.import")}
      </button>
    );
  }

  return (
    <Link href={"/app/importer" as never} className={className} data-tour="nav-importer">
      <Upload className="size-4 shrink-0" strokeWidth={1.9} />
      {t("nav.import")}
    </Link>
  );
}

function UserBlock({ name, initial }: { name: string; initial: string }) {
  return (
    <Link
      href={"/app/reglages" as never}
      className="flex h-10 items-center gap-2.5 rounded-lg px-2 hover:bg-sidebar-accent/60"
    >
      <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-surface-sunken text-[11px] font-semibold text-ink">
        {initial}
      </span>
      <span className="min-w-0 flex-1 truncate text-[13px] text-sidebar-accent-foreground">
        {name}
      </span>
    </Link>
  );
}
