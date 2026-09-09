"use client";

import Link from "next/link";

import {
  MOCK_GAP,
  PASS_MARK,
  isClosedQuestion,
  type MockAnswer,
  type MockDebrief,
  type MockGrade,
  type MockQuestion,
} from "@micabo/core";

import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";

/**
 * Le débriefing : **ce que la copie dit, pas seulement ce qu'elle vaut.**
 *
 * Un score seul ne sert à rien. Ce qui sert est le motif - trois erreurs sur le même chapitre,
 * une notion comprise mais mal nommée - et c'est ce que le modèle est chargé de lire. La liste
 * question par question reste en dessous, dépliée : l'étudiant vient de passer un quart
 * d'heure dessus, il a le droit de voir sur quoi il s'est trompé.
 *
 * L'ordre compte : la phrase d'abord, le score ensuite, le détail à la fin. Un grand chiffre
 * en tête d'écran est ce qu'on retient, et « 54 % » n'apprend rien à personne.
 */
export function MockReport({
  examId,
  score,
  questions,
  answers,
  grades,
  debrief,
}: {
  examId: string | null;
  score: number;
  questions: MockQuestion[];
  answers: MockAnswer[];
  grades: MockGrade[];
  debrief: MockDebrief | null;
}) {
  const { t } = useI18n();
  const byId = new Map(answers.map((answer) => [answer.id, answer]));
  const gradeOf = new Map(grades.map((grade) => [grade.id, grade]));
  const tone = score >= 75 ? "text-positive" : score >= 50 ? "text-caution" : "text-negative";
  const missed = questions.filter(
    (question) => (gradeOf.get(question.id)?.score ?? 0) < PASS_MARK,
  );

  return (
    <div className="mx-auto w-full max-w-[720px] pb-16">
      <p className="eyebrow text-ink-tertiary">{t("app.mock.doneEyebrow")}</p>

      {debrief ? (
        <p className="mt-3 max-w-[46ch] text-[21px] font-semibold leading-snug text-ink">
          {debrief.headline}
        </p>
      ) : null}

      <p className="mt-4 flex items-baseline gap-2">
        <span className={`numeral text-[40px] font-semibold leading-none ${tone}`}>
          {score}
          <span className="text-[22px]"> %</span>
        </span>
        <span className="text-[13px] text-ink-tertiary">
          {t("app.mock.outOf", {
            correct: questions.length - missed.length,
            total: questions.length,
          })}
        </span>
      </p>

      {debrief ? (
        <div className="mt-6 grid gap-3 md:grid-cols-2">
          {debrief.strengths.length > 0 ? (
            <Panel title={t("app.mock.strengths")} tone="solid" items={debrief.strengths} />
          ) : null}
          {debrief.gaps.length > 0 ? (
            <Panel title={t("app.mock.gaps")} tone="fragile" items={debrief.gaps} />
          ) : null}
        </div>
      ) : null}

      {debrief?.advice ? (
        <section className="panel mt-3 p-5">
          <h2 className="section-title">{t("app.mock.advice")}</h2>
          <p className="mt-1.5 text-[14px] leading-relaxed text-ink-secondary">{debrief.advice}</p>
        </section>
      ) : null}

      <section className="mt-8">
        <h2 className="section-title">{t("app.mock.detail")}</h2>
        <ol className="mt-3 space-y-2">
          {questions.map((question, index) => (
            <li key={question.id}>
              <Correction
                question={question}
                position={index + 1}
                answer={byId.get(question.id)}
                grade={gradeOf.get(question.id)}
              />
            </li>
          ))}
        </ol>
      </section>

      <div className="mt-8 flex flex-wrap gap-2">
        {examId ? (
          <Button render={<Link href={`/app/plan/${examId}` as never} />}>
            {t("app.mock.seeExam")}
          </Button>
        ) : null}
        <Button variant="outline" render={<Link href={"/app/plan" as never} />}>
          {t("app.plan.sheet.back")}
        </Button>
      </div>
    </div>
  );
}

