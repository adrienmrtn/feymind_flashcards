import { EXAM_DURATIONS, examQuestionCount } from "@micabo/core";

import { ExamDateStory } from "@/components/onboarding/stories/ExamDateStory";
import { MockExamStory } from "@/components/onboarding/stories/MockExamStory";
import { ArticleMarkup, ArticleP } from "@/components/pages/ArticleMarkup";
import { ArticleFigure, ArticleNote, ArticleSection, ArticleShell } from "@/components/pages/ArticleShell";
import { articleMetadata } from "@/lib/articles";
import { getTranslator } from "@/lib/i18n/server";
import { EXAM_PAGE } from "@/lib/site-pages";

export async function generateMetadata() {
  return articleMetadata(EXAM_PAGE);
}

/**
 * **Le mode examen** : une date, les jours qui restent, et l'examen blanc chronométré, noté
 * dans le barème du pays. Les durées et le nombre de questions viennent du noyau.
 */
export default async function ExamModePage() {
  const { t } = await getTranslator();
  const durations = EXAM_DURATIONS.map((minutes) => t("articles.exam.duration", { minutes, count: examQuestionCount(minutes) })).join(t("articles.exam.durationJoin"));

  return (
    <ArticleShell
      page={EXAM_PAGE}
      eyebrow={t("site.exam")}
      title={t("articles.exam.h1")}
      lead={
        <>
          <ArticleP k="articles.exam.lead1" />
          <ArticleP k="articles.exam.lead2" />
        </>
      }
      figure={
        <div className="flex justify-center">
          <ExamDateStory />
        </div>
      }
    >
      <ArticleSection id="la-date" title={t("articles.exam.dateTitle")}>
        <ArticleP k="articles.exam.date1" />
        <ArticleP k="articles.exam.date2" />
      </ArticleSection>

      <ArticleSection id="examen-blanc" title={t("articles.exam.mockTitle")} wide>
        <ArticleP k="articles.exam.mock1" vars={{ durations }} className="mx-auto max-w-reading" />
        <ArticleFigure caption={<ArticleMarkup text={t("articles.exam.mockFigure")} />}>
          <div className="flex justify-center py-6">
            <MockExamStory />
          </div>
        </ArticleFigure>
        <ArticleP k="articles.exam.mock2" className="mx-auto mt-6 max-w-reading" />
      </ArticleSection>

      <ArticleSection id="la-note" title={t("articles.exam.gradeTitle")}>
        <ArticleP k="articles.exam.grade1" />
        <ArticleP k="articles.exam.grade2" />
      </ArticleSection>

      <ArticleSection id="les-erreurs" title={t("articles.exam.cardsTitle")}>
        <ArticleP k="articles.exam.cards1" />
        <ArticleNote>
          <ArticleMarkup text={t("articles.exam.cardsNote")} />
        </ArticleNote>
      </ArticleSection>

      <ArticleSection id="limites" title={t("articles.exam.limitsTitle")}>
        <ArticleP k="articles.exam.limits1" />
        <ArticleP k="articles.exam.limits2" links={{ method: t("articles.exam.methodLink"), anki: t("articles.exam.ankiLink") }} />
      </ArticleSection>
    </ArticleShell>
  );
}
