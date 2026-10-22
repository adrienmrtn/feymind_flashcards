"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BookOpen, GraduationCap, Home, User } from "lucide-react";

import { PastelWash } from "@/components/atmosphere/PastelWash";
import { BrandMark } from "@/components/BrandMark";
import { useI18n } from "@/lib/i18n/client";
import { EXAMS_PATH, HOME_PATH, insideLesson, LESSONS_PATH, PROFILE_PATH } from "@/lib/lesson/routes";
import { WEBSITE_PASTEL } from "@/lib/pastel";

/**
 * La charpente de l'app : **quatre destinations**, comme l'iPhone (`docs/refonte-web.md` § 0).
 *
 * Home, Leçons, Examen, Profil : en barre latérale sur grand écran, en barre d'onglets sous
 * `lg`. Plus d'« Importer » — on crée depuis Home — ni de section « compte » : les amis, les
 * réglages et l'abonnement vivent dans Profil. Les anciennes adresses redirigent vers leur
 * onglet ; en attendant que leurs écrans partent (lot 8), elles s'allument sous celui qui
 * les remplace.
 */

const DESTINATIONS = [
  { href: HOME_PATH, labelKey: "lesson.tab.home", icon: Home },
  { href: LESSONS_PATH, labelKey: "lesson.tab.lessons", icon: BookOpen },
  { href: EXAMS_PATH, labelKey: "lesson.tab.exams", icon: GraduationCap },
  { href: PROFILE_PATH, labelKey: "lesson.tab.profile", icon: User },
] as const;

/** L'onglet qu'une adresse allume. */
export function destinationOf(pathname: string): (typeof DESTINATIONS)[number]["href"] {
  const path = pathname.replace(/\/+$/, "") || "/app";
  if (path.startsWith("/app/lecons") || path === "/app/cours" || path.startsWith("/app/c/") || path.startsWith("/app/b/") || path.startsWith("/app/paquet")) return LESSONS_PATH;
  if (path.startsWith("/app/examen") || path.startsWith("/app/plan")) return EXAMS_PATH;
  if (
    path.startsWith("/app/profil") ||
    path.startsWith("/app/reglages") ||
    path.startsWith("/app/amis") ||
    path.startsWith("/app/u/") ||
    path.startsWith("/app/retours") ||
    path.startsWith("/app/progres")
  ) {
    return PROFILE_PATH;
  }
  return HOME_PATH;
}

export function AppChrome({ children, userName, userInitial }: { children: React.ReactNode; userName: string; userInitial: string }) {
  const { t } = useI18n();

  return (
    <div className="app-shell relative isolate flex min-h-svh bg-background" {...(WEBSITE_PASTEL ? { "data-pastel": "on" } : {})}>
      {WEBSITE_PASTEL ? <PastelWash /> : null}
      <a
        href="#main-content"
        className="sr-only focus-visible:not-sr-only focus-visible:absolute focus-visible:left-4 focus-visible:top-3 focus-visible:z-50 focus-visible:rounded-button focus-visible:bg-accent focus-visible:px-3 focus-visible:py-2 focus-visible:text-[13px] focus-visible:font-medium focus-visible:text-on-ink"
      >
        {t("app.a11y.skipToContent")}
      </a>

      <Sidebar userName={userName} userInitial={userInitial} />

      <div className="flex min-w-0 flex-1 flex-col">
        <MobileHeader userInitial={userInitial} />
        <main id="main-content" className="flex-1 px-4 pb-8 pt-5 lg:px-10 lg:pt-8">
          <div className="mx-auto w-full max-w-[1040px] space-y-6">{children}</div>
        </main>
        <TabBar />
      </div>
    </div>
  );
}

