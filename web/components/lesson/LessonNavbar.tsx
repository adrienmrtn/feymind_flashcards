"use client";

import Link from "next/link";

import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { useI18n } from "@/lib/i18n/client";
import { flashcardsPath, notesPath, quizPath } from "@/lib/lesson/routes";

/**
 * **La barre du bas d'une leçon** : Notes, Quiz, Flashcards, trois grandes icônes posées sur
 * un fondu, sans cadre. Les cartes à revoir aujourd'hui se comptent sur la pastille.
 * Jumeau de `LessonNavbar` côté Swift.
 */
export function LessonNavbar({ lessonId, dueCount = 0 }: { lessonId: string; dueCount?: number }) {
  const { t } = useI18n();
  const entries = [
    { href: notesPath(lessonId), icon: "fiche", label: t("lesson.nav.notes"), badge: 0 },
    { href: quizPath(lessonId), icon: "quiz", label: t("lesson.nav.quiz"), badge: 0 },
    { href: flashcardsPath(lessonId), icon: "cartes", label: t("lesson.nav.flashcards"), badge: dueCount },
  ];
  return (
    <nav
      aria-label={t("lesson.nav.notes") + " · " + t("lesson.nav.quiz") + " · " + t("lesson.nav.flashcards")}
      className="lesson-bottom-bar -mx-4 mt-2 px-3 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-7 lg:-mx-10"
      style={{ background: "linear-gradient(to bottom, color-mix(in srgb, var(--color-canvas) 0%, transparent), color-mix(in srgb, var(--color-canvas) 92%, transparent) 38%, var(--color-canvas))" }}
      data-print="hide"
    >
      <div className="mx-auto flex max-w-[520px]">
        {entries.map((entry) => (
          <Link key={entry.icon} href={entry.href} className="pressable relative flex flex-1 flex-col items-center gap-1.5 py-1">
            <span className="relative">
              <MicaboIcon id={entry.icon} size={50} className="drop-shadow-[0_4px_6px_rgba(0,0,0,0.08)]" />
              {entry.badge > 0 ? (
                <span className="absolute -right-2 -top-0.5 rounded-pill bg-wrong px-1.5 py-0.5 text-[12px] font-extrabold leading-none text-white">
                  {entry.badge}
                </span>
              ) : null}
            </span>
            <span className="text-[16px] font-bold text-ink">{entry.label}</span>
          </Link>
        ))}
      </div>
    </nav>
  );
}
