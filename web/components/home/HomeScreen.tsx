"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { ArrowUp, Crown, Flame, Loader2, Play, X, AlertCircle } from "lucide-react";

import {
  SUPPORT_ICONS,
  SUPPORT_KINDS,
  canSend,
  composeCreation,
  composerSource,
  hasRoom,
  isImportSource,
  isReading,
  studyTime,
  type ComposerSupport,
  type HomeStats,
  type LessonCreation,
  type LessonTone,
  type ResumeTarget,
  type SupportKind,
} from "@micabo/core";

import { ImportSheet } from "@/components/home/ImportSheet";
import { LessonCreationFlow } from "@/components/home/LessonCreation";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";
import { lessonPath } from "@/lib/lesson/routes";
import { requestPaywall } from "@/lib/paywall";

/**
 * **Home** (`docs/refonte-parcours.md` § 3) : la série en haut à droite, la grande question au
 * centre, la barre « comme une IA » avec Mika perché dessus (c'est elle qu'on voit d'abord),
 * les cinq supports en petit dessous, trois petits chiffres mesurés, et « Reprendre ». Jumeau
 * de `HomeView.swift`.
 *
 * Les supports se lisent dès qu'on les dépose, dans l'onglet : un PDF illisible le dit sur sa
 * pastille, pas trente secondes plus tard sur l'écran de génération. Envoyer assemble le tout
 * en une seule demande. La porte du gratuit se tient avant d'envoyer : PDF, Photo, Audio et
 * YouTube sont Pro, et un texte collé est la leçon offerte.
 */
export interface HomeScreenProps {
  isPro: boolean;
  hasUsedFreeLesson: boolean;
  stats: HomeStats;
  streak: number;
  resume: (ResumeTarget & { icon: string | null; tone: LessonTone }) | null;
}

