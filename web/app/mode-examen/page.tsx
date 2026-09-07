import { BASE_PASSES, CLOSING_DAYS, EXAM_INTENSITIES } from "@micabo/core";

import { ExamMode } from "@/components/landing/ExamMode";
import { ArticleMarkup, ArticleP } from "@/components/pages/ArticleMarkup";
import { ArticleNote, ArticleSection, ArticleShell } from "@/components/pages/ArticleShell";
import { articleMetadata } from "@/lib/articles";
import { getTranslator } from "@/lib/i18n/server";
import { EXAM_PAGE } from "@/lib/site-pages";

export async function generateMetadata() {
  return articleMetadata(EXAM_PAGE);
}

/**
 * **La page du mode examen.**
 *
 * L'histogramme est celui de la vitrine, calculé par `planExam`. Les phrases
 * viennent des catalogues.
 */
export default async function ExamModePage() {
  const { t } = await getTranslator();
  const intensityLabel: Record<(typeof EXAM_INTENSITIES)[number], string> = {
    light: t("articles.exam.intensityLight"),
    standard: t("articles.exam.intensityStandard"),
    intense: t("articles.exam.intensityIntense"),
  };

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
    >
      <ArticleSection id="le-probleme" title={t("articles.exam.trapTitle")}>
        <ArticleP k="articles.exam.trap1" />
        <ArticleP k="articles.exam.trap2" />
      </ArticleSection>

      <ArticleSection id="le-plafond" title={t("articles.exam.capTitle")}>
        <ArticleP k="articles.exam.cap1" />
        <ArticleP k="articles.exam.cap2" />
      </ArticleSection>

      <ArticleSection id="ce-que-ca-donne" title={t("articles.exam.planTitle")} wide>
        <ArticleP k="articles.exam.plan1" className="max-w-reading" />
        <div className="mt-9">
          <ExamMode />
        </div>
        <ArticleP
          k="articles.exam.plan2"
          vars={{ days: CLOSING_DAYS }}
          className="mt-6 max-w-reading"
        />
      </ArticleSection>

      <ArticleSection id="intensite" title={t("articles.exam.intensityTitle")}>
        <ArticleP k="articles.exam.intensityLead" />

        <dl className="not-prose mt-7 grid gap-3 sm:grid-cols-3">
          {EXAM_INTENSITIES.map((intensity) => (
            <div
              key={intensity}
              className="rounded-group border border-stroke bg-surface px-4 py-4"
            >
              <dt className="text-[13px] font-medium text-ink-secondary">
                {intensityLabel[intensity]}
              </dt>
              <dd className="mt-1">
                <span className="numeral text-[22px] font-bold text-ink">
                  {BASE_PASSES[intensity]}
                </span>
                <span className="ms-1.5 text-[13px] text-ink-tertiary">
                  {t("articles.exam.intensityPasses")}
                </span>
              </dd>
            </div>
          ))}
        </dl>

        <ArticleP k="articles.exam.intensityScale" className="mt-7" />
      </ArticleSection>

      <ArticleSection id="plusieurs-examens" title={t("articles.exam.severalTitle")}>
        <ArticleP k="articles.exam.several1" />
        <ArticleNote>
          <ArticleMarkup text={t("articles.exam.severalNote")} />
        </ArticleNote>
      </ArticleSection>

      <ArticleSection id="limites" title={t("articles.exam.limitsTitle")}>
        <ArticleP k="articles.exam.limits1" />
        <ArticleP
          k="articles.exam.limits2"
          links={{
            method: t("articles.exam.methodLink"),
            anki: t("articles.exam.ankiLink"),
          }}
        />
      </ArticleSection>
    </ArticleShell>
  );
}
