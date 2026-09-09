import { localeBcp47 } from "@/lib/i18n/copy";
import type { UiLocale } from "@/lib/i18n/locales";

/**
 * **La semaine, écrite dans la langue de celui qui la lit.**
 *
 * Rien n'est écrit en dur : ni « L M M J V S D », ni « M T W T F S S ». Les initiales sortent
 * d'`Intl`, qui connaît les sept jours dans les cinq langues du site et dans toutes celles
 * qu'on ajoutera. Une liste de lettres tapée à la main serait juste en français, fausse en
 * turc, et personne ne s'en apercevrait avant qu'un étudiant turc ne se demande quel jour il
 * vient de cocher.
 *
 * La semaine commence **lundi**, partout. C'est le premier jour de la semaine dans les cinq
 * langues du site, c'est celui du calendrier de création de plan, et un parcours qui commence
 * la semaine un jour et l'app un autre fait douter des deux.
 */

export interface WeekDay {
  /** Le numéro ISO : 1 pour lundi, 7 pour dimanche. C'est ce qui est enregistré. */
  iso: number;
  /** L'initiale, pour la case : « L », « M »… */
  initial: string;
  /** Le nom entier, pour ceux qui écoutent la page plutôt que de la regarder. */
  full: string;
}

/** Un lundi quelconque, pris comme origine. Le 1er janvier 2024 en était un. */
const MONDAY = Date.UTC(2024, 0, 1);

export function weekDays(locale: UiLocale): WeekDay[] {
  const bcp = localeBcp47(locale);
  return Array.from({ length: 7 }, (_, index) => {
    const day = new Date(MONDAY + index * 86_400_000);
    return {
      iso: index + 1,
      // `narrow` donne bien l'initiale seule ; certaines langues en rendent deux, et c'est
      // leur affaire - la case est assez large.
      initial: day.toLocaleDateString(bcp, { weekday: "narrow", timeZone: "UTC" }),
      full: day.toLocaleDateString(bcp, { weekday: "long", timeZone: "UTC" }),
    };
  });
}
