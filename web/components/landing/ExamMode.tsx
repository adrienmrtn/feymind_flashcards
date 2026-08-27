import { planExam, type ExamCard } from "@micabo/core";

import { Card, CardPanel } from "@/components/ui/card";

/**
 * Le mode examen, montré par son calendrier.
 *
 * C'est la fonctionnalité que personne d'autre n'a, et elle mérite sa section. Mais l'argument
 * n'est pas la fonctionnalité, c'est **le plan qu'elle produit** : le jour J cerné, et les jours
 * qui le précèdent qui se remplissent en se resserrant à l'approche de l'épreuve.
 *
 * La grille n'est pas dessinée à la main : elle est **calculée par `planExam`**, le port du
 * planificateur de l'app. C'est le même algorithme qui déplacera les vraies échéances, donc ce
 * que la page montre est ce que le produit fera. Une capture d'écran aurait été plus facile et
 * n'aurait rien prouvé.
 */

const CARD_COUNT = 34;
const DAYS_BEFORE = 21;

export function ExamMode() {
  // Un jeu plausible : quelques cartes en retard, quelques neuves, le reste à des intervalles
  // divers. Les valeurs importent peu, la forme de la charge dépend surtout de l'ordre.
  const now = new Date(2026, 4, 1, 9, 0);
  const cards: ExamCard[] = Array.from({ length: CARD_COUNT }, (_, index) => ({
    id: `c${String(index).padStart(2, "0")}`,
    state: index % 5 === 0 ? "new" : "review",
    intervalDays: index % 5 === 0 ? 0 : 2 + (index % 9) * 3,
    dueDate: new Date(now.getTime() + (index % 7) * 86_400_000),
  }));

  const plan = planExam(cards, new Date(2026, 4, 1 + DAYS_BEFORE), { now, intensity: "standard" });
  const load = plan.projection.load;
  const peak = Math.max(...load, 1);

  return (
    <Card className="lift" data-print="keep">
    <CardPanel className="p-6 sm:p-8">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <p className="text-[15px] font-semibold text-ink">Maths · DS sur table</p>
        <p className="text-[13px] text-ink-tertiary">
          dans <span className="numeral font-bold text-ink">{DAYS_BEFORE}</span> jours
        </p>
      </div>

      {/* La charge, jour par jour. Elle se resserre vers la fin : les derniers passages de
          chaque carte tombent dans les trois derniers jours, décalés d'une carte à l'autre pour
          ne pas empiler tout le jeu sur la veille. */}
      <div className="mt-7 flex items-end gap-[3px]" aria-hidden>
        {load.map((count, offset) => (
          <div key={offset} className="flex-1">
            <div
              className="rounded-t-[3px]"
              style={{
                height: `${Math.max(3, (count / peak) * 92)}px`,
                backgroundColor:
                  offset >= load.length - 3
                    ? "var(--color-accent)"
                    : "color-mix(in oklch, var(--color-accent) 42%, var(--color-surface-sunken))",
              }}
            />
          </div>
        ))}
        <div className="ml-1.5 w-[3px] self-stretch rounded-pill bg-negative" />
      </div>

      <div className="mt-2 flex items-baseline justify-between text-[11px] text-ink-tertiary">
        <span>aujourd&apos;hui</span>
        <span className="font-semibold text-negative">jour J</span>
      </div>

      <p className="sr-only">
        Un histogramme de {load.length} jours montrant la charge de révision qui se resserre avant
        le jour de l&apos;examen.
      </p>

      <dl className="mt-8 grid grid-cols-3 gap-4 border-t border-hairline pt-6">
        <Stat value={plan.projection.cardCount} label="cartes couvertes" />
        <Stat value={plan.projection.totalReviews} label="passages placés" />
        <Stat value={load.length} label="jours utilisés" />
      </dl>

      <p className="mt-6 text-[13px] leading-relaxed text-ink-tertiary">
        Et pendant que l&apos;examen approche, <strong className="font-semibold text-ink-secondary">
        aucune carte ne repart au-delà du jour J</strong> - sans ce plafond, la première bonne
        réponse renverrait la carte à trois semaines et le plan serait défait au premier passage.
      </p>
    </CardPanel>
    </Card>
  );
}

function Stat({ value, label }: { value: number; label: string }) {
  return (
    <div>
      <dd className="numeral text-2xl font-bold text-ink">{value}</dd>
      <dt className="mt-0.5 text-[12px] text-ink-tertiary">{label}</dt>
    </div>
  );
}
