"use client";

import { useState } from "react";
import { BookOpen, CalendarDays, Repeat, Settings, Sun, TrendingUp, Users } from "lucide-react";

import {
  REVIEW_RATINGS,
  courseAccent,
  examCountdownLabel,
  examUrgency,
  type LoadBar,
  type Mastery,
  type ReviewRating,
} from "@micabo/core";

import { ExamTimeline } from "@/components/app/charts/ExamTimeline";
import { MasteryBar } from "@/components/app/charts/MasteryBar";
import { ReadinessBar } from "@/components/app/charts/ReadinessBar";
import { WeeklyLoad } from "@/components/app/charts/WeeklyLoad";
import { useI18n } from "@/lib/i18n/client";
import { reviewRatingLabel, type Translator } from "@/lib/i18n/copy";

/**
 * **L'app, posée sur la vitrine.**
 *
 * Une capture d'écran vieillit à la première retouche et ne prouve rien. Ici, ce sont les
 * composants de l'app connectée qui dessinent : la barre latérale et ses cinq destinations, le
 * panneau du jour, la barre de préparation, la charge par semaine et la frise des épreuves
 * sont ceux de `/app`, montés dans un cadre avec des données d'exemple. Ce que la vitrine
 * montre est donc ce que l'inscription ouvre.
 *
 * Les onglets se cliquent : un visiteur qui peut parcourir l'app avant de s'inscrire n'a
 * plus à imaginer ce qu'il y a derrière le bouton. La session se joue aussi : la carte se
 * retourne, les quatre boutons notent, et le paquet avance.
 *
 * Tout est daté depuis un lundi fixe, pas depuis l'horloge : un rendu serveur et un rendu
 * client qui ne tombent pas sur la même date se contredisent à l'hydratation.
 */

type Screen = "today" | "review" | "courses" | "exams" | "progress";

const SCREENS: { id: Screen; labelKey: string; icon: typeof Sun }[] = [
  { id: "today", labelKey: "nav.today", icon: Sun },
  { id: "review", labelKey: "nav.review", icon: Repeat },
  { id: "courses", labelKey: "nav.courses", icon: BookOpen },
  { id: "exams", labelKey: "nav.exams", icon: CalendarDays },
  { id: "progress", labelKey: "nav.progress", icon: TrendingUp },
];

/** Un lundi, et tout le reste se compte depuis lui. */
const ANCHOR = new Date(2026, 8, 21, 9, 0, 0);
const DAY = 86_400_000;

function dayAt(offset: number): Date {
  return new Date(ANCHOR.getTime() + offset * DAY);
}

interface DemoExam {
  id: string;
  name: string;
  daysRemaining: number;
  readiness: number;
  target: number;
}

interface DemoCourse {
  id: string;
  title: string;
  subject: string;
  emoji: string;
  cards: number;
  mastery: Mastery;
}

function demoExams(t: Translator): DemoExam[] {
  return [
    { id: "svt", name: t("landing.appExam1"), daysRemaining: 5, readiness: 78, target: 85 },
    { id: "thermo", name: t("landing.appExam2"), daysRemaining: 12, readiness: 64, target: 80 },
    { id: "histoire", name: t("landing.appExam3"), daysRemaining: 26, readiness: 41, target: 75 },
  ];
}

function demoCourses(t: Translator): DemoCourse[] {
  return [
    {
      id: "eau",
      title: t("landing.appCourse1"),
      subject: t("landing.appSubject1"),
      emoji: "💧",
      cards: 48,
      mastery: { percent: 81, cardCount: 48, solid: 36, learning: 7, untouched: 2, fragile: 3 },
    },
    {
      id: "thermo",
      title: t("landing.appCourse2"),
      subject: t("landing.appSubject2"),
      emoji: "🔥",
      cards: 96,
      mastery: { percent: 64, cardCount: 96, solid: 54, learning: 22, untouched: 12, fragile: 8 },
    },
    {
      id: "guerre-froide",
      title: t("landing.appCourse3"),
      subject: t("landing.appSubject3"),
      emoji: "🗺️",
      cards: 70,
      mastery: { percent: 41, cardCount: 70, solid: 24, learning: 18, untouched: 26, fragile: 2 },
    },
  ];
}