function Panel({
  title,
  tone,
  items,
}: {
  title: string;
  tone: "solid" | "fragile";
  items: string[];
}) {
  return (
    <section className="panel p-5">
      <div className="flex items-center gap-2">
        <span
          aria-hidden
          className="size-2 rounded-full"
          style={{
            backgroundColor: tone === "solid" ? "var(--chart-solid)" : "var(--chart-fragile)",
          }}
        />
        <h2 className="section-title">{title}</h2>
      </div>
      <ul className="mt-2 space-y-1.5 text-[13.5px] leading-relaxed text-ink-secondary">
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </section>
  );
}

function Correction({
  question,
  position,
  answer,
  grade,
}: {
  question: MockQuestion;
  position: number;
  answer: MockAnswer | undefined;
  grade: MockGrade | undefined;
}) {
  const { t } = useI18n();
  const score = grade?.score ?? 0;
  const good = score >= PASS_MARK;
  const partial = score > 0 && score < PASS_MARK;

  return (
    <section className={`panel p-5 ${good ? "" : "border-negative/30"}`}>
      <div className="flex items-baseline gap-3">
        <span className="numeral w-5 shrink-0 text-[12.5px] font-semibold text-ink-tertiary">
          {position}
        </span>
        <p className="min-w-0 flex-1 text-[14.5px] leading-snug text-ink">
          {question.kind === "gap" ? question.prompt.split(MOCK_GAP).join(" ____ ") : question.prompt}
        </p>
        <span
          className={`numeral shrink-0 rounded-full px-2 py-0.5 text-[11.5px] font-semibold ${
            good
              ? "bg-positive-soft text-positive"
              : partial
                ? "bg-caution-soft text-caution"
                : "bg-negative-soft text-negative"
          }`}
        >
          {question.kind === "feynman" ? `${score} %` : good ? t("app.mock.right") : t("app.mock.wrong")}
        </span>
      </div>

      <dl className="mt-3 space-y-1.5 pl-8 text-[13.5px]">
        <div className="flex gap-2">
          <dt className="shrink-0 text-ink-tertiary">{t("app.mock.yourAnswer")}</dt>
          <dd className={`min-w-0 ${good ? "text-ink" : "text-negative"}`}>{said(question, answer, t)}</dd>
        </div>
        {!good && isClosedQuestion(question) ? (
          <div className="flex gap-2">
            <dt className="shrink-0 text-ink-tertiary">{t("app.mock.rightAnswer")}</dt>
            <dd className="min-w-0 text-ink">{expected(question, t)}</dd>
          </div>
        ) : null}
      </dl>

      {grade?.comment ? (
        <p className="mt-3 rounded-button bg-surface-muted px-4 py-2.5 text-[13px] leading-relaxed text-ink-secondary">
          {grade.comment}
        </p>
      ) : null}
    </section>
  );
}

function said(
  question: MockQuestion,
  answer: MockAnswer | undefined,
  t: (key: string) => string,
): string {
  if (question.kind === "choice") {
    const index = answer?.choiceIndex;
    return index != null ? (question.choices[index] ?? t("app.mock.blank")) : t("app.mock.blank");
  }
  if (question.kind === "truefalse") {
    if (answer?.truth == null) return t("app.mock.blank");
    return answer.truth ? t("app.mock.true") : t("app.mock.false");
  }
  const text = answer?.text?.trim() ?? "";
  return text.length > 0 ? text : t("app.mock.blank");
}

function expected(question: MockQuestion, t: (key: string) => string): string {
  if (question.kind === "choice") return question.choices[question.answerIndex] ?? "";
  if (question.kind === "truefalse") {
    return question.answer ? t("app.mock.true") : t("app.mock.false");
  }
  if (question.kind === "gap") return question.answer;
  return "";
}
