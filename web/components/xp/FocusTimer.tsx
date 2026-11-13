"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Pause, Play, Square, X, Zap } from "lucide-react";

import { FOCUS_MINUTES, XP_REWARDS } from "@micabo/core";

import { Float } from "@/components/app/Float";
import { Confetti } from "@/components/lesson/LessonFinished";
import { LessonPrimaryButton, LessonSecondaryButton } from "@/components/lesson/LessonButtons";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";
import { HOME_PATH } from "@/lib/lesson/routes";
import { awardXp } from "@/lib/xp/client";

/**
 * **Le minuteur** (`docs/refonte-knowunity.md` § 5) : plein écran, Mika au centre d'un anneau qui
 * se vide, 25:00, Pause / Reprendre, Arrêter (avec confirmation). Au bout : la fête et
 * `focusSession` (40 XP).
 *
 * Le temps se **calcule** depuis l'instant de départ, moins les pauses, et ne se compte pas en
 * secondes écoulées : un onglet en arrière-plan, que le navigateur ralentit, ne fait pas durer la
 * séance plus longtemps. La séance est gardée dans le navigateur, et un rechargement la reprend
 * où elle en est. L'écran reste allumé pendant la séance (Screen Wake Lock), là où le navigateur
 * le permet.
 *
 * Le site compte le temps de révision leçon par leçon (`addStudyTime`) ; une séance du minuteur
 * n'appartient à aucune leçon, et n'entre donc pas dans les heures de révision.
 */
interface FocusSession {
  startedAt: number;
  pausedAt: number | null;
  pausedMs: number;
}

const KEY = "micabo.focus.session";
const TOTAL_MS = FOCUS_MINUTES * 60_000;

function readSession(): FocusSession | null {
  try {
    const raw = window.localStorage.getItem(KEY);
    const value = raw ? (JSON.parse(raw) as Partial<FocusSession>) : null;
    if (value && typeof value.startedAt === "number" && typeof value.pausedMs === "number") {
      return { startedAt: value.startedAt, pausedAt: typeof value.pausedAt === "number" ? value.pausedAt : null, pausedMs: value.pausedMs };
    }
  } catch {
    // Illisible : une nouvelle séance.
  }
  return null;
}

function writeSession(session: FocusSession | null): void {
  try {
    if (session) window.localStorage.setItem(KEY, JSON.stringify(session));
    else window.localStorage.removeItem(KEY);
  } catch {
    // Le navigateur refuse : la séance vit le temps de la page.
  }
}

function elapsed(session: FocusSession, now: number): number {
  return Math.max(0, (session.pausedAt ?? now) - session.startedAt - session.pausedMs);
}

/** Garde l'écran allumé tant que `active`, et le redemande quand l'onglet revient au premier plan. */
function useWakeLock(active: boolean) {
  useEffect(() => {
    if (!active || typeof navigator === "undefined" || !("wakeLock" in navigator)) return;
    let sentinel: WakeLockSentinel | null = null;
    let alive = true;
    async function request() {
      try {
        const lock = await navigator.wakeLock.request("screen");
        if (!alive) {
          void lock.release();
          return;
        }
        sentinel = lock;
      } catch {
        // Refusé (batterie faible, onglet caché) : la séance continue sans.
      }
    }
    function onVisible() {
      if (document.visibilityState === "visible" && (!sentinel || sentinel.released)) void request();
    }
    void request();
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      alive = false;
      document.removeEventListener("visibilitychange", onVisible);
      void sentinel?.release().catch(() => undefined);
    };
  }, [active]);
}

