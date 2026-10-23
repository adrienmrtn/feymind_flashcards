"use client";

import { SUPPORT_ICONS, SUPPORT_KINDS } from "@micabo/core";

import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Les cinq supports de la barre de Home**, qui flottent : un PDF, une photo, un
 * enregistrement, une vidéo YouTube, un texte collé. Les mêmes icônes 3D que dans l'app.
 */
const PLACES = [
  { left: "4%", top: "10%", delay: "0s", size: 84 },
  { left: "56%", top: "0%", delay: "1.1s", size: 76 },
  { left: "28%", top: "40%", delay: "0.5s", size: 92 },
  { left: "68%", top: "46%", delay: "1.7s", size: 80 },
  { left: "2%", top: "66%", delay: "2.2s", size: 72 },
] as const;

export function SupportsStory() {
  const { t } = useI18n();
  return (
    <div className="relative h-[270px] w-full max-w-[340px]">
      {SUPPORT_KINDS.map((kind, index) => {
        const place = PLACES[index]!;
        return (
          <span
            key={kind}
            className="float paper absolute flex flex-col items-center justify-center gap-1 rounded-[20px] bg-surface"
            style={{ left: place.left, top: place.top, width: place.size, height: place.size, animationDelay: place.delay }}
          >
            <MicaboIcon id={SUPPORT_ICONS[kind]} size={Math.round(place.size * 0.5)} />
            <span className="text-[10px] font-extrabold text-ink-secondary">{t(`lesson.import.${kind}`)}</span>
          </span>
        );
      })}
      <span className="sr-only">{t("onboarding.importerFormats")}</span>
    </div>
  );
}
