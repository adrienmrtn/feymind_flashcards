"use client";

import { useEffect, useState } from "react";

import { examGradeLabel } from "@micabo/core";

import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

import { gradeCountry } from "./grade-country";

/**
 * **La copie rendue d'un examen blanc** : l'anneau qui se remplit, la note dans le barème du
 * pays, « La moyenne est là ! », et deux leçons avec leur barre. Le même écran que dans l'app,
 * en plus petit.
 */
const FRACTION = 0.85;

export function MockExamStory() {
  const { t, locale } = useI18n();
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const timer = window.setTimeout(() => setShown(true), 150);
    return () => window.clearTimeout(timer);
  }, []);

  const size = 132;
  const stroke = 12;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const country = gradeCountry(locale);
  const lessons = [
    { title: t("demo.courseTitle"), part: 0.9 },
    { title: t("onboarding.mockSecondLesson"), part: 0.8 },
  ];

  return (
    <div className="paper w-full max-w-[320px] rounded-[22px] bg-surface p-4 text-left">
      <div className="flex items-center gap-4">
        <div className="relative shrink-0" style={{ width: size, height: size }}>
          <svg aria-hidden="true" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
            <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--color-track)" strokeWidth={stroke} />
            <circle
              cx={size / 2}
              cy={size / 2}
              r={radius}
              fill="none"
              stroke="var(--color-correct)"
              strokeWidth={stroke}
              strokeLinecap="round"
              strokeDasharray={circumference}
              strokeDashoffset={circumference * (1 - (shown ? FRACTION : 0))}
              transform={`rotate(-90 ${size / 2} ${size / 2})`}
              className="score-ring"
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <p className="numeral text-[26px] font-extrabold leading-none text-ink">{examGradeLabel(FRACTION, country, locale)}</p>
            <p className="numeral mt-1 text-[11px] font-bold text-ink-secondary">17/20</p>
          </div>
        </div>
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <p className="text-[16px] font-extrabold leading-tight text-ink">{t("lesson.exam.passed")}</p>
          <p className="text-[12px] font-semibold text-ink-secondary">{t("lesson.exam.time", { used: 22, total: 30 })}</p>
          <div className="mt-1 -mr-2 self-end">
            <Mika mood="celebrate" size={56} label="" />
          </div>
        </div>
      </div>
      <div className="mt-3 flex flex-col gap-2 border-t border-hairline pt-3">
        {lessons.map((lesson) => (
          <div key={lesson.title} className="flex flex-col gap-1">
            <div className="flex items-center justify-between gap-3">
              <span className="truncate text-[12.5px] font-bold text-ink">{lesson.title}</span>
              <span className="numeral text-[12.5px] font-extrabold text-correct-ink">{examGradeLabel(lesson.part, country, locale)}</span>
            </div>
            <div className="h-1.5 overflow-hidden rounded-pill bg-track">
              <div className="h-full rounded-pill bg-correct transition-[width] duration-[900ms] ease-out" style={{ width: `${(shown ? lesson.part : 0) * 100}%` }} />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
