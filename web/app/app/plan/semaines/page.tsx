import { weeklyFromRow } from "@micabo/core";

import { WeeklyAvailability } from "@/components/app/plan/WeeklyAvailability";
import { listAvailabilityExceptions } from "@/lib/data/availability";
import { readProfile } from "@/lib/data/profile";
import { getTranslator } from "@/lib/i18n/server";

/**
 * **Mes semaines** : le seul réglage qui change ce que le plan promet.
 *
 * Il vit sous le Plan et non dans les réglages : c'est une pièce du planificateur, pas une
 * préférence de compte. Quelqu'un qui n'y passe jamais garde le rythme quotidien tous les
 * jours, et son plan est celui d'avant - le réglage sert à le rendre juste, pas à le rendre
 * possible.
 */
export default async function WeeklyAvailabilityPage() {
  const [{ t }, profile, exceptions] = await Promise.all([
    getTranslator(),
    readProfile(),
    listAvailabilityExceptions(),
  ]);

  return (
    <>
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">
          {t("app.plan.weekly.pageTitle")}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">{t("app.plan.weekly.pageLead")}</p>
      </header>

      <WeeklyAvailability
        initial={weeklyFromRow(profile?.weekly_minutes, profile?.daily_minutes ?? undefined)}
        exceptions={exceptions}
      />
    </>
  );
}