export function AppShowcase() {
  const { t } = useI18n();
  const [screen, setScreen] = useState<Screen>("today");

  return (
    <div className="app-shell mx-auto w-full max-w-[1060px] overflow-hidden rounded-[22px] border border-stroke bg-canvas text-left shadow-floating">
      {/* La barre du navigateur : trois pastilles neutres et l'adresse, pour qu'on lise « un
          site ouvert » et non « une image ». */}
      <div className="flex h-9 items-center gap-2 border-b border-stroke bg-surface px-3.5">
        <span aria-hidden className="flex gap-1.5">
          <span className="h-2.5 w-2.5 rounded-full bg-surface-sunken" />
          <span className="h-2.5 w-2.5 rounded-full bg-surface-sunken" />
          <span className="h-2.5 w-2.5 rounded-full bg-surface-sunken" />
        </span>
        <span className="numeral mx-auto rounded-[6px] bg-surface-muted px-3 py-0.5 text-[11px] text-ink-tertiary">
          micabo.app/app
        </span>
      </div>

      <div className="flex h-[560px] flex-col md:flex-row">
        <Sidebar screen={screen} onPick={setScreen} />

        <div
          role="tabpanel"
          id={`vitrine-ecran-${screen}`}
          aria-labelledby={`vitrine-onglet-${screen}`}
          className="relative min-w-0 flex-1 overflow-hidden"
        >
          <div key={screen} className="app-showcase-screen h-full space-y-4 overflow-hidden p-4 sm:p-6">
            {screen === "today" ? <TodayScreen /> : null}
            {screen === "review" ? <ReviewScreen /> : null}
            {screen === "courses" ? <CoursesScreen /> : null}
            {screen === "exams" ? <ExamsScreen /> : null}
            {screen === "progress" ? <ProgressScreen /> : null}
          </div>
          <div
            aria-hidden
            className="pointer-events-none absolute inset-x-0 bottom-0 h-12 bg-gradient-to-t from-canvas to-transparent"
          />
        </div>
      </div>
    </div>
  );
}

function Sidebar({ screen, onPick }: { screen: Screen; onPick: (next: Screen) => void }) {
  const { t } = useI18n();
  return (
    <div
      role="tablist"
      aria-label={t("landing.appTabsAria")}
      className="flex shrink-0 gap-1 overflow-x-auto border-b border-stroke bg-sidebar px-2 py-2 md:w-[196px] md:flex-col md:border-b-0 md:border-r md:px-3 md:py-4"
    >
      {SCREENS.map((item) => {
        const Icon = item.icon;
        const active = item.id === screen;
        return (
          <button
            key={item.id}
            type="button"
            role="tab"
            id={`vitrine-onglet-${item.id}`}
            aria-selected={active}
            aria-controls={`vitrine-ecran-${item.id}`}
            onClick={() => onPick(item.id)}
            className={`flex shrink-0 items-center gap-2.5 rounded-[10px] px-3 py-2 text-[13px] font-medium transition-colors duration-hover ${
              active
                ? "bg-sidebar-accent text-sidebar-accent-foreground"
                : "text-sidebar-foreground hover:bg-sidebar-accent/60"
            }`}
          >
            <Icon aria-hidden className="h-4 w-4" strokeWidth={1.9} />
            {t(item.labelKey)}
          </button>
        );
      })}

      <div className="mt-auto hidden md:block">
        <div className="mt-4 space-y-1 border-t border-sidebar-border pt-4">
          {[
            { labelKey: "nav.friends", icon: Users },
            { labelKey: "nav.settings", icon: Settings },
          ].map((item) => {
            const Icon = item.icon;
            return (
              <span
                key={item.labelKey}
                className="flex items-center gap-2.5 rounded-[10px] px-3 py-2 text-[13px] font-medium text-sidebar-foreground"
              >
                <Icon aria-hidden className="h-4 w-4" strokeWidth={1.9} />
                {t(item.labelKey)}
              </span>
            );
          })}
        </div>
        <div className="mt-3 flex items-center gap-2.5 px-3">
          <span
            aria-hidden
            className="flex h-7 w-7 items-center justify-center rounded-full bg-accent-soft text-[12px] font-semibold text-accent"
          >
            {t("landing.appStudent").charAt(0)}
          </span>
          <span className="truncate text-[13px] font-medium text-ink">{t("landing.appStudent")}</span>
        </div>
      </div>
    </div>
  );
}

