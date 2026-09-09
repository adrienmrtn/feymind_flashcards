import Link from "next/link";

import { BrandMark } from "@/components/BrandMark";
import { Button } from "@/components/ui/button";
import { localizedHref } from "@/lib/i18n/paths";
import { getTranslator } from "@/lib/i18n/server";

/**
 * La 404, sur la carte du parcours : fond sauge, carte blanche, une seule chose à faire.
 * Un lien mort n'a pas besoin d'une barre de navigation, il a besoin d'une porte.
 */
export default async function NotFound() {
  const { t, locale } = await getTranslator();
  return (
    <main className="flex min-h-svh items-center justify-center bg-canvas-sage px-3 py-3 sm:px-6 sm:py-6">
      <div className="rise flex w-full max-w-[520px] flex-col items-center rounded-[28px] bg-surface px-6 py-12 text-center shadow-floating sm:px-12">
        <BrandMark size={56} />
        <p className="numeral mt-6 text-[13px] font-semibold text-ink-tertiary">404</p>
        <h1 className="mt-2 text-balance text-[26px] font-bold leading-[1.14] tracking-tight-title text-ink sm:text-[30px]">
          {t("common.notFoundTitle")}
        </h1>
        <p className="mt-3 max-w-[38ch] text-[16px] leading-relaxed text-ink-secondary">
          {t("common.notFoundBody")}
        </p>
        <Button
          size="xl"
          className="mt-8 h-12 rounded-pill px-6 text-[15px] sm:h-12 sm:text-[15px]"
          render={<Link href={localizedHref(locale, "/")} />}
        >
          {t("common.notFoundHome")}
        </Button>
      </div>
    </main>
  );
}