export function HomeScreen(props: HomeScreenProps) {
  const { t, locale } = useI18n();
  const [draft, setDraft] = useState("");
  const [supports, setSupports] = useState<ComposerSupport[]>([]);
  const [sheet, setSheet] = useState<SupportKind | null>(null);
  const [creating, setCreating] = useState<{ creation: LessonCreation; hasSupports: boolean } | null>(null);
  const [focused, setFocused] = useState(false);
  const [mood, setMood] = useState<"wave" | "idle">("wave");
  const field = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    const timer = window.setTimeout(() => setMood("idle"), 2400);
    return () => window.clearTimeout(timer);
  }, []);

  const sendable = canSend(draft, supports);
  const reading = isReading(supports);
  const room = hasRoom(supports);

  const addSupport = useCallback((support: ComposerSupport) => {
    setSupports((current) => (current.length >= 5 ? current : [...current, support]));
  }, []);
  const updateSupport = useCallback((id: string, patch: Partial<ComposerSupport>) => {
    setSupports((current) => current.map((support) => (support.id === id ? { ...support, ...patch } : support)));
  }, []);
  const removeSupport = (id: string) => setSupports((current) => current.filter((support) => support.id !== id));

  /** PDF, Photo, Audio et YouTube sont Pro ; un texte collé est la leçon offerte. */
  function tapImport(kind: SupportKind) {
    if (kind !== "text" && !props.isPro) {
      field.current?.blur();
      requestPaywall("upgrade");
      return;
    }
    setSheet(kind);
  }

  function send() {
    if (!sendable) return;
    const source = composerSource(supports);
    if (!props.isPro && (isImportSource(source) || props.hasUsedFreeLesson)) {
      field.current?.blur();
      requestPaywall(isImportSource(source) ? "upgrade" : "send");
      return;
    }
    field.current?.blur();
    const creation = composeCreation(draft, supports, (text) => t("lesson.import.instruction", { text }));
    setCreating({ creation, hasSupports: creation.source !== "topic" });
  }

  const failure = supports.map((support) => support.failure).filter(Boolean).pop() ?? null;
  const time = studyTime(props.stats.seconds);

  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-[26px] pb-6">
      <div className="flex flex-col gap-2">
        <div className="flex justify-end">
          {props.streak > 1 ? (
            <span className="inline-flex items-center gap-1.5 rounded-pill px-3 py-1.5 text-[13px] font-extrabold" style={{ background: "var(--color-tone-yellow-pale)", color: "var(--color-tone-yellow-ink)" }}>
              <Flame aria-hidden="true" className="size-4" strokeWidth={2.6} />
              {t("app.today.streak", { count: props.streak })}
            </span>
          ) : null}
        </div>
        <HomeTitle text={t("lesson.home.title")} />
      </div>

      <div className="relative pt-[86px]">
        <div className="absolute left-1/2 top-0 z-10 -translate-x-1/2">
          <Mika mood={reading ? "think" : mood} size={96} label="" />
        </div>
        <div className={`home-bar flex min-h-[132px] flex-col justify-end gap-2.5 py-3 ps-5 pe-2.5 ${focused ? "home-bar-focused" : ""}`} data-tour="home-barre">
          {supports.length > 0 ? (
            <div className="flex flex-col gap-2">
              <ul className="-mx-1 flex gap-2 overflow-x-auto px-1 [scrollbar-width:none]">
                {supports.map((support) => (
                  <li key={support.id}>
                    <SupportChip support={support} onRemove={() => removeSupport(support.id)} removeLabel={t("lesson.home.removeSupport")} />
                  </li>
                ))}
              </ul>
              {failure ? <p className="text-[13px] font-bold text-wrong-ink">{failure}</p> : null}
            </div>
          ) : null}
          <div className="flex items-end gap-2.5">
            <textarea
              ref={field}
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              onFocus={() => setFocused(true)}
              onBlur={() => setFocused(false)}
              onKeyDown={(event) => {
                if (event.key === "Enter" && !event.shiftKey) {
                  event.preventDefault();
                  send();
                }
              }}
              rows={2}
              maxLength={2_000}
              placeholder={supports.length === 0 ? t("lesson.home.placeholder") : t("lesson.home.placeholderWithSupports")}
              aria-label={t("lesson.home.question")}
              className="min-h-[60px] flex-1 resize-none bg-transparent py-2.5 text-[20px] font-semibold leading-snug text-ink outline-none placeholder:text-ink-tertiary"
            />
            <button
              type="button"
              onClick={send}
              disabled={!sendable}
              aria-label={t("lesson.home.send")}
              className={`pressable flex size-[52px] shrink-0 items-center justify-center rounded-full text-white ${sendable ? "home-send" : "bg-ink-tertiary"}`}
            >
              <ArrowUp aria-hidden="true" className="size-6" strokeWidth={3} />
            </button>
          </div>
        </div>
      </div>

      <div className="flex flex-col gap-2">
        <ul className="grid grid-cols-5 gap-2" data-tour="home-supports">
          {SUPPORT_KINDS.map((kind) => (
            <li key={kind}>
              <button
                type="button"
                disabled={!room}
                onClick={() => tapImport(kind)}
                className="pressable relative flex w-full flex-col items-center gap-1 rounded-[16px] bg-surface/70 py-2 shadow-[inset_0_0_0_1px_var(--color-stroke)] disabled:opacity-50"
              >
                <MicaboIcon id={SUPPORT_ICONS[kind]} size={30} />
                <span className="max-w-full truncate px-1 text-[12px] font-extrabold text-ink-secondary">{t(`lesson.import.${kind}`)}</span>
                {kind !== "text" && !props.isPro ? (
                  <span aria-label="Pro" className="absolute -right-0.5 -top-0.5 flex size-4 items-center justify-center rounded-full" style={{ background: "var(--color-tone-yellow-pale)", color: "var(--color-tone-yellow-ink)" }}>
                    <Crown aria-hidden="true" className="size-2.5" strokeWidth={3} />
                  </span>
                ) : null}
              </button>
            </li>
          ))}
        </ul>
        {!room ? <p className="text-center text-[13px] font-bold text-ink-secondary">{t("lesson.home.supportsFull", { n: 5 })}</p> : null}
      </div>

      <ul className="grid grid-cols-3 gap-2" data-tour="home-chiffres">
        <StatPill icon="sablier" value={time.unit === "minutes" ? t("lesson.home.minutes", { n: time.value }) : t("lesson.home.hours", { n: new Intl.NumberFormat(localeBcp47(locale)).format(time.value) })} label={t("lesson.home.statTime")} />
        <StatPill icon="diplome" value={String(props.stats.learnedLessons)} label={t("lesson.home.statLessons")} />
        <StatPill icon="cartes" value={String(props.stats.learnedCards)} label={t("lesson.home.statCards")} />
      </ul>

      {props.resume ? <ResumeCard resume={props.resume} /> : null}

      {sheet ? (
        <ImportSheet
          kind={sheet}
          onClose={() => setSheet(null)}
          onBegin={(support) => {
            addSupport(support);
            setSheet(null);
          }}
          onUpdate={updateSupport}
        />
      ) : null}

      {creating ? (
        <LessonCreationFlow
          creation={creating.creation}
          hasSupports={creating.hasSupports}
          onCancel={() => setCreating(null)}
          onCreated={() => {
            setDraft("");
            setSupports([]);
          }}
        />
      ) : null}
    </div>
  );
}

