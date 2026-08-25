import Link from "next/link";
import { notFound } from "next/navigation";

import { entitlement, formatDelay, previewLabels } from "@micabo/core";

import { GenerateCards } from "@/components/app/GenerateCards";
import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import { getCourse, listCards } from "@/lib/data/courses";

/**
 * Les cartes d'un cours, **en table**.
 *
 * C'est l'écran où le web bat le téléphone sans discussion : on corrige vingt cartes à la suite,
 * on voit d'un coup d'œil ce qui est neuf et ce qui revient bientôt. L'app les montre une par une,
 * ce qui est le bon choix sous le pouce et le mauvais devant un clavier.
 *
 * Une fois écrites, **elles s'ouvrent d'elles-mêmes** — c'est la règle de l'app : on retombait
 * avant sur la fiche, qu'il fallait faire défiler jusqu'en bas pour découvrir ce qui venait
 * d'être produit.
 */
export default async function CourseCardsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [course, cards] = await Promise.all([getCourse(id), listCards(id)]);
  if (!course) notFound();


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

        <h1 className="mt-3 text-[30px] font-bold leading-tight text-ink">
          {cards.length === 0 ? "Pas encore de cartes" : `${cards.length} cartes`}
        </h1>
      </header>

      <div className="mt-7">
        <GenerateCards courseId={course.id} existing={cards.length} />
      </div>

      {cards.length > 0 ? (
        <div className="paper mt-8 overflow-hidden rounded-group bg-surface">
          {cards.map((card, index) => {
            const labels = previewLabels({
              state: card.state,
              intervalDays: card.interval_days,
              easeFactor: card.ease_factor,
              repetitions: card.repetitions,
              lapses: card.lapses,
              stepIndex: card.step_index,
            });

            return (
              <div
                key={card.id}
                className={`flex items-start gap-4 px-5 py-4 ${
                  index > 0 ? "border-t border-hairline" : ""
                }`}
              >
                <span
                  aria-hidden
                  className="numeral mt-0.5 w-6 shrink-0 text-[12px] font-semibold text-ink-tertiary"
                >
                  {index + 1}
                </span>

                <div className="min-w-0 flex-1">
                  <p className="text-[15px] font-medium leading-snug text-ink">
                    <InlineMarkup text={card.front} />
                  </p>
                  <p className="mt-1 text-[14px] leading-snug text-ink-secondary">
                    <InlineMarkup text={card.back} />
                  </p>
                </div>

                <div className="shrink-0 text-right">
                  <p className={`text-[11px] font-medium ${stateTone(card.state)}`}>
                    {stateLabel(card.state)}
                  </p>
                  <p className="numeral mt-0.5 text-[12px] text-ink-tertiary">
                    {card.state === "new"
                      ? labels[3]
                      : formatDelay(
                          (new Date(card.due_date).getTime() - Date.now()) / 1000,
                        )}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <p className="mt-8 rounded-group bg-canvas-sage p-6 text-[14.5px] leading-relaxed text-ink-reading">
          Les cartes se tirent de la fiche, pas du document brut : c&apos;est la version que Micabo a
          écrite qui sert de source, et c&apos;est pour ça qu&apos;elles arrivent après elle et non
          au passage de l&apos;import.
        </p>
      )}

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

function stateLabel(state: string): string {
  switch (state) {
    case "new":
      return "Nouvelle";
    case "learning":
      return "Apprentissage";
    case "relearning":
      return "Réapprentissage";
    default:
      return "Révision";
  }
}

function stateTone(state: string): string {
  switch (state) {
    case "new":
      return "text-accent";
    case "learning":
    case "relearning":
      return "text-caution";
    default:
      return "text-ink-tertiary";
  }
}