function TodayScreen() {
  const { t } = useI18n();
  const exams = demoExams(t);
  const courses = demoCourses(t);
  const next = exams[0]!;
  const blocks = [
    { course: courses[0]!, exam: exams[0]!, cards: 16, minutes: 8 },
    { course: courses[1]!, exam: exams[1]!, cards: 24, minutes: 12 },
  ];
  const total = blocks.reduce((sum, block) => sum + block.cards, 0);
  const minutes = blocks.reduce((sum, block) => sum + block.minutes, 0);

  return (
    <>
      <header>
        <h3 className="page-title">
          {t("app.home.greeting.morning")}, {t("landing.appStudent")}
        </h3>
        <p className="page-lead">
          {t("landing.appToday")} · {t("app.today.streak", { count: 9 })}
        </p>
      </header>

      <section className="panel overflow-hidden">
        <div className="flex flex-wrap items-end justify-between gap-4 p-5 pb-4">
          <div>
            <p className="stat-label">{t("nav.today")}</p>
            <p className="mt-1.5 flex items-baseline gap-2">
              <span className="hero-value">{total}</span>
              <span className="text-[14px] text-ink-secondary">
                {t("app.today.cardsMinutes", { count: total, minutes })}
              </span>
            </p>
          </div>
          <span className="inline-flex h-10 items-center rounded-[10px] bg-accent px-4 text-[13.5px] font-medium text-on-ink">
            {t("app.today.start", { minutes })}
          </span>
        </div>
        <ul className="divide-y divide-hairline border-t border-hairline">
          {blocks.map((block) => (
            <li key={block.course.id} className="flex items-center gap-3 px-5 py-2.5">
              <span
                aria-hidden
                className="flex size-9 shrink-0 items-center justify-center rounded-[10px] text-[17px]"
                style={{ backgroundColor: `${courseAccent(block.course.id)}1a` }}
              >
                <span className="emoji">{block.course.emoji}</span>
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[14px] font-medium text-ink">{block.course.title}</span>
                <span className="block truncate text-[12.5px] text-ink-tertiary">
                  {t("app.today.forExam", { exam: block.exam.name })}
                </span>
              </span>
              <span className="numeral shrink-0 text-[12.5px] text-ink-secondary">
                {t("app.today.block", { cards: block.cards, minutes: block.minutes })}
              </span>
            </li>
          ))}
          <li className="flex items-center gap-3 px-5 py-2.5">
            <span
              aria-hidden
              className="flex size-9 shrink-0 items-center justify-center rounded-[10px] bg-caution-soft text-[17px]"
            >
              <span className="emoji">⏱</span>
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-[14px] font-medium text-ink">
                {t("app.today.mockTitle", { exam: next.name })}
              </span>
              <span className="numeral block truncate text-[12.5px] text-ink-tertiary">
                {t("app.today.mock", { questions: 20, minutes: 25 })}
              </span>
            </span>
            <span className="inline-flex h-8 items-center rounded-[10px] border border-stroke bg-surface px-3 text-[12.5px] font-medium text-ink">
              {t("app.mock.start")}
            </span>
          </li>
        </ul>
      </section>

      <div className="grid gap-4 md:grid-cols-2">
        <section className="panel p-5">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="stat-label">{t("app.today.nextExam")}</p>
              <p className="mt-0.5 truncate text-[16px] font-semibold text-ink">{next.name}</p>
            </div>
            <Countdown days={next.daysRemaining} />
          </div>
          <div className="mt-4">
            <ReadinessBar now={next.readiness} target={next.target} />
          </div>
        </section>

        <section className="panel flex flex-col p-5">
          <p className="section-title">{t("app.today.otherExams")}</p>
          <ul className="mt-2 divide-y divide-hairline">
            {exams.slice(1).map((exam) => (
              <li key={exam.id} className="flex items-center justify-between gap-3 py-2.5">
                <span className="min-w-0">
                  <span className="block truncate text-[13.5px] font-medium text-ink">{exam.name}</span>
                  <span className="numeral block text-[12px] text-ink-tertiary">
                    {t("app.today.known", { percent: exam.readiness })}
                  </span>
                </span>
                <span className="numeral shrink-0 text-[12.5px] font-semibold text-ink-secondary">
                  {examCountdownLabel(exam.daysRemaining)}
                </span>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </>
  );
}

function Countdown({ days }: { days: number }) {
  const urgency = examUrgency(days);
  const chip =
    urgency === "critical"
      ? "bg-negative-soft text-negative"
      : urgency === "soon"
        ? "bg-caution-soft text-caution"
        : "bg-surface-muted text-ink-secondary";
  return (
    <span className={`numeral shrink-0 rounded-full px-2.5 py-1 text-[12px] font-semibold ${chip}`}>
      {examCountdownLabel(days)}
    </span>
  );
}

/**
 * La session, jouable. La carte se retourne au clic, les quatre boutons la notent et
 * passent à la suivante. Les intervalles sous les boutons sont ceux qu'une carte reçoit
 * pendant un examen actif : courts, parce que rien ne repart au-delà du jour J.
 */
function ReviewScreen() {
  const { t } = useI18n();
  const exam = demoExams(t)[0]!;
  const cards = [
    { front: t("landing.appCard1Front"), back: t("landing.appCard1Back") },
    { front: t("landing.appCard2Front"), back: t("landing.appCard2Back") },
    { front: t("landing.appCard3Front"), back: t("landing.appCard3Back") },
  ];
  const [index, setIndex] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const card = cards[index % cards.length]!;
  const done = 7 + index;
  const total = 40;
  const intervals: Record<ReviewRating, string> = {
    1: t("landing.appIntervalAgain"),
    2: t("landing.appIntervalHard"),
    3: t("landing.appIntervalGood"),
    4: t("landing.appIntervalEasy"),
  };

  function grade() {
    setFlipped(false);
    setIndex((current) => current + 1);
  }

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h3 className="page-title">{exam.name}</h3>
          <p className="page-lead">{t("landing.appSessionLead")}</p>
        </div>
        <Countdown days={exam.daysRemaining} />
      </header>

      <div>
        <div className="flex items-baseline justify-between text-[12px] text-ink-tertiary">
          <span className="numeral">
            {done} / {total}
          </span>
          <span>{t("landing.appSessionCapped")}</span>
        </div>
        <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-progress-track">
          <div
            className="h-full rounded-full bg-progress transition-[width] duration-menu ease-out-strong"
            style={{ width: `${(done / total) * 100}%` }}
          />
        </div>
      </div>

      <button
        type="button"
        onClick={() => setFlipped((value) => !value)}
        aria-pressed={flipped}
        className="panel block min-h-[200px] w-full p-6 text-left transition-colors duration-hover hover:border-stroke-strong"
      >
        <span className="inline-flex rounded-pill bg-surface-muted px-2 py-0.5 text-[10px] font-bold uppercase tracking-caps text-ink-tertiary">
          {t("demo.card1Kind")}
        </span>
        <p className="mt-3 text-[17px] font-medium leading-snug text-ink">{card.front}</p>
        {flipped ? (
          <p className="mt-4 border-t border-hairline pt-4 text-[15px] leading-relaxed text-ink-secondary">
            {card.back}
          </p>
        ) : (
          <p className="mt-4 text-[13px] text-ink-tertiary">{t("landing.appSessionFlipHint")}</p>
        )}
      </button>

      <div className="grid grid-cols-4 gap-2">
        {REVIEW_RATINGS.map((rating) => (
          <button
            key={rating}
            type="button"
            onClick={grade}
            disabled={!flipped}
            className={`pressable rounded-[10px] px-2 py-3 text-center shadow-[inset_0_0_0_1px_color-mix(in_srgb,currentColor_16%,transparent)] transition-opacity duration-hover disabled:opacity-40 ${ratingTone(rating)}`}
          >
            <span className="block text-[13px] font-semibold">{reviewRatingLabel(t, rating)}</span>
            <span className="numeral mt-0.5 block text-[11px] opacity-80">{intervals[rating]}</span>
          </button>
        ))}
      </div>
      <p className="text-center text-[12px] text-ink-tertiary">{t("landing.appSessionKeys")}</p>
    </>
  );
}

function ratingTone(rating: ReviewRating): string {
  if (rating === 1) return "bg-negative-soft text-negative";
  if (rating === 2) return "bg-caution-soft text-caution";
  if (rating === 3) return "bg-accent-soft text-accent";
  return "bg-positive-soft text-positive";
}

function CoursesScreen() {
  const { t } = useI18n();
  const courses = demoCourses(t);
  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h3 className="page-title">{t("nav.courses")}</h3>
          <p className="page-lead">{t("landing.appCoursesLead")}</p>
        </div>
        <span className="inline-flex h-8 items-center rounded-[10px] bg-accent px-3 text-[12.5px] font-medium text-on-ink">
          {t("app.import.importCourse")}
        </span>
      </header>
      <ul className="panel divide-y divide-hairline">
        {courses.map((course) => (
          <li key={course.id} className="flex items-center gap-3.5 px-5 py-3.5">
            <span
              aria-hidden
              className="flex size-10 shrink-0 items-center justify-center rounded-[10px] text-[19px]"
              style={{ backgroundColor: `${courseAccent(course.id)}1a` }}
            >
              <span className="emoji">{course.emoji}</span>
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-[14px] font-medium text-ink">{course.title}</span>
              <span className="numeral block truncate text-[12.5px] text-ink-tertiary">
                {course.subject} · {t("landing.appCardCount", { count: course.cards })}
              </span>
              <MasteryBar mastery={course.mastery} size="sm" legend={false} className="mt-2 max-w-[260px]" />
            </span>
            <span className="numeral shrink-0 text-[13px] font-semibold text-ink-secondary">
              {course.mastery.percent} %
            </span>
          </li>
        ))}
      </ul>
    </>
  );
}

function ExamsScreen() {
  const { t } = useI18n();
  const exams = demoExams(t);
  const names = new Map(exams.map((exam) => [exam.id, exam.name]));
  const bars = demoLoad(exams);

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h3 className="page-title">{t("app.exams.hub.title")}</h3>
          <p className="page-lead">{t("app.exams.hub.lead")}</p>
        </div>
        <span className="inline-flex h-8 items-center rounded-[10px] bg-accent px-3 text-[12.5px] font-medium text-on-ink">
          {t("app.newPlan.add")}
        </span>
      </header>

      <section className="panel p-5">
        <p className="section-title">{t("landing.appLoadTitle")}</p>
        <p className="section-lead">{t("landing.appLoadLead")}</p>
        <div className="mt-4">
          <WeeklyLoad bars={bars} examNames={names} />
        </div>
      </section>

      <section className="panel p-5 [&_a]:pointer-events-none">
        <p className="section-title">{t("landing.appTimelineTitle")}</p>
        <div className="mt-3">
          <ExamTimeline
            now={ANCHOR}
            exams={exams.map((exam) => ({
              id: exam.id,
              name: exam.name,
              daysRemaining: exam.daysRemaining,
              readiness: exam.readiness,
            }))}
          />
        </div>
      </section>
    </>
  );
}

