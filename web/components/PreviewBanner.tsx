import { PRODUCTION_URL } from "@/lib/config";

/**
 * Le bandeau des aperçus.
 *
 * Un déploiement d'aperçu est **figé sur son commit** : l'adresse
 * `micabo-git-<branche>-…vercel.app` reste servie des heures après que la
 * branche a été fusionnée, et un onglet laissé ouvert dessus montre encore
 * l'ancien produit - même après un rechargement forcé. C'est un piège qui
 * coûte cher : on croit qu'un correctif n'est pas passé alors qu'on regarde
 * un site d'avant.
 *
 * Il ne s'affiche donc **que hors production**, et il dit où est le vrai site.
 */
export function PreviewBanner() {
  if (process.env.VERCEL_ENV === "production" || !process.env.VERCEL_ENV) return null;

  const branch = process.env.VERCEL_GIT_COMMIT_REF;

  return (
    <div
      className="fixed inset-x-0 top-0 z-[60] flex flex-wrap items-center justify-center gap-x-3 gap-y-1 bg-caution-vivid px-4 py-2 text-center text-[12.5px] font-medium text-ink"
      data-print="hide"
    >
      <span>
        Aperçu figé{branch ? ` de ${branch}` : ""} - ce n&apos;est pas le site.
      </span>
      <a href={PRODUCTION_URL} className="font-semibold underline">
        Ouvrir Micabo
      </a>
    </div>
  );
}
