"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";

import {
  TARGET_SCORE_MAX,
  TARGET_SCORE_MIN,
  asExamKind,
  averageDailyLoad,
  busiestDay,
  capacityWindow,
  clampMinutes,
  clampTargetScore,
  dailyMinutesLabel,
  dayDifference,
  defaultFormatsFor,
  desiredGradeLabel,
  desiredGradeScale,
  intensityFor,
  intensityFromTargetScore,
  isProjectionEmpty,
  mockQuestionCount,
  planExam,
  startOfDay,
  wantsMock,
  weeklyTotal,
  type ExamKind,
  type StartingPoint,
  type WeeklyMinutes,
} from "@micabo/core";

import { ThinkingOrb } from "thinking-orbs";

import { ImportPanel } from "@/components/app/ImportPanel";
import { ChoiceRow } from "@/components/onboarding/Scaffold";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { ExamDayPicker, isoDay } from "@/components/app/exams/ExamCalendar";
import { createPlan } from "@/lib/actions/plan";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

/**
 * **Créer un plan** : le parcours qui remplace « ajouter un examen ».
 *
 * Le produit ne part plus des cartes mais de l'épreuve, et ce parcours est l'endroit où ce
 * renversement se voit. Il commence donc par **le matériel** - importer un cours, coller une
 * vidéo, cocher ce qu'on a déjà - parce que c'est le premier geste réel de quelqu'un qui
 * prépare un partiel, et pas par une date, qu'on ne peut rien faire de seule.
 *
 * Six questions, une par écran, dans l'ordre où on se les pose. Trois d'entre elles - le type,
 * le point de départ, le temps - sont celles qui manquaient : sans elles le plan supposait un
 * étudiant moyen sur un programme moyen avec des journées identiques, c'est-à-dire personne.
 *
 * Rien n'est demandé qui puisse être mesuré. Le débit, l'observance et ce qui résiste sortent
 * du journal ; on ne demande ici que ce que la base ne saura jamais.
 */

const STEPS = ["materiel", "jour", "type", "depart", "temps", "note"] as const;
type Step = (typeof STEPS)[number];

export interface PlanCourse {
  id: string;
  title: string;
  emoji: string;
  cardCount: number;
}

export interface PlanCard {
  id: string;
  courseId: string | null;
  kind: string;
  state: "new" | "learning" | "review" | "relearning";
  intervalDays: number;
  dueDate: string;
  isSuspended: boolean;
}

