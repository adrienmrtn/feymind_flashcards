"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { createClient } from "@/lib/supabase/client";

/**
 * Si le mail de confirmation a déposé les jetons sur `/` (la Site URL),
 * on les ramasse et on reprend le parcours. La landing ne sait pas le faire.
 */
export function AuthReturnCatcher() {
  const router = useRouter();

  useEffect(() => {
    const hash = window.location.hash;
    if (!hash.includes("access_token") && !hash.includes("refresh_token")) return;

    const supabase = createClient();
    void supabase.auth.getSession().then(({ data }) => {
      if (data.session) router.replace("/commencer/pays");
    });
  }, [router]);

  return null;
}
