"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";

import type { OnboardingPath } from "@/lib/onboarding/steps";

/**
 * La charpente d'un écran de parcours.
 *
 * **Un écran, une chose** : un titre court, une ligne de sous-titre au plus, et une seule chose à
 * regarder. C'est la règle du tunnel iOS, et c'est celle qui a été la plus mal tenue là-bas — un
 * écran d'inscription se lit en deux secondes ou ne se lit pas.
 *
 * Les réponses **occupent la page** plutôt que d'être tassées sous le titre. Sur un écran de
 * question, les réponses *sont* le contenu : les serrer en haut laisse les deux tiers de l'écran
 * vides en dessous et fait lire un formulaire.
 */
export function Scaffold({
  eyebrow,
  title,
  subtitle,
  skip,
  children,
  footer,
}: {
  eyebrow?: string;
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  /** L'échappatoire, posée en haut à droite sur la ligne du sur-titre. */
  skip?: { label: string; href: OnboardingPath };
  children: React.ReactNode;
  footer: React.ReactNode;
}) {
  return (
    <div className="mx-auto flex min-h-[calc(100svh-var(--onboarding-chrome))] w-full max-w-[560px] flex-col px-screen pb-8">
      <div className="flex items-baseline justify-between gap-4 pt-2">
        {eyebrow ? <p className="eyebrow text-ink-tertiary">{eyebrow}</p> : <span />}
        {skip ? (
          <Link
            href={skip.href}
            className="underline-draw text-[13px] font-medium text-ink-tertiary"
          >
            {skip.label}
          </Link>
        ) : null}
      </div>

      <h1 className="mt-3 text-[26px] font-bold leading-[1.15] text-ink sm:text-[30px]">{title}</h1>
      {subtitle ? (
        <p className="mt-3 text-[15px] leading-relaxed text-ink-secondary">{subtitle}</p>
      ) : null}

      {/* Le contenu prend toute la place qui reste. */}
      <div className="flex min-h-0 flex-1 flex-col justify-center py-7">{children}</div>

      <div className="shrink-0">{footer}</div>
    </div>
  );
}

/**
 * Le bouton principal, **gris tant qu'on n'a pas répondu.**
 *
 * Il occupe sa place depuis le début, éteint : un bouton qui apparaît quand la réponse arrive fait
 * sauter la page au moment où le doigt s'approche.
 */
export function ContinueButton({
  label = "Continuer",
  enabled,
  href,
  onPress,
  shiny = false,
}: {
  label?: string;
  enabled: boolean;
  href?: OnboardingPath;
  onPress?: () => void;
  /** Le seul bouton du parcours qui brille : celui qui suit une animation qu'on a regardée sans rien toucher. */
  shiny?: boolean;
}) {
  const router = useRouter();

  return (
    <button
      type="button"
      disabled={!enabled}
      onClick={() => {
        if (!enabled) return;
        onPress?.();
        if (href) router.push(href);
      }}
      className={`pressable h-14 w-full rounded-button text-[16px] font-semibold transition-colors duration-hover ${
        enabled
          ? `bg-ink text-on-ink ${shiny ? "shiny" : ""}`
          : "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
      }`}
    >
      {label}
    </button>
  );
}

/**
 * Une réponse.
 *
 * Un emoji posé **à même la ligne**, sans fond ni cadre : une pastille colorée par ligne fait lire
 * des pictogrammes au lieu des réponses. C'est un point d'accroche, pas une tuile.
 */
export function ChoiceRow({
  emoji,
  title,
  detail,
  selected,
  onSelect,
}: {
  emoji: string;
  title: string;
  detail?: string;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      className={`pressable flex w-full items-center gap-3.5 rounded-button px-4 py-3.5 text-left transition-colors duration-hover ${
        selected ? "bg-accent-soft" : "bg-surface paper"
      }`}
    >
      <span aria-hidden className="text-[22px] leading-none">
        {emoji}
      </span>
      <span className="min-w-0 flex-1">
        <span
          className={`block text-[16px] font-medium ${selected ? "text-accent" : "text-ink"}`}
        >
          {title}
        </span>
        {detail ? (
          <span className="mt-0.5 block truncate text-[13px] text-ink-tertiary">{detail}</span>
        ) : null}
      </span>
      <span
        aria-hidden
        className={`h-5 w-5 shrink-0 rounded-full border-2 ${
          selected ? "border-accent bg-accent" : "border-stroke-strong"
        }`}
      >
        {selected ? (
          <svg viewBox="0 0 20 20" className="h-full w-full text-on-ink">
            <path
              d="M5 10.5l3.2 3.2L15 7"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.4"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        ) : null}
      </span>
    </button>
  );
}
