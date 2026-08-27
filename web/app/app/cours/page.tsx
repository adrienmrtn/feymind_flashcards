import Link from "next/link";

import { courseAccent, displayUsername, resolveEmoji, studyCounts } from "@micabo/core";

import { LibrarySearch } from "@/components/app/LibrarySearch";
import { listCardSnapshots, listCourses } from "@/lib/data/courses";
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

  const [courses, cards, budget, library] = await Promise.all([
    listCourses(),
    listCardSnapshots(),
    loadNewCardBudget(),
    discover ? listLibraryCourses({ search: query, subject }) : Promise.resolve(null),
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
        <Shelf courses={courses} emptyReviews={counts.total === 0 && cards.length > 0} />
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
}: {
  courses: Awaited<ReturnType<typeof listCourses>>;
  emptyReviews: boolean;
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
        <div className="mt-7 overflow-hidden rounded-group bg-surface paper">
          {courses.map((course, index) => (
            <Link
              key={course.id}
              href={`/app/c/${course.id}` as never}
              className={`hover-row flex items-center gap-4 px-5 py-4 ${
                index > 0 ? "border-t border-hairline" : ""
              }`}
            >
              <span
                aria-hidden
                className="flex h-11 w-11 shrink-0 items-center justify-center rounded-tile text-[20px]"
                style={{ backgroundColor: `${course.accent_hex ?? courseAccent(course.id)}1f` }}
              >
                {resolveEmoji(course.emoji, course.subject, course.title)}
              </span>

              <span className="min-w-0 flex-1">
                <span className="block truncate text-[16px] font-semibold text-ink">
                  {course.title || "Sans titre"}
                </span>
                <span className="mt-0.5 block truncate text-[13px] text-ink-tertiary">
                  {[
                    course.subject,
                    course.is_from_library ? "Repris" : sourceLabel(course.source),
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                </span>
              </span>

              <Chevron />
            </Link>
          ))}
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
        <div className="mt-6 overflow-hidden rounded-group bg-surface paper">
          {courses.map((course, index) => {
            const author = authors.get(course.userId);
            return (
              <Link
                key={course.id}
                href={`/app/b/${course.id}` as never}
                className={`hover-row flex items-center gap-4 px-5 py-4 ${
                  index > 0 ? "border-t border-hairline" : ""
                }`}
              >
                <span
                  aria-hidden
                  className="flex h-11 w-11 shrink-0 items-center justify-center rounded-tile text-[20px]"
                  style={{ backgroundColor: `${course.accentHex ?? courseAccent(course.id)}1f` }}
                >
                  {resolveEmoji(course.emoji, course.subject, course.title)}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[16px] font-semibold text-ink">
                    {course.title || "Sans titre"}
                  </span>
                  <span className="mt-0.5 block truncate text-[13px] text-ink-tertiary">
                    {[author ? displayUsername(author.username) : null, course.subject]
                      .filter(Boolean)
                      .join(" · ")}
                  </span>
                </span>
                <Chevron />
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

function Chevron() {
  return (
    <svg
      aria-hidden
      viewBox="0 0 20 20"
      className="h-4 w-4 shrink-0 text-ink-tertiary"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M8 4l6 6-6 6" />
    </svg>
  );
}