/**
 * Six semaines de charge, calées sur les trois épreuves : la charge monte vers chaque
 * jour J, retombe après, et deux blancs sont posés en chemin.
 */
function demoLoad(exams: DemoExam[]): LoadBar[] {
  const bars: LoadBar[] = [];
  for (let offset = 0; offset < 42; offset += 1) {
    const shares = exams
      .filter((exam) => offset <= exam.daysRemaining)
      .map((exam) => {
        const distance = exam.daysRemaining - offset;
        const weight = distance <= 3 ? 14 : distance <= 10 ? 9 : 5;
        return { examId: exam.id, examName: exam.name, cardCount: weight, minutes: Math.round(weight / 2) };
      });
    const weekend = offset % 7 === 6;
    const cardCount = weekend ? 0 : shares.reduce((sum, share) => sum + share.cardCount, 0);
    const mocks =
      offset === 2
        ? [{ examId: exams[0]!.id, examName: exams[0]!.name, questionCount: 20, minutes: 25 }]
        : offset === 9
          ? [{ examId: exams[1]!.id, examName: exams[1]!.name, questionCount: 30, minutes: 40 }]
          : [];
    bars.push({
      offset,
      date: dayAt(offset),
      minutes: Math.round(cardCount / 2) + mocks.reduce((sum, mock) => sum + mock.minutes, 0),
      cardCount,
      examIds: exams.filter((exam) => exam.daysRemaining === offset).map((exam) => exam.id),
      isOff: weekend,
      mocks,
      byExam: weekend ? [] : shares,
    });
  }
  return bars;
}

