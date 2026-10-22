"use client";

import Link from "next/link";
import { ChevronDown, X } from "lucide-react";

import type { LessonTone } from "@micabo/core";

import { KeywordText } from "@/components/lesson/KeywordText";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { ToneBox } from "@/components/lesson/NoteBlocks";
import { ThemeBody, type StepTheme } from "@/components/lesson/NotesCircle";
import { PathSymbol } from "@/components/lesson/PathSymbol";
import { Spinner } from "@/components/ui/spinner";
import { useI18n } from "@/lib/i18n/client";
import { lessonPath } from "@/lib/lesson/routes";
import { useLessonClock } from "@/lib/lesson/use-lesson-clock";

/**
 * **Les notes entières de la leçon**, sur un seul document : la leçon, son sommaire (un appui
 * mène au thème), puis chaque thème, numéroté, avec ses notes complètes. Pour relire avant un
 * contrôle, d'une traite, ou l'imprimer. Jumeau de `LessonNotesReader`.
 */
export function LessonNotesReader({
  lessonId,
  title,
  subject,
  icon,
  tone,
  themes,
  symbols,
  takeaways,
}: {
  lessonId: string;
  title: string;
  subject: string | null;
  icon: string | null;
  tone: LessonTone;
  themes: StepTheme[];
  /** Le pictogramme de chaque thème sur le chemin, dans l'ordre. */
  symbols: string[];
  takeaways: string[];
}) {
  const { t } = useI18n();
  useLessonClock(lessonId, "notes");
  const ink = `var(--color-tone-${tone}-ink)`;

  return (
    <article className="mx-auto flex w-full max-w-[640px] flex-col gap-8 pb-10">
      <div className="flex items-center justify-between" data-print="hide">
        <Link href={lessonPath(lessonId)} aria-label={t("lesson.circle.close")} className="pressable flex size-10 items-center justify-center rounded-full text-ink hover:bg-surface-muted">
          <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
        </Link>
        <span className="text-[15px] font-bold text-ink-secondary">{t("lesson.notes.full")}</span>
        <span className="size-10" />
      </div>

      <header className="flex items-center gap-4">
        <MicaboIcon id={icon} size={72} />
        <div className="flex min-w-0 flex-col gap-1">
          <h1 className="text-[26px] font-extrabold leading-tight tracking-tight-title text-ink">{title}</h1>
          {subject ? <p className="text-[15px] font-semibold text-ink-secondary">{subject}</p> : null}
        </div>
      </header>

      <nav aria-label={t("lesson.notes.summary")} className="flex flex-col gap-1 rounded-[22px] bg-surface p-4 shadow-floating" data-print="hide">
        <p className="pb-1.5 text-[12px] font-bold uppercase tracking-caps text-ink-secondary">{t("lesson.notes.summary")}</p>
        {themes.map((theme, index) => (
          <a key={theme.id} href={`#theme-${theme.id}`} className="pressable flex items-center gap-3 py-1.5">
            <span className="flex size-[34px] shrink-0 items-center justify-center rounded-full" style={{ background: `var(--color-tone-${tone}-pale)`, color: ink }}>
              <PathSymbol id={symbols[index] ?? ""} size={16} strokeWidth={2.6} />
            </span>
            <span className="flex-1 text-[17px] font-bold text-ink">
              {index + 1}. {theme.title}
            </span>
            <ChevronDown aria-hidden="true" className="size-3.5 text-ink-tertiary" strokeWidth={2.6} />
          </a>
        ))}
      </nav>

      {themes.map((theme, index) => (
        <section key={theme.id} id={`theme-${theme.id}`} className="flex scroll-mt-6 flex-col gap-[18px]">
          <div className="flex items-center gap-3.5">
            <MicaboIcon id={theme.icon} size={48} />
            <div className="flex flex-col gap-0.5">
              <p className="text-[13px] font-extrabold uppercase tracking-[1.2px]" style={{ color: ink }}>
                {t("lesson.notes.themeNumber", { n: index + 1 })}
              </p>
              <h2 className="text-[26px] font-bold leading-tight text-ink">{theme.title}</h2>
            </div>
          </div>
          {theme.status === "pending" && !theme.notes && theme.sheet.length === 0 ? (
            <p className="flex items-center gap-2.5 text-[15px] font-bold text-ink-secondary">
              <Spinner className="size-4" />
              {t("lesson.notes.writing")}
            </p>
          ) : (
            <ThemeBody theme={theme} tone={tone} />
          )}
          <hr className="mt-2 border-0 border-t border-hairline" />
        </section>
      ))}

      {takeaways.length > 0 ? (
        <ToneBox label={t("lesson.conclusion.title")} tone={tone}>
          <ul className="flex flex-col gap-2.5">
            {takeaways.map((line, index) => (
              <li key={index} className="flex items-baseline gap-2.5 text-[17px] leading-[1.35] text-ink">
                <span aria-hidden="true" className="font-black" style={{ color: ink }}>
                  ✓
                </span>
                <span>
                  <KeywordText text={line} />
                </span>
              </li>
            ))}
          </ul>
        </ToneBox>
      ) : null}
    </article>
  );
}
