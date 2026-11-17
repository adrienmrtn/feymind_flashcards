import { withCors } from "../_shared/caller.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * **L'import de vidéo YouTube est retiré** (demande du fondateur, novembre 2026) : c'était la
 * fonction d'IA la plus chère de Micabo — quand les sous-titres manquaient, Gemini regardait
 * la vidéo. Les apps à jour n'appellent plus cette fonction ; elle ne lit plus rien, ne
 * décompte rien et répond **410** à tout appel.
 *
 * Le code `no_captions` est choisi pour les versions déjà installées, qui le disent dans la
 * langue de l'élève sans rien ouvrir d'autre :
 * - iPhone (`YouTubeImportError.noCaptions`) : « Micabo n'a pas pu lire cette vidéo.
 *   Réessaie, ou colle le texte du cours. » ;
 * - Android (`YouTubeImport`, tout code inconnu ou `no_captions`) : la même phrase
 *   (`ios_yt_noCaptions`) ;
 * - site (`lib/actions/youtube.ts`, retiré avec ce changement) : le message ci-dessous.
 *
 * Les leçons déjà écrites depuis une vidéo restent lisibles : elles ne repassent jamais par ici.
 */
const REMOVED = {
  error: "L'import de vidéos YouTube n'est plus disponible. Colle le texte du cours à la place.",
  code: "no_captions",
  reason: "youtube_removed",
};

Deno.serve((request: Request) =>
  withCors(request, () =>
    Promise.resolve(
      new Response(JSON.stringify(REMOVED), {
        status: 410,
        headers: { "Content-Type": "application/json" },
      }),
    )
  )
);
