"use client";

/**
 * Les briques communes des graphes de l'app.
 *
 * Un graphe ici ne dit qu'une chose, avec une couleur par sens et jamais plus de quatre. Les
 * couleurs ne sont pas choisies par composant : elles viennent des jetons `--chart-*` posés
 * sur `.app-shell`, validés ensemble pour le daltonisme. Le texte ne porte jamais la couleur
 * d'une série : la pastille à côté du mot la porte.
 */

export type ChartTone = "work" | "solid" | "fragile" | "over" | "untouched";

export const TONE_VAR: Record<ChartTone, string> = {
  work: "var(--chart-work)",
  solid: "var(--chart-solid)",
  fragile: "var(--chart-fragile)",
  over: "var(--chart-over)",
  untouched: "var(--chart-untouched)",
};

export const TONE_SOFT_VAR: Record<ChartTone, string> = {
  work: "var(--chart-work-soft)",
  solid: "var(--chart-solid-soft)",
  fragile: "var(--chart-fragile-soft)",
  over: "var(--chart-over-soft)",
  untouched: "var(--chart-untouched)",
};

export function Swatch({ tone, shape = "dot" }: { tone: ChartTone; shape?: "dot" | "line" | "soft" }) {
  if (shape === "line") {
    return (
      <span
        aria-hidden
        className="inline-block h-[2px] w-3 shrink-0 rounded-full"
        style={{ backgroundColor: TONE_VAR[tone] }}
      />
    );
  }
  return (
    <span
      aria-hidden
      className="inline-block size-2 shrink-0 rounded-full"
      style={{ backgroundColor: shape === "soft" ? TONE_SOFT_VAR[tone] : TONE_VAR[tone] }}
    />
  );
}

export function Legend({
  items,
  className = "",
}: {
  items: { tone: ChartTone; label: string; value?: string | number; shape?: "dot" | "line" | "soft" }[];
  className?: string;
}) {
  return (
    <ul className={`flex flex-wrap items-center gap-x-4 gap-y-1.5 text-[12.5px] text-ink-secondary ${className}`}>
      {items.map((item) => (
        <li key={item.label} className="flex items-center gap-1.5">
          <Swatch tone={item.tone} shape={item.shape} />
          <span>{item.label}</span>
          {item.value != null ? (
            <span className="numeral font-medium text-ink">{item.value}</span>
          ) : null}
        </li>
      ))}
    </ul>
  );
}

/** Le tableau qui double un graphe pour un lecteur d'écran, ou sans couleur. */
export function SrTable({
  caption,
  headers,
  rows,
}: {
  caption: string;
  headers: string[];
  rows: (string | number)[][];
}) {
  return (
    <table className="sr-only">
      <caption>{caption}</caption>
      <thead>
        <tr>
          {headers.map((header) => (
            <th key={header} scope="col">
              {header}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((row, index) => (
          <tr key={index}>
            {row.map((cell, cellIndex) => (
              <td key={cellIndex}>{cell}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

/** Une échelle propre : 0, un cran rond, deux crans. */
export function niceMax(value: number): number {
  if (value <= 0) return 4;
  const magnitude = 10 ** Math.floor(Math.log10(value));
  const unit = value / magnitude;
  const step = unit <= 1 ? 1 : unit <= 2 ? 2 : unit <= 4 ? 4 : unit <= 5 ? 5 : 10;
  return step * magnitude;
}
