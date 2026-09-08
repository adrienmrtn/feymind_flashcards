"use client";

import { useEffect, useLayoutEffect, useSyncExternalStore } from "react";
import { usePathname } from "next/navigation";

import { GenerationStatus } from "@/components/app/GenerationStatus";
import {
  IMPORT_HANDOFF_EVENT,
  readImportHandoff,
  releaseImportHandoff,
  type ImportHandoff,
} from "@/lib/import-handoff";
import { useI18n } from "@/lib/i18n/client";

/**
 * Le voile d'écriture, collé au chrome : il survit au démontage de l'import.
 *
 * On le lève au clic « écrire la fiche », et on ne le retire que lorsque la
 * page du cours s'est vraiment peinte. `loading.tsx` du cours reprend le
 * même état, au cas où le voile n'aurait pas encore repris la main.
 */
export function ImportHandoffOverlay() {
  const pathname = usePathname();
  const handoff = useImportHandoff();

  useEffect(() => {
    if (!handoff) return;
    // L'identifiant n'est connu qu'à la fin de l'appel : on ne baisse pas
    // le voile juste parce que l'URL a quitté /importer.
    if (pathname.startsWith("/app/importer") || pathname.startsWith("/app/c/")) return;
    releaseImportHandoff();
  }, [handoff, pathname]);

  useEffect(() => {
    if (!handoff) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [handoff]);

  if (!handoff) return null;

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center bg-background px-6"
      data-print="hide"
    >
      <WritingSheetStatus name={handoff.name} startedAt={handoff.startedAt} />
    </div>
  );
}

/** Retire le voile au moment où la fiche est dans le DOM. */
export function ReleaseImportHandoff({ courseId }: { courseId: string }) {
  useLayoutEffect(() => {
    releaseImportHandoff(courseId);
  }, [courseId]);
  return null;
}

export function CourseOpeningFallback({ children }: { children: React.ReactNode }) {
  const handoff = useImportHandoff();
  if (!handoff) return children;
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center">
      <WritingSheetStatus name={handoff.name} startedAt={handoff.startedAt} />
    </div>
  );
}

export function WritingSheetStatus({
  name,
  startedAt,
}: {
  name?: string | null;
  startedAt?: number;
}) {
  const { t } = useI18n();
  return (
    <GenerationStatus
      title={t("app.import.writing")}
      hint={name?.trim() || t("app.import.waitHint")}
      startedAt={startedAt}
    />
  );
}

function subscribe(onStoreChange: () => void) {
  window.addEventListener(IMPORT_HANDOFF_EVENT, onStoreChange);
  return () => window.removeEventListener(IMPORT_HANDOFF_EVENT, onStoreChange);
}

function useImportHandoff(): ImportHandoff | null {
  return useSyncExternalStore(subscribe, readImportHandoff, () => null);
}
