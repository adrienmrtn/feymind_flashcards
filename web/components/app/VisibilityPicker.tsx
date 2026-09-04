"use client";

import { useState, useTransition } from "react";

import { DEFAULT_VISIBILITY, isVisibility, type CourseVisibility } from "@micabo/core";

import { VisibilityChoices } from "@/components/app/VisibilityChoices";
import { setCourseVisibility } from "@/lib/actions/profile";
import { useI18n } from "@/lib/i18n/client";

/**
 * Qui peut retrouver ce cours, changé depuis la fiche.
 *
 * Il en faut un ici, et pas seulement à l'import. On ne propose plus le dépôt
 * public : uniquement les amis, ou soi seul. Un cours déjà public se referme
 * depuis cette fiche.
 *
 * L'affichage change **avant** la réponse du serveur : l'app ne fait jamais attendre quelqu'un qui
 * vient de décider de se refermer. En cas d'échec, on revient à la valeur d'avant et on le dit.
 */
export function VisibilityPicker({
  courseId,
  initial,
}: {
  courseId: string;
  initial: string;
}) {
  const { t } = useI18n();
  const start: CourseVisibility = isVisibility(initial) ? initial : DEFAULT_VISIBILITY;
  const [value, setValue] = useState<CourseVisibility>(start);
  const [failed, setFailed] = useState(false);
  const [, startTransition] = useTransition();

  function choose(next: CourseVisibility) {
    if (next === value) return;
    const previous = value;
    setValue(next);
    setFailed(false);

    startTransition(async () => {
      const result = await setCourseVisibility(courseId, next);
      if (result.status === "error") {
        setValue(previous);
        setFailed(true);
      }
    });
  }

  return (
    <div data-print="hide">
      <VisibilityChoices value={value} onChange={choose} />
      {failed ? (
        <p className="mt-2 text-[12.5px] text-negative">{t("app.course.visibility.saveError")}</p>
      ) : null}
    </div>
  );
}