/** **« Qu'est-ce que tu veux apprendre aujourd'hui ? »**, en grand, le mot marqué `**…**` en dégradé bleu-violet. */
function HomeTitle({ text }: { text: string }) {
  const parts = text.split("**");
  return (
    <h1 className="text-balance text-center text-[34px] font-extrabold leading-[1.1] tracking-tight-title text-ink">
      {parts.map((part, index) =>
        index % 2 === 1 ? (
          <span key={index} className="home-gradient-text">
            {part}
          </span>
        ) : (
          <span key={index}>{part}</span>
        ),
      )}
    </h1>
  );
}

/** Un support déposé : son icône, son nom, et où en est sa lecture. */
function SupportChip({ support, onRemove, removeLabel }: { support: ComposerSupport; onRemove: () => void; removeLabel: string }) {
  const failed = support.state === "failed";
  return (
    <span
      className={`flex items-center gap-2 rounded-pill py-[7px] ps-2.5 pe-2 ${failed ? "bg-wrong-soft shadow-[inset_0_0_0_1px_color-mix(in_srgb,var(--color-wrong)_40%,transparent)]" : "bg-canvas shadow-[inset_0_0_0_1px_var(--color-stroke)]"}`}
    >
      <span className="flex size-6 items-center justify-center">
        {support.state === "reading" ? <Loader2 aria-hidden="true" className="size-4 animate-spin text-ink-secondary" /> : <MicaboIcon id={SUPPORT_ICONS[support.kind]} size={22} />}
      </span>
      <span className={`max-w-[150px] truncate text-[14px] font-bold ${failed ? "text-wrong-ink" : "text-ink"}`}>{support.title}</span>
      <button type="button" onClick={onRemove} aria-label={removeLabel} className="pressable flex size-5 items-center justify-center rounded-full">
        {failed ? <AlertCircle aria-hidden="true" className="size-[17px] text-wrong" strokeWidth={2.4} /> : <X aria-hidden="true" className="size-4 text-ink-tertiary" strokeWidth={2.8} />}
      </button>
    </span>
  );
}

/** X h de révision · X leçons apprises · X flashcards apprises : trois petites pastilles de la même taille. */
function StatPill({ icon, value, label }: { icon: string; value: string; label: string }) {
  return (
    <li className="flex h-[62px] items-center gap-2 rounded-[16px] bg-surface px-2.5 shadow-[inset_0_0_0_1px_var(--color-stroke)]">
      <MicaboIcon id={icon} size={22} />
      <span className="flex min-w-0 flex-col">
        <span className="numeral truncate text-[16px] font-extrabold leading-tight text-ink">{value}</span>
        <span className="line-clamp-2 text-[11px] font-bold leading-tight text-ink-secondary">{label}</span>
      </span>
    </li>
  );
}

/** La dernière leçon ouverte : son anneau, son titre, l'étape où elle attend. */
function ResumeCard({ resume }: { resume: NonNullable<HomeScreenProps["resume"]> }) {
  const { t } = useI18n();
  const size = 60;
  const radius = (size - 5) / 2;
  const circumference = 2 * Math.PI * radius;
  const subtitle =
    resume.circleNumber !== null && resume.circleTitle !== null
      ? t("lesson.home.resumeCircle", { n: resume.circleNumber, title: resume.circleTitle })
      : t("lesson.home.resumeDone");
  return (
    <Link href={lessonPath(resume.lessonId)} className="pressable flex items-center gap-3.5 rounded-[24px] bg-surface p-4 shadow-floating">
      <span className="relative flex shrink-0 items-center justify-center" style={{ width: size, height: size }}>
        <svg aria-hidden="true" className="absolute inset-0" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
          <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--color-track)" strokeWidth={5} />
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={`var(--color-tone-${resume.tone}-vivid)`}
            strokeWidth={5}
            strokeLinecap="round"
            strokeDasharray={`${Math.max(0.02, resume.percent / 100) * circumference} ${circumference}`}
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
          />
        </svg>
        <MicaboIcon id={resume.icon} size={36} />
      </span>
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="text-[12px] font-bold uppercase tracking-caps" style={{ color: `var(--color-tone-${resume.tone}-ink)` }}>
          {t("lesson.home.resume")}
        </span>
        <span className="line-clamp-2 text-[17px] font-bold leading-snug text-ink">{resume.title}</span>
        <span className="truncate text-[14px] font-semibold text-ink-secondary">{subtitle}</span>
      </span>
      <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-ink text-on-ink">
        <Play aria-hidden="true" className="size-4 fill-current" strokeWidth={2.4} />
      </span>
    </Link>
  );
}
