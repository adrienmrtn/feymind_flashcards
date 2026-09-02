"use client";

import { Badge } from "@/components/ui/badge";
import { useI18n } from "@/lib/i18n/client";

import { CourseTransformation } from "./CourseTransformation";
import { HeroAura } from "./HeroAura";
import { StartButton } from "./StartButton";

/**
 * L'accroche : une phrase, puis le trajet entier du document.
 */
export function Hero({ signedIn = false }: { signedIn?: boolean }) {
  const { t } = useI18n();
  return (
    <section className="relative overflow-clip">
      <HeroAura />

      <div className="relative mx-auto max-w-page px-screen pt-16 text-center sm:pt-24">
        <Badge
          variant="secondary"
          className="rise h-auto max-w-[36ch] gap-2 rounded-pill px-3.5 py-1.5 text-balance text-[12.5px] font-medium text-ink-secondary"
        >
          <span className="h-1.5 w-1.5 rounded-full bg-accent-vivid" />
          {t("landing.badge")}
        </Badge>

        <h1
          className="rise mx-auto mt-7 max-w-[22ch] text-[40px] font-bold leading-[1.03] tracking-display text-ink sm:max-w-[24ch] sm:text-[76px]"
          style={{ animationDelay: "60ms" }}
        >
          {t("landing.titleBefore")}{" "}
          <span className="relative whitespace-nowrap text-accent">
            {t("landing.titleAccent")}
            <svg
              aria-hidden
              viewBox="0 0 200 12"
              preserveAspectRatio="none"
              className="absolute -bottom-1.5 left-0 h-2.5 w-full text-accent-vivid"
            >
              <path
                d="M2 8c40-5 90-7 196-4"
                fill="none"
                stroke="currentColor"
                strokeWidth="4"
                strokeLinecap="round"
              />
            </svg>
          </span>
          .
        </h1>

        <p
          className="rise mx-auto mt-7 max-w-[52ch] text-[17px] leading-relaxed text-ink-secondary sm:text-[19px]"
          style={{ animationDelay: "120ms" }}
        >
          {t("landing.subtitle")}
        </p>

        <div className="rise mt-9" style={{ animationDelay: "180ms" }}>
          <StartButton signedIn={signedIn} />
        </div>
      </div>

      <CourseTransformation />
    </section>
  );
}
