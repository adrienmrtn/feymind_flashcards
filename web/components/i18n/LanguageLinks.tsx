"use client";

import { usePathname } from "next/navigation";

import { useI18n } from "@/lib/i18n/client";
import { UI_LOCALES, UI_LOCALE_META } from "@/lib/i18n/locales";
import { localeSwitchHref } from "@/lib/i18n/paths";

/**
 * **Les quatre autres langues de la page, en vrais liens.**
 *
 * Le sélecteur de la barre (`LanguageSwitcher`) est un `<select>` : il change la langue sur
 * un `onChange`, en JavaScript. Un robot ne déclenche pas d'`onChange`, et un `<option>`
 * n'est pas un lien. Résultat, les 24 adresses traduites — `/fr/methode`, `/de/mode-examen`,
 * … — n'étaient **citées nulle part dans le HTML du site**. Elles n'existaient que dans le
 * `sitemap.xml` et dans les annotations `hreflang`.
 *
 * Or `hreflang` ne fait pas découvrir une page : il regroupe des adresses que Google connaît
 * déjà, il ne les recommande pas et ne leur transmet rien. Une page que rien ne lie est une
 * page orpheline, et une page orpheline trouvée dans un sitemap est précisément ce que la
 * Search Console appelle « détectée, actuellement non indexée » : l'adresse est connue, mais
 * rien dans le site ne dit qu'elle vaut le déplacement, alors le robot la remet à plus tard.
 *
 * Ces liens-là réparent ça : chacune des 30 adresses en reçoit quatre, depuis le pied de
 * page de toutes les autres langues, et le maillage devient complet.
 *
 * **Une balise `<a>` nue, pas un `Link`.** Changer de langue doit recharger le document :
 * `/fr/methode` est réécrit en `/methode`, et une navigation client resservirait le cache
 * RSC de l'ancienne langue — c'est déjà la raison du `window.location.assign` du sélecteur.
 * Un `<a>` fait la navigation complète, et c'est aussi ce qui en fait un lien explorable.
 *
 * Le cookie de langue n'est pas posé ici : le middleware le pose en lisant le préfixe de
 * l'adresse. Sur une page indexable, c'est l'adresse qui décide, jamais le cookie.
 */
export function LanguageLinks({ className }: { className?: string }) {
  const { locale, t } = useI18n();
  const pathname = usePathname();

  // `localeSwitchHref` retire le préfixe avant de reposer le bon : il rend la même
  // adresse qu'on lui donne `/methode` (rendu serveur, après réécriture) ou
  // `/fr/methode` (barre d'adresse, après hydratation). Pas de désaccord possible.
  const links = UI_LOCALES.filter((code) => code !== locale).flatMap((code) => {
    const href = localeSwitchHref(pathname, code);
    return href ? [{ code, href }] : [];
  });

  // Hors des pages indexables (l'app, le parcours) il n'y a pas d'adresse traduite à
  // désigner : le sélecteur de la barre suffit, et le cookie fait le reste.
  if (links.length === 0) return null;

  return (
    <div className={className}>
      <p className="eyebrow mb-3 text-ink-tertiary">{t("locale.choose")}</p>
      <ul className="space-y-1.5 text-ink-secondary">
        {links.map(({ code, href }) => (
          <li key={code}>
            <a
              href={href}
              hrefLang={code}
              lang={UI_LOCALE_META[code].html}
              className="underline-draw"
              data-print="bare"
            >
              {UI_LOCALE_META[code].native}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
