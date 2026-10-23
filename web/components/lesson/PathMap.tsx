"use client";

import { useEffect, useRef, useState } from "react";
import { Check, RefreshCw, Star } from "lucide-react";

import {
  circleState,
  currentCircle,
  type CircleReadiness,
  type LessonTone,
  type PathCircle,
  type PathCircleState,
} from "@micabo/core";

import { PathSymbol } from "@/components/lesson/PathSymbol";
import { Spinner } from "@/components/ui/spinner";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Le chemin** : de gros ronds posés sur une courbe douce, reliés par un trait épais qui se
 * remplit dans la couleur de la leçon à mesure qu'on avance. Chaque étape porte son
 * pictogramme ; son numéro et son titre se lisent de l'autre côté. Jumeau de
 * `PathMapView.swift` ; voir `docs/refonte-parcours.md` § 5.3.
 *
 * - Fait : plein, coche blanche, un relief sous le rond.
 * - En cours : plein, étoile, un anneau concentrique qui dit où on en est dans l'étape, la
 *   bulle « Commencer » (ou « Continuer ») et un halo qui respire.
 * - À venir : gris, le pictogramme de l'étape. Un clic secoue le rond : on ne saute pas.
 *
 * La géométrie est calculée, pas mesurée : chaque étape a une hauteur connue, donc le trait se
 * dessine sous les ronds sans attendre la mise en page, et le chemin défile jusqu'à l'étape
 * en cours dès l'ouverture.
 */

export const NODE_SIZE = 84;
export const RING_GAP = 9;
export const RING_WIDTH = 7;
export const ROW_HEIGHT = 148;
export const TRAIL_WIDTH = 12;
export const TITLE_GAP = 18;
const DEPTH = 6;

interface Point {
  x: number;
  y: number;
}

/** Où tombe chaque rond : une courbe douce, d'un bord à l'autre, comme une rivière. */
export function pathGeometry(count: number, width: number) {
  const amplitude = Math.min(88, Math.max(48, width * 0.2));
  const offset = (index: number) => amplitude * Math.sin(index * 0.78 + 0.35);
  const centers: Point[] = Array.from({ length: count }, (_, index) => ({
    x: width / 2 + offset(index),
    y: (index + 0.5) * ROW_HEIGHT,
  }));
  return {
    width,
    height: count * ROW_HEIGHT,
    centers,
    titleOnRight: (index: number) => offset(index) < 0,
  };
}

/** Les points de contrôle d'un segment, à la verticale de ses deux bouts. */
function controls(from: Point, to: Point): [Point, Point] {
  const pull = (to.y - from.y) * 0.5;
  return [
    { x: from.x, y: from.y + pull },
    { x: to.x, y: to.y - pull },
  ];
}

export function trailPath(points: readonly Point[]): string {
  if (points.length === 0) return "";
  const parts = [`M ${points[0]!.x} ${points[0]!.y}`];
  for (let index = 1; index < points.length; index += 1) {
    const [c1, c2] = controls(points[index - 1]!, points[index]!);
    parts.push(`C ${c1.x} ${c1.y} ${c2.x} ${c2.y} ${points[index]!.x} ${points[index]!.y}`);
  }
  return parts.join(" ");
}

/** La longueur de chaque segment, mesurée en suivant la courbe. */
function segmentLengths(points: readonly Point[]): number[] {
  const lengths: number[] = [];
  for (let index = 1; index < points.length; index += 1) {
    const p0 = points[index - 1]!;
    const p3 = points[index]!;
    const [c1, c2] = controls(p0, p3);
    let length = 0;
    let previous = p0;
    const samples = 16;
    for (let step = 1; step <= samples; step += 1) {
      const t = step / samples;
      const u = 1 - t;
      const x = u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p3.x;
      const y = u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p3.y;
      length += Math.hypot(x - previous.x, y - previous.y);
      previous = { x, y };
    }
    lengths.push(length);
  }
  return lengths;
}

