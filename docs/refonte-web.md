# Refonte « parcours » du site

Le site est resté l'app d'avant : un tableau de bord « Aujourd'hui », un onglet Réviser, des
fiches à 30 %, un planificateur d'examen, des paquets de cartes. L'iPhone, lui, est devenu
**une leçon en chemin** (`docs/refonte-parcours.md`) : Mika, une barre, des étapes, des
checkpoints, un quiz final, les flashcards par leçon. Ce document dit comment le site rejoint
l'app, en dix lots, chacun livrable seul.

La règle qui commande tout : **le site est un deuxième client de la même leçon**, pas une
deuxième app. Il lit et écrit les mêmes colonnes que l'iPhone (`courses.path`, `progress`,
`tone`, `icon`, `last_opened_at` ; `chapters.notes`, `quiz`, `icon`, `status`), appelle la
même fonction `generate-lesson`, passe par la même porte serveur (`begin_lesson`,
`begin_extra`). Une étape cochée sur le site est cochée sur le téléphone à la synchro
suivante, et réciproquement : `touch_updated_at` date la ligne, l'iPhone relit la plus
récente (`CloudSync`, « une colonne vide ne vide rien »).

Ce qui reste du site d'aujourd'hui : **le bureau**. Un grand écran, le clavier, l'impression
des notes, et ce qui fait qu'un cours se relit la veille au soir sur un ordinateur.

---

## 0. Les décisions, en une table

| Sujet | Décision |
| --- | --- |
| Référence | **Le code iOS**, pas le PDF : le chemin est Intro · Notes × N · un Checkpoint après chaque palier sauf le dernier · Quiz final (`PathLayout.swift`). Les flashcards vivent dans la barre du bas ; la Conclusion est le « À retenir » du Quiz final |
| Lexique | Leçon · Étape (« Étape 4 ») · Checkpoint · Quiz final · Thème · Notes · Quiz · Flashcards. Les chaînes viennent de `LessonI18nCatalogs.swift`, copiées sur le site avec un test de parité |
| Onglets | **Home, Leçons, Examen, Profil**, en barre latérale sur grand écran, en barre d'onglets sous `lg`. Plus d'« Importer » : on crée depuis Home |
| Adresses | `/app` (Home) · `/app/lecons` · `/app/lecons/[id]` (le chemin) · `/app/examen` · `/app/profil`. Les anciennes (`/app/c/[id]`, `/app/reviser`, `/app/plan`, `/app/progres`, `/app/importer`, `/app/paquets`, `/app/amis`, `/app/reglages`) **redirigent** : un lien dans un mail ou un onglet épinglé ne meurt pas |
| Génération | Le navigateur conduit la boucle, comme `LessonBuilder` : `/api/lesson/plan` puis `/api/lesson/theme` quatre à la fois, `maxDuration = 120` comme `/api/import-course`. Chaque appel écrit en base avant de répondre : une page rechargée retrouve les thèmes prêts et relance ceux en préparation |
| Anciens cours | **Convertis à la première ouverture**, sur le site comme sur l'iPhone (`stage: "convert"`), avec « Ouvrir sans attendre » (un chapitre = un thème, sans appel au modèle). Le premier client qui ouvre écrit le chemin ; l'autre le lit |
| Formes de question | Les cinq (`choice`, `truefalse`, `gap`, `order`, `match`) : le site les déclare (`kinds`) et les affiche. Sans ça, le serveur ne rend que des QCM |
| Notes de flashcards | **Encore · Bien · Facile** (`again`, `good`, `easy`), au clavier 1 · 2 · 3. « Difficile » disparaît, ici aussi |
| Gratuit | **Une** leçon, à vie, depuis un sujet tapé ou un texte collé ; PDF, Photo, Audio, YouTube : Pro ; Mika : une question ; questions d'entraînement et examen blanc : un de chaque. La porte est tenue par le serveur (`begin_lesson`, `begin_extra`) et annoncée par le site (`allowance`). Le refus tombe sur l'envoi, jamais au milieu d'un chemin. La fiche à 30 % et les cinq cartes par session disparaissent |
| Abonnement | Stripe reste la caisse du site, RevenueCat le juge (`entitlements`). L'offre cadeau reste |
| Police | **Nunito partout.** Hanken Grotesk et Inter sortent |
| Couleurs | Ivoire `#F6F4ED`, encre, bleu `#2563EB`, les cinq tons en trois nuances (pâle, vive, encre), violet pour les mots-clés, vert / rouge pour les réponses. Portées valeur par valeur depuis `MicaboPalette` (clair et sombre). Le réglage clair / sombre / système reste (`AppearanceProvider`) |
| Icônes | Les 34 icônes 3D (`Icon3D-*@2x.png`) copiées dans `web/public/icons3d/`, avec le catalogue de `_shared/icons.ts` et son test de parité. Les pictogrammes du chemin (SF Symbols, `PathSymbol.catalog`) passent par une table vers `lucide-react`, avec un repli sûr |
| Mika | `design/mika/mika.svg` + `mika.css` **tels quels** : c'est leur format d'origine. Huit humeurs (`idle`, `wave`, `happy`, `sleep`, `think`, `surprise`, `celebrate`, `sad`), « réduire les animations » fige la pose |
| Emoji | Aucun dans les textes. `courses.emoji` reste lu pour les cours d'avant, jamais écrit |
| Impression | Les Notes d'une leçon s'impriment : c'est la signature du bureau, elle reste |
| Langues | Les cinq (fr, en, de, es, tr), à chaque lot, avec les tests de parité |
| Livraison | Chaque lot finit `pnpm verify` au vert et se déploie seul. Un workflow `web.yml` le fait tourner à chaque push, comme `ios.yml` pour l'app |

