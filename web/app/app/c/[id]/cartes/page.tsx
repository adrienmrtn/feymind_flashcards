import Link from "next/link";
import { notFound } from "next/navigation";

import { UNLIMITED, entitlement, studyCounts, type QueueCard } from "@micabo/core";

import { CardList } from "@/components/app/CardList";
import { GenerateCards } from "@/components/app/GenerateCards";
import { ReviewCta } from "@/components/app/ReviewCta";
import { getCourseMeta, listCards, listExams } from "@/lib/data/courses";
import { examMarkForCourse } from "@/lib/data/exam-marks";

/**
 * L'espace des cartes d'un cours.
 *
 * Ce n'est plus un compteur et un bouton générique : c'est l'atelier du paquet —
 * l'état de la file, la session, puis les cartes qu'on corrige.
 */
export default async function CourseCardsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [course, cards, exams] = await Promise.all([
    getCourseMeta(id),
    listCards(id),
    listExams(),
  ]);
  if (!course) notFound();
  const exam = examMarkForCourse(exams, course.id);
  const counts = studyCounts(cards.map(toQueueCard), { limits: UNLIMITED });

  return (
    <>
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

        <div className="mt-3 flex flex-wrap items-end justify-between gap-5">
          <div>
            <p className="eyebrow text-ink-tertiary">🃏 Espace des cartes</p>
            <h1 className="mt-1.5 text-[30px] font-bold leading-tight text-ink">
              {cards.length === 0 ? "Ton paquet est vide" : "Ton paquet"}
            </h1>
            <p className="mt-2 max-w-[42ch] text-[14.5px] leading-relaxed text-ink-secondary">
              {cards.length === 0
                ? "Micabo écrit les questions à partir de la fiche. Tu choisis les formats."
                : packSummary(cards.length, counts)}
            </p>
          </div>

          {cards.length > 0 ? (
            <ReviewCta
              href={`/app/reviser?cours=${course.id}`}
              detail={reviewDetail(counts)}
            />
          ) : null}
        </div>
      </header>

      {cards.length > 0 ? (
        <div className="mt-7 grid gap-2.5 sm:grid-cols-3">
          <Stat emoji="🔥" value={counts.review} label={counts.review === 1 ? "à revoir" : "à revoir"} />
          <Stat emoji="✨" value={counts.newCards} label={counts.newCards === 1 ? "jamais vue" : "jamais vues"} />
          <Stat
            emoji="🧠"
            value={counts.learning}
            label={counts.learning === 1 ? "en cours" : "en cours"}
          />
        </div>
      ) : null}

      <div className="mt-7">
        <GenerateCards courseId={course.id} existing={cards.length} />
      </div>

      <div className="mt-8">
        <CardList courseId={course.id} cards={cards} exam={exam} />
      </div>

      {cards.length > entitlement.FREE_TIER.cardsPerSession ? (
        <p className="mt-4 text-[12.5px] leading-relaxed text-ink-tertiary">
          Toutes tes cartes se lisent ici. Ce que le gratuit borne, c&apos;est la{" "}
          <strong className="font-medium text-ink-secondary">session</strong> :{" "}
          {entitlement.FREE_TIER.cardsPerSession} cartes à la fois.
        </p>
      ) : null}
    </>
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
  total: number,
  counts: { review: number; newCards: number; learning: number },
): string {
  if (counts.review + counts.newCards + counts.learning === 0) {
    return `${total} carte${total > 1 ? "s" : ""} dans le paquet. Tout est à jour — rien à revoir aujourd'hui.`;
  }
  return `${total} carte${total > 1 ? "s" : ""} dans le paquet. Voici ce qui t'attend.`;
}

function reviewDetail(counts: { review: number; newCards: number; learning: number }): string {
  const waiting = counts.review + counts.newCards + counts.learning;
  if (waiting === 0) return "Une session libre, pour ancrer.";
  if (counts.review > 0) return `${counts.review} à revoir aujourd'hui.`;
  if (counts.newCards > 0) return `${counts.newCards} jamais vue${counts.newCards > 1 ? "s" : ""} à découvrir.`;
  return `${counts.learning} encore en cours.`;
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