/** La part du trait jusqu'au rond `index`, de 0 à 1, mesurée sur la courbe elle-même. */
export function trailFraction(points: readonly Point[], index: number): number {
  if (points.length < 2) return 1;
  const lengths = segmentLengths(points);
  const total = lengths.reduce((sum, length) => sum + length, 0);
  if (total <= 0) return 0;
  const reached = lengths.slice(0, Math.max(0, Math.min(index, lengths.length))).reduce((sum, length) => sum + length, 0);
  return reached / total;
}

export interface PathMapProps {
  circles: readonly PathCircle[];
  done: readonly string[];
  /** Où on en est dans l'étape en cours, entre 0 et 1. */
  inCircle: number;
  readiness: Readonly<Record<string, CircleReadiness>>;
  tone: LessonTone;
  /** L'étape qu'on vient de cocher : son rond se gonfle une fois à l'arrivée. */
  justDone?: string | null;
  onOpen: (circle: PathCircle) => void;
  onRetry?: (circle: PathCircle) => void;
}

export function PathMap({ circles, done, inCircle, readiness, tone, justDone = null, onOpen, onRetry }: PathMapProps) {
  const { t } = useI18n();
  const container = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(390);
  const [shaking, setShaking] = useState<string | null>(null);
  const [blocked, setBlocked] = useState<string | null>(null);

  useEffect(() => {
    const element = container.current;
    if (!element) return;
    const update = () => setWidth(Math.max(280, Math.round(element.getBoundingClientRect().width)));
    update();
    const observer = new ResizeObserver(update);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!blocked) return;
    const timer = window.setTimeout(() => setBlocked(null), 2000);
    return () => window.clearTimeout(timer);
  }, [blocked]);

  // Le chemin s'ouvre centré sur l'étape en cours.
  const current = currentCircle(circles, done);
  useEffect(() => {
    if (!current) return;
    const node = container.current?.querySelector<HTMLElement>(`[data-circle="${CSS.escape(current.id)}"]`);
    node?.scrollIntoView({ block: "center", behavior: "instant" as ScrollBehavior });
  }, [current?.id]);

  const layout = pathGeometry(circles.length, width);
  const reachedIndex = current ? circles.findIndex((circle) => circle.id === current.id) : Math.max(0, circles.length - 1);
  const fraction = trailFraction(layout.centers, reachedIndex);
  const trail = trailPath(layout.centers);

  function tap(circle: PathCircle, state: PathCircleState) {
    if (state === "upcoming") {
      setShaking(circle.id);
      window.setTimeout(() => setShaking(null), 450);
      setBlocked(t("lesson.path.finishFirst", { circle: current?.title ?? "" }));
      return;
    }
    const ready = readiness[circle.id] ?? "ready";
    if (ready === "ready") onOpen(circle);
    else if (ready === "failed") onRetry?.(circle);
  }

  return (
    <div ref={container} className="relative w-full" style={{ height: layout.height + 12 }}>
      <svg
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 top-0"
        width={layout.width}
        height={layout.height}
        viewBox={`0 0 ${layout.width} ${layout.height}`}
      >
        <path d={trail} fill="none" stroke="var(--color-track)" strokeWidth={TRAIL_WIDTH} strokeLinecap="round" strokeLinejoin="round" />
        <path
          d={trail}
          fill="none"
          stroke={`var(--color-tone-${tone}-vivid)`}
          strokeWidth={TRAIL_WIDTH}
          strokeLinecap="round"
          strokeLinejoin="round"
          pathLength={1}
          strokeDasharray={`${Math.max(0, fraction)} 1`}
          className="path-trail"
        />
      </svg>

      {circles.map((circle, index) => {
        const state = circleState(circle, circles, done);
        const ready = readiness[circle.id] ?? "ready";
        const center = layout.centers[index]!;
        const titleOnRight = layout.titleOnRight(index);
        const reach = NODE_SIZE / 2 + RING_GAP + RING_WIDTH + TITLE_GAP;
        const titleWidth = Math.max(96, titleOnRight ? layout.width - 18 - (center.x + reach) : center.x - reach - 18);
        // Le rond se centre par ses marges, pas par une transformation : les animations
        // (apparition, secousse) écrivent `transform`, et une translation posée là serait
        // perdue à la première image.
        const outer = NODE_SIZE + 2 * (RING_GAP + RING_WIDTH);
        return (
          <div key={circle.id} data-circle={circle.id} className="absolute inset-x-0" style={{ top: index * ROW_HEIGHT, height: ROW_HEIGHT }}>
            <div
              className={`path-node absolute ${shaking === circle.id ? "path-shake" : justDone === circle.id ? "path-pop" : ""}`}
              style={{ left: center.x - outer / 2, top: ROW_HEIGHT / 2 - outer / 2, animationDelay: `${index * 50}ms` }}
            >
              <PathNode circle={circle} state={state} readiness={ready} tone={tone} ring={state === "current" ? inCircle : 0} onClick={() => tap(circle, state)} />
            </div>
            <div
              className="path-title absolute flex flex-col justify-center"
              style={{
                top: 0,
                height: ROW_HEIGHT,
                width: titleWidth,
                left: titleOnRight ? center.x + reach : center.x - reach - titleWidth,
                alignItems: titleOnRight ? "flex-start" : "flex-end",
                textAlign: titleOnRight ? "left" : "right",
                animationDelay: `${index * 50 + 100}ms`,
                ["--from" as string]: titleOnRight ? "-12px" : "12px",
              }}
            >
              <PathStepTitle circle={circle} state={state} readiness={ready} tone={tone} onRetry={onRetry ? () => onRetry(circle) : undefined} />
            </div>
          </div>
        );
      })}

      {blocked ? (
        <div role="status" className="pointer-events-none sticky bottom-4 z-10 flex justify-center px-6">
          <p className="rounded-pill bg-ink px-4 py-3 text-center text-[15px] font-bold text-on-ink shadow-floating">{blocked}</p>
        </div>
      ) : null}
    </div>
  );
}

