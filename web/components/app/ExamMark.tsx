/**
 * La pastille d'examen, **sur la carte**.
 *
 * Elle ne dit qu'une chose : cet examen-là comprime le planning de la carte. Rien de plus  - 
 * pas d'icône, pas de compte à rebours en grand, pas de bandeau. Le nom suffit, et le fond
 * ocre reste assez pâle pour qu'on le lise sans qu'il prenne la carte.
 */

export interface ExamMarkInfo {
  name: string;
  daysRemaining: number;
  /** Jour de l'examen, pour rabattre l'intervalle SM-2. */
  date?: string | Date;
}

export function examDeadline(exam: ExamMarkInfo | null | undefined): Date | null {
  if (!exam?.date) return null;
  const date = exam.date instanceof Date ? exam.date : new Date(exam.date);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function ExamMark({
  name,
  daysRemaining,
}: ExamMarkInfo) {
  const label = name.trim() || "Examen";

  return (
    <span
      className="inline-flex max-w-[11rem] items-center truncate rounded-pill bg-caution-soft px-1.5 py-px text-[10px] font-medium leading-4 text-caution"
      title={titleFor(label, daysRemaining)}
    >
      {label}
    </span>
  );
}

function titleFor(name: string, daysRemaining: number): string {
  if (daysRemaining < 0) return name;
  if (daysRemaining === 0) return `${name} · aujourd'hui`;
  if (daysRemaining === 1) return `${name} · demain`;
  return `${name} · J-${daysRemaining}`;
}
