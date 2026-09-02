"use client";

import { useEffect } from "react";
import type { Route } from "next";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";
import { nextPath, previousPath, type OnboardingPath } from "@/lib/onboarding/steps";

/**
 * La charpente d'un écran de parcours, **dans la carte**.
 *
 * Un écran, une question. Le contenu défile à l'intérieur. Le retour et le
 * bouton restent en bas de la carte : à gauche, à droite — le même geste que
 * sur un formulaire posé au milieu de la page.
 */
export function Scaffold({
  eyebrow,
  title,
  titleClassName = "",
  skip,
  children,
  footer,
  center = false,
}: {
  eyebrow?: string;
  title: React.ReactNode;
  /** Pour un titre d'accueil plus grand que les questions qui suivent. */
  titleClassName?: string;
  /** L'échappatoire, posée en haut à droite sur la ligne du sur-titre. */
  skip?: { label: string; href: OnboardingPath };
  children: React.ReactNode;
  footer: React.ReactNode;
  /** Centre le contenu dans la carte. `h-full` sur l'enfant ne suffit
   *  pas : la zone défile, et le pourcentage n'a plus de parent mesuré. */
  center?: boolean;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const { t } = useI18n();
  const back = previousPath(pathname);

  // **L'écran suivant est chargé pendant qu'on lit celui-ci.** Sans ça, chaque
  // « Continuer » attendait le réseau, et c'est ce qui donnait la latence entre
  // deux écrans. Le retour est préchargé aussi : on y revient souvent.
  useEffect(() => {
    const ahead = nextPath(pathname);
    router.prefetch(ahead as Route);
    if (back) router.prefetch(back as Route);
  }, [back, pathname, router]);

  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-hidden px-6 pb-5 pt-3 sm:px-8 sm:pb-6">
      <div className="flex shrink-0 items-baseline justify-between gap-4">
        {eyebrow ? <p className="eyebrow text-ink-tertiary">{eyebrow}</p> : <span />}
        {skip ? (
          <Link
            href={skip.href as Route}
            className="underline-draw text-[13px] font-medium text-ink-tertiary"
          >
            {skip.label}
          </Link>
        ) : null}
      </div>

      <h1
        className={`rise mt-2.5 shrink-0 font-bold leading-[1.12] tracking-tight-title text-ink ${
          titleClassName || "text-balance text-[24px] sm:text-[30px]"
        }`}
      >
        {title}
      </h1>

      <div
        className={`rise mt-4 flex min-h-0 flex-1 flex-col overflow-y-auto overscroll-contain ${
          center ? "justify-center" : ""
        }`}
      >
        {children}
      </div>

      <div className="rise flex shrink-0 items-center justify-between gap-3 pt-4">
        {back ? (
          <Link
            href={back as Route}
            className="pressable inline-flex min-h-11 shrink-0 items-center gap-1.5 text-[14.5px] font-medium text-ink-tertiary"
          >
            <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4">
              <path
                d="M12 4l-6 6 6 6"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            {t("common.back")}
          </Link>
        ) : (
          <span />
        )}
        <div className="min-w-0 max-w-[min(100%,18rem)] shrink">{footer}</div>
      </div>
    </div>
  );
}

/**
 * Le bouton principal, **gris tant qu'on n'a pas répondu.**
 *
 * Il occupe sa place depuis le début, éteint : un bouton qui apparaît quand la
 * réponse arrive fait sauter la page au moment où le doigt s'approche. Il
 * reste en bas à droite de la carte, jamais collé aux bords de l'écran.
 */
export function ContinueButton({
  label,
  enabled,
  href,
  onPress,
}: {
  label?: string;
  enabled: boolean;
  href?: OnboardingPath;
  onPress?: () => void;
}) {
  const router = useRouter();
  const { t } = useI18n();
  const text = label ?? t("common.continue");

  useEffect(() => {
    if (href) router.prefetch(href as Route);
  }, [href, router]);

  return (
    <Button
      type="button"
      variant={enabled ? "outline" : "default"}
      size="xl"
      disabled={!enabled}
      onClick={() => {
        if (!enabled) return;
        onPress?.();
        if (href) router.push(href as Route);
      }}
      className={`h-auto min-h-12 max-w-full whitespace-normal text-balance rounded-pill px-4 text-[14.5px] leading-tight sm:px-5 sm:text-[15px] ${
        enabled
          ? "border-accent bg-accent text-on-ink hover:bg-accent hover:text-on-ink"
          : ""
      }`}
    >
      {text}
      <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4">
        <path
          d="M4 10h11M11 5l5 5-5 5"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </Button>
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
      /* Le fond de la carte est blanc : une réponse blanche dessus ne se voyait
         qu'à son ombre. Le gris la détache, et le filet tient sa forme. */
      className={`pressable flex w-full items-center gap-4 rounded-button px-4 py-3.5 text-left transition-colors duration-hover ${
        selected
          ? "bg-accent-soft"
          : "bg-surface-muted shadow-[inset_0_0_0_1px_var(--color-stroke-strong)]"
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