---

## 1. Ce qui disparaît du site

Tout ce que l'app a retiré (`docs/refonte-parcours.md` § 11), et ce que le site avait en plus.

| Disparaît | Remplacé par |
| --- | --- |
| Aujourd'hui (plan du jour, blocs, charge) | Home : Mika, la barre, les stats, « Reprendre » |
| Réviser (file globale, réglage de session) | Les flashcards **par leçon**, dans la barre du chemin ; la pastille « 8 à réviser » sur la carte |
| La fiche (`SheetReader`, 30 % puis flou), l'éditeur, les surligneurs | Les Notes d'un thème, au nouveau format |
| L'atelier de cartes, les masques sur image, « générer des cartes », « expliquer » | Les flashcards écrites avec la leçon ; Mika dans la leçon |
| Importer (page, formats, longueur de fiche, visibilité, instructions), Anki, les paquets | La barre de Home et ses cinq supports |
| Examens : le plan de la période, la projection, le calendrier, les tests de parcours, les blancs oraux, les jours de repos | Examen : le prochain, « J-12 », les autres, l'examen blanc QCM chronométré |
| Progrès (séries, « ce que tu sais », activité, « ce qui résiste ») | Les trois chiffres de Home |
| Bibliothèque, reprendre un cours (`/app/b/[id]`, `AdoptCourse`), visibilité d'un cours | — (les amis et le classement restent, dans Profil) |
| Réglages d'étude (longueur de fiche, taille de lecture, minutes par jour, cartes neuves par jour) | — |
| « Difficile » | Encore · Bien · Facile |
| La visite guidée des cinq pages | Une visite des quatre pages, réécrite |

