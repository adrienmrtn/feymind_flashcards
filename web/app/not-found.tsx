import Link from "next/link";

import { Button } from "@/components/ui/button";
import { getTranslator } from "@/lib/i18n/server";

export default async function NotFound() {
  const { t } = await getTranslator();
  return (
    <main className="mx-auto flex min-h-dvh max-w-[680px] flex-col justify-center px-6">
      <p className="text-[13px] font-medium text-ink-tertiary">404</p>
      <h1 className="mt-2 text-[26px] font-bold leading-tight text-ink">{t("common.notFoundTitle")}</h1>
      <p className="mt-3 text-[16px] leading-relaxed text-ink-secondary">{t("common.notFoundBody")}</p>
      <Button
        variant="link"
        className="mt-8 h-auto w-fit px-0 text-[15px] text-accent"
        render={<Link href="/" />}
      >
        {t("common.notFoundHome")}
      </Button>
    </main>
  );
}
