import Link from "next/link";

import { examCountdownLabel, examUrgency, studyCounts, currentStreak } from "@micabo/core";

import { TodayPanel } from "@/components/app/home/TodayPanel";
import { ReadinessBar } from "@/components/app/charts/ReadinessBar";
import { Button } from "@/components/ui/button";
import { loadNewCardBudget, loadProfileStats } from "@/lib/data/reviews";
import { getTranslator } from "@/lib/i18n/server";
import { localeBcp47, type Translator } from "@/lib/i18n/copy";
import { loadTermSnapshot, type PlanExam } from "@/lib/term-plan";

/**
 * **L'accueil : aujourd'hui.**
 *
 * L'écran répond à une seule question, celle qu'on se pose en ouvrant l'app : qu'est-ce que
 * j'ai à faire, et je le lance. Le plan de la période, ses verdicts et ses réglages ont leur
 * page (Examens) ; la mesure a la sienne (Progrès). Ici : le travail du jour, la prochaine
 * épreuve, et un mot si le plan ne tient plus.
 */
export default async function TodayPage() {
  const [{ t, locale }, snapshot, budget, stats] = await Promise.all([
    getTranslator(),
    loadTermSnapshot(),
    loadNewCardBudget(),
    loadProfileStats(),
  ]);

  const { now, blocks, todayCards, todayMinutes, upcoming, verdict, snapshots, profile } = snapshot;

  const due = studyCounts(
    snapshots.map((card) => ({
      id: card.id,
      state: card.state,
      dueDate: new Date(card.due_date),
      position: card.position,
      createdAt: new Date(card.created_at),
      isSuspended: card.is_suspended,
    })),
    { limits: { newPerSession: budget.remaining, reviewsPerSession: Number.MAX_SAFE_INTEGER } },
  ).total;

  const streak = currentStreak(stats.reviewDays.map((day) => new Date(day)), now);
  const next = upcoming[0] ?? null;
  const firstName = profile?.display_name?.trim().split(/\s+/)[0] ?? null;

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="page-title">
            {firstName ? `${greetingFor(now, t)}, ${firstName}` : greetingFor(now, t)}
          </h1>
          <p className="page-lead">
            {now.toLocaleDateString(localeBcp47(locale), {
              weekday: "long",
              day: "numeric",
              month: "long",
            })}
            {streak > 1 ? ` · ${t("app.today.streak", { count: streak })}` : ""}
          </p>
        </div>
      </header>

      {verdict.level === "short" ? (
        <Link
          href={"/app/plan" as never}
          className="hover-tile flex items-center justify-between gap-4 rounded-group border border-caution/40 bg-caution-soft px-5 py-3.5"
        >
          <span className="text-[13.5px] font-medium text-ink">
            {t("app.plan.verdict.short", { minutes: verdict.deficitMinutes })}
          </span>
          <span className="shrink-0 text-[13px] font-medium text-caution">{t("app.today.fix")}</span>
        </Link>
      ) : null}

      <TodayPanel
        blocks={blocks}
        minutes={todayMinutes}
        cards={todayCards}
        dueCards={due}
        hasCards={snapshots.length > 0}
      />

      <div className="grid gap-4 md:grid-cols-2">
        <NextExam exam={next} t={t} />
        <UpcomingList exams={upcoming.slice(1, 4)} count={upcoming.length} t={t} />
      </div>
    </>
  );
}

function NextExam({
  exam,
  t,
}: {
  exam: PlanExam | null;
  t: Translator;
}) {
  if (!exam) {
    return (
      <section className="panel p-5">
        <p className="section-title">{t("app.today.noExam")}</p>
        <p className="section-lead max-w-[44ch]">{t("app.today.noExamBody")}</p>
        <div className="mt-4">
          <Button size="sm" render={<Link href={"/app/plan/nouveau" as never} />} data-tour="examens-ajouter">
            {t("app.newPlan.add")}
          </Button>
        </div>
      </section>
    );
  }
  const urgency = examUrgency(exam.daysRemaining);
  const chip =
    urgency === "critical"
      ? "bg-negative-soft text-negative"
      : urgency === "soon"
        ? "bg-caution-soft text-caution"
        : "bg-surface-muted text-ink-secondary";

  return (
    <section className="panel p-5" data-tour="prochaine-epreuve">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="stat-label">{t("app.today.nextExam")}</p>
          <Link href={`/app/plan/${exam.id}` as never} className="underline-draw mt-0.5 block truncate text-[16px] font-semibold text-ink">
            {exam.name}
          </Link>
        </div>
        <span className={`numeral shrink-0 rounded-full px-2.5 py-1 text-[12px] font-semibold ${chip}`}>
          {examCountdownLabel(exam.daysRemaining)}
        </span>
      </div>
      <div className="mt-4">
        <ReadinessBar
          now={exam.measured && exam.mockScore != null ? exam.mockScore : exam.masteryPercent}
          projected={exam.projectedPercent}
          target={exam.targetScore}
          measured={exam.measured}
        />
      </div>
    </section>
  );
}

function UpcomingList({
  exams,
  count,
  t,
}: {
  exams: { id: string; name: string; daysRemaining: number; masteryPercent: number }[];
  count: number;
  t: Translator;
}) {
  return (
    <section className="panel flex flex-col p-5">
      <div className="flex items-baseline justify-between gap-3">
        <p className="section-title">{t("app.today.otherExams")}</p>
        <Link href={"/app/plan" as never} className="underline-draw text-[12.5px] font-medium text-ink-secondary">
          {t("app.today.seeExams")}
        </Link>
      </div>
      {exams.length === 0 ? (
        <p className="section-lead">
          {count <= 1 ? t("app.today.noOtherExam") : ""}
        </p>
      ) : (
        <ul className="mt-2 divide-y divide-hairline">
          {exams.map((exam) => (
            <li key={exam.id}>
              <Link
                href={`/app/plan/${exam.id}` as never}
                className="flex items-center justify-between gap-3 py-2.5"
              >
                <span className="min-w-0">
                  <span className="block truncate text-[13.5px] font-medium text-ink">{exam.name}</span>
                  <span className="numeral block text-[12px] text-ink-tertiary">
                    {t("app.today.known", { percent: exam.masteryPercent })}
                  </span>
                </span>
                <span className="numeral shrink-0 text-[12.5px] font-semibold text-ink-secondary">
                  {examCountdownLabel(exam.daysRemaining)}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
      <div className="mt-auto pt-3">
        <Button variant="outline" size="sm" render={<Link href={"/app/plan/nouveau" as never} />}>
          {t("app.newPlan.add")}
        </Button>
      </div>
    </section>
  );
}

function greetingFor(now: Date, t: Translator): string {
  const hour = now.getHours();
  if (hour < 6) return t("app.home.greeting.night");
  if (hour < 12) return t("app.home.greeting.morning");
  if (hour < 18) return t("app.home.greeting.afternoon");
  return t("app.home.greeting.evening");
}
