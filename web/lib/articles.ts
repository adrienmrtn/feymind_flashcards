import type { Metadata } from "next";

import { getTranslator } from "@/lib/i18n/server";
import {
  articleMetaDescriptionKey,
  articleMetaTitleKey,
  type SitePage,
} from "@/lib/site-pages";

/** Titre, extrait et canonique d'une page d'article, dans la langue servie. */
export async function articleMetadata(page: SitePage): Promise<Metadata> {
  const { t } = await getTranslator();
  const title = t(articleMetaTitleKey(page.id));
  const description = t(articleMetaDescriptionKey(page.id));
  return {
    title,
    description,
    alternates: { canonical: page.path },
    openGraph: {
      type: "article",
      url: page.path,
      title,
      description,
    },
  };
}
