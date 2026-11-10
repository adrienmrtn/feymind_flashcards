"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import type { Route } from "next";
import { ChevronRight, Flame, Play, Sparkles, Zap } from "lucide-react";

import { DAILY_XP_GOAL, FOCUS_MINUTES, type LessonTone, type ResumeTarget } from "@micabo/core";

import { StoreBadges } from "@/components/landing/StoreBadges";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { Sheet } from "@/components/lesson/Sheet";
import { MikaBubble } from "@/components/xp/MikaBubble";
import { useI18n } from "@/lib/i18n/client";
import { FOCUS_PATH, flashcardsPath, LEAGUE_PATH, lessonPath, QUICK_QUIZ_QUESTIONS, quickQuizPath } from "@/lib/lesson/routes";
import { requestPaywall } from "@/lib/paywall";
import { useXp } from "@/lib/xp/client";
import { LEAGUE_EMOJI, leagueNameKey } from "@/lib/xp/league";

/**
 * **Ce que le lot « Knowunity » ajoute à Home** (`docs/refonte-knowunity.md` § 1) : la rangée du
 * haut (Pro, XP, série), la carte « Aujourd'hui » et les quatre « Outils ». La question, Mika, la
 * barre et les imports restent dans `HomeScreen`, inchangés.
 */

export type HomeResume = ResumeTarget & { icon: string | null; tone: LessonTone };

/** ✦ Pro à gauche pour qui n'est pas abonné ; à droite, l'XP de la semaine puis la série. */
export function HomeTopRow({ isPro, streak }: { isPro: boolean; streak: number }) {
  const { t } = useI18n();
  const xp = useXp();
  const league = t(leagueNameKey(xp.league));
  return (
    <div className="flex min-h-9 items-center justify-between gap-2">
      {isPro ? (
        <span />
      ) : (
        <button
          type="button"
          onClick={() => requestPaywall("upgrade")}
          aria-label={t("lesson.profile.goPro")}
          className="kx-gradient pressable inline-flex items-center gap-1 rounded-pill px-3.5 py-1.5 text-[14px] font-extrabold text-white shadow-[0_5px_10px_-3px_color-mix(in_srgb,var(--color-accent)_45%,transparent)]"
        >
          <Sparkles aria-hidden="true" className="size-3.5 fill-current" strokeWidth={2.4} />
          Pro
        </button>
      )}
      <div className="flex items-center gap-2">
        <Link
          href={LEAGUE_PATH}
          aria-label={t("app.kx.xpPillAria", { xp: xp.week, league })}
          className="pressable inline-flex items-center gap-1 rounded-pill bg-surface px-3 py-1.5 text-[13px] font-extrabold text-accent shadow-[inset_0_0_0_1.5px_var(--color-stroke)]"
        >
          <Zap aria-hidden="true" className="size-4 fill-current" strokeWidth={2.4} />
          <span className="numeral">{xp.week}</span>
          <span aria-hidden="true" className="text-[14px] leading-none">
            {LEAGUE_EMOJI[xp.league]}
          </span>
        </Link>
        {streak > 1 ? (
          <span className="inline-flex items-center gap-1.5 rounded-pill px-3 py-1.5 text-[13px] font-extrabold" style={{ background: "var(--color-tone-yellow-pale)", color: "var(--color-tone-yellow-ink)" }}>
            <Flame aria-hidden="true" className="size-4" strokeWidth={2.6} />
            {t("app.today.streak", { count: streak })}
          </span>
        ) : null}
      </div>
    </div>
  );
}

/** L'anneau de l'objectif du jour : l'XP d'aujourd'hui sur cinquante, plein quand c'est atteint. */
function GoalRing({ value, size = 66 }: { value: number; size?: number }) {
  const stroke = 7;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const ratio = Math.min(1, value / DAILY_XP_GOAL);
  const reached = value >= DAILY_XP_GOAL;
  return (
    <span className="relative flex shrink-0 items-center justify-center" style={{ width: size, height: size }}>
      <svg aria-hidden="true" className="absolute inset-0" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <defs>
          <linearGradient id="kx-goal" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="var(--color-accent)" />
            <stop offset="100%" stopColor="var(--color-keyword)" />
          </linearGradient>
        </defs>
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--color-track)" strokeWidth={stroke} />
        {ratio > 0 ? (
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={reached ? "var(--color-correct)" : "url(#kx-goal)"}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={`${ratio * circumference} ${circumference}`}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
          className="score-ring"
        />
        ) : null}
      </svg>
      <Zap aria-hidden="true" className={`size-6 fill-current ${reached ? "text-correct" : "text-accent"}`} strokeWidth={2} />
    </span>
  );
}

