import Link from "next/link";
import { redirect } from "next/navigation";

import { courseAccent, courseAudienceLabel, resolveEmoji, studyCounts } from "@micabo/core";

import { CourseExamBadge } from "@/components/app/CourseExamBadge";
import { CoursesExplore } from "@/components/app/CoursesExplore";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/card";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { examMarkForCourse } from "@/lib/data/exam-marks";
import { loadNewCardBudget } from "@/lib/data/reviews";

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

  const [courses, cards, budget, exams] = await Promise.all([
    listCourses(),
    listCardSnapshots(),
    loadNewCardBudget(),
    listExams(),
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
          <Link
            href="/app/reviser"
            className="inline-flex h-9 items-center gap-2 rounded-lg border border-primary bg-primary px-3 text-sm font-medium text-primary-foreground"
          >
            Réviser <span className="numeral">{counts.total}</span> carte
            {counts.total > 1 ? "s" : ""}
          </Link>
        ) : heldBack > 0 ? (
          <Link
            href="/app/reviser"
            className="inline-flex h-9 items-center gap-2 rounded-lg border border-input bg-background px-3 text-sm font-medium text-foreground"
          >
            Réviser quand même
          </Link>
        ) : null
      }
    >
      <Shelf
        courses={courses}
        emptyReviews={counts.total === 0 && cards.length > 0}
        heldBack={heldBack}
        exams={exams}
      />
    </CoursesExplore>
  );
}

function Shelf({
  courses,
  emptyReviews,
  heldBack,
  exams,
}: {
  courses: Awaited<ReturnType<typeof listCourses>>;
  emptyReviews: boolean;
  heldBack: number;
  exams: Awaited<ReturnType<typeof listExams>>;
}) {
  return (
    <>
      {emptyReviews ? (
        <p className="text-[14px] text-ink-tertiary">
          {heldBack > 0
            ? `Session du jour terminée. Il reste ${heldBack} carte${heldBack > 1 ? "s" : ""} neuve${heldBack > 1 ? "s" : ""} hors rythme — un cours ajouté, par exemple.`
            : "Session du jour terminée. Rien ne revient aujourd'hui."}
        </p>
      ) : null}

      {courses.length === 0 ? (
        <EmptyShelf />
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {courses.map((course) => {
            const exam = examMarkForCourse(exams, course.id);
            return (
              <Link
                key={course.id}
                href={`/app/c/${course.id}` as never}
                className="relative flex flex-col gap-4 rounded-2xl border border-border bg-card p-5 shadow-xs/5"
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
        </div>
      )}
    </>
  );
}

function EmptyShelf() {
  return (
    <EmptyState
      title="Ton étagère est vide."
      description="Dépose un polycopié : Micabo en tire la fiche, puis les cartes."
      action={
        <Button render={<Link href="/app/importer" />}>Importer un cours</Button>
      }
    />
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
