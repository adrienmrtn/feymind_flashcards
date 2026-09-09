import type { ReactNode } from "react";

import { getTranslator } from "@/lib/i18n/server";

/**
 * L'en-tête de l'étagère. La bibliothèque publique (« Découvrir ») n'existe
 * plus ici : les cours des amis se voient encore sur leur profil, si leur
 * visibilité le permet.
 */
export async function CoursesExplore({
  revise,
  children,
}: {
  revise: ReactNode;
  children: ReactNode;
}) {
  const { t } = await getTranslator();
  return (
    <>
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="page-title">
            {t("app.courses.title")}
          </h1>
          <p className="page-lead">{t("app.courses.lead")}</p>
        </div>
        {revise}
      </header>
      {children}
    </>
  );
}
