"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import {
  activeDeadlines,
  buildQueue,
  entitlement,
  resolveEmoji,
  type CardState,
} from "@micabo/core";

import { CountStepper } from "@/components/app/CountStepper";
import { Button } from "@/components/ui/button";
import { Card, CardPanel } from "@/components/ui/card";

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
 * L'écran qui précède la session : ce qui est dû, et un bonus de cartes neuves.
 *
 * **Deux phrases, et elles ne veulent pas dire la même chose.** « Session du jour
 * terminée » : plus aucune carte due, y compris hors rythme. S'il reste des
 * neuves — un cours qu'on vient d'ajouter, par exemple — on le dit, et on propose
 * « Réviser quand même ». Pas un curseur : un + / −.
 */
export function ReviewSetup({
  courseId,
  cards,
  courses,
  exams,
  rhythmNew,
  introducedToday,
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
  const rhythmDone = remaining <= 0;
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
  const cap = isPro ? queue.length : entitlement.FREE_TIER.cardsPerSession;
  const served = Math.min(queue.length, cap);
  const leftoverNew = Math.max(0, dueNew - fresh);

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
    return (
      <div className="mx-auto w-full max-w-page py-10">
        <h1 className="text-lg font-semibold tracking-tight text-foreground">
          Session du jour terminée.
        </h1>
        <p className="mt-2 max-w-[46ch] text-sm leading-relaxed text-muted-foreground">
          {cards.length === 0
            ? "Tu n'as pas encore de cartes ici. Elles se demandent depuis la fiche d'un cours, quand tu l'as lue."
            : "Rien ne revient aujourd'hui. C'est le principe : une carte qu'on revoit trop tôt est une carte pour rien."}
        </p>
        <Button className="mt-6" render={<Link href={(cards.length === 0 ? "/app/importer" : "/app/cours") as never} />}>
          {cards.length === 0 ? "Importer un cours" : "Retour aux cours"}
        </Button>
      </div>
    );
  }

  const dayDoneNoReviews = served === 0 && dueNew > 0;

  return (
    <div className="mx-auto w-full max-w-page py-6">
      <header>
        <p className="text-sm text-muted-foreground">
          {dayDoneNoReviews
            ? "Session du jour terminée"
            : courseId
              ? "Réviser ce cours"
              : "Ta session du jour"}
        </p>
        <h1 className="mt-1 text-lg font-semibold tracking-tight text-foreground">
          {served > 0 ? (
            <>
              <span className="numeral">{served}</span> carte{served > 1 ? "s" : ""} à revoir
            </>
          ) : (
            <>
              Il reste <span className="numeral">{dueNew}</span> carte
              {dueNew > 1 ? "s" : ""} neuve{dueNew > 1 ? "s" : ""}
            </>
          )}
        </h1>
        {dayDoneNoReviews ? (
          <p className="mt-3 max-w-[42ch] text-[15px] leading-relaxed text-ink-secondary">
            Révisions et rythme d&apos;aujourd&apos;hui sont faits. Ces cartes neuves n&apos;y
            rentrent pas — un cours qu&apos;on vient d&apos;ajouter, par exemple.
          </p>
        ) : null}
      </header>

      {served > 0 ? (
        <dl className="rise mt-8 grid grid-cols-2 gap-3" style={{ animationDelay: "80ms" }}>
          <Tile value={again} label="à revoir" />
          <Tile value={fresh} label={fresh === 1 ? "nouvelle" : "nouvelles"} accent />
        </dl>
      ) : null}

      {dueNew > 0 ? (
        <section className="rise mt-8" style={{ animationDelay: "140ms" }}>
          <div className="flex items-center justify-between gap-4">
            <div className="min-w-0">
              <p className="text-[14px] font-medium text-ink">
                {rhythmDone ? "Réviser quand même" : "Cartes neuves, en plus"}
              </p>
              <p className="mt-0.5 text-[12.5px] leading-relaxed text-ink-tertiary">
                {rhythmDone
                  ? `${dueNew} disponible${dueNew > 1 ? "s" : ""} hors rythme.`
                  : `${Math.min(remaining, dueNew)} prévue${Math.min(remaining, dueNew) > 1 ? "s" : ""} sur ${rhythmNew} du rythme · ${dueNew} disponible${dueNew > 1 ? "s" : ""}.`}
                {introducedToday > 0
                  ? ` ${introducedToday} déjà apprise${introducedToday > 1 ? "s" : ""} aujourd'hui.`
                  : ""}
                {leftoverNew > 0 && freshCap > 0
                  ? ` ${leftoverNew} restent pour plus tard.`
                  : ""}
              </p>
            </div>
            <CountStepper
              value={Math.min(freshCap, dueNew)}
              min={0}
              max={dueNew}
              onChange={setFreshCap}
              minusLabel="Une carte neuve de moins"
              plusLabel="Une carte neuve de plus"
            />
          </div>
        </section>
      ) : null}

      {involved.length > 0 ? (
        <section className="rise mt-8" style={{ animationDelay: "180ms" }}>
          <p className="mb-3 text-[13px] font-medium text-muted-foreground">
            {involved.length === 1 ? "Le cours" : "Les cours"}
          </p>
          <ul className="divide-y divide-hairline overflow-hidden rounded-2xl border border-border bg-card">
            {involved.map((course) => {
              const count = queue.filter((item) => {
                const row = cards.find((card) => card.id === item.id);
                return row?.courseId === course.id;
              }).length;
              return (
                <li key={course.id} className="hover-row flex items-center gap-3.5 px-5 py-3.5">
                  <span aria-hidden className="emoji text-[18px]">
                    {resolveEmoji(course.emoji, course.subject, course.title)}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-[14.5px] text-ink">
                    {course.title}
                  </span>
                  <span className="numeral shrink-0 text-[13px] text-ink-tertiary">{count}</span>
                </li>
              );
            })}
          </ul>
        </section>
      ) : null}

      <div className="rise mt-9" style={{ animationDelay: "200ms" }}>
        {served > 0 ? (
          <Button className="w-full" size="lg" render={<Link href={href as never} />}>
            {dayDoneNoReviews || (rhythmDone && again === 0)
              ? `Réviser ${fresh} carte${fresh > 1 ? "s" : ""} neuve${fresh > 1 ? "s" : ""}`
              : "Commencer la session"}
          </Button>
        ) : (
          <p className="text-center text-[14.5px] leading-relaxed text-ink-secondary">
            Ajoute des cartes neuves avec + si tu veux en faire maintenant, ou reviens demain.
          </p>
        )}

        <p className="mt-3.5 text-center text-[12.5px] leading-relaxed text-ink-tertiary">
          Espace retourne la carte, 1 à 4 la notent.
          {!isPro && queue.length > cap ? ` Le gratuit en sert ${cap} à la fois.` : ""}
        </p>
      </div>
    </div>
  );
}

function Tile({ value, label, accent }: { value: number; label: string; accent?: boolean }) {
  return (
    <Card className={accent ? "bg-primary text-primary-foreground" : undefined}>
      <CardPanel>
        <dd className="numeral text-[28px] font-semibold leading-none">{value}</dd>
        <dt className={`mt-1.5 text-[13px] ${accent ? "text-primary-foreground/70" : "text-ink-tertiary"}`}>
          {label}
        </dt>
      </CardPanel>
    </Card>
  );
}
