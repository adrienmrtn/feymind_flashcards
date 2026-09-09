"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  BookOpen,
  CalendarDays,
  House,
  Inbox,
  Repeat,
  Settings,
  Upload,
  UserRound,
  Users,
  X,
} from "lucide-react";

import { ImportHandoffOverlay } from "@/components/app/ImportHandoff";
import { AppearanceSwitcher } from "@/components/appearance/AppearanceSwitcher";
import { PastelWash } from "@/components/atmosphere/PastelWash";
import { BrandMark } from "@/components/BrandMark";
import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";
import { requestPaywall } from "@/lib/paywall";
import { OPEN_COURSES_EVENT, readOpenCourses, unpinOpenCourse, type OpenCourseTab } from "@/lib/open-courses";
import { WEBSITE_PASTEL } from "@/lib/pastel";

/**
 * Le chrome de l'app : celui de micabo OS.
 *
 * **Quatre destinations, et pas huit.** La barre en portait trois groupes et neuf liens, dont
 * deux menaient à la même liste de cours sous deux noms. Ce qui reste répond à une question
 * chacune : qu'est-ce que je fais maintenant, je révise, où sont mes cours, est-ce que je vais
 * y arriver. Amis, profil et réglages n'ont pas disparu - ils sont sous l'avatar, en bas,
 * parce qu'on y va une fois par semaine et pas six fois par jour.
 *
 * Sidebar 256 px sur grand écran ; sur téléphone, une **barre d'onglets basse**. Le tiroir
 * coûtait deux gestes pour chaque navigation, et il cachait justement les quatre destinations
 * qu'on utilise tout le temps.
 */

// Les liens du chrome préchargent : ce sont les quatre pages ouvertes en boucle, et elles
// lisent toutes des instantanés déjà mis en cache.
const DESTINATIONS = [
  { href: "/app", labelKey: "nav.home", icon: House },
  { href: "/app/reviser", labelKey: "nav.review", icon: Repeat },
  { href: "/app/cours", labelKey: "nav.courses", icon: BookOpen },
  { href: "/app/plan", labelKey: "nav.plan", icon: CalendarDays },
] as const;

/** Ce qui vit sous l'avatar : rarement ouvert, jamais dans le chemin du travail. */
const ACCOUNT_LINKS = [
  { href: "/app/amis", labelKey: "nav.friends", icon: Users },
  { href: "/app/profil", labelKey: "nav.profile", icon: UserRound },
  { href: "/app/reglages", labelKey: "nav.settings", icon: Settings },
] as const;

function sectionLabel(pathname: string, t: (key: string) => string): string {
  if (pathname.startsWith("/app/importer")) return t("nav.import");
  if (pathname.startsWith("/app/reviser")) return t("nav.review");
  if (pathname.startsWith("/app/paquet")) {
    return t("nav.decks");
  }
  if (pathname.startsWith("/app/plan") || pathname.startsWith("/app/examens")) {
    return t("nav.plan");
  }
  if (pathname.startsWith("/app/retours")) return t("nav.feedback");
  if (pathname.startsWith("/app/amis") || pathname.startsWith("/app/u/")) return t("nav.friends");
  if (pathname.startsWith("/app/profil")) return t("nav.profile");
  if (pathname.startsWith("/app/reglages")) return t("nav.settings");
  if (
    pathname.startsWith("/app/cours") ||
    pathname.startsWith("/app/c/") ||
    pathname.startsWith("/app/b/")
  ) {
    return t("nav.courses");
  }
  return t("nav.home");
}

function isCurrent(pathname: string, href: string): boolean {
  if (href === "/app") return pathname === "/app";
  if (href === "/app/cours") {
    // Un paquet est un cours : ses anciennes routes s'allument sur la même destination.
    return (
      pathname === "/app/cours" ||
      pathname.startsWith("/app/c/") ||
      pathname.startsWith("/app/b/") ||
      pathname.startsWith("/app/paquet")
    );
  }
  if (href === "/app/plan") {
    return pathname.startsWith("/app/plan") || pathname.startsWith("/app/examens");
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
        {/* En-tête collant, donc repeint à chaque image du défilement. `backdrop-blur` y met
            un filtre plein écran : le navigateur doit rasteriser ce qui passe dessous, puis le
            flouter, soixante fois par seconde, et sur téléphone ça se voit. Le fond de l'app
            est blanc et ses cartes sont blanches - le flou n'y montrait rien. Il reste à partir
            de `lg`, où il porte le verre du chrome sans coûter le défilement. */}
        <header className="sticky top-0 z-30 border-b border-border/80 bg-background lg:bg-background/85 lg:backdrop-blur-md">
          <div className="flex h-14 items-center justify-between gap-3 px-4 lg:px-8">
            <div className="flex min-w-0 items-center gap-2">
              <HeaderTitle />
            </div>
            {/* Se déconnecter était l'élément le plus visible de l'app, pour une action
                faite une fois par an. Il est dans les réglages, avec le reste du compte. */}
            <div className="flex shrink-0 items-center gap-1.5">
              <AppearanceSwitcher variant="compact" />
              <Link
                href={"/app/importer" as never}
                aria-label={t("nav.import")}
                className="pressable flex h-9 w-9 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted lg:hidden"
              >
                <Upload className="size-[18px]" />
              </Link>
              <Link
                href={"/app/profil" as never}
                aria-label={t("nav.profile")}
                className="pressable flex h-9 w-9 items-center justify-center rounded-full bg-surface-muted text-[13px] font-semibold text-ink lg:hidden"
              >
                {userInitial}
              </Link>
            </div>
          </div>
        </header>

        <main id="main-content" className="flex-1 px-4 py-5 lg:px-8 lg:py-6">
          <div className="mx-auto w-full max-w-6xl space-y-5">{children}</div>
        </main>

        <TabBar />
      </div>
      <ImportHandoffOverlay />
    </div>
  );
}