Reste : le compte (connexion, OAuth, déconnexion, suppression), le profil (prénom, nom
d'utilisateur, pays, niveau, établissement, matières, langue), les amis et le classement de
la semaine, Stripe et l'offre cadeau, les pages légales, les langues et leurs adresses, le
SEO, le serveur de démonstration, le thème sombre.

---

## 2. Les dix lots

| # | Lot | Ce qu'il livre |
| --- | --- | --- |
| 1 | **Voir et fonder** | `web.yml` (pnpm verify à chaque push) · Nunito · la palette ivoire / bleu / cinq tons, clair et sombre, dans `globals.css` · `MicaboIcon` (les 34 PNG, le catalogue, la parité) · la table des pictogrammes · `<Mika>` (SVG + CSS, huit humeurs) · les catalogues `lesson-*.ts` et leur test de parité avec le Swift. Rien de nouveau ne s'affiche encore ; le site a déjà l'air de l'app |
| 2 | **Le noyau** | `@micabo/core/lesson/` : les types (`LessonPath`, `ThemeNotes`, `NoteBlock`, `QuizQuestion`, `ThemeQuiz`, `LessonProgress`), `pathLayout` (groupes, étapes, étape en cours, migration des anciennes progressions), `picking` (tirages à graine, du simple à l'exigeant), `homeStats` et `resumeTarget`, `lessonTone` (suivant, stable par FNV-1a), `allowance`. Les tests reprennent les valeurs de `LessonModelTests`, `LessonPickingTests`, `HomeStatsTests`. `lib/data/lessons.ts` lit les nouvelles colonnes, avec les mêmes tags de cache |
| 3 | **Le chemin** | `/app/lecons/[id]` : l'en-tête (icône 3D, titre, « 3 sur 11 étapes · 27 % », la barre au ton de la leçon, la pastille d'examen), le chemin en zigzag (SVG), les trois états, « Continuer », l'appui refusé sur une étape à venir, les en-têtes de palier, le menu Renommer · Recommencer · Supprimer ; la barre Notes · Quiz · Flashcards ; la conversion d'un ancien cours à l'ouverture et « Ouvrir sans attendre » ; la progression écrite dans `courses.progress`, `last_opened_at` posé à l'ouverture. `/app/c/[id]` redirige |
| 4 | **Les étapes** | Intro (« ce que tu vas apprendre », les thèmes et leurs icônes, le temps estimé, « C'est parti ») · Notes (le rendu des onze blocs, « En une phrase », « À retenir », mots-clés violets, `$latex$` par KaTeX, la barre de lecture, la question de fin) · Checkpoint et Quiz final (`QuestionCard` pour les cinq formes, réponse immédiate, l'écran de score avec Mika, une question ratée entre dans `missed` et devient une flashcard due demain) · « Leçon terminée » (confettis, score, temps, deux boutons, `finishedAt`) · le temps mesuré par activité (`seconds`) · les trois écrans de la barre : toutes les Notes (imprimables), le quiz de dix, la révision des flashcards de la leçon (Encore · Bien · Facile, `gradeCard`) · Mika dans la leçon (`mika-chat`, la leçon jointe, une question offerte) |
| 5 | **Home** | `/app` : Mika, la question, la barre « comme une IA » et ses cinq supports (PDF et Word, photo, fichier audio par `transcribe-audio`, YouTube, texte ; jusqu'à cinq pastilles), la porte sur l'envoi, les deux questions (un examen ? quelle date ?), l'écran de génération (quatre étapes reliées au vrai travail), l'atterrissage sur le chemin, les thèmes qui s'écrivent quatre à la fois avec « Réessayer » ; les trois chiffres mesurés ; « Reprendre ». `/api/lesson/plan`, `/api/lesson/theme`, `/api/lesson/convert` |
| 6 | **Leçons et Examen** | `/app/lecons` : les cartes (icône sur le ton, titre, où on en est, la barre, « 8 à réviser », « J-12 »), les dossiers (`course_folders` : ranger, renommer, supprimer), le tri. `/app/examen` : le prochain examen en grand avec son compte à rebours, en déclarer un (nom, date, leçons), les autres, les passés ; l'examen blanc chronométré (`stage: "exam"`, noté dans le barème du pays, son historique) et les questions d'entraînement (`stage: "practice"`), un de chaque offert puis Pro (`begin_extra`) |
| 7 | **Profil, chrome et portes** | `/app/profil` : la carte et son détail, « Passer en Pro » (Stripe), les amis et le classement, Changer la langue · Changer le thème · Nous noter, le support et les pages légales, la suppression du compte. Le nouveau chrome à quatre destinations. `entitlement.ts` réécrit sur les règles de la leçon, `freemium-parity.test.ts` réaligné sur `LessonAllowance` et `FreeTier` ; les trois déclencheurs du paywall (l'envoi, Mika, un supplément) |
| 8 | **Nettoyage** | Les écrans du § 1 et leur code partent : pages, composants, actions, modules de `core` que plus personne ne lit (le plan de la période, les tests de parcours, la copie orale, la charge quotidienne…), clés de catalogue orphelines. Les redirections restent. La visite guidée réécrite pour les quatre pages. Le serveur de démonstration porte les colonnes de la leçon, `lesson_generations`, les RPC de la porte. `pnpm verify` au vert sans code mort |
| 9 | **La vitrine et le parcours d'accueil** | La page d'accueil vend la leçon en chemin : le héros (Mika, la barre), la vitrine faite des vrais composants (Home, le chemin, des Notes, un quiz), les étapes (tape ou dépose · Mika écrit · suis le chemin · l'examen blanc), la preuve, les questions ; `/methode`, `/mode-examen`, `/micabo-ou-anki` réécrits aux mêmes adresses ; la page iPhone, l'image OpenGraph, les données structurées. `/commencer` : les histoires réécrites sur les nouvelles fonctions, l'import écrit **une leçon** (`onboarding: true`, c'est la leçon offerte), le cours de démonstration devient une leçon de démonstration, l'arrivée se fait sur Home avec « Reprendre » |
| 10 | **Finitions** | Les cinq langues relues et les parités au vert ; le thème sombre sur chaque écran neuf ; clavier et accessibilité (espace retourne, 1 · 2 · 3 notent, les étapes au focus) ; la feuille d'impression des Notes ; `docs/web.md`, `web/README.md` et le README mis à jour ; les captures de la démonstration ; la liste des vérifications de prod (`generate-lesson` déployée, les origines CORS, aucune migration nouvelle) |

Les lots 3 à 5 sont le cœur ; ils sont séparés pour que chacun tienne en une relecture. Le
lot 8 vient **après** Home et Profil et non avant : tant que les nouvelles pages n'existent pas,
retirer les anciennes laisserait un site sans écran.

---

## 3. Les données, vues du site

Rien à migrer : tout est déjà en base depuis les migrations `lesson_*`. Le site ajoute des
colonnes à ses lectures et n'en retire aucune.

```ts
// lib/data/lessons.ts
interface LessonRow extends CourseRow {
  path: LessonPath | null;        // nul : un ancien cours, à convertir
  progress: LessonProgress | null;
  tone: string | null;            // yellow · mint · blue · pink · lilac
  icon: string | null;            // « globe », « fiole »…
  last_opened_at: string | null;
}
interface ThemeRow {
  id: string; course_id: string; position: number; title: string;
  icon: string | null;
  notes: ThemeNotes | null;       // nul : un ancien chapitre, qui garde `sheet`
  quiz: ThemeQuiz | null;
  status: "pending" | "ready" | "failed" | null;
  sheet: unknown;                 // l'ancien format, affiché avec la même typo
}
```

**Ce que le site écrit**, et où :

| Geste | Écriture |
| --- | --- |
| Ouvrir une leçon | `courses.last_opened_at` |
| Cocher une étape, un score de quiz, une question ratée, du temps passé, la fin | `courses.progress` (tout le JSON, relu puis réécrit ; `touch_updated_at` date la ligne) |
| Renommer, déplacer, supprimer | `courses.title`, `folder_id`, `deleted_at` : comme aujourd'hui |
| Une question ratée | une ligne `flashcards` de genre `choice`, due demain, rattachée au thème |
| Noter une flashcard | `gradeCard`, inchangé : SM-2 au serveur, `review_logs` |
| Le plan | `courses` (avec `path`, `tone`, `icon`), `chapters` en `pending`, et l'examen s'il y a une date |
| Un thème | `chapters.notes`, `quiz`, `icon`, `status`, et ses flashcards |
| Une conversion | `courses.path`, `icon` ; `chapters.icon`, `quiz`, `status` ; les flashcards manquantes |

La progression est un JSON entier : deux appareils qui la modifient en même temps se résolvent
par `updated_at`, comme pour tout le reste. C'est le choix de l'app, et le site ne le
rediscute pas.

---

## 4. La génération, côté site

`LessonBuilder` vit dans le téléphone, hors de tout écran ; sur le site, c'est **la page du
chemin** qui conduit, parce qu'un navigateur fermé n'a pas d'arrière-plan. Ce que ça impose,
et comment on le tient :

1. `/api/lesson/plan` reçoit le sujet ou les supports (texte combiné, pages en image), lit le
   profil (niveau, pays, langue), appelle `generate-lesson` avec le jeton de l'utilisateur
   (`supabase.functions.invoke`), insère le cours, ses thèmes en `pending`, l'examen, et rend
   l'identifiant. Le refus de la porte (`free_limit`, `import_pro`) revient avec son code : le
   site ouvre le paywall.
2. La page du chemin s'ouvre et **lance les thèmes en préparation**, quatre à la fois :
   `/api/lesson/theme` écrit le thème et rend ; la page relit (`router.refresh`) et le rond
   passe de « en préparation » à prêt. Un thème en échec passe en `failed`, « Réessayer » le
   relance. Une page rechargée retrouve l'état en base et reprend ce qui manque.
3. `/api/lesson/convert` fait la même chose pour un ancien cours, en un appel.

Les quatre étapes de l'écran de génération suivent ces réponses : « je lis tes supports »
(le plan est parti), « je découpe les thèmes » (le plan est là), « j'écris tes notes » (les
thèmes sont lancés), « je prépare tes questions » (le premier thème est arrivé). Comme sur
l'iPhone, pas un minuteur.

Le site envoie `kinds: ["choice", "truefalse", "gap", "order", "match"]` : il sait tout
afficher. Et l'audience (`tier`, `track`, `year`, `exam`, `currentScore`, `targetScore`,
`worries`) part telle que le profil la connaît ; ce que le parcours du site n'a pas demandé
reste absent, et le serveur a ses valeurs par défaut.

---

## 5. Ce qui se partage, et comment on le vérifie

| Chose | Source | Copie sur le site | Vérification |
| --- | --- | --- | --- |
| Le chemin | `Micabo/Models/PathLayout.swift` | `core/src/lesson/path-layout.ts` | les tables de `LessonModelTests` |
| Les tirages | `Micabo/Features/Lesson/LessonPicking.swift` | `core/src/lesson/picking.ts` | `LessonPickingTests`, même graine, même ordre |
| Les groupes de thèmes | `supabase/functions/generate-lesson/schema.ts` (`groupThemes`) | `pathLayout.groups` | un test qui relit le fichier du serveur |
| Les icônes | `supabase/functions/_shared/icons.ts` | `core/src/lesson/icons.ts` | parité à l'octet, comme `sheet/canonical.ts` |
| Les pictogrammes | `supabase/functions/_shared/symbols.ts` | `core/src/lesson/symbols.ts` + la table vers lucide | parité des identifiants ; chaque entrée a un dessin |
| Les textes `lesson.*` | `Micabo/Services/I18n/LessonI18nCatalogs.swift` | `web/lib/i18n/catalogs/lesson-{fr,en,de,es,tr}.ts` | un test relit le Swift : même clé, même texte |
| Le gratuit | `FreeTier`, `LessonAllowance` (Swift) | `core/src/entitlement.ts` | `freemium-parity.test.ts`, réécrit |
| Les tons | `LessonTone.swift`, `MicaboPalette` | `core/src/lesson/tone.ts`, `globals.css` | le hachage FNV-1a donne le même ton pour le même identifiant |

---

## 6. Ce qui ne change pas

- La pile : Next 16, App Router, Tailwind 4, `@micabo/core`, Vercel, `rootDirectory: web/`.
- L'authentification, le middleware, les langues dans l'adresse, le `noindex` de `/app`.
- Le cache de Next et ses tags par étudiant ; une écriture de leçon invalide `courses`.
- Stripe, le webhook RevenueCat, `entitlements`, l'offre cadeau.
- Le serveur de démonstration (`scripts/demo/`), enrichi et non remplacé.
- Le schéma : **aucune migration**.

---

## 7. Ce qu'il faut savoir avant de commencer

- `generate-lesson` doit être déployée sur le projet de production, et les trois migrations
  `lesson_*` passées : c'est déjà ce que `prod.yml` vérifie. Sans elles, le site se comporte
  comme un téléphone sans la fonction : un ancien cours s'ouvre « sans attendre », et la barre
  dit que la création est indisponible.
- Les origines CORS de `_shared/caller.ts` acceptent déjà `micabo.app` et les
  prévisualisations `micabo*.vercel.app`.
- `/api/*` porte `maxDuration = 120` : un thème prend dix à vingt secondes, un plan cinq à dix.
- Les comptes développeur (`LIFETIME_PRO_EMAILS`) restent Pro sans ligne.
