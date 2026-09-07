"use client";

import Link from "next/link";

import { useI18n } from "@/lib/i18n/client";
import { ANKI_PAGE, EXAM_PAGE, METHOD_PAGE } from "@/lib/site-pages";

/**
 * Une phrase d'article : gras et les trois liens internes.
 *
 * `t()` avale un `{jeton}` inconnu. Les liens passent par `[[method]]`,
 * `[[exam]]`, `[[anki]]`. `**gras**` reste dans la chaîne. Le libellé de
 * chaque lien est celui de la page qui parle, pas un libellé global.
 */

const PIECE = /(\[\[(?:method|exam|anki)\]\]|\*\*[^*]+\*\*)/g;

const HREF = {
  method: METHOD_PAGE.path,
  exam: EXAM_PAGE.path,
  anki: ANKI_PAGE.path,
} as const;

export type ArticleLinkId = keyof typeof HREF;

export function ArticleMarkup({
  text,
  links,
  linkClassName = "underline-draw font-medium text-ink",
}: {
  text: string;
  links?: Partial<Record<ArticleLinkId, string>>;
  linkClassName?: string;
}) {
  const parts = text.split(PIECE).filter(Boolean);

  return (
    <>
      {parts.map((part, index) => {
        const token = part.match(/^\[\[(method|exam|anki)\]\]$/);
        if (token) {
          const id = token[1] as ArticleLinkId;
          const label = links?.[id];
          if (!label) return <span key={index}>{part}</span>;
          return (
            <Link key={index} href={HREF[id]} className={linkClassName}>
              {label}
            </Link>
          );
        }
        if (part.startsWith("**") && part.endsWith("**")) {
          return (
            <strong key={index} className="font-semibold text-ink">
              {part.slice(2, -2)}
            </strong>
          );
        }
        return <span key={index}>{part}</span>;
      })}
    </>
  );
}

export function ArticleP({
  k,
  vars,
  links,
  className,
}: {
  k: string;
  vars?: Record<string, string | number>;
  links?: Partial<Record<ArticleLinkId, string>>;
  className?: string;
}) {
  const { t } = useI18n();
  return (
    <p className={className}>
      <ArticleMarkup text={t(k, vars)} links={links} />
    </p>
  );
}
