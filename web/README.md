# Le site

Le compagnon web de Micabo : même Supabase, mêmes leçons, même chemin, mêmes flashcards — et
délibérément pas la même app. **L'iPhone est la poche, le site est le bureau.**

Le plan de la refonte « parcours », ses décisions et ses dix lots vivent dans
[`../docs/refonte-web.md`](../docs/refonte-web.md) ; la conception d'origine, l'authentification,
l'abonnement et le déploiement dans [`../docs/web.md`](../docs/web.md). Ce fichier ne dit que
comment le faire tourner.

## Ce qu'il y a ici

```
web/
  app/                 Next.js 16, App Router. `globals.css` porte tous les jetons, clair et sombre
    app/               l'app connectée : Home, Leçons, Examen, Profil, et la leçon sous lecons/[id]
    api/lesson/        plan, theme, convert, exam, practice — le navigateur conduit la génération
  components/          lesson/ (le chemin, les étapes, le quiz, les flashcards, Mika), home/, lessons/,
                       exams/, profile/, landing/, onboarding/, app/ (la charpente, la visite, le paywall)
  lib/                 données (`data/`), actions serveur, i18n, la porte du gratuit (`paywall.ts`)
  packages/core/       @micabo/core : ce que l'iPhone et le web doivent partager — SM-2, lesson/
                       (chemin, tirages, stats), allowance, entitlement
  public/icons3d/      les 34 icônes 3D de l'app, et design/mika pour l'oiseau
  scripts/demo/        un faux Supabase pour regarder l'app sans compte, et les captures
```

`@micabo/core` est pur — pas de réseau, pas de base, pas de React — et ses tests reprennent
les valeurs attendues de `MicaboTests/` : `lesson/` porte `PathLayout`, `LessonPicking` et
`HomeStats`, `srs/sm2.ts` porte `SM2Scheduler`, et `freemium-parity.test.ts` compare les nombres
du gratuit au Swift. **Deux copies d'une règle finissent par diverger**, et le jour où elles
divergent une étape cochée sur le téléphone ne l'est pas sur le site.

## Les quatre onglets

```
/app                        Home — Mika, la question, la barre et ses cinq supports, Reprendre
/app/lecons                 Leçons
/app/lecons/[id]            le chemin : Intro · Notes × N · Checkpoints · Quiz final
/app/lecons/[id]/etape/…    une étape ; /notes (imprimable), /quiz, /flashcards, /mika
/app/examen                 Examen — le prochain, J-12, l'examen blanc
/app/profil                 Profil — le compte, Pro, le classement, les amis, les réglages
```

Les anciennes adresses (`/app/c/[id]`, `/app/reviser`, `/app/plan`, `/app/progres`,
`/app/importer`, `/app/paquets`, `/app/reglages`, `/app/amis`…) redirigent.

## Commandes

```bash
pnpm install
pnpm dev          # http://localhost:3000
pnpm test         # @micabo/core puis le site (vitest)
pnpm typecheck
pnpm build
pnpm verify       # les trois d'un coup, dans l'ordre où ils échouent le mieux — ce que web.yml fait à chaque push
```

## Les textes, dans les cinq langues

Les catalogues sont dans `lib/i18n/catalogs/`, en français, anglais, allemand, espagnol et turc,
et un test de parité exige les mêmes clés partout. Deux d'entre eux ne s'éditent pas à la main :

```bash
node scripts/sync-lesson-catalogs.mjs      # lesson-*.ts, copie stricte de LessonI18nCatalogs.swift
cd .. && node --experimental-strip-types --import ./scripts/ts-extensions.mjs ./scripts/export-i18n-catalogs.ts
                                           # l'inverse : les clés communes vers SharedI18nCatalogs.swift
```

Une clé qui n'existe que sur le site va dans `app-*.ts` (par exemple `app.lessonsList.*`), jamais
dans `lesson-*.ts`.

## Regarder l'app connectée sans compte

