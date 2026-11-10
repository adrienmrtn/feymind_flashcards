"use client";

import { useState } from "react";
import { Zap } from "lucide-react";

import { XP_REWARDS } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";

/** Les mots qui félicitent une bonne réponse, tirés au hasard (`docs/refonte-knowunity.md` § 6). */
const CHEERS = ["app.kx.cheer.wellDone", "app.kx.cheer.exact", "app.kx.cheer.perfect"] as const;

/**
 * **Le retour d'une réponse, récompensé** : la pastille « +10 XP » ou « +2 XP », et sur une bonne
 * réponse un mot qui félicite. Se pose dans le retour qui existe déjà (vert ou rouge), sans
 * l'ouvrir dans une nouvelle feuille.
 */
export function AnswerReward({ right }: { right: boolean }) {
  const { t } = useI18n();
  // Tiré une fois, quand le retour s'affiche : il ne change pas au rendu suivant.
  const [cheer] = useState(() => CHEERS[Math.floor(Math.random() * CHEERS.length)]!);
  const amount = right ? XP_REWARDS.correctAnswer : XP_REWARDS.wrongAnswer;
  return (
    <span className="flex flex-wrap items-center gap-2">
      <span className="kx-gradient inline-flex items-center gap-1 rounded-pill px-2.5 py-1 text-[13px] font-extrabold text-white">
        <Zap aria-hidden="true" className="size-3.5 fill-current" strokeWidth={2.4} />
        {t("app.kx.xpGain", { n: amount })}
      </span>
      {right ? <span className="text-[15px] font-extrabold text-correct-ink">{t(cheer)}</span> : null}
    </span>
  );
}
