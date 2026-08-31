import Link from "next/link";
import { redirect } from "next/navigation";

import { courseAccent, courseAudienceLabel, resolveEmoji, studyCounts } from "@micabo/core";

import { CourseExamBadge } from "@/components/app/CourseExamBadge";
import { CoursesExplore } from "@/components/app/CoursesExplore";
import { LockedAddCourseCard } from "@/components/app/SecondCourseCard";
import { Button } from "@/components/ui/button";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { canImportNow } from "@/lib/data/entitlement";
import { examMarkForCourse } from "@/lib/data/exam-marks";
import { loadNewCardBudget } from "@/lib/data/reviews";
import { heldBackNew } from "@/lib/micabo-copy";

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

  const [courses, cards, budget, exams, canImport] = await Promise.all([
    listCourses(),
    listCardSnapshots(),
    loadNewCardBudget(),
    listExams(),
    canImportNow(),
  ]);

  const now = new Date();
  const counts = studyCounts(
    cards.map((card) => ({
      id: card.id,
      state: card.state,
      dueDate: new Date(card.due_date),
      position: card.position,
      createdAt: new Date(card.created_at),
      isSuspended: card.is_suspended,
    })),
    {
      limits: {
        newPerSession: budget.remaining,
        reviewsPerSession: Number.MAX_SAFE_INTEGER,
      },
    },
  );
  const dueNow = cards.filter(
    (card) => !card.is_suspended && new Date(card.due_date) <= now,
  ).length;
  const heldBack = Math.max(0, dueNow - counts.total);

  return (
    <CoursesExplore
      revise={
        counts.total > 0 ? (
          <Button render={<Link href={"/app/reviser" as never} />}>
            Réviser <span className="numeral">{counts.total}</span>
          </Button>
        ) : heldBack > 0 ? (
          <Button variant="outline" render={<Link href={"/app/reviser" as never} />}>
            Réviser encore
          </Button>
        ) : null
      }
    >
      <Shelf
        courses={courses}
        emptyReviews={counts.total === 0 && cards.length > 0}
        heldBack={heldBack}
        exams={exams}
        canImport={canImport}
      />
    </CoursesExplore>
  );
}

function Shelf({
  courses,
  emptyReviews,
  heldBack,
  exams,
  canImport,
}: {
  courses: Awaited<ReturnType<typeof listCourses>>;
  emptyReviews: boolean;
  heldBack: number;
  exams: Awaited<ReturnType<typeof listExams>>;
  canImport: boolean;
}) {
  return (
    <>
      {emptyReviews ? (
        <p className="text-[13px] text-muted-foreground">
          {heldBack > 0 ? `C'est fait. ${heldBackNew(heldBack)}` : "C'est fait. Reviens demain."}
        </p>
      ) : null}

      {courses.length === 0 ? (
        <p className="text-[15px] text-ink-secondary">
          Ton premier cours t&apos;attend. PDF, photo, Word ou notes collées.
        </p>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {courses.map((course) => {
          const exam = examMarkForCourse(exams, course.id);
          return (
            <Link
              key={course.id}
              href={`/app/c/${course.id}` as never}
              className="relative flex flex-col gap-4 rounded-2xl border border-border bg-card p-5 shadow-xs/5 transition-[scale] duration-press ease-out-strong active:scale-[0.96]"
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
                  {course.title || "Sans titre"}
                </span>
                <span className="mt-1.5 line-clamp-2 block text-[13px] text-ink-tertiary">
                  {[
                    course.subject,
                    course.is_from_library ? "Repris" : sourceLabel(course.source),
                    courseAudienceLabel(course.view_count ?? 0, course.adopt_count ?? 0),
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                </span>
              </span>
            </Link>
          );
        })}
        {canImport ? <AddCourseCard /> : <LockedAddCourseCard />}
      </div>
    </>
  );
}

/** Même gabarit qu'un cours, posé à la fin : un + pour en ajouter un. */
function AddCourseCard() {
  return (
    <Link
      href={"/app/importer" as never}
      className="relative flex flex-col gap-4 rounded-2xl border border-dashed border-border bg-card p-5 transition-[scale,background-color,border-color] duration-press ease-out-strong hover:border-stroke-strong hover:bg-surface-muted active:scale-[0.96]"
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
          Ajouter un cours
        </span>
        <span className="mt-1.5 line-clamp-2 block text-[13px] text-ink-tertiary">
          PDF, Word, texte ou YouTube
        </span>
      </span>
    </Link>
  );
}

function sourceLabel(source: string): string {
  switch (source) {
    case "pdf":
      return "PDF";
    case "photo":
      return "Photos";
    case "youtube":
      return "Vidéo";
    case "docx":
      return "Word";
    case "deck":
      return "Paquet";
    case "library":
      return "Repris";
    default:
      return "Texte";
  }
}