export function NewPlan({
  courses,
  cards,
  countryCode,
  initialWeekly,
  sheetLength,
}: {
  courses: PlanCourse[];
  cards: PlanCard[];
  countryCode?: string | null;
  initialWeekly: WeeklyMinutes;
  sheetLength?: string;
}) {
  const { t, locale } = useI18n();
  const router = useRouter();
  const today = startOfDay(new Date());

  const [step, setStep] = useState<Step>("materiel");
  const [picked, setPicked] = useState<string[]>([]);
  const [examDate, setExamDate] = useState(isoDay(addWeeks(today, 3)));
  const [month, setMonth] = useState(() => new Date(today.getFullYear(), today.getMonth(), 1));
  const [kind, setKind] = useState<ExamKind>("exam");
  const [start, setStart] = useState<StartingPoint>("seen");
  const [weekly, setWeekly] = useState<number[]>([...initialWeekly]);
  const [offDays, setOffDays] = useState<string[]>([]);
  const [targetScore, setTargetScore] = useState(15);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const index = STEPS.indexOf(step);
  const chosenDay = startOfDay(new Date(`${examDate}T12:00:00`));
  const daysRemaining = dayDifference(today, chosenDay);
  const intensity = intensityFor(intensityFromTargetScore(targetScore), start);

  const scoped = useMemo(
    () =>
      cards.filter(
        (card) => !card.isSuspended && card.courseId && picked.includes(card.courseId),
      ),
    [cards, picked],
  );

  const plan = useMemo(() => {
    const window = Math.max(1, daysRemaining);
    const capacities = capacityWindow(
      {
        weekly: weekly as unknown as WeeklyMinutes,
        exceptions: offDays.map((day) => ({
          day: new Date(`${day}T12:00:00`),
          minutes: 0,
        })),
      },
      today,
      window,
    );

    return planExam(
      scoped.map((card) => ({
        id: card.id,
        state: card.state,
        intervalDays: card.intervalDays,
        dueDate: new Date(card.dueDate),
      })),
      chosenDay,
      { intensity, capacities },
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scoped, daysRemaining, intensity, offDays, weekly, examDate]);

  const canContinue =
    step === "materiel"
      ? picked.length > 0
      : step === "jour"
        ? daysRemaining >= 0
        : step === "temps"
          ? weekly.some((minutes) => minutes > 0)
          : true;

  function next() {
    if (!canContinue) return;
    const following = STEPS[index + 1];
    if (following) {
      setFailure(null);
      setStep(following);
      return;
    }
    void confirm();
  }

  async function confirm() {
    setBusy(true);
    setFailure(null);
    const result = await createPlan({
      courseIds: picked,
      examDate,
      kind,
      startingPoint: start,
      targetScore,
      weeklyMinutes: weekly.map(clampMinutes),
      offDays,
      formats: defaultFormatsFor(kind),
      name: planName(picked, courses),
    });
    setBusy(false);
    if (result.status === "error") {
      setFailure(result.message ?? t("app.plan.verdict.failed"));
      return;
    }
    // On atterrit sur l'épreuve, pas sur l'accueil : quelqu'un qui vient de répondre à six
    // questions veut voir ce qu'il a signé - le calendrier jour par jour, les blancs posés,
    // ses jours de pause. L'accueil, lui, montre la période entière et répond à autre chose.
    startTransition(() =>
      router.push((result.examId ? `/app/plan/${result.examId}` : "/app") as never),
    );
  }

  return (
    <div className="mx-auto w-full max-w-[620px]">
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-1.5" aria-hidden>
          {STEPS.map((item, position) => (
            <span
              key={item}
              className={`h-1.5 rounded-pill transition-all duration-menu ${
                position === index
                  ? "w-6 bg-ink"
                  : position < index
                    ? "w-1.5 bg-ink"
                    : "w-1.5 bg-stroke-strong"
              }`}
            />
          ))}
        </div>
        <Link
          href={"/app" as never}
          className="text-[13px] font-medium text-ink-tertiary underline-draw"
        >
          {t("app.newPlan.leave")}
        </Link>
      </div>

      <div key={step} className="rise mt-7">
        {step === "materiel" ? (
          <MaterialStep
            courses={courses}
            picked={picked}
            sheetLength={sheetLength}
            onToggle={(id) =>
              setPicked((current) =>
                current.includes(id)
                  ? current.filter((item) => item !== id)
                  : [...current, id],
              )
            }
            onImported={(id) => setPicked((current) => [...new Set([...current, id])])}
          />
        ) : null}

        {step === "jour" ? (
          <DayStep
            picked={chosenDay}
            month={month}
            daysRemaining={daysRemaining}
            onMonth={setMonth}
            onSelect={(day) => {
              const start = startOfDay(day);
              if (start.getTime() < today.getTime()) return;
              setExamDate(isoDay(start));
              setMonth(new Date(start.getFullYear(), start.getMonth(), 1));
            }}
          />
        ) : null}

        {step === "type" ? <KindStep kind={kind} onPick={setKind} /> : null}
        {step === "depart" ? <StartStep start={start} onPick={setStart} /> : null}

        {step === "temps" ? (
          <TimeStep
            weekly={weekly}
            offDays={offDays}
            daysRemaining={daysRemaining}
            examDate={examDate}
            onWeekly={setWeekly}
            onToggleOff={(day) =>
              setOffDays((current) =>
                current.includes(day)
                  ? current.filter((item) => item !== day)
                  : [...current, day],
              )
            }
          />
        ) : null}

        {step === "note" ? (
          <ScoreStep
            targetScore={targetScore}
            countryCode={countryCode}
            onPick={setTargetScore}
            cardCount={plan.projection.cardCount}
            daysRemaining={daysRemaining}
            daily={averageDailyLoad(plan.projection)}
            peak={busiestDay(plan.projection)}
            load={plan.projection.load}
            empty={isProjectionEmpty(plan.projection)}
            mockQuestions={wantsMock(kind) ? mockQuestionCount(scoped.length) : 0}
          />
        ) : null}
      </div>

      {failure ? (
        <p className="mt-4 text-[13.5px] text-negative" role="alert">
          {failure}
        </p>
      ) : null}

      <div className="mt-8">
        <Button
          className="h-14 w-full text-[16px]"
          onClick={next}
          disabled={busy || pending || !canContinue}
        >
          {busy || pending ? (
            <>
              <ThinkingOrb state="connecting" size={20} theme="dark" />
              {t("app.exams.wait")}
            </>
          ) : step === "note" ? (
            t("app.newPlan.create")
          ) : (
            t("app.common.continue")
          )}
        </Button>
        {index > 0 ? (
          <Button
            variant="ghost"
            className="mt-2 w-full"
            onClick={() => setStep(STEPS[index - 1] ?? "materiel")}
            disabled={busy || pending}
          >
            {t("app.common.back")}
          </Button>
        ) : null}
      </div>

      <p className="mt-4 text-center text-[12px] text-ink-tertiary">
        {t(`app.newPlan.hint.${step}`)}
      </p>
    </div>
  );
}

/**
 * Le matériel, en premier.
 *
 * C'est le renversement du produit dans un seul écran : on ne demande pas une date à quelqu'un
 * qui n'a encore rien à réviser. L'import vit ici, dans le contexte où il sert, et ce qu'on
 * importe entre directement au programme de l'épreuve.
 */
function MaterialStep({
  courses,
  picked,
  sheetLength,
  onToggle,
  onImported,
}: {
  courses: PlanCourse[];
  picked: string[];
  sheetLength?: string;
  onToggle: (id: string) => void;
  onImported: (id: string) => void;
}) {
  const { t } = useI18n();
  const [adding, setAdding] = useState(courses.length === 0);

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.materialEyebrow")}</p>
      <h1 className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.newPlan.materialTitle")}
      </h1>
      <p className="mt-3 text-[14.5px] leading-relaxed text-ink-secondary">
        {t("app.newPlan.materialLead")}
      </p>

      {courses.length > 0 ? (
        <ul className="mt-6 space-y-2">
          {courses.map((course) => (
            <li key={course.id}>
              <ChoiceRow
                emoji={course.emoji}
                title={course.title || t("app.course.untitled")}
                detail={t("app.course.cardCount", { count: course.cardCount })}
                selected={picked.includes(course.id)}
                onSelect={() => onToggle(course.id)}
              />
            </li>
          ))}
        </ul>
      ) : null}

      {adding ? (
        <div className="mt-6 rounded-group border border-border bg-card p-5">
          <ImportPanel
            initialLength={sheetLength as never}
            onImported={(id) => {
              onImported(id);
              setAdding(false);
            }}
          />
        </div>
      ) : (
        <Button variant="outline" className="mt-4 w-full" onClick={() => setAdding(true)}>
          {t("app.newPlan.addMaterial")}
        </Button>
      )}
    </div>
  );
}

