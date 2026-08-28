"use client";

/**
 * Compteur + / −, le même geste que pour les formats de cartes.
 *
 * Le chiffre est la commande : on l'incrémente, on le sent. Pas un curseur
 * qu'on fait glisser pour viser un entier.
 */
export function CountStepper({
  value,
  min,
  max,
  onChange,
  minusLabel,
  plusLabel,
  size = "md",
}: {
  value: number;
  min: number;
  max: number;
  onChange: (next: number) => void;
  minusLabel: string;
  plusLabel: string;
  size?: "sm" | "md";
}) {
  const large = size === "md";
  const box = large ? "h-10 w-10" : "h-7 w-7";
  const icon = large ? "h-4 w-4" : "h-3.5 w-3.5";
  const numeral = large ? "min-w-8 text-[18px]" : "min-w-7 text-[15px]";

  return (
    <div
      className={`flex shrink-0 items-center gap-1 rounded-pill bg-surface-muted ${large ? "p-1.5" : "p-1"}`}
      role="group"
    >
      <StepButton
        label={minusLabel}
        sign="minus"
        enabled={value > min}
        box={box}
        icon={icon}
        onPress={() => onChange(value - 1)}
      />
      <span className={`numeral text-center font-semibold text-ink ${numeral}`} aria-live="polite">
        {value}
      </span>
      <StepButton
        label={plusLabel}
        sign="plus"
        enabled={value < max}
        box={box}
        icon={icon}
        onPress={() => onChange(value + 1)}
      />
    </div>
  );
}

function StepButton({
  label,
  sign,
  enabled,
  box,
  icon,
  onPress,
}: {
  label: string;
  sign: "plus" | "minus";
  enabled: boolean;
  box: string;
  icon: string;
  onPress: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      disabled={!enabled}
      onClick={onPress}
      className={`pressable flex items-center justify-center rounded-full transition-colors duration-hover ${box} ${
        enabled ? "bg-surface text-ink paper" : "cursor-not-allowed text-ink-tertiary/40"
      }`}
    >
      <svg aria-hidden viewBox="0 0 20 20" className={icon}>
        <path
          d={sign === "plus" ? "M10 4.5v11M4.5 10h11" : "M4.5 10h11"}
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
        />
      </svg>
    </button>
  );
}
