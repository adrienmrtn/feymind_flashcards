import "server-only";

import { readProfile } from "@/lib/data/profile";
import { currentUserId } from "@/lib/data/user";
import { readUiLocale } from "@/lib/i18n/server";
import { readLocalLearner } from "@/lib/lesson/learner-cookie";
import { buildAudience, type LessonAudience } from "@/lib/lesson/learner";

export type { LessonAudience } from "@/lib/lesson/learner";

/**
 * **Pour qui on écrit** : ce que `generate-lesson` lit du profil pour régler le registre, le
 * volume et la profondeur (`supabase/functions/_shared/learner.ts`). Jumeau de
 * `LessonAudience.current` côté Swift, et la même charge, champ par champ (`buildAudience`).
 *
 * Deux sources, comme sur l'iPhone. La ligne `profiles` porte ce que tous les clients
 * partagent : le registre, le pays, la langue des fiches. Le cookie `micabo.learner` porte ce
 * que l'iPhone garde dans `UserDefaults` sans le synchroniser : le palier exact, sa marche,
 * les deux moyennes du parcours d'accueil.
 *
 * **La langue est celle du profil pour toutes les étapes**, plan, thème, entraînement, examen
 * blanc et conversion : c'est ce que fait `LessonBuilder`, qui relit `audience()` à chaque
 * appel. La langue de l'interface ne sert que sans profil.
 */
export async function lessonAudience(options: { exam?: string | null } = {}): Promise<LessonAudience> {
  const [profile, locale, userId] = await Promise.all([readProfile(), readUiLocale(), currentUserId()]);
  const local = await readLocalLearner(userId);
  return buildAudience({
    profile: profile
      ? { study_level: profile.study_level, country_code: profile.country_code, sheet_language: profile.sheet_language }
      : null,
    local,
    uiLocale: locale,
    exam: options.exam ?? null,
  });
}