function DayStep({
  picked,
  month,
  daysRemaining,
  onMonth,
  onSelect,
}: {
  picked: Date;
  month: Date;
  daysRemaining: number;
  onMonth: (next: Date) => void;
  onSelect: (day: Date) => void;
}) {
  const { t, locale } = useI18n();
  const today = startOfDay(new Date());

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.exams.examEyebrow")}</p>
      <h1 className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.exams.whichDay")}
      </h1>
      <p className="mt-3 text-[18px] font-semibold capitalize text-ink">
        {picked.toLocaleDateString(localeBcp47(locale), {
          weekday: "long",
          day: "numeric",
          month: "long",
        })}
      </p>
      <p className="numeral mt-1 text-[13.5px] text-ink-secondary">
        {t("app.newPlan.daysLeft", { count: Math.max(0, daysRemaining) })}
      </p>
      <div className="mt-5">
        <ExamDayPicker
          month={month}
          selected={picked}
          minDate={today}
          onMonth={onMonth}
          onSelect={onSelect}
        />
      </div>
    </div>
  );
}

/** Une figure par type d'épreuve : la rangée en demande une, et un carré vide se remarque. */
const KIND_EMOJI: Record<ExamKind, string> = {
  exam: "📝",
  midterm: "📗",
  final: "🎓",
  quiz: "⚡",
  oral: "🗣",
  mock: "⏱",
};

const START_EMOJI: Record<StartingPoint, string> = {
  cold: "🌱",
  seen: "📖",
  solid: "💪",
};

function KindStep({ kind, onPick }: { kind: ExamKind; onPick: (next: ExamKind) => void }) {
  const { t } = useI18n();
  const options: ExamKind[] = ["exam", "midterm", "final", "quiz", "oral", "mock"];

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.kindEyebrow")}</p>
      <h1 className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.newPlan.kindTitle")}
      </h1>
      <ul className="mt-6 space-y-2">
        {options.map((option) => (
          <li key={option}>
            <ChoiceRow
              emoji={KIND_EMOJI[option]}
              title={t(`app.plan.kind.${option}`)}
              detail={t(`app.newPlan.kindDetail.${option}`)}
              selected={kind === option}
              onSelect={() => onPick(asExamKind(option))}
            />
          </li>
        ))}
      </ul>
    </div>
  );
}

