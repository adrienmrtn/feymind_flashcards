import "server-only";

import { QUIZ_KINDS } from "@micabo/core";

import { readProfile } from "@/lib/data/profile";
import { readUiLocale } from "@/lib/i18n/server";

/**
 * **Pour qui on écrit** : ce que `generate-lesson` lit du profil pour régler le registre et le
 * volume (`supabase/functions/_shared/learner.ts`). Jumeau de `LessonAudience` côté Swift,
 * avec ce que le profil du site connaît : le palier, le pays, la langue de l'interface — qui
 * est aussi celle des notes, comme sur l'iPhone. La marche, la filière et la classe exacte
 * que le parcours du site n'a pas demandées restent absentes, et le serveur a ses valeurs
 * par défaut.
 *
 * `kinds` dit les formes de question que le site sait afficher : les cinq. Sans lui, le
 * serveur ne rendrait que des QCM.
 */
export interface LessonAudience {
  level: string;
  country: string;
  schoolStage: string;
  language: string;
  kinds: string[];
  exam?: string;
}

export async function lessonAudience(options: { language?: string | null; exam?: string | null } = {}): Promise<LessonAudience> {
  const [profile, locale] = await Promise.all([readProfile(), readUiLocale()]);
  const audience: LessonAudience = {
    level: profile?.study_level ?? "",
    country: profile?.country_code ?? "",
    schoolStage: "",
    language: options.language || locale,
    kinds: [...QUIZ_KINDS],
  };
  if (options.exam) audience.exam = options.exam;
  return audience;
}
