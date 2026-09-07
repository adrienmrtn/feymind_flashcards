import type { Metadata } from "next";

import { indexableAlternates } from "@/lib/i18n/alternates";
import { localizedPath } from "@/lib/i18n/paths";
import { getTranslator } from "@/lib/i18n/server";
import { UI_LOCALE_META } from "@/lib/i18n/locales";
import {
  articleMetaDescriptionKey,
  articleMetaTitleKey,
  type SitePage,
} from "@/lib/site-pages";

/** Titre, extrait, canonique et hreflang d'une page d'article. */
export async function articleMetadata(page: SitePage): Promise<Metadata> {
  const { t, locale } = await getTranslator();
  const title = t(articleMetaTitleKey(page.id));
  const description = t(articleMetaDescriptionKey(page.id));
  const path = localizedPath(locale, page.path);
  return {
    title,
    description,
    alternates: indexableAlternates(locale, page.path),
    openGraph: {
      type: "article",
      url: path,
      title,
      description,
      locale: UI_LOCALE_META[locale].og,
    },
  };
}