/** **Un rond du chemin**, dans l'un de ses trois états. */
function PathNode({
  circle,
  state,
  readiness,
  tone,
  ring,
  onClick,
}: {
  circle: PathCircle;
  state: PathCircleState;
  readiness: CircleReadiness;
  tone: LessonTone;
  ring: number;
  onClick: () => void;
}) {
  const { t } = useI18n();
  const vivid = `var(--color-tone-${tone}-vivid)`;
  const ink = `var(--color-tone-${tone}-ink)`;
  const ringDiameter = NODE_SIZE + 2 * RING_GAP + RING_WIDTH;
  const outer = NODE_SIZE + 2 * (RING_GAP + RING_WIDTH);
  const radius = (ringDiameter - RING_WIDTH) / 2;
  const circumference = 2 * Math.PI * radius;
  const face = state === "upcoming" ? "var(--color-surface-sunken)" : vivid;
  const rim = state === "upcoming" ? "var(--color-track)" : `color-mix(in srgb, ${ink} 55%, transparent)`;
  const stateLabel =
    state === "done" ? t("lesson.path.a11y.done") : state === "current" ? t("lesson.path.a11y.current") : t("lesson.path.a11y.locked");
  const showsStartBubble = state === "current" && readiness === "ready";

  let content: React.ReactNode;
  if (readiness === "writing" && state !== "done") {
    content = <Spinner className={state === "current" ? "size-7 text-on-ink" : "size-7 text-ink-tertiary"} />;
  } else if (readiness === "failed" && state !== "done") {
    content = <RefreshCw aria-hidden="true" className={`size-7 ${state === "current" ? "text-on-ink" : "text-wrong-ink"}`} strokeWidth={2.6} />;
  } else if (state === "done") {
    content = <Check aria-hidden="true" className="size-9 text-on-ink" strokeWidth={3.4} />;
  } else if (state === "current") {
    content = circle.isMilestone ? (
      <PathSymbol id={circle.symbol} size={34} strokeWidth={2.6} className="text-on-ink" />
    ) : (
      <Star aria-hidden="true" className="size-9 fill-current text-on-ink" strokeWidth={2} />
    );
  } else {
    content = <PathSymbol id={circle.symbol} size={30} strokeWidth={2.2} className="text-ink-tertiary" />;
  }

  return (
    <div className="relative" style={{ width: outer, height: outer }}>
      {state === "current" ? (
        <>
          <span
            aria-hidden="true"
            className="path-halo absolute rounded-full"
            style={{
              width: ringDiameter + 18,
              height: ringDiameter + 18,
              left: (outer - ringDiameter - 18) / 2,
              top: (outer - ringDiameter - 18) / 2 + DEPTH / 2,
              background: `color-mix(in srgb, ${vivid} 18%, transparent)`,
            }}
          />
          <svg
            aria-hidden="true"
            className="absolute"
            width={ringDiameter}
            height={ringDiameter}
            style={{ left: (outer - ringDiameter) / 2, top: (outer - ringDiameter) / 2 + DEPTH / 2 }}
            viewBox={`0 0 ${ringDiameter} ${ringDiameter}`}
          >
            <circle cx={ringDiameter / 2} cy={ringDiameter / 2} r={radius} fill="none" stroke="var(--color-track)" strokeWidth={RING_WIDTH} />
            {ring > 0.001 ? (
              <circle
                cx={ringDiameter / 2}
                cy={ringDiameter / 2}
                r={radius}
                fill="none"
                stroke={vivid}
                strokeWidth={RING_WIDTH}
                strokeLinecap="round"
                strokeDasharray={`${Math.max(0.001, Math.min(1, ring)) * circumference} ${circumference}`}
                transform={`rotate(-90 ${ringDiameter / 2} ${ringDiameter / 2})`}
              />
            ) : null}
          </svg>
          {showsStartBubble ? (
            <span
              className="absolute left-1/2 z-10 -translate-x-1/2 whitespace-nowrap rounded-pill bg-surface px-3 py-1.5 text-[13px] font-extrabold shadow-floating"
              style={{ top: -30, color: ink }}
            >
              {ring > 0.02 ? t("lesson.path.continue") : t("lesson.path.start")}
            </span>
          ) : null}
        </>
      ) : null}
      <button
        type="button"
        onClick={onClick}
        aria-label={`${circle.title}, ${stateLabel}`}
        className="pressable absolute flex items-center justify-center rounded-full outline-none focus-visible:ring-4 focus-visible:ring-ring/40"
        style={{
          width: NODE_SIZE,
          height: NODE_SIZE,
          left: (outer - NODE_SIZE) / 2,
          top: (outer - NODE_SIZE) / 2,
          background: face,
          boxShadow: `0 ${DEPTH}px 0 ${rim}`,
        }}
      >
        <span
          aria-hidden="true"
          className="pointer-events-none absolute inset-1.5 rounded-full"
          style={{ background: state === "upcoming" ? "transparent" : "linear-gradient(to bottom, rgba(255,255,255,0.22), transparent 50%)" }}
        />
        <span className="relative flex items-center justify-center">{content}</span>
      </button>
    </div>
  );
}

