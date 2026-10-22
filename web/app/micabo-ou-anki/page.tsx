import { SupportsStory } from "@/components/onboarding/stories/SupportsStory";
import { ArticleMarkup, ArticleP } from "@/components/pages/ArticleMarkup";
import { ArticleFigure, ArticleNote, ArticleSection, ArticleShell } from "@/components/pages/ArticleShell";
import { articleMetadata } from "@/lib/articles";
import { getTranslator } from "@/lib/i18n/server";
import { ANKI_PAGE } from "@/lib/site-pages";

export async function generateMetadata() {
  return articleMetadata(ANKI_PAGE);
}

const ROWS = ["Algo", "Write", "Lesson", "Date", "Questions", "Platforms", "Decks", "Start"] as const;

/**
 * **Micabo ou Anki** : la comparaison, ligne par ligne, y compris là où Anki gagne. La
 * différence n'est pas dans la planification des flashcards, c'est le même SM-2 : elle est
 * avant, dans la leçon qu'on n'a pas à écrire, et après, dans la date d'examen.
 */
export default async function AnkiPage() {
  const { t } = await getTranslator();
  const rows = ROWS.map((row) => ({
    criterion: t(`articles.anki.row${row}`),
    micabo: t(`articles.anki.row${row}Micabo`),
    anki: t(`articles.anki.row${row}Anki`),
  }));

  return (
    <ArticleShell
      page={ANKI_PAGE}
      eyebrow={t("articles.anki.eyebrow")}
      title={t("articles.anki.h1")}
      lead={
        <>
          <ArticleP k="articles.anki.lead1" />
          <ArticleP k="articles.anki.lead2" />
        </>
      }
    >
      <ArticleSection id="tableau" title={t("articles.anki.tableTitle")} wide>
        <ArticleP k="articles.anki.tableLead" className="mx-auto max-w-reading" />
        <div className="paper mx-auto mt-8 max-w-[900px] overflow-x-auto rounded-sheet bg-surface">
          <table className="w-full border-collapse text-left text-[14.5px]">
            <caption className="sr-only">{t("articles.anki.tableCaption")}</caption>
            <thead>
              <tr className="border-b border-hairline">
                <th scope="col" className="w-[22%] px-5 py-3.5 text-[12.5px] font-extrabold uppercase tracking-caps text-ink-secondary">
                  {t("articles.anki.colCriterion")}
                </th>
                <th scope="col" className="px-5 py-3.5 text-[12.5px] font-extrabold uppercase tracking-caps text-accent">
                  Micabo
                </th>
                <th scope="col" className="px-5 py-3.5 text-[12.5px] font-extrabold uppercase tracking-caps text-ink-secondary">
                  Anki
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.criterion} className="border-b border-hairline last:border-b-0">
                  <th scope="row" className="px-5 py-4 align-top text-[14px] font-bold text-ink">
                    {row.criterion}
                  </th>
                  <td className="px-5 py-4 align-top font-semibold leading-relaxed text-ink">{row.micabo}</td>
                  <td className="px-5 py-4 align-top leading-relaxed text-ink-secondary">{row.anki}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </ArticleSection>

      <ArticleSection id="le-vrai-cout" title={t("articles.anki.costTitle")} wide>
        <ArticleP k="articles.anki.cost1" className="mx-auto max-w-reading" />
        <ArticleFigure caption={<ArticleMarkup text={t("articles.anki.costFigure")} />}>
          <div className="flex justify-center py-6">
            <SupportsStory />
          </div>
        </ArticleFigure>
        <ArticleP k="articles.anki.cost2" className="mx-auto mt-6 max-w-reading" />
        <ArticleNote>
          <ArticleMarkup text={t("articles.anki.costNote")} />
        </ArticleNote>
      </ArticleSection>

      <ArticleSection id="la-date" title={t("articles.anki.dateTitle")}>
        <ArticleP k="articles.anki.date1" />
        <ArticleP k="articles.anki.date2" links={{ exam: t("articles.anki.examLink") }} />
      </ArticleSection>

      <ArticleSection id="choisir" title={t("articles.anki.pickTitle")}>
        <ArticleP k="articles.anki.pickAnki" />
        <ArticleP k="articles.anki.pickMicabo" />
        <ArticleP k="articles.anki.pickBoth" links={{ method: t("articles.anki.methodLink") }} />
      </ArticleSection>
    </ArticleShell>
  );
}
