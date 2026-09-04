import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { courseAccent, displayUsername, resolveEmoji } from "@micabo/core";

import { FriendActions } from "@/components/app/FriendActions";
import { getDirectoryPerson, listCoursesOf } from "@/lib/data/social";
import { copyCards } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";
import { displaySubject } from "@/lib/i18n/subject-display";

/**
 * Le profil d'un camarade : son @, son école, et **ses cours**.
 *
 * Pas de statistiques. Ce qu'on vient chercher, c'est un cours qu'on n'a pas
 * eu le temps de ficher.
 */
export default async function UserPage({ params }: { params: Promise<{ username: string }> }) {
  const { username } = await params;
  const person = await getDirectoryPerson(username);
  if (!person) notFound();
  if (person.relation === "me") redirect("/app/profil");

  const [{ t, locale }, courses] = await Promise.all([
    getTranslator(),
    listCoursesOf(person.id),
  ]);

  return (
    <div className="mx-auto max-w-[560px]">
      <header>
        <p className="eyebrow text-ink-tertiary">
          {person.institutionName ?? t("app.friends.classmate")}
        </p>
        <div className="mt-2 flex flex-wrap items-end justify-between gap-3">
          <h1 className="text-lg font-semibold tracking-tight text-foreground">
            {displayUsername(person.username)}
          </h1>
          <FriendActions personId={person.id} relation={person.relation} />
        </div>
      </header>

      <p className="mt-6 text-[14.5px] text-ink-secondary">
        {courses.length === 0
          ? t("app.friends.noSharedYet")
          : t("app.friends.sharedCount", { count: courses.length })}
      </p>

      {courses.length > 0 ? (
        <ul className="paper mt-4 divide-y divide-hairline overflow-hidden rounded-group bg-surface">
          {courses.map((course) => (
            <li key={course.id}>
              <Link
                href={`/app/b/${course.id}` as never}
                className="hover-row flex items-center gap-4 px-5 py-4"
              >
                <span
                  aria-hidden
                  className="flex h-11 w-11 shrink-0 items-center justify-center rounded-tile text-[20px]"
                  style={{
                    backgroundColor: `${course.accentHex ?? courseAccent(course.id)}1f`,
                  }}
                >
                  {resolveEmoji(course.emoji, course.subject, course.title)}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[16px] font-semibold text-ink">
                    {course.title || t("app.course.untitled")}
                  </span>
                  <span className="mt-0.5 block truncate text-[13px] text-ink-tertiary">
                    {[
                      course.subject ? displaySubject(course.subject, locale) : null,
                      course.cardCount > 0 ? copyCards(t, course.cardCount) : null,
                      t("copy.audience", { views: course.viewCount, adopts: course.adoptCount }),
                    ]
                      .filter(Boolean)
                      .join(" · ") || t("app.friends.sharedCourse")}
                  </span>
                </span>
              </Link>
            </li>
          ))}
        </ul>
      ) : null}

      <p className="mt-10 text-[13px] text-ink-tertiary">
        <Link href={"/app/amis" as never} className="underline-draw">
          {t("app.friends.allFriends")}
        </Link>
      </p>
    </div>
  );
}
