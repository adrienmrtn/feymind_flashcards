# Le site

Le compagnon web de Micabo : même Supabase, mêmes cours, même fiche, mêmes cartes — et
délibérément pas la même app. **L'iPhone est la poche, le site est le bureau.**

Le plan complet, les décisions et ce qui reste ouvert vivent dans
[`../docs/web.md`](../docs/web.md). Ce fichier ne dit que comment le faire tourner.

## Ce qu'il y a ici

```
web/
  app/                 Next.js 16, App Router. `globals.css` porte tous les jetons
  lib/                 configuration et clients Supabase
  packages/core/       les règles que l'iPhone et le web doivent partager
```

`@micabo/core` est le cœur du monorepo, et sa raison d'être tient en une phrase : **deux copies
de la formule SM-2 finiront par diverger, et le jour où elles divergent une carte est révisée
deux fois.** Tout ce qui y vit est pur — pas de réseau, pas de base, pas de React — ce qui
permet aux tests de reprendre telles quelles les valeurs attendues de `MicaboTests/`.

| Module | Porté depuis |
| --- | --- |
| `srs/sm2.ts` | `Micabo/SRS/SM2Scheduler.swift` |
| `srs/daily-load.ts` | `Micabo/SRS/DailyLoad.swift` |
| `srs/queue.ts` | `Micabo/SRS/StudyQueue.swift` |
| `srs/exam.ts` | `Micabo/SRS/ExamPlanner.swift`, `ExamDeadlines.swift` |
| `sheet/markup.ts` | `Micabo/Services/SheetMarkup.swift` |
| `retention.ts` | `RetentionChartStepView.swift` |
| `sheet/canonical.ts` | **copie** de `supabase/functions/_shared/sheet.ts` |
| `entitlement.ts` | rien — le verrou du gratuit n'existe pas encore côté iOS |

### La copie du module de fiche

`sheet/canonical.ts` est une copie, pas un port : l'original tourne sous Deno, importe ses
modules avec l'extension `.ts`, et le `rootDirectory` de Vercel est `web/`, donc `supabase/`
n'est pas dans le contexte de compilation du site.

Une copie non surveillée dérive. Celle-ci l'est : `test/sheet-parity.test.ts` relit les deux
fichiers et échoue **à l'octet près**. Quand l'original bouge :

```bash
pnpm --filter @micabo/core sync:sheet
```

## Commandes

```bash
pnpm install
pnpm dev          # http://localhost:3000
pnpm test         # les 90 tests de @micabo/core
pnpm typecheck
pnpm build
pnpm verify       # les trois d'un coup, dans l'ordre où ils échouent le mieux
```

## Aucune variable d'environnement n'est nécessaire

L'URL du projet Supabase et la clé publiable sont dans [`lib/config.ts`](lib/config.ts), en
clair, comme elles le sont déjà dans `Micabo/Services/AppConfig.swift`. La clé est un jeton de
rôle `anon` : tout ce qu'elle peut lire est ce que le cloisonnement de Postgres autorise à un
visiteur anonyme, c'est-à-dire rien. `process.env` reste prioritaire.

Les vrais secrets — clé de service, Stripe, webhook RevenueCat — n'arrivent qu'à l'étape 5, et
**aucun ne porte le préfixe `NEXT_PUBLIC_`** : ce préfixe sur la clé de service publierait un
accès total à la base dans le paquet JavaScript.

## L'état des lieux

L'étape 1 est faite : le monorepo, les jetons, `@micabo/core` et ses tests. La page à la racine
est **la référence des fondations, pas la page d'accueil** — elle affiche les jetons et calcule
tous ses nombres avec `@micabo/core`, ce qui en fait aussi une vérification de bout en bout. La
vraie page d'accueil arrive à l'étape 2, et celle-ci passera sous `/fondations`.

Le site n'est pas indexable (`lib/config.ts`, `IS_INDEXABLE`) : il n'y a rien à trouver encore,
et une prévisualisation indexée se présenterait à la place du site.
