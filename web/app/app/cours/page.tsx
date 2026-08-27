import Link from "next/link";

import { courseAccent, courseAudienceLabel, displayUsername, resolveEmoji, studyCounts } from "@micabo/core";

import { CourseExamBadge } from "@/components/app/CourseExamBadge";
import { LibrarySearch } from "@/components/app/LibrarySearch";
import { listCardSnapshots, listCourses, listExams } from "@/lib/data/courses";
import { examMarkForCourse } from "@/lib/data/exam-marks";
import { loadNewCardBudget } from "@/lib/data/reviews";
import { listLibraryCourses } from "@/lib/data/social";

/**
 * L'étagère, et la bibliothèque.
 *
 * Deux onglets, comme sur l'iPhone : **Tes cours** et **Découvrir**. Découvrir
 * ne montre que ce que le cloisonnement de Supabase laisse lire — les cours
 * publics de l'école, et ceux des amis.
 */
export default async function CoursesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const discover = params.vue === "decouvrir";
  const query = typeof params.q === "string" ? params.q : "";
  const subject = typeof params.matiere === "string" ? params.matiere : null;

  const [courses, cards, budget, library, exams] = await Promise.all([
    listCourses(),
    listCardSnapshots(),
    loadNewCardBudget(),
    discover ? listLibraryCourses({ search: query, subject }) : Promise.resolve(null),
    discover ? Promise.resolve([]) : listExams(),
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

  const subjects = library
    ? [...new Set(library.courses.map((course) => course.subject).filter(Boolean))]
    : [];

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="eyebrow text-ink-tertiary">
            {discover ? "📖 Bibliothèque" : "📚 Ton étagère"}
          </p>
          <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">Cours</h1>
        </div>

        {!discover && counts.total > 0 ? (
          <Link
            href="/app/reviser"
            className="pressable flex items-center gap-2.5 rounded-button bg-ink px-5 py-3 text-[15px] font-semibold text-on-ink"
          >
            ⚡ Réviser <span className="numeral">{counts.total}</span> carte
            {counts.total > 1 ? "s" : ""}
          </Link>
        ) : null}
      </header>

      <nav className="mt-6 flex gap-1 rounded-button bg-surface-muted p-1">
        <Tab href="/app/cours" current={!discover} label="Tes cours" />
        <Tab href="/app/cours?vue=decouvrir" current={discover} label="Découvrir" />
      </nav>

      {discover ? (
        <LibraryPane
          query={query}
          subject={subject}
          subjects={subjects as string[]}
          courses={library?.courses ?? []}
          authors={library?.authors ?? new Map()}
        />
      ) : (
        <Shelf
          courses={courses}
          emptyReviews={counts.total === 0 && cards.length > 0}
          exams={exams}
        />
      )}
    </>
  );
}

function Tab({ href, current, label }: { href: string; current: boolean; label: string }) {
  return (
    <Link
      href={href as never}
      aria-current={current ? "page" : undefined}
      className={`flex-1 rounded-button px-4 py-2.5 text-center text-[14px] font-semibold ${
        current ? "bg-surface text-ink shadow-sm" : "text-ink-tertiary"
      }`}
    >
      {label}
    </Link>
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
        <div className="mt-7 grid gap-3 sm:grid-cols-2">
          {courses.map((course) => {
            const exam = examMarkForCourse(exams, course.id);
            return (
              <Link
                key={course.id}
                href={`/app/c/${course.id}` as never}
                className="hover-tile paper relative flex flex-col gap-4 rounded-group bg-surface p-5"
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

function LibraryPane({
  query,
  subject,
  subjects,
  courses,
  authors,
}: {
  query: string;
  subject: string | null;
  subjects: string[];
  courses: Awaited<ReturnType<typeof listLibraryCourses>>["courses"];
  authors: Awaited<ReturnType<typeof listLibraryCourses>>["authors"];
}) {
  return (
    <div className="mt-7">
      <LibrarySearch initial={query} subject={subject} />

      {subjects.length > 0 ? (
        <div className="mt-4 flex flex-wrap gap-2">
          <SubjectChip href="/app/cours?vue=decouvrir" current={!subject} label="Toutes" />
          {subjects.map((name) => (
            <SubjectChip
              key={name}
              href={`/app/cours?vue=decouvrir&matiere=${encodeURIComponent(name)}${
                query ? `&q=${encodeURIComponent(query)}` : ""
              }`}
              current={subject === name}
              label={name}
            />
          ))}
        </div>
      ) : null}

      {courses.length === 0 ? (
        <p className="mt-8 text-[14.5px] leading-relaxed text-ink-secondary">
          Rien à découvrir pour l&apos;instant. Les cours publics de ton école, et ceux de tes
          amis, arriveront ici — le même graphe que sur l&apos;iPhone.
        </p>
      ) : (
        <div className="mt-6 grid gap-3 sm:grid-cols-2">
          {courses.map((course) => {
            const author = authors.get(course.userId);
            return (
              <Link
                key={course.id}
                href={`/app/b/${course.id}` as never}
                className="hover-tile paper flex flex-col gap-4 rounded-group bg-surface p-5"
              >
                <span
                  aria-hidden
                  className="flex h-12 w-12 items-center justify-center rounded-tile text-[22px]"
                  style={{ backgroundColor: `${course.accentHex ?? courseAccent(course.id)}1f` }}
                >
                  {resolveEmoji(course.emoji, course.subject, course.title)}
                </span>
                <span className="min-w-0">
                  <span className="line-clamp-2 block text-[16px] font-semibold leading-snug text-ink">
                    {course.title || "Sans titre"}
                  </span>
                  <span className="mt-1.5 line-clamp-2 block text-[13px] text-ink-tertiary">
                    {[
                      author ? displayUsername(author.username) : null,
                      course.subject,
                      course.cardCount > 0
                        ? `${course.cardCount} carte${course.cardCount > 1 ? "s" : ""}`
                        : null,
                      courseAudienceLabel(course.viewCount, course.adoptCount),
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
    </div>
  );
}

function SubjectChip({ href, current, label }: { href: string; current: boolean; label: string }) {
  return (
    <Link
      href={href as never}
      className={`rounded-pill px-3.5 py-1.5 text-[13px] font-medium ${
        current ? "bg-ink text-on-ink" : "bg-surface-muted text-ink-secondary"
      }`}
    >
      {label}
    </Link>
  );
}

function EmptyShelf() {
  return (
    <div className="mt-10 rounded-group bg-canvas-sage p-8 text-center">
      <p className="text-[17px] font-semibold text-ink">Ton étagère est vide.</p>
      <p className="mx-auto mt-2.5 max-w-[42ch] text-[14.5px] leading-relaxed text-ink-reading">
        Dépose un polycopié, ou reprends un cours déjà fiché dans Découvrir.
      </p>
      <div className="mt-7 flex flex-wrap justify-center gap-3">
        <Link
          href="/app/importer"
          className="pressable inline-flex items-center gap-2 rounded-button bg-ink px-6 py-3.5 text-[15px] font-semibold text-on-ink"
        >
          Importer un cours
        </Link>
        <Link
          href={"/app/cours?vue=decouvrir" as never}
          className="pressable inline-flex items-center rounded-button bg-surface px-6 py-3.5 text-[15px] font-semibold text-ink paper"
        >
          Découvrir
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
