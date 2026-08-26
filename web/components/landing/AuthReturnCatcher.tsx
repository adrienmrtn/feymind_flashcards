"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { persistStoredAnswers } from "@/lib/onboarding/persist";
import { createClient } from "@/lib/supabase/client";

/**
 * Si le mail a déposé les jetons dans le hash (n'importe quelle page, plus
 * seulement la landing), on les ramasse et on ouvre l'app.
 */
export function AuthReturnCatcher() {
  const router = useRouter();

  useEffect(() => {
    const hash = window.location.hash;
    if (!hash.includes("access_token") && !hash.includes("refresh_token")) return;

    const supabase = createClient();

    const enter = async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) return;
      await persistStoredAnswers();
      router.replace("/app");
    };

    void enter();
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) void enter();
    });
    return () => data.subscription.unsubscribe();
  }, [router]);

  return null;
}
