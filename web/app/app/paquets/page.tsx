import Link from "next/link";
import type { Route } from "next";

import { courseAccent, resolveEmoji } from "@micabo/core";

import { LockedAddDeckCard } from "@/components/app/SecondCourseCard";
import { Button } from "@/components/ui/button";
import { listCardSnapshots, listCourses } from "@/lib/data/courses";
import { canImportNow } from "@/lib/data/entitlement";
import { copyCards, copyCourseSource, copyReviewButton } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";
import type { Translator } from "@/lib/i18n/copy";

/**
 * Tous les paquets : ceux des cours, et ceux ouverts sans fiche.
 *
 * C'est d'ici qu'on en crée un, vide ou depuis Anki. La liste des cours n'ouvre
 * plus cette porte : un cours part d'un document, un paquet part des cartes.
 */
export default async function DecksPage() {
  const [{ t }, courses, cards, canImport] = await Promise.all([
    getTranslator(),
    listCourses(),
    listCardSnapshots(),
    canImportNow(),
  ]);

  const byCourse = new Map<string, number>();
  for (const card of cards) {
    if (!card.course_id) continue;
    byCourse.set(card.course_id, (byCourse.get(card.course_id) ?? 0) + 1);
  }

  const dueNow = cards.filter(
    (card) => !card.is_suspended && new Date(card.due_date) <= new Date(),
  ).length;

  return (
    <>
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-lg font-semibold tracking-tight text-foreground">
            {t("app.decks.title")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">{t("app.decks.lead")}</p>
        </div>
        {dueNow > 0 ? (
          <Button render={<Link href={"/app/reviser" as never} />}>
            {copyReviewButton(t, dueNow)}
          </Button>
        ) : null}
      </header>

      <div className="mt-7">
        {courses.length === 0 ? (
          <p className="text-[15px] text-ink-secondary">{t("app.decks.emptyLead")}</p>
        ) : null}

        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3" data-tour="paquets-etagere">
          {courses.map((course) => {
            const count = byCourse.get(course.id) ?? 0;
            const standalone = course.source === "deck";
            return (
              <Link
                key={course.id}
                href={`/app/paquets/${course.id}` as never}
                className="relative flex flex-col gap-4 rounded-2xl border border-border bg-card p-5 shadow-xs/5 transition-[scale] duration-press ease-out-strong active:scale-[0.96]"
              >
                <span
                  aria-hidden
                  className="flex h-12 w-12 items-center justify-center rounded-tile text-[22px]"
                  style={{ backgroundColor: `${course.accent_hex ?? courseAccent(course.id)}1f` }}
                >
                  {resolveEmoji(course.emoji, course.subject, course.title)}
                </span>

                <span className="min-w-0">
                  <span className="line-clamp-2 block text-[16px] font-semibold leading-snug text-ink">
                    {course.title || t("app.course.untitled")}
                  </span>
                  <span className="mt-1.5 line-clamp-2 block text-[13px] text-ink-tertiary">
                    {[
                      standalone ? t("app.decks.standalone") : t("app.decks.fromCourse"),
                      course.subject,
                      !standalone ? copyCourseSource(t, course.source) : null,
                      copyCards(t, count),
                    ]
                      .filter(Boolean)
                      .join(" · ")}
                  </span>
                </span>
              </Link>
            );
          })}
          {canImport ? <AddDeckCard t={t} /> : <LockedAddDeckCard />}
        </div>
      </div>
    </>
  );
}

function AddDeckCard({ t }: { t: Translator }) {
  return (
    <Link
      href={"/app/paquet" as Route}
      data-tour="paquets-ajouter"
      className="relative flex flex-col gap-4 rounded-2xl border border-dashed border-border bg-card p-5 transition-[scale,background-color,border-color] duration-press ease-out-strong hover:border-stroke-strong hover:bg-surface-muted active:scale-[0.96]"
    >
      <span
        aria-hidden
        className="flex h-12 w-12 items-center justify-center rounded-tile bg-surface-muted text-[22px]"
      >
        🃏
      </span>
      <span className="min-w-0">
        <span className="line-clamp-2 block text-[16px] font-semibold leading-snug text-ink">
          {t("app.decks.addTitle")}
        </span>
        <span className="mt-1.5 line-clamp-2 block text-[13px] text-ink-tertiary">
          {t("app.decks.addHint")}
        </span>
      </span>
    </Link>
  );
}
