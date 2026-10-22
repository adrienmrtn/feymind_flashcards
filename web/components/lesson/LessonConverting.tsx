"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Mika } from "@/components/mika/Mika";
import { Button } from "@/components/ui/button";
import { Spinner } from "@/components/ui/spinner";
import { openLessonOffline } from "@/lib/actions/lesson";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Un ancien cours qui devient une leçon** : Mika prépare le chemin.
 *
 * La page appelle `/api/lesson/convert` dès qu'elle s'ouvre, puis se recharge : le cours a
 * maintenant un plan, et c'est le chemin qui s'affiche. Si le modèle ne répond pas, deux
 * sorties : réessayer, ou « Ouvrir sans attendre » — la conversion sans le modèle, pour
 * n'être jamais bloqué devant son propre cours. Jumeau de `LessonPreparingView`.
 */
export function LessonConverting({ lessonId }: { lessonId: string }) {
  const { t } = useI18n();
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [pending, startTransition] = useTransition();
  const running = useRef(false);

  useEffect(() => {
    if (running.current) return;
    running.current = true;
    let cancelled = false;
    (async () => {
      try {
        const response = await fetch("/api/lesson/convert", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ lessonId }),
        });
        const result = (await response.json()) as { status: string; message?: string };
        if (cancelled) return;
        if (result.status === "ok") {
          router.refresh();
          return;
        }
        setError(result.message ?? t("lesson.convert.failed"));
      } catch {
        if (!cancelled) setError(t("lesson.error.generic"));
      } finally {
        running.current = false;
      }
    })();
    return () => {
      cancelled = true;
    };
    // Relancé par « Réessayer », qui incrémente `attempt`.
  }, [lessonId, attempt, router, t]);

  function openNow() {
    startTransition(async () => {
      const result = await openLessonOffline(lessonId);
      if (result.status === "error") {
        setError(result.message ?? t("lesson.convert.failed"));
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="flex min-h-[60svh] flex-col items-center justify-center gap-5 px-8 text-center">
      <Mika mood={error ? "sad" : "think"} size={180} />
      <h1 className="text-[22px] font-extrabold text-ink">{error ? t("lesson.convert.failed") : t("lesson.convert.title")}</h1>
      <p className="max-w-[40ch] text-[16px] font-medium leading-relaxed text-ink-secondary">{error ?? t("lesson.convert.subtitle")}</p>
      {error ? (
        <div className="flex w-full max-w-[320px] flex-col gap-3">
          <Button size="xl" onClick={() => { setError(null); setAttempt((value) => value + 1); }} disabled={pending}>
            {t("lesson.path.retry")}
          </Button>
          <Button size="xl" variant="outline" onClick={openNow} loading={pending}>
            {t("lesson.convert.openNow")}
          </Button>
        </div>
      ) : (
        <Spinner className="size-6 text-ink" />
      )}
    </div>
  );
}
