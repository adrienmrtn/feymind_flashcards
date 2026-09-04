import Link from "next/link";
import { notFound } from "next/navigation";

import { UNLIMITED, entitlement, studyCounts, type QueueCard } from "@micabo/core";

import { CardList } from "@/components/app/CardList";
import { GenerateCards } from "@/components/app/GenerateCards";
import { ReviewCta } from "@/components/app/ReviewCta";
import { getCourseMeta, listCards, listExams } from "@/lib/data/courses";
import { examMarkForCourse } from "@/lib/data/exam-marks";
import { copyCards, type Translator } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";

/**
 * L'espace des cartes d'un cours.
 *
 * Ce n'est plus un compteur et un bouton générique : c'est l'atelier du paquet  - 
 * l'état de la file, la session, puis les cartes qu'on corrige.
 */
export default async function CourseCardsPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ generer?: string }>;
}) {
  const { id } = await params;
  const { generer } = await searchParams;
  const [{ t }, course, cards, exams] = await Promise.all([
    getTranslator(),
    getCourseMeta(id),
    listCards(id),
    listExams(),
  ]);
  if (!course) notFound();
  const exam = examMarkForCourse(exams, course.id);
  const counts = studyCounts(cards.map(toQueueCard), { limits: UNLIMITED });

  return (
    <div className="pb-24">
      <header>
        <Link
          href={`/app/c/${course.id}` as never}
          className="inline-flex items-center gap-1.5 text-[13.5px] text-ink-tertiary"
        >
          <svg
            aria-hidden
            viewBox="0 0 20 20"
            className="h-3.5 w-3.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M12 4l-6 6 6 6" />
          </svg>
          {course.title}
        </Link>

        <div className="mt-3">
          <h1 className="text-lg font-semibold tracking-tight text-foreground">
            {cards.length === 0 ? t("app.workshop.emptyTitle") : t("app.workshop.title")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {cards.length === 0
              ? t("app.workshop.emptyHint")
              : packSummary(t, cards.length, counts)}
          </p>
        </div>
      </header>

      {cards.length > 0 ? (
        <div className="mt-7 grid gap-2.5 sm:grid-cols-3" data-tour="cartes-etats">
          <Stat emoji="🔥" value={counts.review} label={t("app.workshop.statReview")} />
          <Stat
            emoji="✨"
            value={counts.newCards}
            label={t("app.workshop.statNew", { count: counts.newCards })}
          />
          <Stat emoji="🧠" value={counts.learning} label={t("app.workshop.statLearning")} />
        </div>
      ) : null}

      <div className="mt-7" data-tour="cartes-generer">
        <GenerateCards courseId={course.id} existing={cards.length} autoStart={generer === "1"} />
      </div>

      <div className="mt-8" data-tour="cartes-liste">
        <CardList courseId={course.id} cards={cards} exam={exam} />
      </div>

      {cards.length > entitlement.FREE_TIER.cardsPerSession ? (
        <p className="mt-4 text-[12.5px] leading-relaxed text-ink-tertiary">
          {t("app.workshop.freeCap", { limit: entitlement.FREE_TIER.cardsPerSession })}
        </p>
      ) : null}

      {cards.length > 0 ? (
        <ReviewCta href={`/app/reviser?cours=${course.id}`} floating />
      ) : null}
    </div>
  );
}

function Stat({ emoji, value, label }: { emoji: string; value: number; label: string }) {
  return (
    <div className="paper rounded-group bg-surface px-5 py-4">
      <p className="text-[13px] text-ink-tertiary">
        <span aria-hidden className="emoji mr-1.5">
          {emoji}
        </span>
        {label}
      </p>
      <p className="numeral mt-1.5 text-[28px] font-bold leading-none text-ink">{value}</p>
    </div>
  );
}

function packSummary(
  t: Translator,
  total: number,
  counts: { review: number; newCards: number; learning: number },
): string {
  const cards = copyCards(t, total);
  if (counts.review + counts.newCards + counts.learning === 0) {
    return t("app.workshop.summaryIdle", { cards });
  }
  return cards;
}

function toQueueCard(card: {
  id: string;
  state: QueueCard["state"];
  due_date: string;
  position: number;
  created_at: string;
  is_suspended: boolean;
}): QueueCard {
  return {
    id: card.id,
    state: card.state,
    dueDate: new Date(card.due_date),
    position: card.position,
    createdAt: new Date(card.created_at),
    isSuspended: card.is_suspended,
  };
}
