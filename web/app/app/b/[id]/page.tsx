import Link from "next/link";
import { notFound } from "next/navigation";

import { courseAccent, courseAudienceLabel, displayUsername, resolveEmoji } from "@micabo/core";

import { AdoptCourse } from "@/components/app/AdoptCourse";
import { SharedCardsPreview } from "@/components/app/SharedCardsPreview";
import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import {
  findAdoptedCourse,
  getDirectoryById,
  getSharedCourse,
  listSharedCards,
} from "@/lib/data/social";

/**
 * La fiche de quelqu'un d'autre, en lecture, avec un bouton pour la reprendre.
 *
 * On voit la fiche **et** les cartes. Les reprendre les copie neuves : le contenu
 * devient le sien, pas l'état de répétition de l'auteur.
 */
export default async function SharedCoursePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const course = await getSharedCourse(id);
  if (!course) notFound();

  const [author, alreadyId, cards] = await Promise.all([
    getDirectoryById(course.userId),
    findAdoptedCourse(course.title),
    listSharedCards(course.id),
  ]);

  const tint = course.accentHex ?? courseAccent(course.id);

  return (
    <article>
      <header className="flex items-start gap-4" data-print="keep">
        <span
          aria-hidden
          className="flex h-14 w-14 shrink-0 items-center justify-center rounded-tile text-[26px]"
          style={{ backgroundColor: `${tint}1f` }}
        >
          {resolveEmoji(course.emoji, course.subject, course.title)}
        </span>
        <div className="min-w-0 flex-1">
          <p className="eyebrow text-ink-tertiary">
            {[
              course.subject,
              author ? displayUsername(author.username) : null,
              cards.length > 0 ? `${cards.length} carte${cards.length > 1 ? "s" : ""}` : null,
              courseAudienceLabel(course.viewCount, course.adoptCount),
            ]
              .filter(Boolean)
              .join(" · ")}
          </p>
          <h1 className="mt-1.5 text-[30px] font-bold leading-tight text-ink">{course.title}</h1>
        </div>
      </header>

      {course.summary ? (
        <p className="mt-6 max-w-reading text-[15.75px] leading-relaxed text-ink-secondary">
          {course.summary}
        </p>
      ) : null}

      <div className="mt-7" data-print="hide">
        <AdoptCourse courseId={course.id} alreadyId={alreadyId} />
        <p className="mt-3 text-center text-[12.5px] text-ink-tertiary">
          {cards.length > 0
            ? "La fiche et les cartes deviennent les tiennes. Tu les révises à zéro."
            : "La fiche devient la tienne."}
        </p>
      </div>

      <div className="mt-10">
        {course.blocks.length > 0 ? (
          <SheetBlocks blocks={course.blocks} tint={tint} />
        ) : (
          <p className="rounded-group bg-caution-soft px-5 py-4 text-[14px] text-ink-reading">
            Cette fiche n&apos;est plus lisible.
          </p>
        )}
      </div>

      <div className="mt-10" data-print="hide">
        <SharedCardsPreview cards={cards} />
      </div>

      <p className="mt-12 text-[13px] text-ink-tertiary" data-print="hide">
        <Link href={"/app/cours?vue=decouvrir" as never} className="underline-draw">
          Retour à la bibliothèque
        </Link>
      </p>
    </article>
  );
}
