"use client";

import Link from "next/link";

import { useI18n } from "@/lib/i18n/client";
import {
  LEGAL_CONTACT,
  LEGAL_EDITOR,
  LEGAL_IOS_BUNDLE,
  LEGAL_SITE,
  PRIVACY_PATH,
  TERMS_PATH,
} from "@/lib/legal";

/**
 * Une phrase de droit, avec les seuls liens qu'on autorise.
 *
 * `t()` avale un `{jeton}` inconnu. Les liens passent donc par `[[site]]`,
 * `[[contact]]`, `[[terms]]`, `[[privacy]]`. `**gras**` et `` `code` ``
 * restent dans la chaîne : un prix, une adresse, un identifiant ne se
 * coupent pas en deux clés.
 */

const PIECE =
  /(\[\[(?:site|contact|terms|privacy)\]\]|\*\*[^*]+\*\*|`[^`]+`)/g;

export function LegalMarkup({ text }: { text: string }) {
  const { t } = useI18n();
  const parts = text.split(PIECE).filter(Boolean);

  return (
    <>
      {parts.map((part, index) => {
        if (part === "[[site]]") {
          return (
            <a key={index} href={LEGAL_SITE} className="underline-draw text-ink">
              micabo.app
            </a>
          );
        }
        if (part === "[[contact]]") {
          return (
            <a
              key={index}
              href={`mailto:${LEGAL_CONTACT}`}
              className="underline-draw text-ink"
            >
              {LEGAL_CONTACT}
            </a>
          );
        }
        if (part === "[[terms]]") {
          return (
            <Link key={index} href={TERMS_PATH} className="underline-draw text-ink">
              {t("legal.terms.linkLabel")}
            </Link>
          );
        }
        if (part === "[[privacy]]") {
          return (
            <Link key={index} href={PRIVACY_PATH} className="underline-draw text-ink">
              {t("legal.privacy.linkLabel")}
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
        if (part.startsWith("`") && part.endsWith("`")) {
          return <code key={index}>{part.slice(1, -1)}</code>;
        }
        return <span key={index}>{part}</span>;
      })}
    </>
  );
}

export function LegalP({ k, vars }: { k: string; vars?: Record<string, string | number> }) {
  const { t } = useI18n();
  return (
    <p>
      <LegalMarkup text={t(k, vars)} />
    </p>
  );
}

export function LegalList({ keys, vars }: { keys: string[]; vars?: Record<string, string | number> }) {
  const { t } = useI18n();
  return (
    <ul className="list-disc space-y-2 pl-5">
      {keys.map((key) => (
        <li key={key}>
          <LegalMarkup text={t(key, vars)} />
        </li>
      ))}
    </ul>
  );
}

export function legalVars(): Record<string, string> {
  return {
    editor: LEGAL_EDITOR,
    bundle: LEGAL_IOS_BUNDLE,
  };
}
