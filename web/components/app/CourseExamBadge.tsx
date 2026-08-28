import { examCountdownLabel, examUrgency, type ExamUrgency } from "@micabo/core";

/**
 * La pastille d'examen, **sur la carte du cours**.
 *
 * 📝 plus le compte à rebours. Rien d'autre : le nom de l'épreuve se lit
 * au survol, la couleur dit s'il reste de la marge.
 */
export function CourseExamBadge({
  name,
  daysRemaining,
}: {
  name: string;
  daysRemaining: number;
}) {
  const urgency = examUrgency(daysRemaining);
  const label = name.trim() || "Examen";

  return (
    <span
      className={`inline-flex max-w-full items-center gap-1 rounded-pill px-2 py-0.5 text-[11px] font-semibold leading-4 ${tone(urgency)}`}
      title={`${label} · ${examCountdownLabel(daysRemaining)}`}
    >
      <span aria-hidden className="emoji">
        📝
      </span>
      {examCountdownLabel(daysRemaining)}
    </span>
  );
}

function tone(urgency: ExamUrgency): string {
  switch (urgency) {
    case "critical":
      return "bg-negative-soft text-negative";
    case "soon":
      return "bg-caution-soft text-caution";
    case "upcoming":
      return "bg-info-soft text-info";
    case "later":
      return "bg-surface-muted text-ink-secondary";
    case "past":
      return "bg-surface-muted text-ink-tertiary";
  }
}
