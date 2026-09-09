import Link from "next/link";

import { ExamsWorkspace } from "@/components/app/plan/ExamsWorkspace";
import { Button } from "@/components/ui/button";
import { getTranslator } from "@/lib/i18n/server";
import { loadTermSnapshot } from "@/lib/term-plan";

/**
 * **Les examens : la période.**
 *
 * Tout est calculé ici, à chaque rendu, et rien n'est stocké : un plan est une fonction des
 * épreuves, des cartes, du journal et du temps disponible. Les lectures sont en cache et
 * partagées avec l'accueil, donc ouvrir cette page après l'accueil ne touche pas la base.
 */
export default async function ExamsPage() {
  const [{ t }, snapshot] = await Promise.all([getTranslator(), loadTermSnapshot()]);
  const mine = snapshot.courses.filter((course) => !course.is_from_library);

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="page-title">{t("app.exams.hub.title")}</h1>
          <p className="page-lead">{t("app.exams.hub.lead")}</p>
        </div>
        <Button size="sm" data-tour="examens-ajouter" render={<Link href={"/app/plan/nouveau" as never} />}>
          {t("app.newPlan.add")}
        </Button>
      </header>

      <ExamsWorkspace
        bars={snapshot.bars}
        verdict={snapshot.verdict}
        levers={snapshot.levers}
        exams={snapshot.exams}
        weeklyMinutes={snapshot.weeklyMinutes}
        adherence={snapshot.adherence}
        throughput={snapshot.throughput}
        hasCourses={mine.length > 0}
      />
    </>
  );
}