/**
 * Le point de départ : la seule question que le journal ne peut pas remplacer.
 *
 * Le produit sait ce qui a été travaillé **dans l'app**. Il ne sait rien d'un cours suivi en
 * amphi toute l'année, ni d'un chapitre découvert la veille.
 */
function StartStep({
  start,
  onPick,
}: {
  start: StartingPoint;
  onPick: (next: StartingPoint) => void;
}) {
  const { t } = useI18n();
  const options: StartingPoint[] = ["cold", "seen", "solid"];

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.startEyebrow")}</p>
      <h1 className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.newPlan.startTitle")}
      </h1>
      <ul className="mt-6 space-y-2">
        {options.map((option) => (
          <li key={option}>
            <ChoiceRow
              emoji={START_EMOJI[option]}
              title={t(`app.newPlan.start.${option}`)}
              detail={t(`app.newPlan.startDetail.${option}`)}
              selected={start === option}
              onSelect={() => onPick(option)}
            />
          </li>
        ))}
      </ul>
    </div>
  );
}

/** Les paliers du curseur de temps : cinq minutes ne sont pas une soirée. */
const TIME_STEPS = [0, 15, 20, 30, 45, 60, 90, 120, 180] as const;

function TimeStep({
  weekly,
  offDays,
  daysRemaining,
  examDate,
  onWeekly,
  onToggleOff,
}: {
  weekly: number[];
  offDays: string[];
  daysRemaining: number;
  examDate: string;
  onWeekly: (next: number[]) => void;
  onToggleOff: (day: string) => void;
}) {
  const { t, locale } = useI18n();
  const today = startOfDay(new Date());
  const names = useMemo(() => weekdayNames(locale), [locale]);
  const total = weeklyTotal(weekly as unknown as WeeklyMinutes);

  // Les jours à venir jusqu'à l'épreuve, pour poser les pauses à la main. Au-delà d'un mois,
  // pointer chaque jour n'a plus de sens : la semaine type fait le travail.
  const upcoming = Array.from({ length: Math.min(28, Math.max(0, daysRemaining)) }, (_, offset) => {
    const day = new Date(today.getTime());
    day.setDate(day.getDate() + offset);
    return day;
  });

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.newPlan.timeEyebrow")}</p>
      <h1 className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.newPlan.timeTitle")}
      </h1>
      <p className="numeral mt-2 text-[13.5px] text-ink-secondary">
        {t("app.plan.weekly.total", {
          total: dailyMinutesLabel(total),
          days: weekly.filter((minutes) => minutes > 0).length,
        })}
      </p>

      <ul className="mt-5 divide-y divide-hairline">
        {weekly.map((minutes, index) => (
          <li key={index} className="flex items-center gap-4 py-2.5">
            <span className="w-20 shrink-0 text-[14px] font-medium capitalize text-ink">
              {names[index]}
            </span>
            <Slider
              className="min-w-0 flex-1"
              min={0}
              max={TIME_STEPS.length - 1}
              step={1}
              value={nearestTimeStep(minutes)}
              onValueChange={(value) =>
                onWeekly(
                  weekly.map((current, position) =>
                    position === index ? (TIME_STEPS[Number(value)] ?? 0) : current,
                  ),
                )
              }
              aria-label={names[index]}
            />
            <span
              className={`numeral w-14 shrink-0 text-right text-[13px] ${
                minutes === 0 ? "text-ink-tertiary" : "text-ink"
              }`}
            >
              {minutes === 0 ? t("app.plan.weekly.off") : dailyMinutesLabel(minutes)}
            </span>
          </li>
        ))}
      </ul>

      {upcoming.length > 0 ? (
        <div className="mt-7">
          <p className="text-[14px] font-semibold text-ink">{t("app.newPlan.pausesTitle")}</p>
          <p className="mt-1 text-[13px] text-ink-secondary">{t("app.newPlan.pausesLead")}</p>
          <div className="mt-3 flex flex-wrap gap-1.5">
            {upcoming.map((day) => {
              const key = isoDay(day);
              const off = offDays.includes(key);
              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => onToggleOff(key)}
                  aria-pressed={off}
                  className={`pressable numeral rounded-pill px-2.5 py-1.5 text-[12.5px] font-medium ${
                    off
                      ? "bg-ink text-on-ink line-through"
                      : "bg-surface-muted text-ink-secondary"
                  }`}
                >
                  {day.toLocaleDateString(localeBcp47(locale), {
                    day: "numeric",
                    month: "short",
                  })}
                </button>
              );
            })}
          </div>
          <p className="mt-2 text-[12px] text-ink-tertiary">
            {t("app.newPlan.pausesCount", { count: offDays.length })}
          </p>
        </div>
      ) : null}

      <p className="mt-5 text-[12px] text-ink-tertiary">
        {t("app.newPlan.examDay", { day: examDate })}
      </p>
    </div>
  );
}

