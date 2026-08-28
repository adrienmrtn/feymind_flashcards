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
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-lg font-semibold tracking-tight text-foreground">Cours</h1>
          <p className="mt-1 text-sm text-muted-foreground">Tes fiches.</p>
        </div>
        {revise}
      </header>
      {children}
    </>
  );
}
