"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import {
  activeDeadlines,
  buildQueue,
  resolveEmoji,
  type CardState,
} from "@micabo/core";

import { CountStepper } from "@/components/app/CountStepper";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/card";
import { requestPaywall } from "@/lib/paywall";
import { heldBackNew, practiceReview } from "@/lib/micabo-copy";

export interface ReviewSetupCard {
  id: string;
  courseId: string | null;
  state: CardState;
  dueDate: string;
  position: number;
  createdAt: string;
  isSuspended: boolean;
}

export interface ReviewSetupCourse {
  id: string;
  title: string;
  emoji: string | null;
  subject: string | null;
}

export interface ReviewSetupExam {
  date: string;
  isPlanned: boolean;
  courseIds: string[];
}

/**
 * L'écran avant la session : le chiffre, les cours, un bouton.
 *
 * Si la file est vide, on le dit en deux mots. Les paragraphes sur le rythme
 * n'aident pas à décider.
 */
export function ReviewSetup({
  courseId,
  cards,
  courses,
  exams,
  remaining,
  isPro,
}: {
  courseId: string | null;
  cards: ReviewSetupCard[];
  courses: ReviewSetupCourse[];
  exams: ReviewSetupExam[];
  rhythmNew: number;
  introducedToday: number;
  remaining: number;
  isPro: boolean;
}) {
  const now = useMemo(() => new Date(), []);
  const dueNew = cards.filter(
    (card) => !card.isSuspended && card.state === "new" && new Date(card.dueDate) <= now,
  ).length;
  const [freshCap, setFreshCap] = useState(() => Math.min(remaining, dueNew));

  const deadlines = useMemo(
    () =>
      activeDeadlines(
        exams.map((exam) => ({
          date: new Date(`${exam.date}T12:00:00`),
          isPlanned: exam.isPlanned,
          courseIds: exam.courseIds,
        })),
        cards.map((card) => ({
          id: card.id,
          courseId: card.courseId,
          isSuspended: card.isSuspended,
        })),
        now,
      ),
    [cards, exams, now],
  );

  const queue = useMemo(
    () =>
      buildQueue(
        cards.map((card) => ({
          id: card.id,
          state: card.state,
          dueDate: new Date(card.dueDate),
          position: card.position,
          createdAt: new Date(card.createdAt),
          isSuspended: card.isSuspended,
        })),
        {
          now,
          limits: { newPerSession: freshCap, reviewsPerSession: Number.MAX_SAFE_INTEGER },
          deadlines,
        },
      ),
    [cards, deadlines, freshCap, now],
  );

  const fresh = queue.filter((card) => card.state === "new").length;
  const again = queue.length - fresh;
  // Le plafond se joue **pendant** la session, pas ici : on annonce la
  // vraie file. Sinon on ouvre cinq cartes, on les finit, et on rentre
  // — le paywall n'a plus rien à couper.
  const served = queue.length;

  const involved = courses.filter((course) =>
    queue.some((item) => {
      const row = cards.find((card) => card.id === item.id);
      return row?.courseId === course.id;
    }),
  );

  const href =
    courseId != null
      ? `/app/reviser?cours=${courseId}&go=1&neuves=${freshCap}`
      : `/app/reviser?go=1&neuves=${freshCap}`;

  if (queue.length === 0 && dueNew === 0) {
    const empty = cards.length === 0;
    return (
      <EmptyState
        title="Rien à réviser"
        description={
          empty
            ? "Importe un cours pour commencer."
            : isPro
              ? "Rien à réviser aujourd'hui. Tu peux prendre de l'avance sur un cours."
              : "Réviser sans compter est dans Pro."
        }
        action={
          empty ? (
            <Button render={<Link href={"/app/importer" as never} />}>Importer un cours</Button>
          ) : isPro ? (
            <Button render={<Link href={"/app/cours" as never} />}>Voir les cours</Button>
          ) : (
            <Button onClick={requestPaywall}>{practiceReview}</Button>
          )
        }
      />
    );
  }

  const leftoverOnly = served === 0 && dueNew > 0;

  return (
    <div className="space-y-5">
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">
          {leftoverOnly ? "C'est fait" : `${served} carte${served > 1 ? "s" : ""}`}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {leftoverOnly
            ? heldBackNew(dueNew)
            : courseId
              ? "Ce cours"
              : "Aujourd'hui"}
        </p>
      </header>

      {served > 0 || dueNew > 0 ? (
        <dl className="grid grid-cols-2 gap-3">
          <Stat value={again} label="à revoir" />
          {dueNew > 0 ? (
            <NewCardsControl
              value={Math.min(freshCap, dueNew)}
              max={dueNew}
              planned={remaining}
              onChange={setFreshCap}
            />
          ) : (
            <Stat value={fresh} label={fresh === 1 ? "nouvelle" : "nouvelles"} />
          )}
        </dl>
      ) : null}

      {involved.length > 0 ? (
        <ul className="divide-y divide-border overflow-hidden rounded-2xl border border-border bg-card">
          {involved.map((course) => {
            const count = queue.filter((item) => {
              const row = cards.find((card) => card.id === item.id);
              return row?.courseId === course.id;
            }).length;
            return (
              <li key={course.id} className="flex items-center gap-3 px-4 py-3">
                <span aria-hidden className="emoji text-[16px]">
                  {resolveEmoji(course.emoji, course.subject, course.title)}
                </span>
                <span className="min-w-0 flex-1 truncate text-sm text-foreground">{course.title}</span>
                <span className="numeral text-sm text-muted-foreground">{count}</span>
              </li>
            );
          })}
        </ul>
      ) : null}

      {served > 0 ? (
        <Button className="w-full sm:w-auto" render={<Link href={href as never} />}>
          {leftoverOnly ? `Réviser ${fresh} neuve${fresh > 1 ? "s" : ""}` : "Commencer"}
        </Button>
      ) : (
        <p className="text-sm text-muted-foreground">
          Ton rythme du jour est atteint.{" "}
          <Link href={"/app/reglages" as never} className="underline-draw font-medium text-ink">
            Changer le rythme
          </Link>
        </p>
      )}
    </div>
  );
}

function NewCardsControl({
  value,
  max,
  planned,
  onChange,
}: {
  value: number;
  max: number;
  planned: number;
  onChange: (next: number) => void;
}) {
  const relation = value === planned ? "at" : value > planned ? "above" : "below";
  const info =
    relation === "at"
      ? "Nombre de nouvelles cartes prévues selon ton rythme."
      : relation === "above"
        ? "Au-dessus de ton rythme."
        : "En dessous de ton rythme.";
  const tone = relation === "at" ? "info" : relation === "above" ? "caution" : "ink";

  return (
    <div className="rounded-2xl border border-border bg-card px-4 py-4">
      <dd>
        <CountStepper
          value={value}
          min={0}
          max={max}
          onChange={onChange}
          minusLabel="Une carte neuve de moins"
          plusLabel="Une carte neuve de plus"
          tone={tone}
          info={info}
        />
      </dd>
      <dt className="mt-2 text-[13px] text-muted-foreground">
        {value === 1 ? "nouvelle" : "nouvelles"}
      </dt>
    </div>
  );
}

function Stat({ value, label }: { value: number; label: string }) {
  return (
    <div className="rounded-2xl border border-border bg-card px-4 py-4">
      <dd className="numeral text-2xl font-semibold leading-none text-foreground">{value}</dd>
      <dt className="mt-1.5 text-[13px] text-muted-foreground">{label}</dt>
    </div>
  );
}
