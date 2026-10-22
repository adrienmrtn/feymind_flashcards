"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ChevronLeft } from "lucide-react";

import type { CircleReadiness, LessonTone, PathCircle } from "@micabo/core";

import { LessonHeader } from "@/components/lesson/LessonHeader";
import { LessonMenu } from "@/components/lesson/LessonMenu";
import { LessonNavbar } from "@/components/lesson/LessonNavbar";
import { PathMap } from "@/components/lesson/PathMap";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { openLesson } from "@/lib/actions/lesson";
import { useI18n } from "@/lib/i18n/client";
import { LESSONS_PATH, stepPath } from "@/lib/lesson/routes";

/**
 * **L'écran d'une leçon : son chemin.** Voir `docs/refonte-parcours.md` § 5.3.
 *
 * En haut, le retour, le menu « ⋯ » et Mika. La grande illustration de la leçon, son titre,
 * « 27 % · 3 sur 11 étapes » et la barre qui se remplit. Le chemin, centré sur l'étape en
 * cours à l'ouverture ; « Recommencer la leçon » tout en bas. En bas de l'écran, Notes, Quiz
 * et Flashcards. Jumeau de `LessonPathView`.
 *
 * Tout ce qui se lit est calculé par la page (le serveur) et passé ici ; ce qui s'écrit passe
 * par les actions de `lib/actions/lesson.ts`, puis la page se recharge.
 */
export interface LessonScreenProps {
  lessonId: string;
  title: string;
  icon: string | null;
  tone: LessonTone;
  circles: PathCircle[];
  done: string[];
  inCircle: number;
  readiness: Record<string, CircleReadiness>;
  percent: number;
  stepsLabel: string;
  shortenedLabel: string | null;
  examLabel: string | null;
  dueCount: number;
  mikaLabel: string;
}

export function LessonScreen(props: LessonScreenProps) {
  const { t } = useI18n();
  const router = useRouter();
  const [pastHeader, setPastHeader] = useState(false);
  const header = useRef<HTMLDivElement>(null);
  const opened = useRef(false);

  // La leçon vient de s'ouvrir : « Reprendre » sur Home la retrouvera.
  useEffect(() => {
    if (opened.current) return;
    opened.current = true;
    void openLesson(props.lessonId);
  }, [props.lessonId]);

  // Passé l'en-tête, son titre monte dans la barre du haut.
  useEffect(() => {
    const element = header.current;
    if (!element) return;
    const observer = new IntersectionObserver(([entry]) => setPastHeader(entry ? !entry.isIntersecting : false), { threshold: 0.1 });
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  function open(circle: PathCircle) {
    router.push(stepPath(props.lessonId, circle.id));
  }

  return (
    <div className="relative -mt-2">
      <div
        className={`sticky top-0 z-30 -mx-4 flex items-center gap-3 px-4 py-2 lg:-mx-10 lg:px-10 ${
          pastHeader ? "border-b border-hairline bg-canvas/90 backdrop-blur-sm" : ""
        }`}
      >
        <Link
          href={LESSONS_PATH}
          aria-label={t("common.back")}
          className="pressable flex size-10 items-center justify-center rounded-full bg-surface text-ink shadow-floating"
        >
          <ChevronLeft aria-hidden="true" className="size-5" strokeWidth={2.6} />
        </Link>
        <span className={`min-w-0 flex-1 truncate text-center text-[17px] font-extrabold text-ink transition-opacity ${pastHeader ? "opacity-100" : "opacity-0"}`}>
          {props.title}
        </span>
        <LessonMenu lessonId={props.lessonId} title={props.title} canReset={props.done.length > 0} />
        <span
          aria-label={props.mikaLabel}
          role="img"
          className="flex size-10 items-center justify-center rounded-full bg-surface shadow-floating"
          title={props.mikaLabel}
        >
          <MicaboIcon id="mika" size={34} />
        </span>
      </div>

      <div ref={header} className="pb-11 pt-8">
        <LessonHeader
          title={props.title}
          icon={props.icon}
          tone={props.tone}
          percent={props.percent}
          stepsLabel={props.stepsLabel}
          shortenedLabel={props.shortenedLabel}
          examLabel={props.examLabel}
        />
      </div>

      <div className="mx-auto w-full max-w-[520px]">
        <PathMap
          circles={props.circles}
          done={props.done}
          inCircle={props.inCircle}
          readiness={props.readiness}
          tone={props.tone}
          onOpen={open}
        />
      </div>

      <LessonNavbar lessonId={props.lessonId} dueCount={props.dueCount} />
    </div>
  );
}
