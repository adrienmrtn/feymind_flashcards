"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";

import { dailyMinutesLabel, type TermLever, type TermVerdict } from "@micabo/core";

import { Button } from "@/components/ui/button";
import { addWeeklyMinutes } from "@/lib/actions/availability";
import { useI18n } from "@/lib/i18n/client";

/**
 * Est-ce que ça tient, et sinon qu'est-ce qu'on fait.
 *
 * Un plan qui déborde ne doit ni s'afficher comme un plan complet ni s'excuser. Il annonce le
 * déficit **en minutes**, la seule unité que l'étudiant sait arbitrer, puis il propose les
 * trois façons de le combler - et chacune est un bouton qui écrit, pas un conseil.
 *
 * L'ordre des leviers vient du cœur de calcul et pas d'ici : c'est lui qui sait ce que chacun
 * récupère. L'écran ne fait que les rendre cliquables.
 */

export interface VerdictExam {
  id: string;
  name: string;
}

export function Verdict({
  verdict,
  levers,
  exams,
}: {
  verdict: TermVerdict;
  levers: TermLever[];
  exams: VerdictExam[];
}) {
  const { t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [failed, setFailed] = useState(false);

  const tone =
    verdict.level === "short"
      ? "border-caution/40 bg-caution-soft"
      : verdict.level === "tight"
        ? "border-border bg-surface-muted"
        : "border-border bg-card";

  const headline =
    verdict.level === "short"
      ? t("app.plan.verdict.short", { minutes: verdict.deficitMinutes })
      : verdict.level === "tight"
        ? t("app.plan.verdict.tight", { minutes: verdict.averageMinutes })
        : t("app.plan.verdict.clear", { minutes: verdict.averageMinutes });

  function openTime(extra: number) {
    setFailed(false);
    startTransition(async () => {
      const result = await addWeeklyMinutes(extra);
      if (result.status === "error") setFailed(true);
      else router.refresh();
    });
  }

  return (
    <section className={`rounded-group border p-5 ${tone}`}>
      <p className="text-[16.5px] font-semibold leading-snug text-ink">{headline}</p>

      {verdict.level !== "short" && verdict.busiest ? (
        <p className="mt-1 text-[13.5px] text-ink-secondary">
          {t("app.plan.verdict.busiest", {
            minutes: verdict.busiest.minutes,
            days: verdict.busiest.offset,
          })}
        </p>
      ) : null}

      {verdict.level === "short" ? (
        <>
          <p className="mt-1 text-[13.5px] text-ink-secondary">
            {t("app.plan.verdict.shortLead", {
              exams: exams
                .filter((exam) => verdict.examIds.includes(exam.id))
                .map((exam) => exam.name)
                .join(", "),
            })}
          </p>

          <ul className="mt-4 space-y-2">
            {levers.map((lever) => (
              <li key={`${lever.kind}:${lever.examId ?? ""}`}>
                <LeverRow
                  lever={lever}
                  examName={exams.find((exam) => exam.id === lever.examId)?.name}
                  pending={pending}
                  onOpenTime={openTime}
                />
              </li>
            ))}
          </ul>

          {failed ? (
            <p className="mt-3 text-[13px] text-negative" role="alert">
              {t("app.plan.verdict.failed")}
            </p>
          ) : null}
        </>
      ) : null}
    </section>
  );
}

function LeverRow({
  lever,
  examName,
  pending,
  onOpenTime,
}: {
  lever: TermLever;
  examName?: string;
  pending: boolean;
  onOpenTime: (extra: number) => void;
}) {
  const { t } = useI18n();
  const gain = t("app.plan.lever.gain", { minutes: lever.recoveredMinutes });

  if (lever.kind === "capacity") {
    return (
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-button bg-surface px-4 py-3">
        <span className="min-w-0">
          <span className="block text-[14.5px] font-medium text-ink">
            {t("app.plan.lever.capacity", { minutes: dailyMinutesLabel(15) })}
          </span>
          <span className="mt-0.5 block text-[12.5px] text-ink-tertiary">{gain}</span>
        </span>
        <Button size="sm" disabled={pending} onClick={() => onOpenTime(15)}>
          {t("app.plan.lever.capacityAction")}
        </Button>
      </div>
    );
  }

  const href = lever.examId ? (`/app/plan/${lever.examId}` as const) : ("/app/plan" as const);
  const label =
    lever.kind === "target"
      ? t("app.plan.lever.target", { exam: examName ?? "" })
      : t("app.plan.lever.scope", { exam: examName ?? "" });

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-button bg-surface px-4 py-3">
      <span className="min-w-0">
        <span className="block text-[14.5px] font-medium text-ink">{label}</span>
        <span className="mt-0.5 block text-[12.5px] text-ink-tertiary">{gain}</span>
      </span>
      <Button size="sm" variant="outline" render={<Link href={href as never} />}>
        {t("app.plan.lever.open")}
      </Button>
    </div>
  );
}
