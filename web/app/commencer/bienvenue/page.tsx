"use client";

import type { Route } from "next";
import Link from "next/link";

import { BrandWordmark } from "@/components/BrandMark";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * La porte. Un mot large, le logo au centre, et la sortie pour ceux
 * qui ont déjà un compte.
 */
export default function WelcomeStep() {
  return (
    <Scaffold
      title="Bienvenue sur Micabo."
      titleClassName="text-[34px] tracking-display sm:text-[44px]"
      footer={
        <div className="flex flex-col items-end gap-3">
          <ContinueButton enabled href="/commencer/importer" />
          <Link
            href={"/connexion" as Route}
            className="underline-draw text-[14.5px] font-medium text-ink-secondary"
          >
            J&apos;ai déjà un compte
          </Link>
        </div>
      }
    >
      <div className="flex h-full flex-col items-center justify-center">
        <BrandWordmark mark={104} />
      </div>
    </Scaffold>
  );
}
