import { DEFAULT_CONFIG, LESSON_RATINGS, newCardSnapshot } from "@micabo/core";

import { RetentionChart } from "@/components/landing/RetentionChart";
import { MikaWritesStory } from "@/components/onboarding/stories/MikaWritesStory";
import { QuizStory } from "@/components/onboarding/stories/QuizStory";
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
 * **La méthode** : le rappel actif, l'espacement, et comment une leçon les applique sans
 * qu'on y pense. Les chiffres sont ceux du planificateur, pas écrits à la main.
 */
export default async function MethodPage() {
  const { t, locale } = await getTranslator();
  const steps = DEFAULT_CONFIG.learningStepsMinutes;
  const stepsLabel = steps.map((minutes) => t("articles.method.stepMinutes", { n: minutes })).join(t("articles.method.stepJoin"));
  const ease = new Intl.NumberFormat(locale, { minimumFractionDigits: 1, maximumFractionDigits: 1 }).format(DEFAULT_CONFIG.startingEase);
  const labels = previewLabelsLocalized(t, newCardSnapshot(), { now: new Date() });

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

      <ArticleSection id="espacement" title={t("articles.method.spacingTitle")}>
        <ArticleP k="articles.method.spacing1" />
        <ArticleP k="articles.method.spacing2" />
      </ArticleSection>

      <ArticleSection id="la-lecon" title={t("articles.method.lessonTitle")} wide>
        <ArticleP k="articles.method.lesson1" className="mx-auto max-w-reading" />
        <ArticleFigure caption={<ArticleMarkup text={t("articles.method.lessonFigure")} />}>
          <div className="flex justify-center py-6">
            <MikaWritesStory />
          </div>
        </ArticleFigure>
        <ArticleP k="articles.method.lesson2" className="mx-auto mt-6 max-w-reading" />
      </ArticleSection>

      <ArticleSection id="planificateur" title={t("articles.method.plannerTitle")} wide>
        <ArticleP k="articles.method.planner1" vars={{ steps: stepsLabel, ease }} className="mx-auto max-w-reading" />
        <ArticleP k="articles.method.planner2" className="mx-auto max-w-reading" />
        <div className="paper mx-auto mt-8 max-w-[560px] rounded-sheet bg-surface p-4 sm:p-6">
          <p className="paper mx-auto max-w-[420px] rounded-[14px] bg-surface-muted px-5 py-4 text-center text-[15px] font-semibold text-ink">{t("demo.card1Front")}</p>
          <div className="mx-auto mt-4 grid max-w-[420px] grid-cols-3 gap-2">
            {LESSON_RATINGS.map((rating) => (
              <span key={rating} className="rounded-[12px] bg-surface-muted px-2 py-2.5 text-center">
                <span className="block text-[13px] font-extrabold text-ink">{reviewRatingLabel(t, rating)}</span>
                <span className="numeral mt-0.5 block text-[12px] text-ink-secondary">{labels[rating]}</span>
              </span>
            ))}
          </div>
          <p className="mt-4 text-center text-[13px] text-ink-tertiary">{t("articles.method.buttonsCaption")}</p>
        </div>
        <ArticleP k="articles.method.planner3" className="mx-auto mt-6 max-w-reading" />
      </ArticleSection>

      <ArticleSection id="cinq-formes" title={t("articles.method.formatsTitle")} wide>
        <ArticleP k="articles.method.formats1" className="mx-auto max-w-reading" />
        <ArticleFigure caption={<ArticleMarkup text={t("articles.method.formatsFigure")} />}>
          <div className="flex justify-center py-6">
            <QuizStory />
          </div>
        </ArticleFigure>
      </ArticleSection>

      <ArticleSection id="limites" title={t("articles.method.limitsTitle")}>
        <ArticleP k="articles.method.limits1" />
        <ArticleP k="articles.method.limits2" links={{ exam: t("articles.method.examLink") }} />
        <ArticleNote>
          <ArticleMarkup text={t("articles.method.note")} />
        </ArticleNote>
      </ArticleSection>
    </ArticleShell>
  );
}