/** « ÉTAPE 4 » puis le titre, du côté où il y a de la place. */
function PathStepTitle({
  circle,
  state,
  readiness,
  tone,
  onRetry,
}: {
  circle: PathCircle;
  state: PathCircleState;
  readiness: CircleReadiness;
  tone: LessonTone;
  onRetry?: () => void;
}) {
  const { t } = useI18n();
  const muted = state === "upcoming";
  return (
    <div className="flex flex-col gap-0.5">
      <span className={`text-[12px] font-extrabold uppercase tracking-caps ${state === "current" ? "" : "text-ink-tertiary"}`} style={state === "current" ? { color: `var(--color-tone-${tone}-ink)` } : undefined}>
        {t("lesson.path.step", { n: circle.number })}
      </span>
      <span className={`text-[17px] font-extrabold leading-tight ${muted ? "text-ink-tertiary" : "text-ink"}`}>{circle.title}</span>
      {circle.subtitle ? <span className="text-[13px] font-semibold text-ink-secondary">{circle.subtitle}</span> : null}
      {readiness === "writing" && state !== "done" ? (
        <span className="text-[13px] font-semibold text-ink-secondary">{t("lesson.path.writing")}</span>
      ) : null}
      {readiness === "failed" && state !== "done" && onRetry ? (
        <button type="button" onClick={onRetry} className="underline-draw self-start text-[13px] font-bold text-wrong-ink">
          {t("lesson.path.retry")}
        </button>
      ) : null}
    </div>
  );
}
