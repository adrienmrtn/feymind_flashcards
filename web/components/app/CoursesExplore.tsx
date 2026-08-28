import type { ReactNode } from "react";

/**
 * L'en-tête de l'étagère. La bibliothèque publique (« Découvrir ») n'existe
 * plus ici : les cours des amis se voient encore sur leur profil, si leur
 * visibilité le permet.
 */
export function CoursesExplore({
  revise,
  children,
}: {
  revise: ReactNode;
  children: ReactNode;
}) {
  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="eyebrow text-ink-tertiary">📚 Ton étagère</p>
          <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">Cours</h1>
        </div>
        {revise}
      </header>
      {children}
    </>
  );
}
