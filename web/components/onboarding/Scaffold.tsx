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
 * Le titre est **centré**, et c'est le seul changement qui compte. Il était calé à gauche,
 * ce qui marche sur une colonne étroite ; sur une carte de 1120 px, l'œil part chercher la
 * suite du texte à droite et ne trouve rien. Centré, le titre est une pancarte : on le lit,
 * puis on descend.
 *
 * Le retour et le bouton restent en bas, à gauche et à droite. C'est le geste d'un
 * formulaire posé au milieu de la page, et il ne change pas d'un écran à l'autre.
 */
export function Scaffold({
  eyebrow,
  lead,
  title,
  titleClassName = "",
  skip,
  children,
  footer,
  center = false,
  /** Largeur de la colonne de contenu. Une liste de réponses ne se lit pas sur 1120 px. */
  width = "narrow",
}: {
  eyebrow?: string;
  /** Contrôle posé au-dessus du titre. */
  lead?: React.ReactNode;
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
  width?: "narrow" | "wide" | "full";
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

  const column =
    width === "full" ? "w-full" : width === "wide" ? "mx-auto w-full max-w-[760px]" : "mx-auto w-full max-w-[560px]";

  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-hidden px-6 pb-6 pt-6 sm:px-14 sm:pb-8">
      {eyebrow || skip ? (
        <div className={`flex shrink-0 items-baseline justify-between gap-4 ${column}`}>
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
      ) : null}

      {lead ? <div className={`rise mt-3 shrink-0 ${column}`}>{lead}</div> : null}

      <h1
        className={`rise mt-4 shrink-0 text-center font-bold leading-[1.14] tracking-tight-title text-ink ${
          titleClassName || "text-balance text-[26px] sm:text-[32px]"
        }`}
      >
        {title}
      </h1>

      <div
        className={`rise mt-9 min-h-0 flex-1 overflow-y-auto overscroll-contain ${
          center ? "flex flex-col" : ""
        }`}
      >
        <div className={`${column} ${center ? "my-auto" : ""}`}>{children}</div>
      </div>

      <div className="rise flex shrink-0 items-center justify-between gap-3 pt-6">
        {back ? (
          <Link
            href={back as Route}
            className="pressable inline-flex min-h-11 shrink-0 items-center gap-1.5 text-[15px] font-medium text-ink-tertiary"
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
 * Un écran de démonstration : **on montre à gauche, on explique à droite.**
 *
 * Les six écrans qui précèdent les questions racontaient chacun leur histoire à leur façon,
 * les uns pleine largeur, les autres en colonne. Ils disent pourtant tous la même chose sous
 * des formes différentes - voilà ce que fait Micabo - et six mises en page pour un seul
 * propos oblige à réapprendre où regarder six fois de suite.
 *
 * Ils partagent donc une forme unique : une **vignette** dans un cadre gris à gauche, une
 * **phrase** à droite. La vignette porte tout le poids, parce qu'une capture se comprend plus
 * vite qu'un paragraphe ; la phrase dit ce que la vignette ne peut pas montrer.
 */
export function StoryScaffold({
  title,
  lead,
  children,
  next,
  nextLabel,
}: {
  title: React.ReactNode;
  /** La phrase de droite. */
  lead: React.ReactNode;
  /** La vignette, posée dans le cadre gris. */
  children: React.ReactNode;
  next: OnboardingPath;
  nextLabel?: string;
}) {
  return (
    <Scaffold
      title={title}
      width="full"
      footer={<ContinueButton label={nextLabel} enabled href={next} />}
      center
    >
      <div className="flex flex-col items-center gap-8 lg:flex-row lg:items-center lg:gap-14">
        <div className="flex w-full shrink-0 items-center justify-center rounded-[22px] bg-surface-muted p-5 sm:p-6 lg:w-[44%]">
          {children}
        </div>
        <div className="flex min-w-0 flex-1 justify-center">
          <p className="max-w-[32ch] text-center text-[17px] leading-relaxed text-ink-secondary">
            {lead}
          </p>
        </div>
      </div>
    </Scaffold>
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
      className={`h-auto min-h-12 max-w-full whitespace-normal text-balance rounded-pill px-5 text-[15px] leading-tight sm:px-6 sm:text-[15.5px] ${
        enabled ? "border-accent bg-accent text-on-ink hover:bg-accent hover:text-on-ink" : ""
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
