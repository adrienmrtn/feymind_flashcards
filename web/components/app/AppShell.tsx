"use client";

import { usePathname } from "next/navigation";

/**
 * Le fond de l'app. L'ivoire reste la toile des listes et des cours.
 * Le profil (et les pages qui en sortent) se posent sur le gris froid
 * du modal « Sign up » — blanc, filet, ombre, rien d'autre.
 */
export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const cool =
    pathname.startsWith("/app/profil") ||
    pathname.startsWith("/app/amis") ||
    pathname.startsWith("/app/u/");

  return (
    <div className={`min-h-svh lg:flex ${cool ? "bg-[#f6f7f9]" : "bg-canvas"}`}>
      {children}
    </div>
  );
}
