"use client";

import { useI18n } from "@/lib/i18n/client";

/** Une clé, rendue côté client : elle suit le sélecteur sans recharger la page. */
export function T({
  k,
  vars,
}: {
  k: string;
  vars?: Record<string, string | number>;
}) {
  const { t } = useI18n();
  return t(k, vars);
}