function HeaderTitle() {
  const pathname = usePathname();
  const { t } = useI18n();
  return (
    <span className="truncate text-sm font-semibold tracking-tight">{sectionLabel(pathname, t)}</span>
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
      className="sticky top-0 hidden h-svh w-64 shrink-0 flex-col self-start border-r border-sidebar-border bg-sidebar lg:flex"
      data-print="hide"
    >
      <Brand />
      <div className="mx-3 h-px bg-sidebar-border" />
      <div className="flex-1 overflow-y-auto">
        <NavList canReadInbox={canReadInbox} />
        <OpenCourses />
      </div>
      <div className="space-y-3 border-t border-sidebar-border p-3">
        <ImportLink canImport={canImport} />
        <UserBlock name={userName} initial={userInitial} />
      </div>
    </aside>
  );
}

function Brand() {
  const { t } = useI18n();
  return (
    <Link href="/app" className="flex items-center gap-3 px-4 py-5" aria-label="Micabo">
      <BrandMark size={36} />
      <span className="min-w-0">
        <span className="block truncate text-base font-semibold tracking-tight text-sidebar-accent-foreground">
          micabo
        </span>
        <span className="block truncate text-[10px] uppercase tracking-[0.16em] text-sidebar-foreground">
          {t("app.brand.tagline")}
        </span>
      </span>
    </Link>
  );
}

function NavList({ canReadInbox }: { canReadInbox: boolean }) {
  const pathname = usePathname();
  const { t } = useI18n();

  return (
    <nav className="flex flex-col gap-5 px-3 py-2" data-tour="nav">
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
        <p className="px-2.5 pb-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-sidebar-foreground/70">
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
  icon: typeof House;
  current: boolean;
}) {
  return (
    <Link
      href={href as never}
      prefetch
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
      <span className="truncate">{label}</span>
    </Link>
  );
}

/**
 * La barre d'onglets du téléphone.
 *
 * Elle remplace le tiroir : les quatre destinations sont atteignables au pouce, en un geste.
 * Elle disparaît en session - on ne change pas d'écran au milieu d'une carte.
 */
function TabBar() {
  const pathname = usePathname();
  const { t } = useI18n();

  return (
    <nav
      aria-label={t("app.a11y.navigation")}
      data-print="hide"
      className="sticky bottom-0 z-30 flex border-t border-border bg-background/95 backdrop-blur-md lg:hidden"
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
            className={`flex min-w-0 flex-1 flex-col items-center gap-1 px-1 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-2.5 text-[11px] ${
              current ? "font-semibold text-ink" : "text-ink-tertiary"
            }`}
          >
            <Icon className={`size-[19px] shrink-0 ${current ? "text-ink" : ""}`} />
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
    <div className="px-3 pb-2">
      <p className="px-2.5 pb-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-sidebar-foreground/70">
        {t("nav.openCourses")}
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
  const className = `flex items-center gap-2.5 rounded-lg border px-2.5 py-2 text-sm font-medium transition-[scale,background-color,border-color,color] duration-press ease-out-strong active:scale-[0.96] ${
    current
      ? "border-transparent bg-sidebar-accent text-sidebar-accent-foreground"
      : "border-input bg-background text-foreground hover:bg-sidebar-accent/70"
  }`;

  if (!canImport) {
    return (
      <button
        type="button"
        onClick={requestPaywall}
        className={`${className} w-full`}
        data-tour="nav-importer"
      >
        <Upload className="size-4 shrink-0 opacity-80" />
        {t("nav.import")}
      </button>
    );
  }

  return (
    <Link href={"/app/importer" as never} className={className} data-tour="nav-importer">
      <Upload className="size-4 shrink-0 opacity-80" />
      {t("nav.import")}
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