function ScoreStep({
  targetScore,
  countryCode,
  onPick,
  cardCount,
  daysRemaining,
  daily,
  peak,
  load,
  empty,
  mockQuestions,
}: {
  targetScore: number;
  countryCode?: string | null;
  onPick: (value: number) => void;
  cardCount: number;
  daysRemaining: number;
  daily: number;
  peak: { offset: number; count: number } | null;
  load: number[];
  empty: boolean;
  mockQuestions: number;
}) {
  const { t } = useI18n();
  const scale = desiredGradeScale(countryCode);

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.exams.gradeEyebrow")}</p>
      <h1 className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.exams.desiredGrade")}
      </h1>

      <p className="mt-6 text-center text-[32px] font-bold leading-none text-ink">
        {desiredGradeLabel(targetScore, countryCode)}
      </p>
      <div className="mt-6 flex items-center gap-3">
        <span className="numeral w-12 shrink-0 text-[12.5px] text-ink-tertiary">{scale.min}</span>
        <Slider
          className="min-w-0 flex-1"
          min={TARGET_SCORE_MIN}
          max={TARGET_SCORE_MAX}
          step={1}
          value={targetScore}
          onValueChange={(value) => onPick(clampTargetScore(Number(value)))}
          aria-label={t("app.exams.desiredGrade")}
        />
        <span className="numeral w-12 shrink-0 text-right text-[12.5px] text-ink-tertiary">
          {scale.max}
        </span>
      </div>

      {empty ? (
        <p className="mt-6 text-[13.5px] leading-relaxed text-caution">
          {t("app.exams.missingCards")}
        </p>
      ) : (
        <div className="mt-6 rounded-group bg-canvas p-4">
          <p className="text-[13.5px] leading-relaxed text-ink-secondary">
            {t("app.newPlan.projection", {
              cards: cardCount,
              days: Math.max(0, daysRemaining),
              daily,
              peak: peak?.count ?? daily,
            })}
          </p>
          {mockQuestions > 0 ? (
            <p className="mt-2 text-[13px] leading-relaxed text-ink-secondary">
              {t("app.newPlan.projectionMock", { questions: mockQuestions })}
            </p>
          ) : null}
          <div className="mt-3 flex h-10 items-end gap-0.5">
            {load.map((count, position) => {
              const max = Math.max(1, ...load);
              return (
                <span
                  key={position}
                  className={`min-w-0 flex-1 rounded-t-sm ${
                    peak && position === peak.offset ? "bg-caution" : "bg-ink/40"
                  }`}
                  style={{ height: `${Math.max(6, (count / max) * 100)}%` }}
                />
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

function planName(courseIds: string[], courses: PlanCourse[]): string {
  const titles = courseIds
    .map((id) => courses.find((course) => course.id === id)?.title.trim())
    .filter((title): title is string => Boolean(title));
  return titles.slice(0, 2).join(" · ");
}

function nearestTimeStep(minutes: number): number {
  let best = 0;
  TIME_STEPS.forEach((step, index) => {
    if (Math.abs(step - minutes) < Math.abs((TIME_STEPS[best] ?? 0) - minutes)) best = index;
  });
  return best;
}

function weekdayNames(locale: string): string[] {
  const monday = new Date(2024, 0, 1);
  return Array.from({ length: 7 }, (_, index) => {
    const day = new Date(monday.getTime());
    day.setDate(day.getDate() + index);
    return day.toLocaleDateString(localeBcp47(locale as never), { weekday: "long" });
  });
}

function addWeeks(date: Date, weeks: number): Date {
  const result = new Date(date.getTime());
  result.setDate(result.getDate() + weeks * 7);
  return result;
}
