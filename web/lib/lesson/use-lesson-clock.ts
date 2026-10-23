"use client";

import { useEffect, useRef } from "react";

import type { LessonActivity } from "@micabo/core";

import { addStudyTime } from "@/lib/actions/lesson";

/**
 * **Le temps de révision, mesuré** : ce qu'on passe dans Notes, Quiz et Flashcards, ajouté à
 * la leçon quand l'écran se ferme ou que l'onglet passe en arrière-plan. Jumeau de
 * `LessonClock` côté Swift. Sans activité (l'Intro, la Conclusion), rien ne se compte.
 */
export function useLessonClock(lessonId: string, activity: LessonActivity | null): { elapsed: () => number } {
  const since = useRef<number | null>(null);
  const banked = useRef(0);

  useEffect(() => {
    if (!activity) return;
    since.current = Date.now();

    function flush() {
      if (since.current === null) return;
      const seconds = (Date.now() - since.current) / 1000;
      since.current = null;
      if (seconds < 1) return;
      banked.current += seconds;
      void addStudyTime(lessonId, seconds, activity!);
    }

    function visibility() {
      if (document.visibilityState === "visible") {
        if (since.current === null) since.current = Date.now();
      } else {
        flush();
      }
    }

    document.addEventListener("visibilitychange", visibility);
    return () => {
      document.removeEventListener("visibilitychange", visibility);
      flush();
    };
  }, [lessonId, activity]);

  return {
    /** Les secondes de cette ouverture, déjà envoyées ou pas : pour l'écran de fin. */
    elapsed: () => banked.current + (since.current === null ? 0 : (Date.now() - since.current) / 1000),
  };
}
