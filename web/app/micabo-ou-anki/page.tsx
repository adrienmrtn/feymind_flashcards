import { entitlement, pricing } from "@micabo/core";

import { ArticleMarkup, ArticleP } from "@/components/pages/ArticleMarkup";
import { ArticleNote, ArticleSection, ArticleShell } from "@/components/pages/ArticleShell";
import { articleMetadata } from "@/lib/articles";
import { getTranslator } from "@/lib/i18n/server";
import { ANKI_PAGE } from "@/lib/site-pages";

export async function generateMetadata() {
  return articleMetadata(ANKI_PAGE);
}

interface Row {
  criterion: string;
  micabo: string;
  anki: string;
  edge: "micabo" | "anki" | null;
}

/**
 * **La comparaison avec Anki, écrite honnêtement.**
 *
 * Trois lignes vont à Anki, dont la plus importante — il est gratuit.
 * Les phrases viennent des catalogues ; les nombres (prix, cartes) restent
 * lus dans `@micabo/core`.
 */
export default async function AnkiComparisonPage() {
  const { t, locale } = await getTranslator();
  const price = new Intl.NumberFormat(locale, {
    style: "currency",
    currency: "EUR",
  }).format(pricing.YEARLY.price);

  const rows: Row[] = [
    {
      criterion: t("articles.anki.rowAlgo"),
      micabo: t("articles.anki.rowAlgoMicabo"),
      anki: t("articles.anki.rowAlgoAnki"),
      edge: "anki",
    },
    {
      criterion: t("articles.anki.rowWrite"),
      micabo: t("articles.anki.rowWriteMicabo"),
      anki: t("articles.anki.rowWriteAnki"),
      edge: "micabo",
    },
    {
      criterion: t("articles.anki.rowDate"),
      micabo: t("articles.anki.rowDateMicabo"),
      anki: t("articles.anki.rowDateAnki"),
      edge: "micabo",
    },
    {
      criterion: t("articles.anki.rowPrice"),
      micabo: t("articles.anki.rowPriceMicabo", {
        cards: entitlement.FREE_TIER.cardsPerSession,
        price,
      }),
      anki: t("articles.anki.rowPriceAnki"),
      edge: "anki",
    },
    {
      criterion: t("articles.anki.rowPlatforms"),
      micabo: t("articles.anki.rowPlatformsMicabo"),
      anki: t("articles.anki.rowPlatformsAnki"),
      edge: "anki",
    },
    {
      criterion: t("articles.anki.rowDecks"),
      micabo: t("articles.anki.rowDecksMicabo"),
      anki: t("articles.anki.rowDecksAnki"),
      edge: "anki",
    },
    {
      criterion: t("articles.anki.rowFriends"),
      micabo: t("articles.anki.rowFriendsMicabo"),
      anki: t("articles.anki.rowFriendsAnki"),
      edge: "micabo",
    },
    {
      criterion: t("articles.anki.rowStart"),
      micabo: t("articles.anki.rowStartMicabo"),
      anki: t("articles.anki.rowStartAnki"),
      edge: "micabo",
    },
  ];

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
        <ArticleP k="articles.anki.tableLead" className="max-w-reading" />
        <ComparisonTable
          rows={rows}
          caption={t("articles.anki.tableCaption")}
          criterion={t("articles.anki.colCriterion")}
        />
      </ArticleSection>

      <ArticleSection id="le-vrai-cout" title={t("articles.anki.costTitle")}>
        <ArticleP k="articles.anki.cost1" />
        <ArticleP k="articles.anki.cost2" />
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

function ComparisonTable({
  rows,
  caption,
  criterion,
}: {
  rows: Row[];
  caption: string;
  criterion: string;
}) {
  return (
    <>
      <div className="not-prose mt-8 hidden overflow-hidden rounded-group border border-stroke sm:block">
        <table className="w-full border-collapse text-left text-[14.5px]">
          <caption className="sr-only">{caption}</caption>
          <thead>
            <tr className="bg-surface-muted">
              <th scope="col" className="w-[22%] px-5 py-3.5 text-[12.5px] font-semibold text-ink">
                {criterion}
              </th>
              <th scope="col" className="px-5 py-3.5 text-[12.5px] font-semibold text-ink">
                Micabo
              </th>
              <th scope="col" className="px-5 py-3.5 text-[12.5px] font-semibold text-ink">
                Anki
              </th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.criterion} className="border-t border-hairline">
                <th scope="row" className="px-5 py-4 align-top text-[14px] font-medium text-ink">
                  {row.criterion}
                </th>
                <Cell text={row.micabo} leading={row.edge === "micabo"} />
                <Cell text={row.anki} leading={row.edge === "anki"} />
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <ul className="not-prose mt-8 space-y-3 sm:hidden">
        {rows.map((row) => (
          <li key={row.criterion} className="rounded-group border border-stroke bg-surface p-5">
            <p className="text-[13px] font-semibold text-ink">{row.criterion}</p>
            <dl className="mt-3 space-y-2.5 text-[14px]">
              <div>
                <dt className="text-[12px] font-medium text-ink-tertiary">Micabo</dt>
                <dd className={row.edge === "micabo" ? "text-ink" : "text-ink-secondary"}>
                  {row.micabo}
                </dd>
              </div>
              <div>
                <dt className="text-[12px] font-medium text-ink-tertiary">Anki</dt>
                <dd className={row.edge === "anki" ? "text-ink" : "text-ink-secondary"}>
                  {row.anki}
                </dd>
              </div>
            </dl>
          </li>
        ))}
      </ul>
    </>
  );
}

function Cell({ text, leading }: { text: string; leading: boolean }) {
  return (
    <td
      className={`px-5 py-4 align-top leading-relaxed ${
        leading ? "font-medium text-ink" : "text-ink-secondary"
      }`}
    >
      {text}
    </td>
  );
}