/** Sous `lg` : le nom de l'onglet, et le compte. Rien d'autre — et rien du tout dans une leçon. */
function MobileHeader({ userInitial }: { userInitial: string }) {
  const pathname = usePathname();
  const { t } = useI18n();
  const current = DESTINATIONS.find((item) => item.href === destinationOf(pathname)) ?? DESTINATIONS[0];
  if (insideLesson(pathname)) return null;

  return (
    <header className="sticky top-0 z-30 border-b border-border bg-background/95 backdrop-blur-sm lg:hidden" data-print="hide">
      <div className="flex h-13 items-center justify-between gap-3 px-4">
        <span className="truncate text-[15px] font-extrabold tracking-tight text-ink">{t(current.labelKey)}</span>
        <Link href={PROFILE_PATH} aria-label={t("lesson.tab.profile")} className="pressable flex h-8 w-8 items-center justify-center rounded-full bg-accent text-[12px] font-extrabold text-on-ink">
          {userInitial}
        </Link>
      </div>
    </header>
  );
}

function Sidebar({ userName, userInitial }: { userName: string; userInitial: string }) {
  const pathname = usePathname();
  const { t } = useI18n();
  const current = destinationOf(pathname);

  return (
    <aside aria-label={t("app.a11y.navigation")} className="sticky top-0 hidden h-svh w-60 shrink-0 flex-col self-start border-r border-sidebar-border bg-sidebar lg:flex" data-print="hide">
      <Link href={HOME_PATH} className="flex items-center gap-2.5 px-5 pb-4 pt-5" aria-label="Micabo">
        <BrandMark size={28} />
        <span className="text-[15px] font-extrabold tracking-tight text-sidebar-accent-foreground">micabo</span>
      </Link>
      <nav className="flex flex-1 flex-col gap-0.5 overflow-y-auto px-3 pt-2" data-tour="nav">
        {DESTINATIONS.map((item) => {
          const Icon = item.icon;
          const on = item.href === current;
          return (
            <Link
              key={item.href}
              href={item.href}
              prefetch
              aria-current={on ? "page" : undefined}
              className={`group flex h-10 items-center gap-2.5 rounded-[12px] px-2.5 text-[14.5px] font-bold transition-colors duration-hover ${
                on ? "bg-sidebar-accent text-sidebar-accent-foreground" : "text-sidebar-foreground hover:bg-sidebar-accent/60 hover:text-sidebar-accent-foreground"
              }`}
            >
              <Icon className={`size-[18px] shrink-0 ${on ? "text-accent" : "text-sidebar-foreground/80"}`} strokeWidth={on ? 2.4 : 2} />
              <span className="truncate">{t(item.labelKey)}</span>
            </Link>
          );
        })}
      </nav>
      <div className="border-t border-sidebar-border p-3">
        <Link href={PROFILE_PATH} className="flex h-10 items-center gap-2.5 rounded-[12px] px-2 hover:bg-sidebar-accent/60">
          <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-accent text-[11px] font-extrabold text-on-ink">{userInitial}</span>
          <span className="min-w-0 flex-1 truncate text-[13px] font-semibold text-sidebar-accent-foreground">{userName}</span>
        </Link>
      </div>
    </aside>
  );
}

/** Sous `lg` : les quatre onglets, collés en bas. Sa hauteur est `--tab-bar-space` (voir `globals.css`). */
function TabBar() {
  const pathname = usePathname();
  const { t } = useI18n();
  const current = destinationOf(pathname);

  return (
    <nav aria-label={t("app.a11y.navigation")} data-print="hide" className="sticky bottom-0 z-30 flex border-t border-border bg-background/95 backdrop-blur-sm lg:hidden">
      {DESTINATIONS.map((item) => {
        const on = item.href === current;
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            prefetch
            aria-current={on ? "page" : undefined}
            className={`flex min-w-0 flex-1 flex-col items-center gap-1 px-1 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-2 text-[10.5px] ${on ? "font-extrabold text-accent" : "font-bold text-ink-tertiary"}`}
          >
            <Icon className="size-[19px] shrink-0" strokeWidth={on ? 2.4 : 2} />
            <span className="w-full truncate text-center">{t(item.labelKey)}</span>
          </Link>
        );
      })}
    </nav>
  );
}