function ProgressScreen() {
  const { t } = useI18n();
  const mastery: Mastery = { percent: 72, cardCount: 214, solid: 154, learning: 28, untouched: 20, fragile: 12 };
  const weak = [
    { front: t("landing.appWeak1"), course: t("landing.appCourse2"), lapses: 4 },
    { front: t("landing.appWeak2"), course: t("landing.appCourse3"), lapses: 3 },
    { front: t("landing.appWeak3"), course: t("landing.appCourse1"), lapses: 3 },
  ];

  return (
    <>
      <header>
        <h3 className="page-title">{t("app.progress.title")}</h3>
        <p className="page-lead">{t("app.progress.lead")}</p>
      </header>

      <dl className="grid grid-cols-3 gap-3">
        <Stat label={t("app.home.stats.streak")} value={t("app.progress.days", { count: 9 })} />
        <Stat label={t("app.home.stats.passes")} value="1 240" />
        <Stat label={t("app.home.stats.accuracy")} value="86 %" />
      </dl>

      <section className="panel p-5">
        <p className="section-title">{t("app.home.mastery.title")}</p>
        <p className="section-lead">{t("app.progress.masteryLead")}</p>
        <p className="mt-4 flex items-baseline gap-2">
          <span className="hero-value">
            {mastery.percent}
            <span className="text-[20px] text-ink-secondary"> %</span>
          </span>
          <span className="text-[13px] text-ink-tertiary">
            {t("app.home.mastery.of", { count: mastery.cardCount })}
          </span>
        </p>
        <MasteryBar mastery={mastery} className="mt-4" />
      </section>

      <section className="panel p-5">
        <p className="section-title">{t("app.home.weak.title")}</p>
        <p className="section-lead">{t("app.home.weak.lead")}</p>
        <ul className="mt-3 divide-y divide-hairline">
          {weak.map((card) => (
            <li key={card.front} className="flex items-center justify-between gap-3 py-2.5">
              <span className="min-w-0">
                <span className="block truncate text-[13.5px] font-medium text-ink">{card.front}</span>
                <span className="block truncate text-[12px] text-ink-tertiary">{card.course}</span>
              </span>
              <span className="numeral shrink-0 rounded-full bg-negative-soft px-2 py-0.5 text-[11px] font-semibold text-negative">
                {t("landing.appLapses", { count: card.lapses })}
              </span>
            </li>
          ))}
        </ul>
      </section>
    </>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="panel px-4 py-3.5">
      <dt className="stat-label">{label}</dt>
      <dd className="stat-value mt-1.5">{value}</dd>
    </div>
  );
}
