"use client";

import { useLayoutEffect } from "react";

import { recoverGeneratedCourseIfAny } from "@/lib/import-handoff";
import { useI18n } from "@/lib/i18n/client";

/**
 * Si un vol RSC casse l'app après l'écriture, on ouvre la fiche neuve
 * plutôt que le message générique de Next.
 */
export default function AppError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const { t } = useI18n();

  useLayoutEffect(() => {
    if (recoverGeneratedCourseIfAny()) return;
  }, [error]);

  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center px-6 text-center">
      <h1 className="text-lg font-semibold tracking-tight text-foreground">
        {t("app.common.errorGeneric")}
      </h1>
      <button
        type="button"
        onClick={() => reset()}
        className="mt-5 h-11 rounded-button bg-ink px-5 text-[15px] font-semibold text-white"
      >
        {t("app.common.continue")}
      </button>
    </div>
  );
}
