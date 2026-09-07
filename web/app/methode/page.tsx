import {
  CARDS_PER_MINUTE,
  DEFAULT_CONFIG,
  DEFAULT_DAILY_MINUTES,
  REPETITIONS_PER_CARD,
  REVIEW_RATINGS,
  newCardSnapshot,
  newCardsPerDay,
} from "@micabo/core";

import { RetentionChart } from "@/components/landing/RetentionChart";
import { ArticleMarkup, ArticleP } from "@/components/pages/ArticleMarkup";
import { ArticleNote, ArticleSection, ArticleShell } from "@/components/pages/ArticleShell";
import { articleMetadata } from "@/lib/articles";
import { previewLabelsLocalized, reviewRatingLabel } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";
import { EXAM_PAGE, METHOD_PAGE } from "@/lib/site-pages";

export async function generateMetadata() {
  return articleMetadata(METHOD_PAGE);
}

/**
 * **La page de la méthode.**
 *
 * Tous les nombres affichés sont lus dans `@micabo/core` au moment du rendu —
 * les mêmes valeurs que l'iPhone. Les phrases, elles, viennent des catalogues.
 */
export default async function MethodPage() {
  const { t, locale } = await getTranslator();
  const steps = DEFAULT_CONFIG.learningStepsMinutes;
  const perDay = newCardsPerDay(DEFAULT_DAILY_MINUTES);
  const seenPerDay = Math.round(DEFAULT_DAILY_MINUTES * CARDS_PER_MINUTE);
  const stepsLabel = steps
    .map((minutes) => t("articles.method.stepMinutes", { n: minutes }))
    .join(t("articles.method.stepJoin"));
  const ease = new Intl.NumberFormat(locale, {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  }).format(DEFAULT_CONFIG.startingEase);

  return (
    <ArticleShell
      page={METHOD_PAGE}
      eyebrow={t("site.method")}
      title={t("articles.method.h1")}
      lead={
        <>
          <ArticleP k="articles.method.lead1" />
          <ArticleP k="articles.method.lead2" />
        </>
      }
    >
      <ArticleSection id="rappel-actif" title={t("articles.method.activeTitle")}>
        <ArticleP k="articles.method.active1" />
        <ArticleP k="articles.method.active2" />
      </ArticleSection>

      <ArticleSection id="courbe-oubli" title={t("articles.method.spacingTitle")} wide>
        <ArticleP k="articles.method.spacing1" className="max-w-reading" />
        <div className="mt-9">
          <RetentionChart />
        </div>
        <ArticleP k="articles.method.spacing2" className="mt-6 max-w-reading" />
      </ArticleSection>

      <ArticleSection id="planificateur" title={t("articles.method.plannerTitle")}>
        <ArticleP k="articles.method.planner1" vars={{ steps: stepsLabel, ease }} />
        <ArticleP k="articles.method.planner2" />
        <NewCardIntervals />
        <ArticleP k="articles.method.planner3" />
      </ArticleSection>

      <ArticleSection id="rythme" title={t("articles.method.paceTitle")}>
        <ArticleP
          k="articles.method.pace1"
          vars={{ minutes: DEFAULT_DAILY_MINUTES, seen: seenPerDay, perDay }}
        />
        <ArticleP k="articles.method.pace2" vars={{ reps: REPETITIONS_PER_CARD }} />
        <ArticleNote>
          <ArticleMarkup text={t("articles.method.paceNote")} />
        </ArticleNote>
      </ArticleSection>

      <ArticleSection id="fiche-avant-cartes" title={t("articles.method.sheetTitle")}>
        <ArticleP k="articles.method.sheet1" />
        <ArticleP k="articles.method.sheet2" />
        <ArticleP k="articles.method.sheet3" />
      </ArticleSection>

      <ArticleSection id="limites" title={t("articles.method.limitsTitle")}>
        <ArticleP k="articles.method.limits1" />
        <ArticleP
          k="articles.method.limits2"
          links={{ exam: t("articles.method.examLink") }}
        />
      </ArticleSection>
    </ArticleShell>
  );
}

async function NewCardIntervals() {
  const { t } = await getTranslator();
  const labels = previewLabelsLocalized(t, newCardSnapshot());

  return (
    <dl className="not-prose mt-7 grid grid-cols-2 gap-3 sm:grid-cols-4">
      {REVIEW_RATINGS.map((rating) => (
        <div
          key={rating}
          className="rounded-group border border-stroke bg-surface px-4 py-3.5 text-center"
        >
          <dt className="text-[13px] font-medium text-ink-secondary">
            {reviewRatingLabel(t, rating)}
          </dt>
          <dd className="numeral mt-1 text-[19px] font-bold text-ink">{labels[rating]}</dd>
        </div>
      ))}
    </dl>
  );
}
