"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";

import { EXAM_KINDS, type ExamKind, type WeakCard } from "@micabo/core";

import { Button } from "@/components/ui/button";
import { saveExamDetails } from "@/lib/actions/exams";
import { useI18n } from "@/lib/i18n/client";

/**
 * La fiche d'une épreuve : **tout ce qui n'a pas sa place dans les trois questions.**
 *
 * Déclarer une épreuve reste un geste court - le jour, les matières, la note visée - parce que
 * c'est ce qu'on fait en marchant entre deux amphis. Ce qui demande de la réflexion vit ici,
 * et **replié** : le type d'épreuve et les formats à travailler. Quelqu'un qui n'ouvre jamais
 * ce pli a exactement le produit d'avant.
 *
 * Chaque case cochée change ce que le plan pose, donc chaque enregistrement refait le plan.
 * Une case qui ne changerait rien serait une décoration, et le produit en a déjà assez.
 */

export interface SheetCourse {
  id: string;
  title: string;
  emoji: string;
  cardCount: number;
  masteryPercent: number;
}

const FORMATS: readonly { kind: string; labelKey: string; effectKey: string }[] = [
  { kind: "basic", labelKey: "app.cardKind.basic", effectKey: "app.plan.sheet.effect.basic" },
  { kind: "choice", labelKey: "app.cardKind.choice", effectKey: "app.plan.sheet.effect.choice" },
  { kind: "cloze", labelKey: "app.cardKind.gap", effectKey: "app.plan.sheet.effect.cloze" },
];

