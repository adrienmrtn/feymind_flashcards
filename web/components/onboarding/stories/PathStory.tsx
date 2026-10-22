"use client";

import { useMemo } from "react";

import { pathCircles, type CircleReadiness } from "@micabo/core";

import { PathMap } from "@/components/lesson/PathMap";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Le chemin d'une leçon**, dessiné par le vrai composant : l'intro cochée, le premier thème
 * en cours, les suivants à venir, le quiz final au bout. Le cycle de l'eau, comme la leçon de
 * démonstration. Réduit pour tenir dans une vignette : le composant se dessine à sa largeur
 * de téléphone, puis l'ensemble est mis à l'échelle depuis son coin haut gauche.
 */
const PHONE_WIDTH = 390;

export function PathStory({ scale = 0.62, height = 300 }: { scale?: number; height?: number }) {
  const { t } = useI18n();
  const circles = useMemo(
    () =>
      pathCircles(
        [
          { title: t("demo.evap"), icon: "flamme", symbol: "flame" },
          { title: t("demo.cond"), icon: "fiole", symbol: "drop" },
          { title: t("demo.precip"), icon: "globe", symbol: "cloud.rain" },
        ],
        { intro: t("lesson.circle.intro"), checkpoint: t("lesson.circle.checkpoint"), final: t("lesson.circle.final") },
        { singleQuiz: true },
      ),
    [t],
  );
  const readiness = useMemo(() => Object.fromEntries(circles.map((circle) => [circle.id, "ready" as CircleReadiness])), [circles]);

  return (
    <div className="relative overflow-hidden" style={{ width: Math.round(PHONE_WIDTH * scale), height }} aria-hidden="true">
      <div className="pointer-events-none absolute left-0 top-0" style={{ width: PHONE_WIDTH, transform: `scale(${scale})`, transformOrigin: "top left" }}>
        <PathMap circles={circles} done={["intro"]} inCircle={0.45} readiness={readiness} tone="blue" onOpen={() => undefined} />
      </div>
    </div>
  );
}
