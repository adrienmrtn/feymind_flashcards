import {
  CARDS_PER_MINUTE,
  DEFAULT_CONFIG,
  REPETITIONS_PER_CARD,
  REVIEW_RATINGS,
  newCardSnapshot,
} from "@micabo/core";

import { RetentionChart } from "@/components/landing/RetentionChart";
import { SheetStory } from "@/components/landing/SheetStory";
import { AiStory } from "@/components/onboarding/stories/AiStory";
import { ArticleMarkup, ArticleP } from "@/components/pages/ArticleMarkup";
import { ArticleFigure, ArticleNote, ArticleSection, ArticleShell } from "@/components/pages/ArticleShell";
import { articleMetadata } from "@/lib/articles";
import { previewLabelsLocalized, reviewRatingLabel } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";
import { METHOD_PAGE } from "@/lib/site-pages";

export async function generateMetadata() {
  return articleMetadata(METHOD_PAGE);
}

/**
 * **La page de la méthode.**
 *
 * Tous les nombres affichés sont lus dans `@micabo/core` au moment du rendu :
 * les mêmes valeurs que l'iPhone. Les phrases, elles, viennent des catalogues.
 * Les vignettes sont celles du parcours d'inscription : la fiche qui devient des cartes,
 * les quatre façons d'être interrogé.
 */
export default async function MethodPage() {
  const { t, locale } = await getTranslator();
  const steps = DEFAULT_CONFIG.learningStepsMinutes;
  const seenPerHour = Math.round(60 * CARDS_PER_MINUTE);
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
      figure={<RetentionChart />}
    >
      <ArticleSection id="rappel-actif" title={t("articles.method.activeTitle")}>
        <ArticleP k="articles.method.active1" />
        <ArticleP k="articles.method.active2" />
      </ArticleSection>

      <ArticleSection id="courbe-oubli" title={t("articles.method.spacingTitle")}>
        <ArticleP k="articles.method.spacing1" />
        <ArticleP k="articles.method.spacing2" />
      </ArticleSection>

      <ArticleSection id="planificateur" title={t("articles.method.plannerTitle")} wide>
        <ArticleP
          k="articles.method.planner1"
          vars={{ steps: stepsLabel, ease }}
          className="mx-auto max-w-reading"
        />
        <ArticleP k="articles.method.planner2" className="mx-auto max-w-reading" />
        <RatingButtons />
        <ArticleP k="articles.method.planner3" className="mx-auto mt-6 max-w-reading" />
      </ArticleSection>

      <ArticleSection id="rythme" title={t("articles.method.paceTitle")}>
        <ArticleP k="articles.method.pace1" vars={{ seen: seenPerHour }} />
        <ArticleP k="articles.method.pace2" vars={{ reps: REPETITIONS_PER_CARD }} />
        <ArticleNote>
          <ArticleMarkup text={t("articles.method.paceNote")} />
        </ArticleNote>
      </ArticleSection>

      <ArticleSection id="fiche" title={t("articles.method.sheetTitle")} wide>
        <ArticleP k="articles.method.sheet1" className="mx-auto max-w-reading" />
        <ArticleFigure caption={<ArticleMarkup text={t("articles.method.sheetFigure")} />}>
          <SheetStory />
        </ArticleFigure>
        <ArticleP k="articles.method.sheet2" className="mx-auto mt-6 max-w-reading" />
        <ArticleP k="articles.method.sheet3" className="mx-auto max-w-reading" />
      </ArticleSection>

      <ArticleSection id="formats" title={t("articles.method.formatsTitle")} wide>
        <ArticleP k="articles.method.formats1" className="mx-auto max-w-reading" />
        <ArticleFigure caption={<ArticleMarkup text={t("articles.method.formatsFigure")} />}>
          <AiStory />
        </ArticleFigure>
      </ArticleSection>

      <ArticleSection id="limites" title={t("articles.method.limitsTitle")}>
        <ArticleP k="articles.method.limits1" />
        <ArticleP k="articles.method.limits2" links={{ exam: t("articles.method.examLink") }} />
      </ArticleSection>
    </ArticleShell>
  );
}

/**
 * Les quatre boutons d'une carte neuve, avec l'intervalle que chacun annonce. Les
 * étiquettes sont calculées par le planificateur, pas écrites à la main : si un réglage
 * change dans `@micabo/core`, la page change avec.
 */
async function RatingButtons() {
  const { t } = await getTranslator();
  const labels = previewLabelsLocalized(t, newCardSnapshot(), {
    now: new Date(2026, 0, 1, 9, 0),
  });
  const tone = (rating: number) =>
    rating === 1
      ? "bg-negative-soft text-negative"
      : rating === 2
        ? "bg-caution-soft text-caution"
        : rating === 3
          ? "bg-accent-soft text-accent"
          : "bg-positive-soft text-positive";

  return (
    <div className="paper mx-auto mt-8 max-w-[860px] rounded-sheet bg-surface p-4 sm:p-6">
      <div className="rounded-[22px] bg-surface-muted p-5 sm:p-8">
        <p className="paper mx-auto max-w-[420px] rounded-[14px] bg-surface px-5 py-4 text-center text-[15px] font-medium text-ink">
          {t("demo.card1Front")}
        </p>
        <div className="mx-auto mt-4 grid max-w-[520px] grid-cols-4 gap-2">
          {REVIEW_RATINGS.map((rating) => (
            <div
              key={rating}
              className={`rounded-[12px] px-2 py-3 text-center shadow-[inset_0_0_0_1px_color-mix(in_srgb,currentColor_16%,transparent)] ${tone(rating)}`}
            >
              <span className="block text-[13px] font-semibold">{reviewRatingLabel(t, rating)}</span>
              <span className="numeral mt-0.5 block text-[11.5px] opacity-80">{labels[rating]}</span>
            </div>
          ))}
        </div>
        <p className="mt-4 text-center text-[12.5px] text-ink-tertiary">{t("articles.method.buttonsCaption")}</p>
      </div>
    </div>
  );
}
