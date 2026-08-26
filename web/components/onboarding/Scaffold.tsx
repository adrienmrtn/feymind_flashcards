"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";

import type { OnboardingPath } from "@/lib/onboarding/steps";

/**
 * La charpente d'un écran de parcours.
 *
 * **Un écran, une question, aucun sous-titre.** Les lignes d'explication sous le titre ont été
 * retirées : sur un écran qui ne pose qu'une question, elles répètent le titre ou expliquent une
 * mécanique que la réponse suivante rend évidente. Ce qui reste tient debout tout seul.
 *
 * La colonne s'élargit sur un ordinateur (`640px` contre `560px`) et le titre grandit avec elle :
 * un tunnel dessiné pour un téléphone, servi tel quel au milieu d'un écran de portable, se lit
 * comme un site mobile encadré de vide.
 */
export function Scaffold({
  eyebrow,
  title,
  skip,
  children,
  footer,
}: {
  eyebrow?: string;
  title: React.ReactNode;
  /** L'échappatoire, posée en haut à droite sur la ligne du sur-titre. */
  skip?: { label: string; href: OnboardingPath };
  children: React.ReactNode;
  footer: React.ReactNode;
}) {
  return (
    // Sur téléphone la colonne remplit l'écran et le bouton reste sous le pouce. Sur un
    // ordinateur, le bloc reprend sa hauteur naturelle et se centre : étiré sur mille pixels de
    // haut, un écran à une question laisse deux cents points de vide entre le titre et la réponse.
    <div className="mx-auto flex min-h-[calc(100svh-var(--onboarding-chrome))] w-full max-w-[640px] flex-col px-screen pb-10 sm:justify-center sm:pb-16">
      <div className="flex items-baseline justify-between gap-4 pt-3 sm:pt-0">
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

      <h1 className="rise mt-4 text-[28px] font-bold leading-[1.12] tracking-tight-title text-ink sm:text-[34px]">
        {title}
      </h1>

      {/* Le contenu prend la place qui reste sur téléphone, sa hauteur propre ailleurs. */}
      <div
        className="rise flex min-h-0 flex-1 flex-col justify-center py-9 sm:flex-none sm:py-10"
        style={{ animationDelay: "90ms" }}
      >
        {children}
      </div>

      <div className="rise shrink-0" style={{ animationDelay: "150ms" }}>
        {footer}
      </div>
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
      className={`pressable group flex h-14 w-full items-center justify-center gap-2 rounded-button text-[16px] font-semibold transition-colors duration-hover ${
        enabled
          ? `bg-ink text-on-ink ${shiny ? "shiny" : ""}`
          : "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
      }`}
    >
      {label}
      {/* La flèche avance de deux points au survol : le seul mouvement du bouton, et il dit le
          sens de la marche. */}
      <svg
        aria-hidden
        viewBox="0 0 20 20"
        className="h-4 w-4 transition-transform duration-hover ease-out-strong group-hover:translate-x-0.5"
      >
        <path
          d="M4 10h11M11 5l5 5-5 5"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </button>
  );
}

/**
 * Une réponse.
 *
 * L'emoji est posé **à même la ligne**, sans fond ni cadre : une pastille colorée par ligne fait
 * lire des pictogrammes au lieu des réponses. Il porte la classe `emoji`, sans quoi un drapeau se
 * dessine « FR » sur les systèmes dont la police de texte n'a pas les glyphes régionaux.
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
      className={`pressable flex w-full items-center gap-4 rounded-button px-4 py-4 text-left transition-colors duration-hover ${
        selected ? "bg-accent-soft" : "bg-surface paper"
      }`}
    >
      <span aria-hidden className="emoji text-[24px]">
        {emoji}
      </span>
      <span className="min-w-0 flex-1">
        <span className={`block text-[16px] font-medium ${selected ? "text-accent" : "text-ink"}`}>
          {title}
        </span>
        {detail ? (
          <span className="mt-0.5 block truncate text-[13px] text-ink-tertiary">{detail}</span>
        ) : null}
      </span>
      <span
        aria-hidden
        className={`flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 transition-colors duration-hover ${
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
