import Link from "next/link";
import { redirect } from "next/navigation";

import { courseAccent, courseAudienceLabel, resolveEmoji, studyCounts } from "@micabo/core";

import { CourseExamBadge } from "@/components/app/CourseExamBadge";
import { CoursesExplore } from "@/components/app/CoursesExplore";
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

  return (
    <CoursesExplore
      revise={
        counts.total > 0 ? (
          <Link
            href="/app/reviser"
            className="pressable flex items-center gap-2.5 rounded-button bg-ink px-5 py-3 text-[15px] font-semibold text-on-ink"
          >
            Réviser <span className="numeral">{counts.total}</span> carte
            {counts.total > 1 ? "s" : ""}
          </Link>
        ) : null
      }
    >
      <Shelf
        courses={courses}
        emptyReviews={counts.total === 0 && cards.length > 0}
        exams={exams}
      />
    </CoursesExplore>
  );
}

function Shelf({
  courses,
  emptyReviews,
  exams,
}: {
  courses: Awaited<ReturnType<typeof listCourses>>;
  emptyReviews: boolean;
  exams: Awaited<ReturnType<typeof listExams>>;
}) {
  return (
    <>
      {emptyReviews ? (
        <p className="mt-6 text-[14px] text-ink-tertiary">
          Tout est à jour. Rien ne revient aujourd&apos;hui.
        </p>
      ) : null}

      {courses.length === 0 ? (
        <EmptyShelf />
      ) : (
        <div className="mt-7 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {courses.map((course) => {
            const exam = examMarkForCourse(exams, course.id);
            return (
              <Link
                key={course.id}
                href={`/app/c/${course.id}` as never}
                className="paper relative flex flex-col gap-4 rounded-group bg-surface p-5"
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
    <div className="paper mt-10 rounded-group bg-surface p-8 text-center">
      <p className="text-[17px] font-semibold text-ink">Ton étagère est vide.</p>
      <p className="mx-auto mt-2.5 max-w-[42ch] text-[14.5px] leading-relaxed text-ink-reading">
        Dépose un polycopié : Micabo en tire la fiche, puis les cartes.
      </p>
      <div className="mt-7 flex flex-wrap justify-center gap-3">
        <Link
          href="/app/importer"
          className="pressable inline-flex items-center gap-2 rounded-button bg-ink px-6 py-3.5 text-[15px] font-semibold text-on-ink"
        >
          Importer un cours
        </Link>
      </div>
    </div>
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
