"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";

import { EXAM_KINDS, wantsMock, type ExamKind, type WeakCard } from "@micabo/core";

import { StartMock } from "@/components/app/plan/StartMock";
import { Button } from "@/components/ui/button";
import { saveExamDetails } from "@/lib/actions/exams";
import { useI18n } from "@/lib/i18n/client";

/**
 * La fiche d'une épreuve : **tout ce qui n'a pas sa place dans les trois questions.**
 *
 * Déclarer une épreuve reste un geste court - le jour, les matières, la note visée - parce que
 * c'est ce qu'on fait en marchant entre deux amphis. Ce qui demande de la réflexion vit ici :
 * le programme, ce qui résiste, les examens blancs, et le type d'épreuve.
 *
 * Le type change ce que le plan pose, donc l'enregistrer refait le plan. Un réglage qui ne
 * changerait rien serait une décoration, et le produit en a déjà assez.
 */

export interface PastMock {
  id: string;
  score: number;
  questionCount: number;
  finishedAt: string;
}

export interface SheetCourse {
  id: string;
  title: string;
  emoji: string;
  cardCount: number;
  masteryPercent: number;
}

export function ExamSheet({
  examId,
  kind,
  courses,
  weak,
  mocks,
  canRunMock,
}: {
  examId: string;
  kind: ExamKind;
  courses: SheetCourse[];
  weak: WeakCard[];
  mocks: PastMock[];
  canRunMock: boolean;
}) {
  const { t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [draftKind, setDraftKind] = useState<ExamKind>(kind);
  const [failed, setFailed] = useState(false);

  const dirty = draftKind !== kind;

  function save() {
    setFailed(false);
    startTransition(async () => {
      // Les formats partent vides, ce qui veut dire « tous » : c'est déjà ce que la base
      // lit, et ce que le plan applique pour les épreuves déclarées avant ce changement.
      const result = await saveExamDetails({ id: examId, kind: draftKind, formats: [] });
      if (result.status === "error") setFailed(true);
      else router.refresh();
    });
  }

  return (
    <div className="space-y-5">
      <section className="panel p-5">
        <h2 className="section-title">{t("app.plan.sheet.programTitle")}</h2>
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
                className="h-1.5 w-20 shrink-0 overflow-hidden rounded-full"
                style={{ backgroundColor: "var(--color-surface-sunken)" }}
              >
                <span
                  className="block h-full rounded-full"
                  style={{ width: `${Math.max(2, course.masteryPercent)}%`, backgroundColor: "var(--chart-work)" }}
                />
              </span>
            </li>
          ))}
        </ul>
      </section>

      <MockPanel
        examId={examId}
        kind={draftKind}
        mocks={mocks}
        canRun={canRunMock}
      />

      {weak.length > 0 ? (
        <section className="panel p-5">
          <h2 className="section-title">{t("app.plan.sheet.weakTitle")}</h2>
          <p className="section-lead">{t("app.plan.sheet.weakLead")}</p>
          <ul className="mt-3 divide-y divide-hairline">
            {weak.map((card) => (
              <li key={card.id} className="flex items-start justify-between gap-3 py-2.5">
                <span className="min-w-0">
                  <span className="line-clamp-2 text-[13.5px] text-ink">{card.front}</span>
                  <span className="numeral mt-0.5 block text-[12px] text-ink-tertiary">
                    {t("app.plan.sheet.weakLine", {
                      again: card.againCount,
                      reviews: card.reviews,
                    })}
                  </span>
                </span>
                {card.isStubborn ? (
                  <span className="shrink-0 rounded-full bg-negative-soft px-2 py-0.5 text-[11.5px] font-semibold text-negative">
                    {t("app.plan.sheet.stubborn")}
                  </span>
                ) : null}
              </li>
            ))}
          </ul>
          <p className="mt-3 text-[12.5px] leading-relaxed text-ink-tertiary">
            {t("app.plan.sheet.weakHint")}
          </p>
        </section>
      ) : null}

      {/*
        **Les formats ne se choisissent plus.** Trois cases - questions-réponses, QCM, textes à
        trous - qu'il fallait déplier pour découvrir qu'elles étaient toutes cochées, et qui le
        restaient chez tout le monde. Une épreuve se prépare avec ce qu'on a écrit dessus, pas
        avec une moitié de ses cartes, et une case que personne ne décoche n'est pas un
        réglage : c'est une question de plus posée à quelqu'un qui voulait réviser.

        Reste le type d'épreuve, qui décide des examens blancs et de la façon dont le plan
        monte. Il n'a plus besoin d'un pli pour lui tout seul.
      */}
      <section className="panel p-5">
        <h2 className="section-title">{t("app.plan.sheet.kindTitle")}</h2>
        <div className="mt-3 flex flex-wrap gap-1.5">
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

/**
 * L'examen blanc, sur la fiche.
 *
 * Un blanc se lance d'ici quand l'étudiant le veut, sans attendre que le plan le pose : à
 * J-15 on a parfois besoin de savoir où l'on en est. Les scores passés se lisent en dessous,
 * dans l'ordre, parce que la progression entre deux blancs dit plus que le dernier score.
 */
function MockPanel({
  examId,
  kind,
  mocks,
  canRun,
}: {
  examId: string;
  kind: ExamKind;
  mocks: PastMock[];
  canRun: boolean;
}) {
  const { t } = useI18n();

  if (!wantsMock(kind)) return null;

  return (
    <section className="panel p-5">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <h2 className="section-title">{t("app.mock.panelTitle")}</h2>
        {canRun ? <StartMock examId={examId} /> : null}
      </div>

      <p className="mt-1 text-[13px] text-ink-secondary">{t("app.mock.panelLead")}</p>

      {mocks.length === 0 ? (
        <p className="mt-3 text-[13px] text-ink-tertiary">
          {canRun ? t("app.mock.none") : t("app.mock.tooFew")}
        </p>
      ) : null}

    </section>
  );
}

