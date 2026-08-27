"use client";

import { useEffect, useState } from "react";

import { examStoryFor, isoFromFlagEmoji, subjectEmoji, type ExamStory as Story } from "@micabo/core";

import { Flag } from "@/components/onboarding/Flag";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * L'exemple animé d'un examen **déjà décidé**.
 *
 * Quatre temps, dans cet ordre, et chacun n'apparaît qu'après le précédent : l'examen se pose,
 * les cours s'y accrochent, on révise, la note arrive. Tout montrer d'un coup ferait lire un
 * schéma ; le montrer dans le temps fait comprendre une chaîne.
 *
 * La note n'est pas toujours 17/20 : elle parle le système du pays choisi. Un Allemand lit
 * 1,3, un Anglais lit A. C'est la même réussite, écrite comme on la reçoit.
 */

const BEATS = [
  { at: 280, id: "exam" },
  { at: 1680, id: "courses" },
  { at: 3360, id: "review" },
  { at: 5240, id: "grade" },
] as const;

export function ExamStory({ onReady }: { onReady: () => void }) {
  const { answers } = useOnboarding();
  const story = examStoryFor(answers.country, answers.subjects ?? []);
  const [beat, setBeat] = useState(0);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setBeat(BEATS.length);
      onReady();
      return;
    }

    const timers = BEATS.map((item, index) =>
      window.setTimeout(() => {
        setBeat(index + 1);
        if (index === BEATS.length - 1) onReady();
      }, item.at),
    );
    return () => timers.forEach((timer) => window.clearTimeout(timer));
  }, [onReady]);

  return (
    <div className="mx-auto w-full max-w-[440px]">
      <ol className="mb-5 flex justify-center gap-2" aria-hidden>
        {BEATS.map((item, index) => (
          <li
            key={item.id}
            className={`h-1.5 w-8 rounded-pill transition-colors duration-menu ${
              beat > index ? "bg-accent" : "bg-progress-track"
            }`}
          />
        ))}
      </ol>

      <div className="relative min-h-[340px]">
        {beat >= 1 ? <ExamCard story={story} /> : null}

        {beat >= 2 ? (
          <div className="exam-beat mt-3 flex flex-wrap justify-center gap-2">
            {story.courses.map((course) => (
              <span
                key={course}
                className="flex items-center gap-1.5 rounded-pill bg-surface px-3 py-1.5 text-[13.5px] font-medium text-ink paper"
              >
                <CourseMark name={course} />
                {course}
              </span>
            ))}
          </div>
        ) : null}

        {beat >= 3 ? <ReviewBeat subject={story.subject} /> : null}

        {beat >= 4 ? (
          <div className="exam-stamp mt-6 flex flex-col items-center">
            <p className="numeral text-[72px] font-bold leading-none tracking-display text-accent">
              {story.grade.score}
            </p>
            <p className="mt-1.5 text-[15px] font-semibold text-ink">{story.grade.mention}</p>
            <p className="mt-1 text-[13px] text-ink-tertiary">{story.examName}</p>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function ExamCard({ story }: { story: Story }) {
  return (
    <div className="exam-beat paper rounded-group bg-ink px-5 py-4 text-on-ink">
      <p className="eyebrow text-on-ink-muted">📅 {story.examKind}</p>
      <p className="mt-2 text-[20px] font-bold leading-tight">{story.examName}</p>
      <p className="mt-1.5 text-[13.5px] text-on-ink-muted">{story.dateLabel}</p>
    </div>
  );
}

function ReviewBeat({ subject }: { subject: string }) {
  return (
    <div className="exam-beat mt-4 rounded-group bg-surface px-4 py-4 paper">
      <p className="eyebrow text-ink-tertiary">⚡ Révision</p>
      <div className="mt-3 space-y-2">
        <MiniCard front={`Notion clé · ${subject}`} back="Revoir demain" done />
        <MiniCard front="Deuxième passage" back="Dans 4 jours" done />
      </div>
      <div className="mt-3 h-1.5 overflow-hidden rounded-pill bg-progress-track">
        <div className="exam-fill h-full rounded-pill bg-progress" />
      </div>
    </div>
  );
}

function CourseMark({ name }: { name: string }) {
  const emoji = subjectEmoji(name);
  const iso = isoFromFlagEmoji(emoji);
  if (iso) {
    return <Flag iso={iso} emoji={emoji} label={name} className="h-[13px] w-[18px]" />;
  }
  return (
    <span aria-hidden className="emoji text-[14px]">
      {emoji}
    </span>
  );
}

function MiniCard({ front, back, done }: { front: string; back: string; done?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-button bg-surface-muted px-3 py-2.5">
      <span className="min-w-0 truncate text-[13.5px] text-ink">{front}</span>
      <span className="shrink-0 text-[12px] text-ink-tertiary">
        {done ? "✓ " : ""}
        {back}
      </span>
    </div>
  );
}
