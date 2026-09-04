import Link from "next/link";
import { notFound } from "next/navigation";

import { courseAccent, entitlement, resolveEmoji } from "@micabo/core";

import { GenerateCardsCta } from "@/components/app/GenerateCardsCta";
import { LockedSheetTail } from "@/components/app/LockedSheetTail";
import { ReviewCta } from "@/components/app/ReviewCta";
import { SheetReader } from "@/components/app/SheetReader";
import { VisibilityPicker } from "@/components/app/VisibilityPicker";
import { getCourse, listCards } from "@/lib/data/courses";
import { readEntitlement } from "@/lib/data/entitlement";
import { copyCards } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";
import { displaySubject } from "@/lib/i18n/subject-display";

/**
 * **La fiche : l'écran du cours.**
 *
 * Le seul endroit du produit où l'on lit vraiment - les autres écrans sont des listes. Elle a donc
 * droit à sa colonne de lecture et à rien d'autre : le texte posé à même le papier, les objets dans
 * des blocs, et l'en-tête qui porte la couleur du cours dans sa tuile plutôt que dans un bandeau.
 *
 * Et **elle s'imprime**. C'est la seconde signature du site, et ce n'est pas un gadget : une fiche
 * *est* une page, elle se relit sur papier la veille au soir, et la feuille de style d'impression
 * retire tout ce qui sert à naviguer.
 */
export default async function CourseSheetPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [{ t, locale }, course, cards, right] = await Promise.all([
    getTranslator(),
    getCourse(id),
    listCards(id),
    readEntitlement(),
  ]);
  if (!course) notFound();

  const tint = course.accent_hex ?? courseAccent(course.id);

  // Le droit est **lu en base**, par la seule fonction qui le lit. Un achat fait sur l'iPhone
  // referme donc le gratuit ici dans la seconde.
  const { readable, locked } = entitlement.splitSheet(course.blocks, right);
  const minutes = readingMinutes(course.context_text);

  return (
    <article className="pb-24">
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
              course.subject ? displaySubject(course.subject, locale) : null,
              t("app.course.readTime", { minutes }),
              t("copy.audience", {
                views: course.view_count ?? 0,
                adopts: course.adopt_count ?? 0,
              }),
            ]
              .filter(Boolean)
              .join(" · ")}
          </p>
          <h1 className="mt-1.5 text-lg font-semibold tracking-tight text-foreground">{course.title}</h1>
        </div>
      </header>

      {course.summary ? (
        <p className="mt-6 w-full max-w-page text-[15.75px] leading-relaxed text-ink-secondary">
          {course.summary}
        </p>
      ) : null}

      {/* Sans paquet, le CTA d'écriture tient la place. Avec un paquet,
          on ouvre l'atelier, et la révision flotte. */}
      {cards.length > 0 ? (
        <Link
          href={`/app/c/${course.id}/cartes` as never}
          className="mt-7 flex w-full items-center gap-4 rounded-2xl border border-border bg-card px-6 py-5"
          data-print="hide"
          data-tour="fiche-cartes"
        >
          <span
            aria-hidden
            className="flex h-14 w-14 shrink-0 items-center justify-center rounded-tile bg-surface-muted text-[28px]"
          >
            🃏
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-[18px] font-bold leading-tight text-ink">
              {t("app.course.cardsSpace")}
            </span>
            <span className="mt-1 block text-[14px] text-ink-secondary">
              {t("app.course.cardsSpaceHint", { cards: copyCards(t, cards.length) })}
            </span>
          </span>
          <svg
            aria-hidden
            viewBox="0 0 20 20"
            className="h-5 w-5 shrink-0 text-ink-tertiary"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M8 4l6 6-6 6" />
          </svg>
        </Link>
      ) : null}

      {cards.length === 0 ? (
        <div className="mt-7" data-print="hide" data-tour="fiche-cartes">
          <GenerateCardsCta href={`/app/c/${course.id}/cartes?generer=1`} />
        </div>
      ) : (
        <ReviewCta href={`/app/reviser?cours=${course.id}`} floating />
      )}

      <div
        className="mt-7 border-t border-hairline-on-canvas pt-6"
        data-print="hide"
        data-tour="fiche-visibilite"
      >
        <p className="eyebrow mb-3 text-ink-tertiary">{t("app.course.visibility.label")}</p>
        <VisibilityPicker courseId={course.id} initial={course.visibility} />
      </div>

      <div className="mt-10" data-tour="fiche-texte">
        <SheetReader courseId={course.id} blocks={readable} tint={tint} />

        {locked.length > 0 ? <LockedSheetTail blocks={locked} tint={tint} /> : null}
      </div>

      {course.blocks.length === 0 ? (
        <p className="mt-8 rounded-group bg-caution-soft px-5 py-4 text-[14px] text-ink-reading">
          {t("app.course.noReadableSheet")}
        </p>
      ) : null}
    </article>
  );
}

/** Durée de lecture annoncée, sur une base de 200 mots par minute, comme dans l'app. */
function readingMinutes(text: string): number {
  const words = text.split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.round(words / 200));
}
