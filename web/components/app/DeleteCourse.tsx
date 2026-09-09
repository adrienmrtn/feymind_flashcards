"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { deleteCourse } from "@/lib/actions/course";
import { unpinOpenCourse } from "@/lib/open-courses";
import { useI18n } from "@/lib/i18n/client";

/**
 * Supprimer un cours.
 *
 * **Deux clics, jamais un.** Le premier ouvre la question, le second l'exécute : un cours
 * emporte sa fiche, ses cartes et sa place dans les épreuves, et rien de tout ça ne se
 * retrouve depuis l'écran. Un bouton qui supprime au premier clic transforme une glissade de
 * pouce en travail perdu.
 *
 * Il vit en bas de la fiche, en petit, après tout ce qui sert à lire : c'est un geste rare, et
 * un geste rare qui se présente aussi gros que le geste courant finit par être fait par
 * erreur.
 */
export function DeleteCourse({ courseId, title }: { courseId: string; title: string }) {
  const { t } = useI18n();
  const router = useRouter();
  const [asking, setAsking] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function remove() {
    setFailure(null);
    startTransition(async () => {
      const result = await deleteCourse(courseId);
      if (result.status === "error") {
        setFailure(result.message ?? t("app.common.errorGeneric"));
        setAsking(false);
        return;
      }
      // L'onglet du cours vit dans le navigateur, pas en base : sans ça, le cours supprimé
      // resterait dans « Ouverts » jusqu'au prochain nettoyage, et un clic dessus ouvrirait
      // une page introuvable.
      unpinOpenCourse(courseId);
      router.push("/app/cours" as never);
      router.refresh();
    });
  }

  if (!asking) {
    return (
      <div data-print="hide">
        <button
          type="button"
          onClick={() => setAsking(true)}
          className="text-[13px] font-medium text-ink-tertiary underline-draw hover:text-negative"
        >
          {t("app.course.delete.action")}
        </button>
        {failure ? (
          <p className="mt-2 text-[12.5px] text-negative" role="alert">
            {failure}
          </p>
        ) : null}
      </div>
    );
  }

  return (
    <div className="panel p-5" data-print="hide">
      <p className="section-title">{t("app.course.delete.title", { name: title })}</p>
      <p className="section-lead max-w-[52ch]">{t("app.course.delete.lead")}</p>
      <div className="mt-4 flex flex-wrap gap-2">
        <Button variant="destructive" disabled={pending} onClick={remove}>
          {pending ? t("app.exams.wait") : t("app.course.delete.confirm")}
        </Button>
        <Button variant="ghost" disabled={pending} onClick={() => setAsking(false)}>
          {t("app.common.cancel")}
        </Button>
      </div>
      {failure ? (
        <p className="mt-3 text-[12.5px] text-negative" role="alert">
          {failure}
        </p>
      ) : null}
    </div>
  );
}
