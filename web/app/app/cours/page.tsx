import Link from "next/link";
import { redirect } from "next/navigation";

import { EMPTY_MASTERY, courseAccent, masteryByCourse, resolveEmoji, studyCounts, type Mastery } from "@micabo/core";

import { MasteryBar } from "@/components/app/charts/MasteryBar";
import { CourseExamBadge } from "@/components/app/CourseExamBadge";
import { CoursesExplore } from "@/components/app/CoursesExplore";
import { LockedAddCourseCard } from "@/components/app/SecondCourseCard";
import { Button } from "@/components/ui/button";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { canImportNow } from "@/lib/data/entitlement";
import { examMarkForCourse } from "@/lib/data/exam-marks";
import { loadCardDifficulty } from "@/lib/data/difficulty";
import { copyCourseSource, copyReviewButton } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";
import type { Translator } from "@/lib/i18n/copy";

/**
 * L'étagère. Les cours des amis se lisent encore sur leur profil, selon
 * la visibilité qu'ils ont choisie.
 */
export default async function CoursesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  if (params.vue === "decouvrir") redirect("/app/cours");

  const [{ t }, courses, cards, exams, canImport, difficulties] = await Promise.all([
    getTranslator(),
    listCourses(),
    listCardSnapshots(),
    listExams(),
    canImportNow(),
    loadCardDifficulty(),
  ]);

  // La maîtrise remplace le compte de vues sur chaque tuile : « 42 vues » ne dit rien à celui
  // qui révise, « appris à 61 % » lui dit s'il peut passer à autre chose.
  const mastery = masteryByCourse(
    cards.map((card) => ({
      id: card.id,
      courseId: card.course_id,
      state: card.state,
      intervalDays: card.interval_days,
      isSuspended: card.is_suspended,
    })),
    difficulties,
  );

  const counts = studyCounts(
    cards.map((card) => ({
      id: card.id,
      state: card.state,
      dueDate: new Date(card.due_date),
      position: card.position,
      createdAt: new Date(card.created_at),
      isSuspended: card.is_suspended,
    })),
  );
  return (
    <CoursesExplore
      revise={
        counts.total > 0 ? (
          <Button render={<Link href={"/app/reviser" as never} />}>
            {copyReviewButton(t, counts.total)}
          </Button>
        ) : null
      }
    >
      <Shelf
        t={t}
        courses={courses}
        emptyReviews={counts.total === 0 && cards.length > 0}
        exams={exams}
        canImport={canImport}
        mastery={mastery}
      />
    </CoursesExplore>
  );
}

function Shelf({
  t,
  courses,
  emptyReviews,
  exams,
  canImport,
  mastery,
}: {
  t: Translator;
  courses: Awaited<ReturnType<typeof listCourses>>;
  emptyReviews: boolean;
  exams: Awaited<ReturnType<typeof listExams>>;
  canImport: boolean;
  mastery: Map<string, Mastery>;
}) {
  // Une seule étagère : un paquet Anki est un cours sans fiche, pas une autre espèce.
  const sheets = courses;

  return (
    <>
      {emptyReviews ? (
        <p className="text-[13px] text-muted-foreground">{t("app.courses.doneTomorrow")}</p>
      ) : null}

      {sheets.length === 0 ? (
        <p className="text-[15px] text-ink-secondary">{t("app.courses.emptyLead")}</p>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3" data-tour="cours-etagere">
        {sheets.map((course) => {
          const exam = examMarkForCourse(exams, course.id);
          return (
            <Link
              key={course.id}
              href={`/app/c/${course.id}` as never}
              className="hover-tile relative flex flex-col gap-4 rounded-group border border-border bg-card p-5 transition-[border-color] duration-hover"
            >
              {exam ? (
                <span className="absolute right-3 top-3">
                  <CourseExamBadge name={exam.name} daysRemaining={exam.daysRemaining} />
                </span>
              ) : null}

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
                <span className="mt-1.5 line-clamp-1 block text-[13px] text-ink-tertiary">
                  {[
                    course.subject,
                    course.is_from_library
                      ? t("app.course.source.adopted")
                      : copyCourseSource(t, course.source),
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                </span>
              </span>

              <span className="mt-auto block">
                <MasteryBar mastery={mastery.get(course.id) ?? EMPTY_MASTERY} size="sm" legend={false} />
                <span className="numeral mt-2 block text-[12.5px] text-ink-secondary">
                  {t("app.courses.mastery", {
                    percent: mastery.get(course.id)?.percent ?? 0,
                    cards: mastery.get(course.id)?.cardCount ?? 0,
                  })}
                </span>
              </span>
            </Link>
          );
        })}
        {canImport ? <AddCourseCard t={t} /> : <LockedAddCourseCard />}
      </div>
    </>
  );
}

/** Même gabarit qu'un cours, posé à la fin : un + pour en ajouter un. */
function AddCourseCard({ t }: { t: Translator }) {
  return (
    <Link
      href={"/app/importer" as never}
      data-tour="cours-ajouter"
      className="relative flex flex-col gap-4 rounded-group border border-dashed border-stroke-strong bg-transparent p-5 transition-[background-color,border-color] duration-hover hover:bg-surface-muted"
    >
      <span
        aria-hidden
        className="flex h-12 w-12 items-center justify-center rounded-tile bg-surface-muted text-ink-secondary"
      >
        <svg viewBox="0 0 24 24" className="h-6 w-6">
          <path
            d="M12 5v14M5 12h14"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          />
        </svg>
      </span>
      <span className="min-w-0">
        <span className="line-clamp-2 block text-[16px] font-semibold leading-snug text-ink">
          {t("app.courses.addTitle")}
        </span>
        <span className="mt-1.5 line-clamp-2 block text-[13px] text-ink-tertiary">
          {t("app.courses.addFormats")}
        </span>
      </span>
    </Link>
  );
}

