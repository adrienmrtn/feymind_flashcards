import Link from "next/link";
import { notFound } from "next/navigation";

import { entitlement } from "@micabo/core";

import { CardList } from "@/components/app/CardList";
import { GenerateCards } from "@/components/app/GenerateCards";
import { getCourseMeta, listCards, listExams } from "@/lib/data/courses";
import { examMarkForCourse } from "@/lib/data/exam-marks";

/**
 * Les cartes d'un cours.
 *
 * Elles sont **modifiables ici**, et c'est le point : une carte écrite par un modèle doit pouvoir
 * être corrigée, et une carte fausse révisée vingt fois installe l'erreur au lieu du cours. On peut
 * aussi en écrire une à la main — il y a toujours la question que le modèle n'a pas posée.
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

        <div className="mt-3 flex flex-wrap items-end justify-between gap-4">
          <h1 className="text-[30px] font-bold leading-tight text-ink">
            {cards.length === 0
              ? "Pas encore de cartes"
              : `${cards.length} carte${cards.length > 1 ? "s" : ""}`}
          </h1>

          {cards.length > 0 ? (
            <Link
              href={`/app/reviser?cours=${course.id}` as never}
              className="pressable rounded-button bg-ink px-5 py-3 text-[15px] font-semibold text-on-ink"
            >
              Réviser ce cours
            </Link>
          ) : null}
        </div>
      </header>

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