export function FocusTimer() {
  const { t } = useI18n();
  const router = useRouter();
  const [session, setSession] = useState<FocusSession | null>(null);
  const [now, setNow] = useState(() => Date.now());
  const [finished, setFinished] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const rewarded = useRef(false);

  const start = useCallback(() => {
    const fresh = { startedAt: Date.now(), pausedAt: null, pausedMs: 0 };
    writeSession(fresh);
    rewarded.current = false;
    setFinished(false);
    setSession(fresh);
    setNow(Date.now());
  }, []);

  // Une séance gardée reprend ; sinon, une nouvelle commence.
  useEffect(() => {
    const kept = readSession();
    if (kept) {
      setSession(kept);
      setNow(Date.now());
    } else {
      start();
    }
  }, [start]);

  const running = session !== null && session.pausedAt === null && !finished;
  useWakeLock(running);

  useEffect(() => {
    if (!running) return;
    const timer = window.setInterval(() => setNow(Date.now()), 250);
    return () => window.clearInterval(timer);
  }, [running]);

  const spent = session ? elapsed(session, now) : 0;
  const remaining = Math.max(0, TOTAL_MS - spent);

  // Au bout : une seule récompense, la séance oubliée, la fête.
  useEffect(() => {
    if (!session || finished || remaining > 0) return;
    writeSession(null);
    setFinished(true);
    if (!rewarded.current) {
      rewarded.current = true;
      awardXp("focusSession");
    }
  }, [finished, remaining, session]);

  function togglePause() {
    if (!session) return;
    const at = Date.now();
    const next = session.pausedAt === null ? { ...session, pausedAt: at } : { ...session, pausedMs: session.pausedMs + (at - session.pausedAt), pausedAt: null };
    writeSession(next);
    setSession(next);
    setNow(at);
  }

  function stop() {
    writeSession(null);
    router.push(HOME_PATH);
  }

  const seconds = Math.ceil(remaining / 1000);
  const clock = `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
  const size = 264;
  const stroke = 14;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const paused = session?.pausedAt !== null && session !== null;

  // Sur `body` : l'entrée de page pose une transformation, et `fixed` s'y arrêterait au lieu de
  // couvrir la fenêtre (la barre d'onglets passait devant).
  if (finished) {
    return (
      <Float>
        <div className="fixed inset-0 z-50 flex flex-col overflow-hidden bg-canvas" role="dialog" aria-modal="true" aria-label={t("app.kx.timer.doneTitle")}>
          <Confetti />
          <div className="flex flex-1 flex-col items-center justify-center gap-4 px-6 text-center">
            <Mika mood="celebrate" size={180} label="" />
            <h1 className="text-[30px] font-extrabold leading-tight tracking-tight-title text-ink">{t("app.kx.timer.doneTitle")}</h1>
            <p className="max-w-[360px] text-[17px] font-medium text-ink-secondary">{t("app.kx.timer.doneBody", { n: FOCUS_MINUTES })}</p>
            <span className="kx-gradient inline-flex items-center gap-1 rounded-pill px-3.5 py-1.5 text-[16px] font-extrabold text-white">
              <Zap aria-hidden="true" className="size-4 fill-current" strokeWidth={2.4} />
              {t("app.kx.xpGain", { n: XP_REWARDS.focusSession })}
            </span>
          </div>
          <div className="mx-auto flex w-full max-w-[420px] flex-col gap-3 px-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
            <LessonPrimaryButton onClick={start}>{t("app.kx.timer.again")}</LessonPrimaryButton>
            <LessonSecondaryButton onClick={() => router.push(HOME_PATH)}>{t("lesson.tab.home")}</LessonSecondaryButton>
          </div>
        </div>
      </Float>
    );
  }

  return (
    <Float>
      <div className="fixed inset-0 z-50 flex flex-col bg-canvas" role="dialog" aria-modal="true" aria-label={t("app.kx.timer.title")}>
        <div className="flex items-center justify-between px-3 pt-[max(0.5rem,env(safe-area-inset-top))]">
          <span className="ps-2 text-[17px] font-extrabold text-ink">{t("app.kx.timer.title")}</span>
          <button
            type="button"
            onClick={() => setConfirming(true)}
            aria-label={t("app.kx.timer.stop")}
            className="pressable flex size-10 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted"
          >
            <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
          </button>
        </div>

        <div className="flex flex-1 flex-col items-center justify-center gap-5 px-6 text-center">
          <div className="relative" style={{ width: size, height: size, maxWidth: "78vw", maxHeight: "78vw" }}>
            <svg aria-hidden="true" className="absolute inset-0 size-full" viewBox={`0 0 ${size} ${size}`}>
              <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--color-track)" strokeWidth={stroke} />
              <circle
                cx={size / 2}
                cy={size / 2}
                r={radius}
                fill="none"
                stroke="var(--color-accent)"
                strokeWidth={stroke}
                strokeLinecap="round"
                strokeDasharray={circumference}
                strokeDashoffset={circumference * (1 - remaining / TOTAL_MS)}
                transform={`rotate(-90 ${size / 2} ${size / 2})`}
                className="focus-ring"
              />
            </svg>
            <div className="absolute inset-0 flex items-center justify-center">
              <Mika mood={paused ? "sleep" : "idle"} size={150} label="" className="max-w-[56%]" />
            </div>
          </div>
          <p className="numeral font-display text-[68px] leading-none text-ink" role="timer" aria-live="off">
            {clock}
          </p>
          <p className="max-w-[340px] text-[16px] font-semibold text-ink-secondary">{paused ? t("app.kx.timer.paused") : t("app.kx.timer.focus")}</p>
        </div>

        <div className="mx-auto grid w-full max-w-[420px] grid-cols-2 gap-3 px-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
          <LessonPrimaryButton onClick={togglePause} disabled={!session}>
            {paused ? <Play aria-hidden="true" className="size-5 fill-current" strokeWidth={2.4} /> : <Pause aria-hidden="true" className="size-5 fill-current" strokeWidth={2.4} />}
            {paused ? t("app.kx.timer.resume") : t("app.kx.timer.pause")}
          </LessonPrimaryButton>
          <LessonSecondaryButton onClick={() => setConfirming(true)}>
            <Square aria-hidden="true" className="size-4 fill-current" strokeWidth={2.4} />
            {t("app.kx.timer.stop")}
          </LessonSecondaryButton>
        </div>

        {confirming ? (
          <div
            className="fixed inset-0 z-[60] flex items-end justify-center bg-ink/40 sm:items-center sm:p-6"
            role="alertdialog"
            aria-modal="true"
            aria-label={t("app.kx.timer.stopConfirm")}
            onClick={() => setConfirming(false)}
          >
            <div
              className="score-in flex w-full max-w-[420px] flex-col gap-3 rounded-t-[28px] bg-canvas p-5 pb-[max(1.25rem,env(safe-area-inset-bottom))] text-center sm:rounded-[28px]"
              onClick={(event) => event.stopPropagation()}
            >
              <p className="text-[18px] font-extrabold text-ink">{t("app.kx.timer.stopConfirm")}</p>
              <p className="text-[15px] font-medium text-ink-secondary">{t("app.kx.timer.stopBody")}</p>
              <LessonPrimaryButton onClick={stop} style={{ background: "var(--color-wrong)" }}>
                {t("app.kx.timer.stop")}
              </LessonPrimaryButton>
              <LessonSecondaryButton onClick={() => setConfirming(false)}>{t("app.kx.timer.keepGoing")}</LessonSecondaryButton>
            </div>
          </div>
        ) : null}
      </div>
    </Float>
  );
}