`scripts/demo/` est un faux Supabase : un serveur HTTP qui répond au jeton par mot de passe, à
l'utilisateur, aux lectures PostgREST (`eq`, `is`, `in`, `gte`, `order`, `limit`…), aux RPC
(`begin_lesson`, `begin_extra`, `is_pro`…) et aux fonctions Edge, sur un jeu de données fictif :
des leçons dont une au nouveau format avec son chemin, des examens, des flashcards, un journal.
Les écritures sont gardées **en mémoire**, donc une étape cochée reste cochée et un examen blanc
se relit. C'est ce qui permet de regarder chaque écran de `/app` et de faire des captures sans
toucher au projet.

```bash
node scripts/demo/server.mjs                                   # écoute sur 54329
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54329 pnpm dev
open "http://localhost:3000/auth/dev?email=camille@micabo.test&password=demo"
```

La route `/auth/dev` est inerte en production et n'accepte que les adresses `@micabo.test`. Le
compte de démonstration est Pro.

### Les captures

[`../docs/captures/web/`](../docs/captures/web/) montre chaque écran, en clair et en sombre, sur
téléphone et sur grand écran, et les Notes telles qu'elles s'impriment. Elles se refont en une
commande, le faux Supabase et le site étant en route :

```bash
node scripts/demo/captures.mjs             # CHROME=/chemin/vers/chromium si besoin
```

## Le bureau

- **Le clavier.** Espace ou Entrée retourne une flashcard, 1 · 2 · 3 la notent (Encore · Bien ·
  Facile). Dans un quiz, 1 à 4 choisissent, Espace ou Entrée continue. Dans les Notes, ← et →
  tournent la page. Chaque étape du chemin est un bouton : Tab s'y arrête, Entrée l'ouvre.
- **L'impression.** `/app/lecons/[id]/notes` s'imprime sans la charpente ni le sommaire, les
  définitions ouvertes, les titres jamais seuls en bas de page (`@media print` dans
  `globals.css`, `data-print="hide"` et `"keep"`).
- **Le sombre.** `data-appearance` sur `<html>` (`day`, `night`, `twilight`, ou le système) ;
  chaque jeton de `globals.css` a sa valeur de nuit, portée de `MicaboPalette`.

## Aucune variable d'environnement n'est nécessaire

L'URL du projet Supabase et la clé publiable sont dans [`lib/config.ts`](lib/config.ts), en
clair, comme elles le sont déjà dans `Micabo/Services/AppConfig.swift`. La clé est un jeton de
rôle `anon` : tout ce qu'elle peut lire est ce que le cloisonnement de Postgres autorise à un
visiteur anonyme, c'est-à-dire rien. `process.env` reste prioritaire.

Les vrais secrets — clé de service, Stripe, webhook RevenueCat — vivent sur Vercel, et **aucun
ne porte le préfixe `NEXT_PUBLIC_`** : ce préfixe sur la clé de service publierait un accès total
à la base dans le paquet JavaScript.

## Ce qu'il faut savoir avant de déployer

- `generate-lesson` doit être déployée sur le projet de production, et les trois migrations
  `lesson_*` passées : `supabase/prod-check.sh`, lancé par `prod.yml`, le vérifie de
  l'extérieur. Sans elles, un ancien cours s'ouvre « sans attendre » et la barre dit que la
  création est indisponible.
- Les origines de `supabase/functions/_shared/caller.ts` acceptent déjà `micabo.app` et les
  prévisualisations `micabo*.vercel.app` ; rien à ajouter.
- La refonte n'ajoute **aucune migration** et aucune variable d'environnement.
- `/api/lesson/*` porte `maxDuration = 120` : un thème prend dix à vingt secondes, un plan cinq
  à dix.

Le site s'indexe **en production seulement** (`lib/config.ts`, `IS_INDEXABLE`) : une
prévisualisation indexée se présenterait dans les résultats à la place du site, avec une URL
qui meurt au déploiement suivant. L'app connectée, le parcours et les retours
d'authentification restent hors index par en-tête `X-Robots-Tag` (`next.config.ts`). Le reste —
hôte canonique, sitemap, données structurées, favicon et logo — est dans
**[`docs/seo.md`](../docs/seo.md)**.
