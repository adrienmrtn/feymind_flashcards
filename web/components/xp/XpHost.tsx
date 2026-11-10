"use client";

import { useEffect, useRef, useState } from "react";
import { Zap } from "lucide-react";

import { DAILY_XP_GOAL } from "@micabo/core";

import { Float } from "@/components/app/Float";
import { Confetti } from "@/components/lesson/LessonFinished";
import { LessonPrimaryButton } from "@/components/lesson/LessonButtons";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";
import { setXpOwner, XP_EVENT, type XpGain } from "@/lib/xp/client";
import { syncXp } from "@/lib/xp/sync";

/**
 * **L'XP, montée une fois pour toute l'app** (`docs/refonte-knowunity.md` § 2) : le petit
 * « +10 XP » qui monte et s'efface à chaque gain (et une vibration légère là où le navigateur
 * en a une), la feuille de fête quand l'objectif du jour tombe — une fois par jour —, et la
 * synchro vers `profiles`, quelques secondes après un gain et quand l'onglet passe en arrière-plan.
 */
export function XpHost({ userId }: { userId: string | null }) {
  // Posé au rendu : les écrans qui lisent l'XP dans leur effet lisent déjà celle de ce compte.
  setXpOwner(userId);
  const { t } = useI18n();
  const [toasts, setToasts] = useState<{ id: number; amount: number }[]>([]);
  const [celebrating, setCelebrating] = useState(false);
  const counter = useRef(0);
  const timer = useRef<number | null>(null);

  useEffect(() => {
    setXpOwner(userId);
    void syncXp(userId);

    function onGain(event: Event) {
      const gain = (event as CustomEvent<XpGain>).detail;
      if (!gain || gain.amount <= 0) return;
      const id = ++counter.current;
      setToasts((current) => [...current.slice(-2), { id, amount: gain.amount }]);
      window.setTimeout(() => setToasts((current) => current.filter((toast) => toast.id !== id)), 1600);
      try {
        navigator.vibrate?.(8);
      } catch {
        // Pas de vibration ici : le « +XP » suffit.
      }
      if (gain.reachedGoal) setCelebrating(true);
      if (timer.current) window.clearTimeout(timer.current);
      timer.current = window.setTimeout(() => void syncXp(userId), 6000);
    }
    function onHide() {
      if (document.visibilityState === "hidden") void syncXp(userId);
    }
    window.addEventListener(XP_EVENT, onGain);
    document.addEventListener("visibilitychange", onHide);
    return () => {
      window.removeEventListener(XP_EVENT, onGain);
      document.removeEventListener("visibilitychange", onHide);
      if (timer.current) window.clearTimeout(timer.current);
    };
  }, [userId]);

  // Sur `body` (`Float`) : la page porte une transformation, et `fixed` ne couvrirait qu'elle.
  return (
    <Float>
      <div aria-live="polite" className="pointer-events-none fixed inset-x-0 top-[max(0.75rem,env(safe-area-inset-top))] z-[70] flex flex-col items-center gap-1.5" data-print="hide">
        {toasts.map((toast) => (
          <span key={toast.id} className="xp-toast inline-flex items-center gap-1 rounded-pill px-3.5 py-1.5 text-[15px] font-extrabold text-white shadow-floating">
            <Zap aria-hidden="true" className="size-4 fill-current" strokeWidth={2.4} />
            {t("app.kx.xpGain", { n: toast.amount })}
          </span>
        ))}
      </div>
      {celebrating ? <GoalSheet onClose={() => setCelebrating(false)} /> : null}
    </Float>
  );
}

/** **« Objectif du jour atteint ! »** : Mika fait la fête, des confettis, un seul bouton. */
function GoalSheet({ onClose }: { onClose: () => void }) {
  const { t } = useI18n();
  useEffect(() => {
    function escape(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    document.addEventListener("keydown", escape);
    return () => document.removeEventListener("keydown", escape);
  }, [onClose]);
  return (
    <div className="fixed inset-0 z-[60] flex items-end justify-center bg-ink/40 sm:items-center sm:p-6" role="dialog" aria-modal="true" aria-label={t("app.kx.goal.title")} onClick={onClose}>
      <div
        className="score-in relative flex w-full max-w-[440px] flex-col items-center gap-3 overflow-hidden rounded-t-[28px] bg-canvas px-5 pb-[max(1.25rem,env(safe-area-inset-bottom))] pt-6 text-center sm:rounded-[28px]"
        onClick={(event) => event.stopPropagation()}
      >
        <Confetti />
        <Mika mood="celebrate" size={150} label="" />
        <h2 className="text-[26px] font-extrabold leading-tight tracking-tight-title text-ink">{t("app.kx.goal.title")}</h2>
        <p className="max-w-[340px] text-[16px] font-medium leading-snug text-ink-secondary">{t("app.kx.goal.body", { goal: DAILY_XP_GOAL })}</p>
        <div className="mt-3 w-full">
          <LessonPrimaryButton onClick={onClose}>{t("app.kx.goal.cta")}</LessonPrimaryButton>
        </div>
      </div>
    </div>
  );
}
