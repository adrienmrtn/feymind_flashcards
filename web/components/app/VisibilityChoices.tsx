"use client";

import { choosableVisibilities, type CourseVisibility } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { copyVisibilityDetail, copyVisibilityTitle } from "@/lib/i18n/copy";

/**
 * Les visibilités encore proposées, en icônes.
 *
 * Plus de dépôt public : uniquement les amis, ou soi seul. Un cours déjà
 * public garde son pictogramme jusqu'à ce qu'on le referme.
 *
 * Le libellé tenait trop de place pour des choix qui se comprennent d'un
 * pictogramme. Le détail reste au survol (et à la lecture d'écran).
 */
export function VisibilityChoices({
  value,
  onChange,
  disabled = false,
}: {
  value: CourseVisibility;
  onChange: (next: CourseVisibility) => void;
  disabled?: boolean;
}) {
  const { t } = useI18n();
  return (
    <div className="flex items-center gap-1.5" role="group" aria-label={t("app.course.visibility.groupAria")}>
      {choosableVisibilities(value).map((item) => {
        const selected = value === item.value;
        const title = copyVisibilityTitle(t, item.value);
        const detail = copyVisibilityDetail(t, item.value);
        return (
          <span key={item.value} className="relative">
            <button
              type="button"
              disabled={disabled}
              onClick={() => onChange(item.value)}
              aria-pressed={selected}
              aria-label={t("app.course.visibility.optionAria", { title, detail })}
              className={`peer pressable flex h-10 w-10 items-center justify-center rounded-button transition-colors duration-hover ${
                selected
                  ? "bg-accent text-on-ink"
                  : "bg-surface-muted text-ink-secondary hover:bg-surface-sunken"
              } ${disabled ? "cursor-not-allowed opacity-60" : ""}`}
            >
              <VisibilityIcon name={item.value} />
            </button>
            <span
              role="tooltip"
              className="pointer-events-none absolute bottom-[calc(100%+8px)] left-1/2 z-10 w-max max-w-[220px] -translate-x-1/2 rounded-tile bg-ink px-3 py-2 text-left text-[12.5px] leading-snug text-on-ink opacity-0 shadow-floating transition-opacity duration-[var(--duration-tooltip)] peer-hover:opacity-100 peer-focus-visible:opacity-100"
            >
              <span className="block font-semibold">{title}</span>
              <span className="mt-0.5 block text-on-ink-muted">{detail}</span>
            </span>
          </span>
        );
      })}
    </div>
  );
}

function VisibilityIcon({ name }: { name: CourseVisibility }) {
  return (
    <svg
      aria-hidden
      viewBox="0 0 20 20"
      className="h-[18px] w-[18px]"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {name === "public" ? (
        <>
          <circle cx="10" cy="10" r="7" />
          <path d="M3.2 10h13.6" />
          <path d="M10 3c2.1 2.3 3.1 4.6 3.1 7s-1 4.7-3.1 7" />
          <path d="M10 3C7.9 5.3 6.9 7.6 6.9 10s1 4.7 3.1 7" />
        </>
      ) : null}
      {name === "friends" ? (
        <>
          <circle cx="7.4" cy="6.8" r="2.3" />
          <path d="M3.4 15.4a4.1 4.1 0 0 1 8 0" />
          <circle cx="13.4" cy="7.2" r="2" />
          <path d="M11.6 15.4a3.5 3.5 0 0 1 5.2 0" />
        </>
      ) : null}
      {name === "private" ? (
        <>
          <rect x="4.4" y="9" width="11.2" height="7.4" rx="1.6" />
          <path d="M7.2 9V6.7a2.8 2.8 0 0 1 5.6 0V9" />
        </>
      ) : null}
    </svg>
  );
}
