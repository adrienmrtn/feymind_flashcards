import {
  HORIZON_DAYS,
  REVIEW_DAYS,
  curveWithMicabo,
  curveWithoutReview,
  intervalLabel,
} from "@micabo/core";

/**
 * La courbe de l'oubli, prise à contre-pied.
 *
 * **C'est la seule section de pédagogie du site**, et c'est déjà la règle de l'app : l'écran qui
 * reprenait ensuite les mêmes intervalles en liste disait une deuxième fois ce que le graphe
 * montre. Elle doit se lire en trois secondes — un titre qui annonce ce qu'on regarde, les
 * intervalles réels étiquetés, et deux lignes de légende. Aucun paragraphe.
 *
 * Les deux tracés **partent confondus** et se séparent à la première révision : c'est l'endroit
 * où ils divergent qu'on regarde, pas la forme de chacun.
 */

const WIDTH = 640;
const HEIGHT = 240;
const FLOOR = 200;
const CEILING = 24;

export function RetentionChart() {
  const without = curveWithoutReview();
  const withMicabo = curveWithMicabo();

  return (
    <figure className="paper lift rounded-group bg-surface p-6 sm:p-8" data-print="keep">
      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        className="h-auto w-full"
        role="img"
        aria-label={`Deux courbes de mémorisation sur ${HORIZON_DAYS} jours. Sans révision, ce qu'on retient tombe à presque rien en un mois. Avec Micabo, chaque révision — à ${REVIEW_DAYS.join(", ")} jours — la ramène à cent pour cent, et elle redescend de plus en plus lentement.`}
      >
        {/* Les repères de révision, posés avant les courbes pour passer dessous. */}
        {REVIEW_DAYS.map((day) => (
          <line
            key={day}
            x1={x(day / HORIZON_DAYS)}
            y1={CEILING - 6}
            x2={x(day / HORIZON_DAYS)}
            y2={FLOOR}
            stroke="var(--color-stroke)"
            strokeWidth="1"
          />
        ))}

        <line x1="0" y1={FLOOR} x2={WIDTH} y2={FLOOR} stroke="var(--color-hairline-on-canvas)" />

        <path
          d={path(without)}
          fill="none"
          stroke="var(--color-ink-tertiary)"
          strokeWidth="2"
          strokeDasharray="5 5"
        />
        <path
          d={path(withMicabo)}
          fill="none"
          stroke="var(--color-accent)"
          strokeWidth="2.5"
          strokeLinejoin="round"
        />

        {REVIEW_DAYS.map((day) => (
          <g key={day}>
            <circle
              cx={x(day / HORIZON_DAYS)}
              cy={CEILING - 6}
              r="3.5"
              fill="var(--color-accent-vivid)"
            />
            <text
              x={x(day / HORIZON_DAYS)}
              y={CEILING - 14}
              textAnchor="middle"
              className="fill-ink-tertiary text-[11px]"
            >
              {intervalLabel(day)}
            </text>
          </g>
        ))}
      </svg>

      <figcaption className="mt-6 space-y-2 text-[13.5px]">
        <Legend
          color="var(--color-accent)"
          label="Avec Micabo, chaque rappel remet à zéro — et la descente est plus lente à chaque fois."
        />
        <Legend
          color="var(--color-ink-tertiary)"
          dashed
          label="Sans révision, il ne reste presque rien au bout d'un mois."
        />
      </figcaption>
    </figure>
  );
}

function x(ratio: number): number {
  return ratio * WIDTH;
}

function path(points: { x: number; y: number }[]): string {
  return points
    .map(
      (point, index) =>
        `${index === 0 ? "M" : "L"}${x(point.x).toFixed(2)} ${(
          FLOOR -
          point.y * (FLOOR - CEILING)
        ).toFixed(2)}`,
    )
    .join(" ");
}

function Legend({ color, label, dashed }: { color: string; label: string; dashed?: boolean }) {
  return (
    <p className="flex items-start gap-3 text-ink-secondary">
      <span
        aria-hidden
        className="mt-2 h-0.5 w-7 shrink-0 rounded-pill"
        style={
          dashed
            ? {
                backgroundImage: `repeating-linear-gradient(to right, ${color} 0 5px, transparent 5px 10px)`,
              }
            : { backgroundColor: color }
        }
      />
      {label}
    </p>
  );
}
