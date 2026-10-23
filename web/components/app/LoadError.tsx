"use client";

import { startTransition, useEffect } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Une lecture a échoué** - Supabase injoignable, une requête refusée.
 *
 * Les lectures de l'app lèvent maintenant au lieu de rendre une liste vide (`rowsOrThrow`,
 * `lib/data/cache`) : une panne de trois secondes ne doit pas se mettre en cache comme « aucune
 * leçon ». Cette page est l'autre moitié du marché : l'étudiant lit que ça n'a pas chargé, pas
 * que ses cours ont disparu, et il réessaie d'un appui. La barre de l'app reste autour.
 */
export function LoadError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const { t } = useI18n();
  const router = useRouter();

  // L'erreur vient d'un composant serveur : `reset()` seul re-rendrait le même échec en
  // mémoire. On redemande la page au serveur, puis on remonte l'arbre.
  const retry = () =>
    startTransition(() => {
      router.refresh();
      reset();
    });

  useEffect(() => {
    console.error("app.load", error.digest ?? error.message);
  }, [error]);

  return (
    <div role="alert" className="mx-auto flex w-full max-w-[460px] flex-col items-center px-6 py-16 text-center">
      <h1 className="text-balance text-[24px] font-bold leading-[1.15] tracking-tight-title text-ink">
        {t("app.errors.loadFailedTitle")}
      </h1>
      <p className="mt-3 max-w-[38ch] text-[15.5px] leading-relaxed text-ink-secondary">
        {t("app.errors.loadFailedBody")}
      </p>
      <Button size="xl" className="mt-7 h-12 rounded-pill px-6 text-[15px] sm:h-12 sm:text-[15px]" onClick={retry}>
        {t("app.errors.retry")}
      </Button>
    </div>
  );
}