export function ExamSheet({
  examId,
  kind,
  formats,
  courses,
  weak,
  availableKinds,
}: {
  examId: string;
  kind: ExamKind;
  formats: string[];
  courses: SheetCourse[];
  weak: WeakCard[];
  availableKinds: string[];
}) {
  const { t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [openFormats, setOpenFormats] = useState(false);
  const [draftKind, setDraftKind] = useState<ExamKind>(kind);
  const [draftFormats, setDraftFormats] = useState<string[]>(formats);
  const [failed, setFailed] = useState(false);

  const dirty = draftKind !== kind || !sameSet(draftFormats, formats);

  function toggleFormat(value: string) {
    setDraftFormats((current) =>
      current.includes(value)
        ? current.filter((item) => item !== value)
        : [...current, value],
    );
  }

  function save() {
    setFailed(false);
    startTransition(async () => {
      const result = await saveExamDetails({
        id: examId,
        kind: draftKind,
        formats: draftFormats,
      });
      if (result.status === "error") setFailed(true);
      else router.refresh();
    });
  }

  return (
    <div className="space-y-5">
      <section className="rounded-group border border-border bg-card p-5">
        <h2 className="text-[15px] font-semibold text-ink">{t("app.plan.sheet.programTitle")}</h2>
        <ul className="mt-3 divide-y divide-hairline">
          {courses.map((course) => (
            <li key={course.id} className="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
              <span aria-hidden className="text-[18px]">
                {course.emoji}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[14.5px] font-medium text-ink">
                  {course.title || t("app.course.untitled")}
                </span>
                <span className="numeral mt-0.5 block text-[12.5px] text-ink-tertiary">
                  {t("app.plan.sheet.courseLine", {
                    cards: course.cardCount,
                    percent: course.masteryPercent,
                  })}
                </span>
              </span>
              <span
                aria-hidden
                className="h-1.5 w-16 shrink-0 overflow-hidden rounded-pill bg-surface-sunken"
              >
                <span
                  className="block h-full rounded-pill bg-accent"
                  style={{ width: `${Math.max(2, course.masteryPercent)}%` }}
                />
              </span>
            </li>
          ))}
        </ul>
      </section>

      {weak.length > 0 ? (
        <section className="rounded-group border border-caution/40 bg-caution-soft p-5">
          <h2 className="text-[15px] font-semibold text-ink">{t("app.plan.sheet.weakTitle")}</h2>
          <p className="mt-1 text-[13px] text-ink-secondary">{t("app.plan.sheet.weakLead")}</p>
          <ul className="mt-4 space-y-2">
            {weak.map((card) => (
              <li
                key={card.id}
                className="flex items-start justify-between gap-3 rounded-button bg-surface px-4 py-3"
              >
                <span className="min-w-0">
                  <span className="line-clamp-2 text-[14px] text-ink">{card.front}</span>
                  <span className="numeral mt-1 block text-[12px] text-ink-tertiary">
                    {t("app.plan.sheet.weakLine", {
                      again: card.againCount,
                      reviews: card.reviews,
                    })}
                  </span>
                </span>
                {card.isStubborn ? (
                  <span className="shrink-0 rounded-pill bg-negative-soft px-2 py-0.5 text-[11.5px] font-semibold text-negative">
                    {t("app.plan.sheet.stubborn")}
                  </span>
                ) : null}
              </li>
            ))}
          </ul>
          <p className="mt-3 text-[12.5px] leading-relaxed text-ink-secondary">
            {t("app.plan.sheet.weakHint")}
          </p>
        </section>
      ) : null}

      <section className="overflow-hidden rounded-group border border-border bg-card">
        <Fold
          title={t("app.plan.sheet.formatsTitle")}
          detail={
            draftFormats.length === 0
              ? t("app.plan.sheet.formatsAll")
              : t("app.plan.sheet.formatsSome", { count: draftFormats.length })
          }
          open={openFormats}
          onToggle={() => setOpenFormats((open) => !open)}
        >
          <fieldset className="mt-1">
            <legend className="sr-only">{t("app.plan.sheet.formatsTitle")}</legend>
            <ul className="space-y-1.5">
              {FORMATS.filter((format) => availableKinds.includes(format.kind)).map((format) => (
                <li key={format.kind}>
                  <CheckRow
                    checked={draftFormats.includes(format.kind)}
                    title={t(format.labelKey)}
                    detail={t(format.effectKey)}
                    onToggle={() => toggleFormat(format.kind)}
                  />
                </li>
              ))}
            </ul>
          </fieldset>

          <div className="mt-4">
            <p className="eyebrow mb-2 text-ink-tertiary">{t("app.plan.sheet.kindTitle")}</p>
            <div className="flex flex-wrap gap-1.5">
              {EXAM_KINDS.map((option) => (
                <button
                  key={option}
                  type="button"
                  onClick={() => setDraftKind(option)}
                  aria-pressed={draftKind === option}
                  className={`pressable rounded-pill px-3 py-1.5 text-[13px] font-medium ${
                    draftKind === option
                      ? "bg-ink text-on-ink"
                      : "bg-surface-muted text-ink-secondary"
                  }`}
                >
                  {t(`app.plan.kind.${option}`)}
                </button>
              ))}
            </div>
          </div>
        </Fold>

      </section>

      {dirty ? (
        <div className="flex flex-wrap items-center gap-3">
          <Button onClick={save} disabled={pending}>
            {pending ? t("app.exams.wait") : t("app.plan.sheet.apply")}
          </Button>
          <span className="text-[12.5px] text-ink-tertiary">
            {t("app.plan.sheet.applyHint")}
          </span>
        </div>
      ) : null}

      {failed ? (
        <p className="text-[13px] text-negative" role="alert">
          {t("app.plan.verdict.failed")}
        </p>
      ) : null}

      <p className="text-[13px]">
        <Link href={"/app/plan" as never} className="underline-draw font-medium text-ink-secondary">
          {t("app.plan.sheet.back")}
        </Link>
      </p>
    </div>
  );
}

function Fold({
  title,
  detail,
  open,
  onToggle,
  children,
}: {
  title: string;
  detail: string;
  open: boolean;
  onToggle: () => void;
  children: React.ReactNode;
}) {
  return (
    <div>
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={open}
        className="hover-row flex w-full items-center justify-between gap-4 px-5 py-4 text-left"
      >
        <span className="min-w-0">
          <span className="block text-[15px] font-semibold text-ink">{title}</span>
          <span className="mt-0.5 block truncate text-[12.5px] text-ink-tertiary">{detail}</span>
        </span>
        <svg
          aria-hidden
          viewBox="0 0 20 20"
          className={`h-4 w-4 shrink-0 text-ink-tertiary transition-transform duration-menu ${
            open ? "rotate-180" : ""
          }`}
        >
          <path
            d="M5 8l5 5 5-5"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
          />
        </svg>
      </button>
      {open ? <div className="px-5 pb-5">{children}</div> : null}
    </div>
  );
}

function CheckRow({
  checked,
  title,
  detail,
  onToggle,
}: {
  checked: boolean;
  title: string;
  detail?: string;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={checked}
      onClick={onToggle}
      className={`hover-tile flex w-full items-start gap-3 rounded-button border px-4 py-3 text-left ${
        checked ? "border-accent/40 bg-accent-soft/40" : "border-border bg-surface"
      }`}
    >
      <span
        aria-hidden
        className={`mt-0.5 flex h-[18px] w-[18px] shrink-0 items-center justify-center rounded-[5px] border ${
          checked ? "border-accent bg-accent text-on-ink" : "border-stroke-strong bg-surface"
        }`}
      >
        {checked ? (
          <svg viewBox="0 0 16 16" className="h-3 w-3">
            <path
              d="M3.5 8.5l3 3 6-7"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        ) : null}
      </span>
      <span className="min-w-0">
        <span className="block text-[14.5px] font-medium text-ink">{title}</span>
        {detail ? (
          <span className="mt-0.5 block text-[12.5px] leading-snug text-ink-tertiary">
            {detail}
          </span>
        ) : null}
      </span>
    </button>
  );
}

function sameSet(left: string[], right: string[]): boolean {
  if (left.length !== right.length) return false;
  const set = new Set(right);
  return left.every((value) => set.has(value));
}