/**
 * **« Aujourd'hui »** : l'anneau de l'objectif du jour, les cartes dues, la leçon en cours (la
 * carte « Reprendre » y est fondue), ou l'invitation à créer la première leçon.
 */
export function TodayCard({
  dueCards,
  resume,
  hasLessons,
  onFirstLesson,
}: {
  dueCards: { count: number; lessonId: string } | null;
  resume: HomeResume | null;
  hasLessons: boolean;
  onFirstLesson: () => void;
}) {
  const { t } = useI18n();
  const xp = useXp();
  const reached = xp.today >= DAILY_XP_GOAL;
  return (
    <section aria-labelledby="kx-today" className="flex flex-col gap-1 rounded-[24px] bg-surface p-4 shadow-floating">
      <div className="flex items-center gap-3.5 pb-1">
        <GoalRing value={xp.today} />
        <div className="flex min-w-0 flex-col gap-0.5">
          <h2 id="kx-today" className="text-[12px] font-extrabold uppercase tracking-caps text-ink-secondary">
            {t("app.kx.today.title")}
          </h2>
          <p className={`text-[19px] font-extrabold leading-tight ${reached ? "text-correct-ink" : "text-ink"}`}>{reached ? t("app.kx.today.goalReached") : t("app.kx.today.goal")}</p>
          <p className="numeral text-[14px] font-bold text-ink-secondary">{t("app.kx.today.goalProgress", { xp: Math.min(xp.today, 9999), goal: DAILY_XP_GOAL })}</p>
        </div>
      </div>

      {dueCards && dueCards.count > 0 ? (
        <TodayRow href={`${flashcardsPath(dueCards.lessonId)}?reviser=1` as Route} icon={<MicaboIcon id="cartes" size={30} />} title={t("app.kx.today.cardsDue", { count: dueCards.count })} />
      ) : null}

      {resume ? (
        <TodayRow
          href={lessonPath(resume.lessonId)}
          icon={<ResumeRing resume={resume} />}
          title={t("app.kx.today.continue", { lesson: resume.title })}
          subtitle={resume.circleNumber !== null && resume.circleTitle !== null ? t("lesson.home.resumeCircle", { n: resume.circleNumber, title: resume.circleTitle }) : t("lesson.home.resumeDone")}
          play
        />
      ) : null}

      {!hasLessons ? (
        <button type="button" onClick={onFirstLesson} className="pressable flex items-center gap-3 rounded-[16px] border-t border-hairline px-1 pt-3 text-start">
          <MicaboIcon id="fusee" size={30} />
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="text-[16px] font-extrabold text-ink">{t("app.kx.today.firstLesson")}</span>
            <span className="text-[13.5px] font-medium text-ink-secondary">{t("app.kx.today.firstLessonSub")}</span>
          </span>
          <ChevronRight aria-hidden="true" className="size-5 shrink-0 text-ink-tertiary rtl:rotate-180" strokeWidth={2.6} />
        </button>
      ) : null}
    </section>
  );
}

function TodayRow({ href, icon, title, subtitle, play = false }: { href: Route; icon: ReactNode; title: string; subtitle?: string; play?: boolean }) {
  return (
    <Link href={href} className="pressable flex items-center gap-3 border-t border-hairline px-1 py-3 last:pb-1">
      <span className="flex size-[42px] shrink-0 items-center justify-center">{icon}</span>
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="line-clamp-2 text-[16px] font-extrabold leading-snug text-ink">{title}</span>
        {subtitle ? <span className="truncate text-[13.5px] font-semibold text-ink-secondary">{subtitle}</span> : null}
      </span>
      {play ? (
        <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-ink text-on-ink">
          <Play aria-hidden="true" className="size-4 fill-current rtl:rotate-180" strokeWidth={2.4} />
        </span>
      ) : (
        <ChevronRight aria-hidden="true" className="size-5 shrink-0 text-ink-tertiary rtl:rotate-180" strokeWidth={2.6} />
      )}
    </Link>
  );
}

