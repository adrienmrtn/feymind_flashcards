"use client";

import type { Route } from "next";
import Link from "next/link";

import { BrandWordmark } from "@/components/BrandMark";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";

/**
 * La porte. Un mot large, le logo au centre, et la sortie pour ceux
 * qui ont déjà un compte.
 */
export default function WelcomeStep() {
  const { t } = useI18n();
  return (
    <Scaffold
      title={t("onboarding.welcomeTitle")}
      titleClassName="text-[34px] tracking-display sm:text-[40px]"
      footer={
        <div className="flex flex-col items-end gap-3">
          <ContinueButton enabled href="/commencer/importer" />
          <Link
            href={"/connexion" as Route}
            className="underline-draw text-[15px] font-semibold text-ink-secondary"
          >
            {t("common.alreadyAccount")}
          </Link>
        </div>
      }
    >
      <div className="flex h-full flex-col items-center justify-center">
        <BrandWordmark mark={104} tagline={t("app.brand.tagline")} />
      </div>
    </Scaffold>
  );
}
