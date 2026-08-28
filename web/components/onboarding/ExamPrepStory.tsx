import { planExam, type ExamCard } from "@micabo/core";

/**
 * Le plan d'un examen générique, calculé par `planExam`.
 *
 * Même argument que la vitrine : Micabo resserre les cartes vers le jour J.
 * Ici c'est plus court, pour tenir sous le bouton sans faire défiler la page.
 */

const CARD_COUNT = 28;
const DAYS_BEFORE = 14;

export function ExamPrepStory() {
  const now = new Date(2026, 4, 1, 9, 0);
  const cards: ExamCard[] = Array.from({ length: CARD_COUNT }, (_, index) => ({
    id: `c${String(index).padStart(2, "0")}`,
    state: index % 5 === 0 ? "new" : "review",
    intervalDays: index % 5 === 0 ? 0 : 2 + (index % 8) * 3,
    dueDate: new Date(now.getTime() + (index % 6) * 86_400_000),
  }));

  const plan = planExam(cards, new Date(2026, 4, 1 + DAYS_BEFORE), { now, intensity: "standard" });
  const load = plan.projection.load;
  const peak = Math.max(...load, 1);

  return (
    <div className="paper mx-auto w-full max-w-[420px] rounded-group bg-surface p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[15px] font-semibold text-ink">Devoir de SVT</p>
          <p className="mt-0.5 text-[12px] text-ink-tertiary">
            Note visée <span className="numeral font-bold text-ink">16</span>
            <span>/20</span>
          </p>
        </div>
        <p className="text-[12px] text-ink-tertiary">
          dans <span className="numeral font-bold text-ink">{DAYS_BEFORE}</span> jours
        </p>
      </div>

      <div className="mt-5 flex h-[88px] items-end gap-[3px]" aria-hidden>
        {load.map((count, offset) => (
          <div key={offset} className="flex-1">
            <div
              className="rounded-t-[3px]"
              style={{
                height: `${Math.max(4, (count / peak) * 84)}px`,
                backgroundColor:
                  offset >= load.length - 3
                    ? "var(--color-accent)"
                    : "color-mix(in oklch, var(--color-accent) 42%, var(--color-surface-sunken))",
              }}
            />
          </div>
        ))}
        <div className="ml-1 w-[3px] self-stretch rounded-pill bg-negative" />
      </div>

      <div className="mt-1.5 flex items-baseline justify-between text-[11px] text-ink-tertiary">
        <span>aujourd&apos;hui</span>
        <span className="font-semibold text-negative">jour J</span>
      </div>

      <p className="sr-only">
        Histogramme de {load.length} jours : les flashcards se resserrent avant le devoir de SVT.
      </p>
    </div>
  );
}