/** La leçon en cours : son icône dans l'anneau de sa progression, comme l'ancienne carte « Reprendre ». */
function ResumeRing({ resume }: { resume: HomeResume }) {
  const size = 42;
  const radius = (size - 4) / 2;
  const circumference = 2 * Math.PI * radius;
  return (
    <span className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      <svg aria-hidden="true" className="absolute inset-0" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--color-track)" strokeWidth={4} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={`var(--color-tone-${resume.tone}-vivid)`}
          strokeWidth={4}
          strokeLinecap="round"
          strokeDasharray={`${Math.max(0.02, resume.percent / 100) * circumference} ${circumference}`}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
      </svg>
      <MicaboIcon id={resume.icon} size={24} />
    </span>
  );
}

/**
 * **« Outils »** : quatre tuiles, deux par deux. Le scanner, le quiz éclair sur la dernière
 * leçon ouverte, le minuteur, la ligue.
 */
export function ToolsGrid({ quizLessonId, onScan, onFirstLesson }: { quizLessonId: string | null; onScan: () => void; onFirstLesson: () => void }) {
  const { t } = useI18n();
  return (
    <section aria-labelledby="kx-tools" className="flex flex-col gap-2.5">
      <h2 id="kx-tools" className="ps-1 text-[12px] font-extrabold uppercase tracking-caps text-ink-secondary">
        {t("app.kx.tools.title")}
      </h2>
      <ul className="grid grid-cols-2 gap-2.5">
        <li>
          <ToolTile icon="photo" tone="blue" title={t("app.kx.tools.scan")} line={t("app.kx.tools.scanSub")} onClick={onScan} />
        </li>
        <li>
          {quizLessonId ? (
            <ToolTile icon="quiz" tone="lilac" title={t("app.kx.tools.quiz")} line={t("app.kx.tools.quizSub", { n: QUICK_QUIZ_QUESTIONS })} href={quickQuizPath(quizLessonId)} />
          ) : (
            <ToolTile icon="quiz" tone="lilac" title={t("app.kx.tools.quiz")} line={t("app.kx.tools.quizEmpty")} onClick={onFirstLesson} />
          )}
        </li>
        <li>
          <ToolTile icon="reveil" tone="mint" title={t("app.kx.tools.timer")} line={t("app.kx.tools.timerSub", { n: FOCUS_MINUTES })} href={FOCUS_PATH} />
        </li>
        <li>
          <ToolTile icon="trophee" tone="yellow" title={t("app.kx.tools.league")} line={t("app.kx.tools.leagueSub")} href={LEAGUE_PATH} />
        </li>
      </ul>
    </section>
  );
}

function ToolTile({ icon, tone, title, line, href, onClick }: { icon: string; tone: LessonTone; title: string; line: string; href?: Route; onClick?: () => void }) {
  const body = (
    <>
      <span className="flex size-12 items-center justify-center rounded-[15px]" style={{ background: `var(--color-tone-${tone}-pale)` }}>
        <MicaboIcon id={icon} size={34} />
      </span>
      <span className="flex min-w-0 flex-col gap-0.5">
        <span className="truncate text-[16px] font-extrabold text-ink">{title}</span>
        <span className="line-clamp-2 text-[13px] font-semibold leading-snug text-ink-secondary">{line}</span>
      </span>
    </>
  );
  const className = "pressable flex h-full w-full flex-col items-start gap-2.5 rounded-[22px] bg-surface p-3.5 text-start shadow-[inset_0_0_0_1.5px_var(--color-stroke)]";
  return href ? (
    <Link href={href} className={className}>
      {body}
    </Link>
  ) : (
    <button type="button" onClick={onClick} className={className}>
      {body}
    </button>
  );
}

/**
 * **« Le scanner est dans l'app »** : le site ne lit pas de photo en texte sur l'appareil, et le
 * scanner (`docs/refonte-knowunity.md` § 4) ne doit appeler aucun serveur nouveau. La tuile dit
 * donc où il vit, avec les deux boutiques — le même compte ouvre l'app.
 */
export function ScanSheet({ onClose }: { onClose: () => void }) {
  const { t } = useI18n();
  return (
    <Sheet title={t("app.kx.scan.title")} onClose={onClose}>
      <MikaBubble mood="wave" size={72}>
        {t("app.kx.scan.body")}
      </MikaBubble>
      <StoreBadges size="small" className="justify-center pt-1" />
    </Sheet>
  );
}
