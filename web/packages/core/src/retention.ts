/**
 * Les deux courbes de mémorisation, portées depuis `RetentionChartStepView.swift`.
 *
 * La rétention décroît de façon exponentielle et remonte à 100 % à chaque révision, avec une
 * stabilité qui augmente à chaque passage. Les deux tracés **partent confondus** - la première
 * stabilité est identique à celle de la courbe sans révision - puis divergent à la première
 * révision. C'est ce qui rend le graphe lisible en trois secondes : on ne compare pas deux
 * courbes, on regarde l'endroit où elles se séparent.
 *
 * Le site s'en sert dans la section pédagogie de la page d'accueil, et c'est la seule qu'il y
 * aura : l'écran qui reprenait ensuite les mêmes intervalles en liste disait une deuxième fois
 * ce que le graphe montre déjà.
 */

export interface CurvePoint {
  /** Position sur l'horizon, dans `[0, 1]`. */
  x: number;
  /** Rétention, dans `[0, 1]`. */
  y: number;
}

export const HORIZON_DAYS = 30;
/** Les intervalles réels, étiquetés au-dessus de chaque point de révision. */
export const REVIEW_DAYS: readonly number[] = [1, 3, 7, 16];

/** Stabilité, en jours, de chaque segment. La première est celle de la courbe sans révision. */
const STABILITIES: readonly number[] = [3.5, 6, 13, 28, 70];
const BASE_STABILITY = 3.5;

export function intervalLabel(day: number): string {
  return `${Math.trunc(day)} j`;
}

export const INTERVAL_LABELS: readonly string[] = REVIEW_DAYS.map(intervalLabel);

export function curveWithoutReview(samples = 140): CurvePoint[] {
  return Array.from({ length: samples + 1 }, (_, index) => {
    const t = (HORIZON_DAYS * index) / samples;
    return { x: t / HORIZON_DAYS, y: Math.exp(-t / BASE_STABILITY) };
  });
}

export function curveWithMicabo(samplesPerSegment = 30): CurvePoint[] {
  const points: CurvePoint[] = [];
  const segments = [...REVIEW_DAYS, HORIZON_DAYS];
  let segmentStart = 0;

  segments.forEach((segmentEnd, index) => {
    const stability = STABILITIES[Math.min(index, STABILITIES.length - 1)]!;

    for (let step = 0; step <= samplesPerSegment; step += 1) {
      const t = segmentStart + ((segmentEnd - segmentStart) * step) / samplesPerSegment;
      points.push({
        x: t / HORIZON_DAYS,
        y: Math.exp(-(t - segmentStart) / stability),
      });
    }

    // Remontée verticale au moment de la révision.
    if (segmentEnd < HORIZON_DAYS) {
      points.push({ x: segmentEnd / HORIZON_DAYS, y: 1 });
    }
    segmentStart = segmentEnd;
  });

  return points;
}
