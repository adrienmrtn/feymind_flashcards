"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { persistStoredAnswers } from "@/lib/onboarding/persist";
import { createClient } from "@/lib/supabase/client";

/**
 * Si le mail de confirmation a déposé les jetons sur `/` (la Site URL),
 * on les ramasse et on ouvre l'app. La landing ne sait pas le faire.
 *
 * Les réponses du parcours, si elles sont encore sur l'appareil, traversent ici.
 */
export function AuthReturnCatcher() {
  const router = useRouter();

  useEffect(() => {
    const hash = window.location.hash;
    if (!hash.includes("access_token") && !hash.includes("refresh_token")) return;

    const supabase = createClient();
    void supabase.auth.getSession().then(async ({ data }) => {
      if (!data.session) return;
      await persistStoredAnswers();
      router.replace("/app?bienvenue=1");
    });
  }, [router]);

  return null;
}
