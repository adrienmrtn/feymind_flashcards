"use client";

import { useMemo, useState } from "react";
import { CalendarDays, Check, ChevronRight, Pencil, Play, Plus, Trophy } from "lucide-react";

import { examFraction, examGradeLabel, examPasses, type ExamPaperResult, type LessonTone } from "@micabo/core";

import { ExamEditSheet, type ExamDraft, type ExamLessonChoice } from "@/components/exams/ExamEditSheet";
import { MockExamFlow } from "@/components/exams/MockExamFlow";
import { LessonPrimaryButton } from "@/components/lesson/LessonButtons";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

/**
 * **L'onglet Examen**. Le prochain examen tient le haut de l'écran : les jours qui restent,
 * son nom, sa date, ses leçons, la meilleure note d'examen blanc, et le bouton pour en
 * lancer un. Sans examen, une carte invite à en poser un. Puis l'examen blanc libre, les
 * autres examens à venir, les copies rendues, et les examens passés. Jumeau de `ExamTab.swift`.
 */
export interface ExamItem {
  id: string;
  name: string;
  /** `AAAA-MM-JJ`. */
  examDate: string;
  courseIds: string[];
}

export type ExamLesson = ExamLessonChoice & { tone: LessonTone };

export function ExamsScreen({ exams, lessons, results, country }: { exams: ExamItem[]; lessons: ExamLesson[]; results: ExamPaperResult[]; country: string | null }) {
  const { t, locale } = useI18n();
  const [editing, setEditing] = useState<ExamDraft | null>(null);
  const [mock, setMock] = useState<{ title: string; examId: string | null; preselected: string[] } | null>(null);

  const today = useMemo(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  }, []);
  const daysUntil = (date: string) => Math.round((new Date(`${date}T00:00:00`).getTime() - today) / 86_400_000);
  const upcoming = exams.filter((exam) => daysUntil(exam.examDate) >= 0).sort((a, b) => a.examDate.localeCompare(b.examDate));
  const past = exams.filter((exam) => daysUntil(exam.examDate) < 0).sort((a, b) => b.examDate.localeCompare(a.examDate));
  const next = upcoming[0] ?? null;
  const others = upcoming.slice(1);
  const byId = new Map(lessons.map((lesson) => [lesson.id, lesson]));

  const dateLabel = (date: string) => new Intl.DateTimeFormat(localeBcp47(locale), { weekday: "long", day: "numeric", month: "long" }).format(new Date(`${date}T12:00:00`));
  const best = (examId: string) => {
    const mine = results.filter((result) => result.examId === examId);
    if (mine.length === 0) return null;
    return Math.max(...mine.map(examFraction));
  };

  function edit(exam: ExamItem | null) {
    const soon = new Date(today + 14 * 86_400_000);
    const iso = `${soon.getFullYear()}-${String(soon.getMonth() + 1).padStart(2, "0")}-${String(soon.getDate()).padStart(2, "0")}`;
    setEditing(exam ? { id: exam.id, name: exam.name, examDate: exam.examDate, courseIds: exam.courseIds } : { name: "", examDate: iso, courseIds: [] });
  }

  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-6 pb-6">
      <header className="flex items-end justify-between gap-3 pt-1">
        <div className="flex flex-col gap-0.5">
          <h1 className="text-[32px] font-extrabold leading-tight tracking-tight-title text-ink">{t("lesson.tab.exams")}</h1>
          <p className="text-[15px] font-semibold text-ink-secondary">{upcoming.length === 0 ? t("lesson.exam.none") : t("lesson.exam.count", { count: upcoming.length })}</p>
        </div>
        <button type="button" onClick={() => edit(null)} className="pressable flex h-11 items-center gap-1.5 rounded-pill bg-ink px-4 text-[15px] font-extrabold text-on-ink">
          <Plus aria-hidden="true" className="size-[18px]" strokeWidth={2.8} />
          {t("lesson.exam.new")}
        </button>
      </header>

      {next ? (
        <section className="relative overflow-hidden rounded-[28px] p-5 text-on-ink shadow-floating" style={{ background: "linear-gradient(135deg, var(--color-accent) 0%, var(--color-keyword) 100%)" }} aria-label={t("lesson.exam.upNext")} data-tour="examen-prochain">
          <div className="flex items-start justify-between gap-3">
            <p className="text-[12px] font-extrabold uppercase tracking-caps opacity-85">{t("lesson.exam.upNext")}</p>
            <button type="button" onClick={() => edit(next)} aria-label={t("lesson.exam.edit")} className="pressable flex size-9 items-center justify-center rounded-full bg-white/20">
              <Pencil aria-hidden="true" className="size-4" strokeWidth={2.6} />
            </button>
          </div>
          <div className="mt-2 flex items-end gap-4">
            <div className="flex flex-col items-start leading-none">
              <span className="numeral text-[72px] font-extrabold leading-none tracking-tight-title">{daysUntil(next.examDate)}</span>
              <span className="text-[14px] font-extrabold opacity-85">{daysUntil(next.examDate) === 1 ? t("lesson.exam.dayLeft") : t("lesson.exam.daysLeft")}</span>
            </div>
            <div className="mb-1 flex min-w-0 flex-1 flex-col gap-0.5">
              <h2 className="line-clamp-2 text-[24px] font-extrabold leading-tight tracking-tight-title">{next.name}</h2>
              <p className="flex items-center gap-1.5 text-[14px] font-bold opacity-90">
                <CalendarDays aria-hidden="true" className="size-4" strokeWidth={2.6} />
                {dateLabel(next.examDate)}
              </p>
            </div>
            <div className="-mb-3 -mr-2 shrink-0">
              <Mika mood="idle" size={76} label="" />
            </div>
          </div>
          {next.courseIds.length > 0 ? (
            <ul className="mt-4 flex flex-wrap gap-1.5">
              {next.courseIds.map((id) => {
                const lesson = byId.get(id);
                return lesson ? (
                  <li key={id} className="flex items-center gap-1.5 rounded-pill bg-white/20 py-1 pl-1.5 pr-3 text-[13px] font-bold">
                    <MicaboIcon id={lesson.icon} size={20} />
                    <span className="max-w-[180px] truncate">{lesson.title}</span>
                  </li>
                ) : null;
              })}
            </ul>
          ) : null}
          {best(next.id) !== null ? (
            <p className="mt-4 flex items-center gap-2 text-[14px] font-bold">
              <Trophy aria-hidden="true" className="size-[18px]" strokeWidth={2.4} />
              <span className="numeral">{examGradeLabel(best(next.id)!, country, locale)}</span>
              <span className="opacity-85">{t("lesson.exam.best")}</span>
            </p>
          ) : null}
          <div className="mt-5">
            <LessonPrimaryButton onClick={() => setMock({ title: next.name, examId: next.id, preselected: next.courseIds })} disabled={lessons.length === 0} style={{ background: "var(--color-ink)" }}>
              <Play aria-hidden="true" className="size-5 fill-current" />
              {t("lesson.exam.startMock")}
            </LessonPrimaryButton>
          </div>
        </section>
      ) : (
        <section className="flex items-center gap-4 rounded-[28px] bg-surface p-5 shadow-floating" data-tour="examen-prochain">
          <Mika mood="think" size={96} label="" />
          <div className="flex min-w-0 flex-1 flex-col gap-1.5">
            <h2 className="text-[20px] font-extrabold leading-tight text-ink">{t("lesson.exam.emptyTitle")}</h2>
            <p className="text-[14.5px] font-medium text-ink-secondary">{t("lesson.exam.emptyBody")}</p>
            <button type="button" onClick={() => edit(null)} className="pressable mt-1 w-fit rounded-pill bg-accent px-4 py-2 text-[14px] font-extrabold text-on-ink">
              {t("lesson.exam.new")}
            </button>
          </div>
        </section>
      )}

      <section className="flex items-center gap-4 rounded-[24px] bg-surface p-4 shadow-[inset_0_0_0_1.5px_var(--color-stroke)]" data-tour="examen-blanc">
        <span className="flex size-[56px] shrink-0 items-center justify-center rounded-[16px] bg-accent-soft">
          <MicaboIcon id="quiz" size={40} />
        </span>
        <div className="flex min-w-0 flex-1 flex-col gap-0.5">
          <h2 className="text-[18px] font-extrabold text-ink">{t("lesson.exam.mockTitle")}</h2>
          <p className="text-[14px] font-medium text-ink-secondary">{t("lesson.exam.mockBody")}</p>
        </div>
        <button
          type="button"
          onClick={() => setMock({ title: t("lesson.exam.mockTitle"), examId: null, preselected: [] })}
          disabled={lessons.length === 0}
          aria-label={t("lesson.exam.startMock")}
          className="pressable flex size-11 shrink-0 items-center justify-center rounded-full bg-ink text-on-ink disabled:opacity-40"
        >
          <Play aria-hidden="true" className="size-4 fill-current" strokeWidth={2.4} />
        </button>
      </section>

      {others.length > 0 ? (
        <section className="flex flex-col gap-3">
          <h2 className="text-[18px] font-extrabold text-ink">{t("lesson.exam.upcoming")}</h2>
          <ul className="flex flex-col gap-2.5">
            {others.map((exam) => (
              <li key={exam.id}>
                <ExamRow exam={exam} days={daysUntil(exam.examDate)} date={dateLabel(exam.examDate)} best={best(exam.id)} country={country} onClick={() => edit(exam)} />
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {results.length > 0 ? (
        <section className="flex flex-col gap-3">
          <h2 className="text-[18px] font-extrabold text-ink">{t("lesson.exam.history")}</h2>
          <ul className="flex flex-col gap-2.5">
            {results.map((result) => {
              const fraction = examFraction(result);
              const passes = examPasses(fraction);
              return (
                <li key={result.id} className="flex items-center gap-3.5 rounded-[20px] bg-surface p-3.5 shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
                  <span className={`numeral flex h-12 min-w-12 items-center justify-center rounded-[14px] px-2 text-[17px] font-extrabold ${passes ? "bg-correct-soft text-correct-ink" : "bg-caution-soft text-caution-ink"}`}>
                    {examGradeLabel(fraction, country, locale)}
                  </span>
                  <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span className="truncate text-[16px] font-bold text-ink">{result.title}</span>
                    <span className="truncate text-[13.5px] font-semibold text-ink-secondary">
                      {new Intl.DateTimeFormat(localeBcp47(locale), { day: "numeric", month: "long" }).format(new Date(result.date))} · {result.correct}/{result.total} · {t("lesson.exam.lessonCount", { count: result.lessons.length })}
                    </span>
                  </span>
                </li>
              );
            })}
          </ul>
        </section>
      ) : null}

      {past.length > 0 ? (
        <section className="flex flex-col gap-3">
          <h2 className="text-[18px] font-extrabold text-ink">{t("lesson.exam.past")}</h2>
          <ul className="flex flex-col gap-2.5">
            {past.map((exam) => (
              <li key={exam.id}>
                <ExamRow exam={exam} days={daysUntil(exam.examDate)} date={dateLabel(exam.examDate)} best={best(exam.id)} country={country} onClick={() => edit(exam)} />
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {editing ? <ExamEditSheet draft={editing} lessons={lessons} onClose={() => setEditing(null)} /> : null}
      {mock ? <MockExamFlow title={mock.title} examId={mock.examId} lessons={lessons} preselected={mock.preselected} country={country} onClose={() => setMock(null)} /> : null}
    </div>
  );
}

function ExamRow({ exam, days, date, best, country, onClick }: { exam: ExamItem; days: number; date: string; best: number | null; country: string | null; onClick: () => void }) {
  const { t, locale } = useI18n();
  return (
    <button type="button" onClick={onClick} className="pressable flex w-full items-center gap-3.5 rounded-[20px] bg-surface p-3.5 text-left shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
      <span className={`numeral flex h-12 min-w-12 flex-col items-center justify-center rounded-[14px] px-2 leading-none ${days >= 0 ? "bg-accent-soft text-accent" : "bg-surface-muted text-ink-secondary"}`}>
        {days >= 0 ? (
          <>
            <span className="text-[18px] font-extrabold">{days}</span>
            <span className="mt-0.5 text-[9px] font-extrabold uppercase tracking-caps">{days === 1 ? t("lesson.exam.dayLeft") : t("lesson.exam.daysLeft")}</span>
          </>
        ) : (
          <Check aria-hidden="true" className="size-5" strokeWidth={3} />
        )}
      </span>
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="truncate text-[16px] font-bold text-ink">{exam.name}</span>
        <span className="truncate text-[13.5px] font-semibold text-ink-secondary">
          {date} · {t("lesson.exam.lessonCount", { count: exam.courseIds.length })}
          {best !== null ? ` · ${examGradeLabel(best, country, locale)} ${t("lesson.exam.best")}` : ""}
        </span>
      </span>
      <ChevronRight aria-hidden="true" className="size-5 shrink-0 text-ink-tertiary" strokeWidth={2.6} />
    </button>
  );
}
