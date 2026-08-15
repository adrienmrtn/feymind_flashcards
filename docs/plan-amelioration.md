# Plan d'amélioration de Micabo

Parcours, design, textes — de l'installation à la troisième semaine d'usage.

---

## Comment lire ce document

Ce document part d'un audit complet du dépôt à l'état actuel (`main`, ~10 400 lignes de Swift) :
les 20 écrans du parcours d'accueil, les 5 onglets, la session de révision, l'import, les réglages,
le design system et tous les textes affichés. Chaque reproche est appuyé sur un fichier et, quand
c'est utile, sur une ligne. Chaque proposition est écrite pour être implémentable telle quelle :
quand je propose un texte, il est prêt à coller.

Il est organisé pour être lu dans l'ordre, mais chaque partie se tient seule :

| Partie | Contenu |
| --- | --- |
| 1 | Ce que l'app est aujourd'hui, chiffré |
| 2 | Le diagnostic : 7 problèmes structurels |
| 3 | Ce que font les concurrents, et ce qu'il faut leur prendre |
| 4 | La refonte du parcours d'accueil (la partie la plus dense) |
| 5 | La boucle de rétention : ce qui se passe après l'onboarding |
| 6 | Écran par écran, les corrections concrètes |
| 7 | Les textes : principes, incohérences, réécritures |
| 8 | Le design : jetons, mode sombre, accessibilité, mouvement |
| 9 | Les manques produit structurants |
| 10 | Plan d'exécution en 4 lots |
| 11 | Ce qu'il faut mesurer |
| 12 | Annexes |

**Sur les chiffres externes.** Les repères de conversion et de rétention viennent de sources
publiques de qualité inégale (billets d'éditeurs d'outils de monétisation, teardowns, un mémoire
universitaire). Je les cite parce qu'ils donnent des ordres de grandeur utiles, pas parce qu'ils
font autorité. Ils sont marqués comme tels. Les seuls chiffres à traiter comme durs sont ceux
tirés du code de Micabo.

---

## 1. Ce que Micabo est aujourd'hui

### 1.1 En chiffres

| Élément | Valeur constatée |
| --- | --- |
| Code Swift | ~10 440 lignes |
| Écrans d'onboarding | **20**, strictement linéaires, aucun retour arrière possible |
| Jauge de progression | présente sur 15 écrans, absente sur 5 |
| Réponses collectées à l'inscription | **9** clés `UserDefaults` (`micabo.onboarding.*`) |
| Réponses réellement relues par l'app | **1** (`completed`, dans `RootView`) |
| Attente artificielle dans l'onboarding | ~4,85 s sur `PersonalizingStepView`, sans calcul réel |
| Démonstrations factices avant le paywall | 3 écrans (`demoImport`, `demoWrite`, `demoReview`) |
| Cours réellement importé avant le paywall | **0** |
| Onglets | 5, dont **2** non livrés (Bibliothèque, section Amis du Profil) |
| Cours injectés au premier lancement | 2 (`SampleData` : photosynthèse, fonctions affines) |
| Algorithme de révision | SM-2, réglages Anki (`learningSteps [1, 10]`, `graduating 1 j`, `easy 4 j`, `ease 2,5`, `leech 8`) |
| Offre | 39,99 €/an ou 6,99 €/mois, 3 jours d'essai (`Micabo.storekit`) |
| Notifications | **aucune** demande système, aucune programmation (`UNUserNotificationCenter` absent du dépôt) |
| Widget écran d'accueil | absent |
| Compte / synchronisation | absents (tout est local, SwiftData) |
| Mode sombre | désactivé de force (`.preferredColorScheme(.light)`, `MicaboApp.swift:19`) |

### 1.2 Ce qui est déjà bon, et qu'il ne faut pas casser

Il faut le dire avant de critiquer, parce que ça oriente le reste du plan : la base est solide et
le goût est bon.

- **Le planificateur SM-2 est sérieux.** `SM2Scheduler` reproduit fidèlement les réglages d'Anki,
  y compris la dispersion aléatoire des échéances (`fuzzed`), le seuil de sangsue, le
  réapprentissage par paliers, et la garantie qu'une réponse positive allonge toujours
  l'intervalle d'au moins un jour. C'est mieux que ce que font la plupart des applications
  « IA + flashcards » du marché, qui se contentent d'un espacement approximatif.
- **L'extraction de contenu est faite sur l'appareil** (PDFKit, Vision pour l'OCR, lecture locale
  des `.docx`), et l'appel au modèle ne sert qu'à rédiger. C'est un vrai argument de confidentialité,
  aujourd'hui mal exploité côté marketing.
- **La direction artistique tient debout.** Fond ivoire, encre presque noire, un seul accent indigo,
  coins mesurés, pas de dégradés criards : l'app ne ressemble pas à un template. C'est rare.
- **L'écran de la courbe de l'oubli** (`RetentionChartStepView`) est la meilleure page du produit :
  une démonstration animée, honnête, qui explique la valeur en dix secondes.
- **L'écran de projection** (`ProjectionStepView`) affiche sa propre formule et écrit
  « Une estimation, pas une promesse ». C'est un choix éditorial que je recommande de conserver
  et d'étendre : c'est un différenciateur de ton face à des concurrents qui promettent des « +300 % de mémorisation ».

---

## 2. Diagnostic : 7 problèmes structurels

### P1. L'onboarding promet une personnalisation qui n'existe pas

Le parcours pose trois questions présentées comme structurantes (« QUESTION 1 SUR 3 »,
objectifs, matières, rythme), demande l'établissement, mesure le rapport à l'oubli, puis affiche
un écran « On personnalise ton profil » pendant presque cinq secondes.

Dans le code, `OnboardingPreferences` écrit bien ces neuf clés. **Aucune n'est relue ailleurs que
dans l'onboarding lui-même.** Le tableau de bord est identique pour un étudiant en médecine qui
révise 45 min/jour et pour un lycéen qui vise 5 min. Le curseur « minutes par jour » ne pilote
aucun objectif. Les matières choisies ne préremplissent pas le filtre par matière du tableau de
bord, qui existe pourtant (`DashboardView.subjectFilter`).

C'est le problème le plus coûteux du produit : il transforme trois minutes d'investissement de
l'utilisateur en promesse non tenue, et une promesse non tenue au premier lancement se paie en
rétention J7.

### P2. Le paywall arrive avant le premier vrai succès

L'ordre actuel est : 17 écrans → écran d'attente → offre d'essai → rappel d'essai → paywall.
Au moment où le prix apparaît, l'utilisateur a vu une simulation d'import (un faux PDF « La
Révolution française »), une simulation de génération (trois cartes écrites d'avance) et une
simulation de révision (une carte, deux boutons). Il n'a **rien importé, rien généré, rien révisé
de son propre contenu**.

C'est exactement l'inverse de ce que fait la référence du secteur. Le teardown public de
l'onboarding de Duolingo (38 écrans, ~10 % de conversion payante) décrit le principe : la première
leçon est jouée *avant* le paywall, et chaque écran sert à augmenter ce que l'utilisateur aurait à
perdre en partant. Les données d'A/B tests publiées par Adapty vont dans le même sens : sur une
app d'éducation, la variante « questionnaire + leçon d'essai » a battu « questionnaire seul » et
« leçon seule » avec +25 % de démarrages d'essai et +78 % d'ARPU.

Micabo a le questionnaire. Il lui manque la leçon — la vraie.

### P3. La boucle de rétention n'existe pas encore

L'app affiche une série (`StudyStats.streak`) sur la carte d'accueil et dans le profil. Mais :

- Il n'y a **aucune notification** : `NotificationsStepView` enregistre une intention
  (`notificationsOptIn`) et le commentaire du code le dit franchement — « L'autorisation système
  n'est pas encore demandée ». Aucun rappel ne partira jamais.
- Il n'y a **aucun widget**.
- La série n'est **pas protégée** : un jour manqué la remet à zéro, sans filet.
- Rien ne ramène l'utilisateur dans l'app. Le produit compte entièrement sur la motivation
  intrinsèque d'un étudiant en période de révisions — c'est-à-dire sur le pire moment de son année
  pour lui demander de la discipline.

L'ordre de grandeur du marché, largement cité : autour de 77 % des utilisateurs abandonnent une
app dans les trois jours, et la rétention J7 moyenne sur iOS tourne autour de 7 %. Une app d'étude
sans rappel ni widget se prive du seul levier qui compte à cette échelle de temps.

### P4. L'app parle comme un développeur

Trois exemples pris tels quels dans le code :

- Réglages, section « Backend » : un champ **URL Supabase**, un champ **Clé publique**
  (`sb_publishable_...`), et un sélecteur de **modèle d'IA** listant `google/gemini-flash-1.5`,
  `openai/gpt-4o-mini`… Exposés à tous les utilisateurs, depuis l'icône engrenage du Profil.
- Message d'erreur (`AIService.swift:45`) : « La clé fal.ai est absente côté Supabase. Ajoutez le
  secret FAL_KEY à votre projet. »
- Écran d'import (`ImportView.swift:397`) : « Seule la rédaction des cartes passe par vos Edge
  Functions (google/gemini-flash-1.5). »

Un étudiant ne sait pas ce qu'est une Edge Function, et n'a pas de projet Supabase. Ces écrans
sont des réglages de développement laissés dans le produit.

### P5. La session de révision est en dessous de ses propres fondations

C'est le cœur du produit et l'écran le plus abouti techniquement, mais il lui manque des choses
que le code sait déjà faire :

- **Les intervalles ne sont pas affichés sous les boutons.** `SM2Scheduler.previewLabels` calcule
  « 1 min / 10 min / 1 j / 4 j » et `StudySession.previewLabels` l'expose. `StudyView` ne l'utilise
  jamais. C'est une fonctionnalité écrite, testable, gratuite, et non branchée — et c'est
  précisément ce qui permet à l'utilisateur de comprendre l'effet de son choix.
- **Pas d'annulation.** Une erreur de bouton est définitive et modifie la planification de la carte.
  Anki a `Undo` depuis toujours ; c'est la première chose que réclame quelqu'un qui a appuyé à côté.
- **Pas d'édition en session.** Quand une carte générée est fausse ou mal tournée — ce qui arrive
  avec un modèle — on ne peut ni la corriger ni la signaler sans quitter la session.
- **Pas de reprise.** Fermer la session (croix) perd la progression : `StudySession` est un `@State`
  recréé à chaque présentation.
- **Pas de plafond de session.** `StudySession.start` appelle `StudyQueueBuilder.build(..., limits: .unlimited)`
  alors que `Limits.default` (20 nouvelles, 200 révisions) existe. Un import de 200 cartes produit
  une session de 200 cartes : c'est la façon la plus sûre de dégoûter quelqu'un le premier jour.

### P6. Les démonstrations enseignent un produit qui n'existe pas

Les trois écrans de démo sont bien faits, mais ils décrivent un autre produit que le vôtre :

| La démo montre | L'app fait |
| --- | --- |
| Deux boutons : « À revoir » / « Je savais » | Quatre boutons : « À revoir » / « Difficile » / « Correct » / « Facile » |
| « Je savais » → « Prochaine révision dans 3 jours » | Une carte neuve notée « Correct » revient **dans 10 minutes** (palier d'apprentissage) |
| « Micabo lit tout, y compris les schémas » | L'analyse des schémas est une case à cocher, désactivée par défaut, décrite comme « Option payante » |
| Une carte de bienvenue affiche « Appuie pour retourner » | La carte n'a aucun gestionnaire de tap : l'invite ne mène nulle part |

Quand la première session réelle contredit la démonstration, l'utilisateur ne pense pas
« intéressant », il pense « ce n'est pas ce qu'on m'avait montré ».

### P7. Deux promesses affichées ne sont pas tenues

La barre d'onglets annonce cinq destinations. « Bibliothèque » est un écran d'attente
(« Connexion requise », « La bibliothèque n'est pas encore active. ») avec quatre pavés de matières
non cliquables (`allowsHitTesting(false)`). Le Profil affiche une section « Amis » avec la mention
« Bientôt ». La feuille d'import propose une cinquième entrée « Depuis la bibliothèque · Bientôt
disponible », grisée.

Trois « bientôt » visibles dans le premier tiers de l'expérience, c'est le signal d'un produit
inachevé — alors que ce qui est livré, lui, fonctionne.

**Cas particulier à trancher : les deux cours d'exemple.** `SampleData` insère au premier lancement
un cours de photosynthèse et un cours de fonctions affines, avec un historique de révision
fabriqué. L'intention est bonne (éviter l'écran vide), mais la conséquence est que la première
session de l'utilisateur porte sur le cycle de Calvin, pas sur son cours à lui. Et personne ne lui
dit d'où viennent ces cours. Voir §4.6 pour la sortie proposée.

---

## 3. Analyse concurrentielle

### 3.1 Le paysage

| Produit | Positionnement | Algorithme | Génération IA | Prix indicatif | Ce qu'il fait mieux que Micabo |
| --- | --- | --- | --- | --- | --- |
| **Anki** | La référence des gros volumes (médecine, droit, langues) | FSRS par défaut depuis la v23.10, SM-2 en repli | Non (greffons tiers) | Gratuit sauf iOS (~25–30 € une fois) | Ergonomie de session (annuler, éditer, enterrer, marquer), statistiques, intervalles affichés, écosystème de paquets partagés |
| **Quizlet** | Le grand public, la bibliothèque | Espacement simple | Oui, derrière l'abonnement | ~8 €/mois | Modes d'étude multiples (apprendre, test, association), catalogue communautaire massif, partage |
| **Knowt** | L'alternative gratuite qui génère | SRS simplifié | Oui, PDF, notes, cours filmés, gratuit | Gratuit | La génération gratuite : c'est le concurrent frontal sur la promesse de Micabo |
| **RemNote** | Notes et cartes dans le même outil | SM-2 modifié, FSRS optionnel | Oui (texte) | ~8 €/mois | Les cartes naissent des notes, pas d'un import séparé |
| **Brainscape** | Apprentissage par niveau de confiance | Propriétaire (CBR) | Oui, offre payante | ~8–10 €/mois | Une notation à 5 niveaux plus lisible que « facile/correct/difficile » |
| **Memrise** | Langues | Espacement | — | Freemium | Vidéos de locuteurs natifs : du contenu qu'on ne peut pas générer |
| **Mochi** | Minimaliste, Markdown, code | SRS | — | ~5 €/mois ou gratuit sans sync | Le local-first assumé, et un prix bas |
| **Gizmo** | Quiz IA depuis YouTube, PDF, slides | SRS | Oui | Freemium | Les sources vidéo |

Deux constats pour Micabo.

**Le marché s'est scindé en deux moitiés et personne ne tient les deux.** Anki tient la
planification et rate l'ergonomie (un comparatif français avance que 60 % des nouveaux venus
abandonnent en moins d'une semaine devant son interface). Les outils IA tiennent la génération et
bâclent la planification. Micabo est aujourd'hui l'un des rares à avoir **un vrai SM-2 réglé comme
Anki *et* une génération depuis PDF/photo/Word**. C'est le positionnement, il n'est pas revendiqué
nulle part dans le produit.

**La confidentialité est un angle libre.** Tous les concurrents IA envoient le document entier sur
leurs serveurs. Micabo extrait le texte sur l'appareil et n'envoie que ce qu'il faut pour rédiger.
Aucun écran ne le dit clairement à un utilisateur non technique — la seule mention est noyée dans
une note grise sous un formulaire d'import.

### 3.2 Ce qu'il faut copier, adapter, ou refuser

**À copier tel quel**

1. **La leçon avant le prix** (Duolingo). Le paywall ne doit apparaître qu'après une vraie session
   sur un vrai contenu. C'est la recommandation n°1 de ce document.
2. **Les intervalles sous les boutons de notation** (Anki). Déjà codé, à afficher.
3. **Annuler la dernière réponse** (Anki). Un bouton, en haut à droite de la session.
4. **Le gel de série** (Duolingo). Les données de la plateforme Trophy sur des apps tierces
   indiquent, pour les utilisateurs ayant dépassé 7 jours, une série moyenne de 17,19 jours avec
   gel contre 11,62 sans ; à 14 jours, 30,63 contre 18,87. C'est le meilleur rapport
   effort/rétention de toute cette liste.
5. **Le widget de série** (Duolingo). Surface de rappel gratuite, non intrusive, qui ne dépend pas
   de l'autorisation de notification.
6. **La deuxième demande d'autorisation** (Duolingo). Un refus n'est pas définitif : on redemande
   quand l'utilisateur a une série à protéger.
7. **Le plafond de nouvelles cartes par jour** (Anki). `Limits.default` existe déjà.

**À adapter**

8. **La notation par confiance** (Brainscape). Ne pas remplacer les quatre boutons — le
   planificateur en dépend — mais revoir les libellés (voir §7.4) : « Correct » ne dit pas à
   l'utilisateur qu'il s'agit du cas normal.
9. **La bibliothèque partagée** (Quizlet, Anki). C'est le plus gros chantier du marché et l'onglet
   est déjà là, vide. Voir §6.6 pour ce qu'on peut en faire sans backend.
10. **Les modes d'étude multiples** (Quizlet). Un mode « QCM » et un mode « écrire la réponse »
    depuis les mêmes cartes coûtent peu et augmentent nettement le temps passé. À placer après le
    reste.

**À refuser**

11. **Le personnage-mascotte et la culpabilisation** (Duolingo). Ça marche pour eux, ça détonnerait
    avec la sobriété de Micabo, qui est son actif de marque.
12. **La preuve sociale inventée.** Voir juste en dessous : c'est la seule chose de ce document
    qui relève du risque, pas de l'optimisation.
13. **Le paywall qui cache son prix jusqu'au dernier moment.** Duolingo le fait ; sur un public
    étudiant français et avec la sobriété que revendique Micabo, l'ancrage clair
    (« 39,99 €/an, soit 3,33 €/mois ») sert mieux la confiance.

### 3.3 Un point à corriger sans attendre

`SchoolPeersStepView` affiche « **{N} personnes de {ton établissement} utilisent déjà Micabo pour
étudier** », où `N` est, littéralement :

```swift
if peers == 0 { peers = Int.random(in: 30...70) }
```

Un nombre tiré au hasard entre 30 et 70, présenté comme un fait. Ce n'est pas une pratique
d'optimisation, c'est une affirmation commerciale fausse : côté français, elle relève de la
pratique commerciale trompeuse, et côté Apple, des règles de l'App Store sur les contenus
mensongers. Le risque est disproportionné par rapport au gain d'un écran.

Trois sorties possibles, par ordre de préférence :

1. **Supprimer l'écran** (ma recommandation ; il supprime aussi la question sur l'établissement,
   dont la réponse ne sert à rien d'autre).
2. Le remplacer par une preuve vérifiable : nombre total de cartes révisées dans Micabo, nombre de
   cours importés cette semaine — un chiffre réel, même modeste.
3. Le garder mais dire la vérité : « Rejoins les premiers utilisateurs » sans nombre.

---

## 4. Refonte du parcours d'accueil

### 4.1 Les trois principes

1. **Aucune question dont la réponse ne change rien.** Si on demande, on utilise — et on montre
   qu'on a utilisé.
2. **Le prix arrive après le premier succès réel**, pas après sa simulation.
3. **Toute affirmation est vérifiable.** Pas de nombre inventé, pas d'attente feinte, pas de
   promesse que la première session dément.

### 4.2 Verdict écran par écran sur les 20 étapes actuelles

| # | Étape | Verdict | Motif |
| --- | --- | --- | --- |
| 1 | `welcome` | **Garder**, corriger | Belle entrée. Soit on rend les cartes retournables, soit on retire « Appuie pour retourner » qui ne fait rien |
| 2 | `language` | **Supprimer** | Une seule langue disponible : l'écran ne fait que rappeler ce qui manque. À déplacer dans les Réglages quand il y en aura plusieurs |
| 3 | `personalizeIntro` | **Supprimer** | Écran qui annonce des questions au lieu de les poser. Son contenu utile (« Trois minutes, tout reste sur ton téléphone ») se recase en sous-titre de la première question |
| 4 | `goal` | **Garder** | Bonne question, bonnes réponses. Mais elle doit servir (§4.5) |
| 5 | `forgetting` | **Fusionner** avec la courbe | La réponse ne sert qu'à préparer l'écran suivant : autant en faire son introduction |
| 6 | `retentionChart` | **Garder tel quel** | Le meilleur écran du produit |
| 7 | `science` | **Raccourcir** | Deux révélations au tap avant la démo, c'est un temps de lecture de plus. Garder le bloc « intervalles expansifs », retirer la citation d'Ebbinghaus mot à mot (déjà dite par la courbe) |
| 8 | `demoImport` | **Remplacer** par le vrai import | §4.4 |
| 9 | `demoWrite` | **Remplacer** par la vraie génération | §4.4 |
| 10 | `demoReview` | **Remplacer** par la vraie session | §4.4 |
| 11 | `subjects` | **Garder**, déplacer plus tôt | Sert à proposer un pack de démarrage (§4.6) et à préremplir le filtre |
| 12 | `school` | **Supprimer** | La réponse n'est utilisée que par l'écran suivant, qui est lui-même à supprimer. Le catalogue de 14 500 établissements reste disponible pour plus tard (comptes, classements par école) |
| 13 | `schoolPeers` | **Supprimer** | §3.3 |
| 14 | `dailyTime` | **Garder** | À condition de piloter réellement l'objectif quotidien et l'heure du rappel |
| 15 | `projection` | **Garder**, déplacer après la première session | Beaucoup plus fort quand le chiffre est calculé sur les cartes que l'utilisateur vient de créer |
| 16 | `notifications` | **Garder**, déplacer après le succès, et **demander réellement** l'autorisation |
| 17 | `personalizing` | **Garder l'écran, supprimer le mensonge** | Il doit couvrir un vrai travail (génération du premier paquet), pas 4,85 s de vide |
| 18 | `trialOffer` | **Fusionner** avec le paywall | Trois écrans pour une seule offre, c'est deux de trop |
| 19 | `trialReminder` | **Fusionner** avec le paywall | La frise « aujourd'hui / jour 2 / jour 3 » est bonne : elle devient un bloc du paywall |
| 20 | `paywall` | **Garder**, refondre | §4.7 |

Bilan : 20 écrans → **14 écrans + un import réel**. Le parcours est plus court en nombre d'écrans
et plus long en temps passé, ce qui est exactement l'objectif : on remplace de la lecture passive
par de la manipulation de son propre contenu.

### 4.3 Le parcours cible

```
BLOC 1 — Accroche (~20 s)
  1. Bienvenue
  2. Ton objectif                    → sert au discours et au rythme conseillé

BLOC 2 — Preuve (~40 s)
  3. Tu oublies ? + courbe de l'oubli (fusion)
  4. Les intervalles expansifs

BLOC 3 — Ton contenu (le cœur, ~90 s)
  5. Tes matières                    → sert au pack de démarrage et au filtre
  6. « On commence par un vrai cours »
       ├── Importer maintenant (PDF · photo · Word · texte)
       └── Commencer avec un cours prêt (choisi dans TES matières)
  7. Génération réelle (l'écran d'attente couvre enfin un vrai travail)
  8. Première session réelle : 3 cartes, boutons réels, intervalles réels
  9. « Première carte ancrée » : ce qui vient d'être planifié, série à 1

BLOC 4 — Engagement (~40 s)
 10. Ton rythme quotidien            → objectif quotidien + heure du rappel
 11. Notifications (vraie demande système, après le succès)
 12. Ta projection à un an           → calculée sur SES cartes

BLOC 5 — Offre (~30 s)
 13. Essai 3 jours + frise de rappel + prix (écran unique)
 14. Repli si StoreKit ne répond pas
```

### 4.4 Le changement principal : remplacer les trois démos par le vrai produit

C'est le seul changement de ce document qui demande un vrai travail d'intégration, et c'est celui
qui rapporte le plus.

**Ce qui existe déjà et qu'on réutilise :**

- `ImportChoiceSheet` et `ImportView` gèrent les quatre formats, la lecture sur l'appareil et les
  erreurs.
- `GenerationOverlay` affiche déjà une progression par étapes.
- **`StudyView` a déjà un mode embarqué** : le paramètre `isEmbedded` (`StudyView.swift:7`) masque
  la croix de fermeture et transforme le bouton final en « Recharger la session ». Il n'est utilisé
  nulle part. Il a manifestement été prévu pour ça.

**Le déroulé :**

1. Écran 6, deux chemins. Le premier : « Importe ton cours » ouvre la feuille d'import réelle.
   Le second, indispensable, pour qui n'a pas son PDF sous la main à 23 h : « Je n'ai pas mon cours
   ici » → pack de démarrage dans une matière déjà choisie à l'écran 5.
2. Génération réelle. Si elle échoue (pas de clé, pas de réseau), on ne montre pas l'alerte
   technique actuelle : on bascule silencieusement sur `OfflineCourseBuilder`, qui sait déjà
   fabriquer des cartes sans IA, et on le dit sobrement (voir §7.5).
3. Session réelle limitée à **3 cartes** — pas la session complète. On affiche les quatre boutons
   avec leurs intervalles, donc on enseigne le vrai geste.
4. Écran de victoire, avec les vraies données : « 3 cartes ancrées. La première revient dans
   10 minutes, la dernière demain. Série : 1 jour. »

**Le risque à couvrir :** l'import peut durer (OCR sur 20 pages) ou échouer. Trois garde-fous :
un chemin de secours toujours visible, un temps d'attente occupé par du contenu utile plutôt que
par une fausse barre, et la possibilité de continuer le parcours si l'import n'aboutit pas
(l'utilisateur ne doit jamais rester coincé dans l'onboarding).

### 4.5 Faire servir les réponses

Le tableau des engagements. Chaque ligne doit être vérifiable dans l'app après la refonte :

| Réponse collectée | Utilisation concrète à implémenter |
| --- | --- |
| `goals` (objectifs) | Le pack de démarrage et le nombre de cartes conseillé par jour. Un « concours » ne se révise pas comme une « culture générale » |
| `subjects` (matières) | Préremplir `DashboardView.subjectFilter`, choisir l'emoji et la teinte du premier cours, filtrer les packs de démarrage |
| `dailyMinutes` | L'objectif quotidien affiché sur l'accueil (« 12 / 15 min aujourd'hui »), le plafond de nouvelles cartes par jour, l'heure du rappel |
| `forgetsOften` | Le seul usage honnête est rhétorique (l'introduction de la courbe). À garder tel quel, ou à supprimer |
| `notificationsOptIn` | Doit déclencher une vraie demande `UNUserNotificationCenter` et la programmation du rappel |
| `institutionId` / `institutionName` | Plus collectées (§3.3). Le catalogue reste en réserve pour la fonctionnalité de comptes |

À faire aussi : **`OnboardingModel` ne recharge pas les préférences au lancement**. Les réponses
sont écrites dans `UserDefaults` à chaque étape, mais si l'utilisateur ferme l'app au milieu du
parcours, il repart de l'écran 1 avec un modèle vide. Recharger l'état et reprendre à la dernière
étape atteinte est une correction de quelques lignes qui évite de perdre les gens qui ont été
interrompus.

### 4.6 Le sort des cours d'exemple

Aujourd'hui : deux cours imposés à tout le monde, sans explication, avec un faux historique.

Proposition : **remplacer `SampleData` par le pack de démarrage choisi**. Concrètement, la même
mécanique (des cours préécrits livrés avec l'app), mais :

- un seul cours, pas deux ;
- choisi dans une matière que l'utilisateur vient de cocher ;
- inséré **seulement** s'il choisit « Je n'ai pas mon cours ici » ;
- étiqueté comme tel dans l'interface (« Cours d'exemple », avec une action « Supprimer » évidente) ;
- sans historique de révision fabriqué : la série doit démarrer à la première vraie révision.

Bénéfice secondaire : l'accueil d'un utilisateur qui a importé son cours ne contient plus que son
cours à lui. C'est son produit, pas une démonstration.

### 4.7 Le paywall

**Structure proposée, en un seul écran :**

1. Titre : ce qu'on débloque, pas le nom du plan.
2. Trois à quatre avantages, formulés en usage (« Autant de cours que tu veux », pas « Cours illimités »).
3. La frise de l'essai (reprise de `trialReminder`) : aujourd'hui / jour 2, on te prévient / jour 3, tu décides.
4. Les deux offres côte à côte, avec l'ancrage mensuel calculé : **39,99 €/an (3,33 €/mois)** contre
   **6,99 €/mois**. Marquer l'annuel « −52 % », ce qui est le chiffre réel.
5. Un bouton principal : « Commencer les 3 jours offerts ».
6. En dessous, en petit et lisible : « Sans engagement. Résiliable à tout moment depuis l'App Store. »
7. Le lien de restauration d'achat (déjà géré par `SubscriptionStoreView`).

**Ce qu'il manque techniquement.** L'achat n'est branché à aucun verrou : le commentaire de
`PaywallStepView.swift:13` le dit (« L'achat n'est branché à rien pour l'instant »). Avant de
travailler la conversion, il faut décider ce que l'abonnement débloque et où le vérifier. Le plus
défendable pour ce produit : **tout est ouvert, sauf la génération par IA au-delà de N cours**.
La révision de ses propres cartes ne devrait jamais être derrière un mur — c'est ce qui a de la
valeur pour l'utilisateur et ce qui ne coûte rien à l'éditeur.

**Repères de conversion** (sources tierces, à traiter comme des ordres de grandeur) : l'essai vers
payant se situe autour de 25–40 % pour une app grand public bien réglée ; en dessous de 20 %, le
problème est presque toujours le placement du paywall ou la durée de l'essai, pas son graphisme.
Environ 90 % des essais démarrent le jour de l'installation, ce qui justifie de tout jouer dans la
première session.

### 4.8 Les permissions

| Moment | Ce qu'on demande | Comment |
| --- | --- | --- |
| Après la première session réussie | Notifications | Écran de préparation (celui qui existe, il est bon), puis **vraie** demande système. Si refus : on n'insiste pas, on n'affiche plus l'écran |
| Fin de la première session hors onboarding, si série ≥ 3 jours et refus précédent | Notifications, deuxième et dernière tentative | « Tu as 3 jours de série. On te prévient si elle est menacée ? » |
| Après 7 jours d'usage | Widget | Une carte discrète sur l'accueil, avec les instructions d'ajout |
| Après une session avec ≥ 90 % de réussite, jamais avant J7 | Note App Store (`SKStoreReviewController`) | Une fois, au bon moment |

---

## 5. La boucle de rétention

C'est la partie qui n'existe pas du tout aujourd'hui, et celle qui décidera si l'app est utilisée
la deuxième semaine.

### 5.1 Les notifications

Cinq messages suffisent. Ils doivent tous être écrits au présent, mentionner un nombre réel, et ne
jamais culpabiliser.

| Déclencheur | Heure | Texte proposé |
| --- | --- | --- |
| Cartes dues, aucune révision aujourd'hui | Heure choisie à l'écran « rythme », par défaut 18 h | **« {n} cartes t'attendent »** — « {m} minutes suffisent pour boucler ta journée. » |
| Série ≥ 2 jours menacée | 21 h, seulement si rien n'a été fait | **« Ta série de {n} jours tient à une carte »** — « Deux minutes et elle est sauvée. » |
| Retour après 3 jours d'absence | 18 h | **« {n} cartes ont dépassé leur date »** — « On reprend doucement : les 10 plus urgentes d'abord. » |
| Fin de l'essai, J−1 | 12 h | **« Il te reste un jour d'essai »** — « Tes cours et ta progression restent à toi dans tous les cas. » |
| Premier cours généré, J+1 | Heure du rythme | **« Ton cours {titre} est prêt à être révisé »** — « Première révision : {n} cartes. » |

Règles : **une seule notification par jour**, jamais deux jours de suite sans ouverture, arrêt
automatique après trois notifications ignorées d'affilée. C'est ce qui distingue un rappel utile
d'un produit qu'on désinstalle.

### 5.2 La série, et son gel

- Afficher la série **dans la session**, pas seulement sur l'accueil : c'est au moment de finir
  qu'elle prend son sens (« Série : 6 jours » sur l'écran de fin).
- **Un gel par semaine, cumulable jusqu'à deux.** Consommé automatiquement en cas de jour manqué,
  avec une notification le lendemain : « Ton gel a servi. Série intacte : {n} jours. »
- **Ne pas casser une série pour un jour sans cartes dues.** Aujourd'hui, `StudyStats.streak` compte
  les jours avec au moins une révision : si le planificateur ne propose rien un mardi, la série
  meurt alors que l'utilisateur a fait exactement ce qu'on lui demandait. C'est un bug de conception
  à corriger — un jour sans carte due doit être neutre.

### 5.3 Le widget

Un seul widget, petite taille, trois informations : le nombre de cartes dues, la série, et l'état
du jour (fait / pas fait). Ouverture directe sur la session. C'est le rappel le moins intrusif qui
existe et il ne dépend d'aucune autorisation.

### 5.4 L'objectif quotidien

`dailyMinutes` doit devenir visible : une barre sur l'accueil, « 8 / 15 min aujourd'hui », remplie
par le temps réel de session (`StudySession.elapsed` existe déjà). Et l'objectif se célèbre : un
retour haptique de succès et une ligne sur l'écran de fin quand il est atteint.

### 5.5 Le retour après absence

Quand un utilisateur revient après une semaine, il trouve aujourd'hui une pile de plusieurs
centaines de cartes en retard : c'est le moment où l'on perd les gens, et c'est le défaut le plus
connu d'Anki. Proposer explicitement, sur l'accueil : « **203 cartes en retard.** On étale ? » avec
deux boutons — « Rattraper sur 5 jours » (répartit les échéances) et « Tout réviser ». C'est un
petit algorithme et un grand soulagement.

---

## 6. Écran par écran

### 6.1 Accueil (`DashboardView`)

**Ce qui va :** la carte sombre « Réviser maintenant » est le bon point d'entrée, la hiérarchie est
claire, le bouton flottant est bien placé.

**À corriger :**

- **Le doublon Accueil / Réviser.** Deux onglets sur cinq lancent la même session `\.allDue`.
  « Réviser » (`TodayView`) affiche la répartition et le détail par cours ; « Accueil » affiche la
  même information en résumé. Trancher : soit `TodayView` devient un écran de détail atteint depuis
  la carte de l'accueil, soit l'accueil perd son bloc de révision. Ma recommandation : **fusionner
  et passer à 4 onglets** (Accueil, Mes cours, Bibliothèque, Profil), l'accueil portant la session
  du jour, la répartition et l'objectif quotidien.
- Afficher l'**objectif quotidien** (§5.4) et la **série avec son gel**.
- Le filtre par matière n'apparaît qu'au-delà de deux matières et n'est jamais prérempli par les
  réponses de l'onboarding.
- L'estimation « ≈ 6 min aujourd'hui » repose sur 30 s par carte codées en dur
  (`CourseCardViews.swift:73`). Une moyenne mobile du temps réel par carte est à portée : les
  données de session existent.

### 6.2 Réviser (`TodayView`)

Si l'onglet est conservé : l'état vide dit « Aucune carte due aujourd'hui. Revenez demain. » —
c'est une impasse. Proposer une action : réviser en avance, importer un cours, ou consolider un
cours faible. Une app d'étude ne devrait jamais dire « reviens demain » sans rien offrir.

### 6.3 La session d'étude (`StudyView`) — priorité absolue

C'est l'écran sur lequel se joue la valeur perçue. Par ordre d'impact :

1. **Afficher les intervalles sous les quatre boutons.** Une ligne de code par bouton, la donnée
   est déjà calculée (`StudySession.previewLabels`). Sans ça, l'utilisateur choisit à l'aveugle
   entre « Difficile » et « Correct ».
2. **Ajouter « Annuler »** en haut à droite : restaure l'état de la carte précédente et la remet en
   tête de file. Il faut mémoriser le `SM2CardSnapshot` d'avant réponse — la structure existe déjà,
   c'est fait pour.
3. **Plafonner la session** : utiliser `Limits.default` (20 nouvelles / 200 révisions) au lieu de
   `.unlimited`, et rendre le plafond de nouvelles cartes dépendant de `dailyMinutes`.
4. **Éditer la carte en session** : un appui long sur la carte ouvre `FlashcardEditorSheet`, qui
   existe. Indispensable avec des cartes générées.
5. **Reprendre une session interrompue** : conserver la file dans le modèle plutôt que dans un
   `@State`, et proposer « Reprendre la session (7 cartes restantes) » sur l'accueil.
6. **Enrichir l'écran de fin** : aujourd'hui trois compteurs (acquises, à revoir, réussite). Y
   ajouter la série, l'objectif quotidien, la prochaine échéance (« Prochaine session : demain,
   14 cartes ») et un bouton « Encore 10 cartes » — le geste qui prolonge une session est le geste
   le plus rentable du produit.
7. **Le geste.** La carte se retourne au tap, très bien. Ajouter le balayage horizontal pour noter
   (gauche = à revoir, droite = correct) ferait gagner du temps aux utilisateurs réguliers, sans
   retirer les boutons.
8. **Accessibilité de la notation :** les quatre boutons n'ont pas d'étiquette d'accessibilité
   distincte de leur texte ; avec l'intervalle affiché, VoiceOver doit lire « Correct, prochaine
   révision dans 1 jour ».

### 6.4 Détail d'un cours (`FlashcardsView`)

- La liste des cartes n'affiche que le recto et une pastille de couleur. Ajouter le nombre de
  révisions et la prochaine échéance en ligne rendrait la page utile hors session.
- Pas de recherche ni de tri dans les cartes d'un cours : gênant au-delà de 50 cartes.
- Pas de sélection multiple : impossible de supprimer dix cartes ratées d'un coup après une
  génération médiocre. C'est le premier réflexe après un import moyen.
- « Générer avec l'IA » ajoute 10 cartes sans dire combien il en existe déjà ni prévenir des
  doublons (`existingFronts` est bien transmis, mais l'utilisateur ne le sait pas).
- L'action de suppression du cours est dans le menu « … » avec une confirmation correcte : bon.

### 6.5 Mes cours (`CoursesListView`)

Écran sain. Deux ajouts : le tri « À réviser » devrait être le tri par défaut quand des cartes sont
dues, et la recherche devrait porter aussi sur le contenu des cartes, pas seulement sur le titre,
la matière et le résumé.

### 6.6 Bibliothèque (`LibraryView`)

Un onglet sur cinq occupé par une promesse. Deux options :

- **Option courte (recommandée pour l'instant) :** retirer l'onglet de la barre et le remplacer par
  la version fusionnée de « Réviser ». La bibliothèque revient quand elle existe.
- **Option intermédiaire :** livrer une bibliothèque *locale* — 15 à 30 paquets préécrits fournis
  avec l'app, par matière, alignés sur les matières de l'onboarding. Pas de backend, pas de compte,
  et l'onglet tient enfin sa promesse. C'est aussi la réserve où puiser le pack de démarrage du §4.6.

### 6.7 Profil et Réglages

**Profil :** les statistiques sont bonnes (série, révisions, cours, cartes, graphique 14 jours).
Retirer la section « Amis · Bientôt » tant qu'elle n'existe pas. Ajouter ce qui manque vraiment :
la rétention réelle (part de « Correct » ou mieux sur 30 jours), le nombre de cartes « acquises »
(intervalle > 21 jours), et l'export des données.

**Réglages :** l'écran est aujourd'hui un panneau de développement (§P4). Le découper :

| Section | Contenu | Visibilité |
| --- | --- | --- |
| Révision | Objectif quotidien, nouvelles cartes par jour, heure du rappel, notifications | Tous |
| Contenu | Langue de génération, longueur des réponses, exporter mes cours | Tous |
| Confidentialité | Ce qui reste sur l'appareil, ce qui part au serveur, effacer mes données | Tous |
| À propos | Version, algorithme, mentions | Tous |
| Développement | URL Supabase, clé publique, modèle, refaire l'onboarding | **Caché** derrière sept appuis sur le numéro de version, ou compilé en `#if DEBUG` |

---

## 7. Les textes

### 7.1 Le problème le plus visible : l'app change de personne

L'onboarding tutoie de bout en bout : « Tu révises quoi ? », « Sois honnête, personne ne regarde »,
« C'est quoi tes objectifs ? ».

L'application vouvoie : « Revenez plus tard, ou entraînez-vous en avance depuis un cours. »
(`StudyView`), « Importez un PDF… pour générer vos premières flashcards. » (`DashboardView`),
« Les cours que vous importez depuis l'accueil apparaîtront ici. » (`CoursesListView`),
« Collez vos notes, même brutes. » (`ImportView`), « Essayez un autre mot-clé. », « Revenez demain. »

Un utilisateur passe donc du tutoiement au vouvoiement au moment exact où il entre dans le
produit. **Trancher pour le tutoiement partout** : la cible est étudiante, l'onboarding — la partie
la plus travaillée — est déjà écrit ainsi, et le vouvoiement des états vides sonne administratif.
Le chantier est court : une dizaine de chaînes dans six fichiers.

### 7.2 Trois mots pour une même chose

L'app appelle une carte à réviser tantôt « **due** » (« 12 cartes dues », accueil), tantôt
« **à revoir** » (« cartes à revoir », Réviser), tantôt « **à réviser** » (« 8 à réviser », liste
des cours). « Due » est en plus un anglicisme opaque pour un lycéen.

**Décision à prendre et à tenir : « à réviser » partout.** Et « À revoir » reste réservé au bouton
de notation, où il a un sens précis.

Autres termes à figer dans un glossaire : *carte* (jamais « flashcard » dans l'interface, sauf dans
les textes marketing où le mot est cherché), *cours* (jamais « paquet » ni « deck »), *session*,
*série*, *acquise* (intervalle > 21 jours).

### 7.3 Principes d'écriture

1. **Un chiffre plutôt qu'un adjectif.** « 12 cartes, environ 6 minutes » bat « quelques cartes ».
2. **Dire ce que ça fait, pas ce que c'est.** « Ton cours redevient des questions » bat
   « Génération automatique par IA ».
3. **Les états vides proposent une action.** Aucun cul-de-sac.
4. **Les erreurs disent quoi faire.** Jamais le nom d'un service tiers.
5. **Pas de superlatif.** La sobriété est la marque ; « révolutionnaire » la détruit.
6. **Le bouton dit le résultat.** « Commencer les 3 jours offerts » bat « Continuer ».

### 7.4 Réécritures — session et notation

Les libellés actuels des quatre boutons (`Flashcard.swift`) : « À revoir », « Difficile »,
« Correct », « Facile ». Le problème : « Correct » et « Facile » se ressemblent, et rien ne dit que
« Correct » est le cas normal.

| Élément | Aujourd'hui | Proposé |
| --- | --- | --- |
| Bouton 1 | À revoir | **Oublié** · sous-titre `1 min` |
| Bouton 2 | Difficile | **Difficile** · sous-titre `10 min` |
| Bouton 3 | Correct | **Su** · sous-titre `1 j` |
| Bouton 4 | Facile | **Trop facile** · sous-titre `4 j` |
| Invite | Comment as-tu répondu ? | **Tu savais ?** |
| Bouton de révélation | Afficher la réponse | **Voir la réponse** |
| Action secondaire | Passer | **Plus tard** |
| Action secondaire | Mettre en pause | **Mettre de côté** |
| Fin de session (titre) | Session terminée | **C'est bouclé** |
| Fin de session (détail) | 12 cartes révisées en 5 min | **12 cartes en 5 min · série 6 jours** |
| Fin de session (vide) | Rien à réviser | **Rien à réviser aujourd'hui** |
| Fin de session (vide, détail) | Revenez plus tard, ou entraînez-vous en avance depuis un cours. | **Tu es à jour. Tu peux prendre de l'avance sur un cours si tu veux.** |
| Indice | Indice | inchangé, mais l'étiquette d'accessibilité doit annoncer qu'il ne révèle pas la réponse |

### 7.5 Réécritures — erreurs et messages techniques

| Situation | Aujourd'hui (`AIService.swift`) | Proposé |
| --- | --- | --- |
| Service non configuré | L'accès à l'IA n'est pas configuré. Renseignez l'URL Supabase dans Profil, Réglages. | **La génération est indisponible pour l'instant.** On peut quand même créer tes cartes à partir du texte, sans IA. |
| Clé du fournisseur absente | La clé fal.ai est absente côté Supabase. Ajoutez le secret FAL_KEY à votre projet. | *(même message que ci-dessus — l'utilisateur n'a pas à connaître la cause)* |
| Réseau | Connexion impossible. {message} | **Pas de connexion.** Ton cours est enregistré, on générera les cartes dès que le réseau revient. |
| Réponse illisible | La réponse de l'IA n'a pas pu être lue. Réessayez. | **La génération a échoué.** Réessayer, ou créer les cartes sans IA. |
| Texte trop court | Il n'y a pas assez de texte à analyser. | **Ce document est trop court** (moins de 40 caractères lus). Ajoute des pages ou colle plus de texte. |
| Titre de l'alerte | Génération impossible | **On n'a pas pu générer les cartes** |
| Bouton de repli | Créer sans IA | **Créer les cartes sans IA** |

Et dans l'import : remplacer « Seule la rédaction des cartes passe par vos Edge Functions
(google/gemini-flash-1.5) » par **« Le texte de ton document est lu sur ton téléphone. Seul le
texte nécessaire à la rédaction des cartes est envoyé. »** — même information, sans jargon, et
c'est un argument de vente.

De même, l'option « Analyser les schémas et images » est décrite comme « Option payante : jusqu'à
6 pages partent au modèle de vision ». Proposer : **« Lire aussi les schémas et les images —
utile pour les cours annotés. Un peu plus long. »**

### 7.6 Réécritures — onboarding conservé

| Écran | Aujourd'hui | Proposé |
| --- | --- | --- |
| Bienvenue | Apprends tout,\nplus vite. | **Ce que tu apprends,\ntu le gardes.** |
| Bienvenue (sous-titre) | Tes cours deviennent des flashcards, et Micabo te les repose pile au moment où tu allais les oublier. | inchangé — c'est la meilleure phrase du produit |
| Objectifs | C'est quoi tes objectifs ? | **Tu révises pour quoi ?** |
| Rythme (sous-titre) | Mieux vaut dix minutes tous les jours qu'une heure le dimanche. | inchangé |
| Import réel (nouveau) | — | **Assez parlé. Importe ton cours.** / « Un PDF, une photo du tableau, tes notes. On en fait des cartes en moins d'une minute. » |
| Repli import (nouveau) | — | **Je n'ai pas mon cours ici** → « On commence avec un cours de {matière}. Tu importeras le tien plus tard. » |
| Attente de génération | On personnalise ton profil / Quelques secondes, promis. | **On écrit tes cartes** / « {n} pages lues. Une question par idée. » |
| Victoire (nouveau) | — | **Ta première carte est ancrée.** / « Elle revient dans 10 minutes, puis demain, puis dans quatre jours. C'est ça, la répétition espacée. » |
| Notifications | On te rappelle\nau bon moment. | inchangé — bon écran |
| Notifications (refus) | Plus tard | **Pas maintenant** |
| Paywall (titre) | Micabo, en entier | **Continue sans limite** |
| Paywall (sous-titre) | 3 jours offerts, puis tu décides. | inchangé |
| Paywall (bouton) | *(natif StoreKit)* | **Commencer les 3 jours offerts** |
| Repli sans offre | Offre bientôt disponible / Les abonnements ne sont pas encore publiés. | **Tout est ouvert** / « L'abonnement n'est pas encore en place. Profite de l'app entière en attendant. » |

### 7.7 États vides

| Écran | Aujourd'hui | Proposé |
| --- | --- | --- |
| Accueil, aucun cours | Aucun cours pour l'instant / Importez un PDF, des photos, un Word ou collez du texte pour générer vos premières flashcards. | **Ton premier cours t'attend** / « PDF, photo du tableau, Word ou notes collées : tout marche. » |
| Mes cours, vide | Votre liste est vide / Les cours que vous importez depuis l'accueil apparaîtront ici. | **Rien ici pour l'instant** / « Tes cours importés apparaîtront ici. » + bouton d'import |
| Recherche sans résultat | Aucun résultat / Essayez un autre mot-clé. | **Aucun cours ne correspond** / « Essaie un autre mot. » |
| Cours sans carte | Aucune flashcard / Générez un jeu de cartes à partir du contenu importé, ou créez-en une à la main. | **Ce cours n'a pas encore de cartes** / « Génère-les à partir du contenu importé, ou écris-en une. » |
| Réviser, à jour | Tout est à jour / Aucune carte due aujourd'hui. Revenez demain. | **Tout est à jour** / « Rien à réviser aujourd'hui. Prochaine session : {jour}, {n} cartes. » + « Prendre de l'avance » |

---

## 8. Design

### 8.1 Le mode sombre

`MicaboApp.swift:19` force `.preferredColorScheme(.light)`. Pour une app qu'on ouvre le soir, à
21 h, pour sauver une série, c'est un manque qui se remarque — et une critique récurrente en
commentaires d'App Store.

Le chantier n'est pas cosmétique : `MicaboColor` définit une vingtaine de jetons plus huit teintes
de cours, tous en valeurs fixes (`Color(hex:)`), donc non adaptatives. La bonne façon de faire est de déplacer la palette dans le
catalogue d'assets (`Assets.xcassets`) avec une variante sombre par jeton, et de garder l'API
`MicaboColor` identique — les vues n'ont alors rien à changer, sauf celles qui codent une couleur
en dur.

### 8.2 La dérive du design system

Le thème est bien fait, mais les vues le contournent régulièrement. Exemples relevés :
`Color(hex: 0x4A463F)` pour du texte (session, bibliothèque), `Color(hex: 0xC9C3B8)` pour les
chevrons (trois fichiers), `Color(hex: 0x8F8B82)` et `Color(hex: 0x9A958A)` pour des textes sur
fond sombre, `Color(hex: 0xC9B98A)` pour l'état « dû », `Color(hex: 0xB5573C)` pour le bouton
« À revoir », `Color(hex: 0xB39A5A)` et `Color(hex: 0xF0ECE2)` pour le trophée de fin de session.

Ces couleurs ont un rôle réel — il leur manque juste un nom. À ajouter au thème :
`inkOnDark`, `inkOnDarkMuted`, `chevron`, `due`, `ratingAgain`, `trophy`, `trophyBackground`,
`hintText`. Sans ça, le mode sombre sera ingérable.

Même dérive côté typographie : `MicaboFont` définit une échelle (11, 13, 15, 16, 18, 22, 27) mais
les vues appellent `MicaboFont.hanken(...)` avec des tailles hors échelle — 10, 12, 14, 17, 20, 21,
24, 26, 30, 72. Recommandation : figer une échelle de huit valeurs, la nommer par rôle, et rendre
l'appel direct à `hanken(_:weight:)` exceptionnel.

### 8.3 Accessibilité

C'est le point le plus faible du design actuel, et le plus simple à traiter.

- **La taille dynamique n'est pas supportée.** Toutes les polices passent par
  `.custom(nom, size:)` sans `relativeTo:`, donc **le texte ne grandit pas** quand l'utilisateur
  agrandit la police du système. Sur une app de lecture destinée à des étudiants qui révisent des
  heures, c'est un vrai problème. Correction mécanique dans `MicaboFont` :
  `.custom(postscriptName(for: weight), size: size, relativeTo: textStyle)`.
- **Les contrastes secondaires sont limites.** `inkTertiary` (#B3ADA2) sur le fond ivoire (#FAF9F6)
  tourne autour de 2:1 — nettement sous le seuil AA de 4,5:1 pour du texte courant. Cette couleur
  porte pourtant des informations utiles (compteurs, méta-données des cours, sous-titres). À
  assombrir, ou à réserver à du décoratif.
- **Le mouvement réduit n'est pas respecté.** L'app est très animée (cascades, compteurs animés,
  tracé de courbe sur 1,9 s, halos pulsés en boucle). Aucune vérification de
  `accessibilityReduceMotion`.
- **VoiceOver est partiel.** Des étiquettes existent aux bons endroits (onglets, bouton d'indice,
  bouton retour), mais les cartes de cours, les statistiques et les boutons de notation lisent leur
  contenu brut.

### 8.4 Micro-interactions

Ce qui existe est de bonne qualité (haptiques centralisées dans `Haptics`, cascades d'apparition,
ressorts bien réglés). Trois ajouts à fort rapport :

1. **Célébrer la fin d'objectif quotidien** — c'est le seul moment où une animation appuyée est
   justifiée.
2. **Animer le changement de série** sur l'accueil quand elle augmente.
3. **Retirer l'animation qui ne veut rien dire** : le halo pulsé en boucle de l'écran d'attente
   attire l'œil sur une attente. Une progression réelle vaut mieux qu'un effet.

### 8.5 Détails visuels relevés

- L'invite « Appuie pour retourner » des cartes de bienvenue ne fait rien (§P6).
- Les pavés de matières de la Bibliothèque sont `allowsHitTesting(false)` : ils ont l'air cliquables
  et ne le sont pas. Il faut soit les rendre inertes visuellement, soit les brancher.
- La barre d'onglets a cinq entrées avec des libellés longs (« Bibliothèque ») en 10 pt : à la
  limite de la lisibilité, et un argument de plus pour passer à quatre onglets.
- L'écran de session ne montre pas la répartition des cartes restantes alors que
  `StudySession.counts` la calcule.

---

## 9. Les manques produit

Par ordre de valeur décroissante, indépendamment de l'effort :

1. **Un compte et la synchronisation.** Tout est local. Changer de téléphone, c'est tout perdre ;
   réviser sur deux appareils est impossible. C'est aussi le préalable à la bibliothèque partagée,
   aux amis et aux classements par établissement — trois fonctionnalités déjà annoncées dans
   l'interface.
2. **FSRS en remplacement de SM-2.** Les benchmarks publics (Anki, sur plusieurs centaines de
   millions de révisions) donnent 20–30 % de révisions en moins à rétention égale ; c'est
   l'algorithme par défaut d'Anki depuis la v23.10. Pour un produit qui vend le temps gagné, c'est
   un argument mesurable. `SM2Scheduler` est déjà isolé derrière `SM2CardSnapshot` / `SM2Outcome`,
   donc l'échange est faisable proprement, avec conservation de SM-2 en repli.
3. **Le partage d'un cours** (lien ou fichier). Le geste le plus viral du secteur, et le plus
   naturel entre étudiants d'une même promo.
4. **L'import audio et vidéo** (cours enregistré, YouTube). C'est là que se battent Gizmo et
   Mindgrasp. La transcription sur l'appareil est possible côté Apple.
5. **Les modes d'étude alternatifs** (QCM, réponse écrite) à partir des mêmes cartes.
6. **L'export** (CSV, format Anki). Rassure à l'achat autant qu'il sert à l'usage : « tes données
   sortent quand tu veux » est un argument face à Quizlet.

---

## 10. Plan d'exécution

Quatre lots, ordonnés par rapport valeur/risque. Chaque lot est livrable seul.

### Lot 0 — Honnêteté et hygiène

*Le préalable : rien de ce qui suit ne mérite d'être optimisé tant que le produit affirme des
choses fausses.*

| Action | Fichiers |
| --- | --- |
| Supprimer le nombre de pairs inventé (et l'écran) | `SchoolPeersStepView.swift`, `SchoolStepView.swift`, `OnboardingStep.swift` |
| Cacher les réglages de développement | `SettingsView.swift` |
| Réécrire les messages d'erreur | `AIService.swift`, `ImportView.swift` |
| Retirer ou brancher les invites mortes | `WelcomeStepView.swift`, `LibraryView.swift` |
| Uniformiser le tutoiement | 6 fichiers de vues |
| Un seul mot pour « à réviser » | `CourseCardViews.swift`, `TodayView.swift`, `DashboardView.swift` |

**Critère de sortie :** aucune affirmation invérifiable, aucun terme technique tourné vers
l'utilisateur, une seule personne grammaticale.

### Lot 1 — La session mérite son statut de cœur du produit

| Action | Fichiers |
| --- | --- |
| Intervalles sous les quatre boutons | `StudyView.swift` (données déjà présentes) |
| Bouton « Annuler » | `StudyView.swift`, `StudySession.swift` |
| Plafonner la session (`Limits.default`) | `StudySession.swift` |
| Édition en session (appui long) | `StudyView.swift` + `FlashcardEditorSheet` |
| Écran de fin enrichi + « Encore 10 cartes » | `StudyView.swift` |
| Reprise de session | `StudySession.swift`, `DashboardView.swift` |
| Libellés de notation revus | `Flashcard.swift`, `StudyView.swift` |

**Critère de sortie :** un utilisateur qui se trompe de bouton peut se rattraper, sait ce que
chaque bouton fait avant d'appuyer, et n'est jamais coincé dans une session de 200 cartes.

### Lot 2 — La refonte du parcours d'accueil

Le plus gros lot, celui du §4. Il touche `OnboardingStep`, `OnboardingFlowView`, six vues d'étapes
supprimées ou fusionnées, et surtout l'intégration de `ImportView` et de `StudyView(isEmbedded:)`
dans le parcours. Il faut aussi câbler les réponses (§4.5), remplacer `SampleData` par le pack de
démarrage, et refondre le paywall en un écran.

**Critère de sortie :** un nouvel utilisateur atteint sa première carte révisée — issue de son
propre contenu ou d'un pack qu'il a choisi — **avant** de voir un prix, et chaque question posée a
un effet visible dans l'app.

**Risque principal :** un import qui échoue ou traîne au milieu de l'onboarding. Le chemin de
secours doit être testé en premier, pas en dernier.

### Lot 3 — La boucle de rétention

Notifications réelles (permission, programmation, cinq messages, règles anti-spam), série avec gel,
objectif quotidien branché sur `dailyMinutes`, widget, rattrapage des cartes en retard, deuxième
demande d'autorisation. C'est le lot qui décide de la rétention J7 et J30.

### Hors lots — à instruire séparément

Le mode sombre, la taille dynamique et le compte/synchronisation sont des chantiers transverses.
La taille dynamique et les contrastes devraient être traités **avant** le mode sombre : ce sont des
corrections mécaniques, alors que le mode sombre demande de renommer et de dédoubler toute la
palette.

---

## 11. Ce qu'il faut mesurer

Rien de ce plan ne se pilote sans quelques événements. Le minimum utile, six événements :

| Événement | Ce qu'il permet |
| --- | --- |
| `onboarding_step_view(step)` | Trouver l'écran qui perd le plus de monde |
| `first_import_started(kind)` / `first_import_succeeded(cards)` | Mesurer le vrai goulot : l'import |
| `first_session_completed(cards, seconds)` | L'activation |
| `paywall_view` / `trial_started` / `trial_converted` | La conversion |
| `session_completed(cards, accuracy, streak)` | L'usage |
| `notification_opened(type)` | L'efficacité de chaque message |

**La métrique d'activation à retenir :** *part des nouveaux utilisateurs qui terminent une session
d'au moins trois cartes le jour de l'installation*. C'est elle qui prédit la rétention, pas le
nombre d'écrans complétés.

**Repères pour se situer** (sources tierces, ordres de grandeur) : essai vers payant 25–40 % pour
une app grand public bien réglée ; en dessous de 20 %, revoir le placement du paywall avant son
graphisme. ~90 % des essais démarrent le jour de l'installation. Une part importante des
utilisateurs qui n'atteignent jamais un jalon de valeur sont perdus en deux semaines.

---

## 12. Annexes

### 12.1 Les 20 étapes actuelles, dans l'ordre

| # | Étape | Type | Sortie | Persiste |
| --- | --- | --- | --- | --- |
| 1 | `welcome` | Bouton | « Commencer » | — |
| 2 | `language` | Affichage | « Continuer » | — |
| 3 | `personalizeIntro` | Bouton | « C'est parti » | — |
| 4 | `goal` | Choix multiple | « Continuer » | `goals` |
| 5 | `forgetting` | Choix unique | Auto (0,34 s) | `forgetsOften` |
| 6 | `retentionChart` | Animation (1,9 s) | « Continuer » | — |
| 7 | `science` | 2 taps | « Continuer » | — |
| 8 | `demoImport` | Tap simulé | Auto (~2,2 s) | — |
| 9 | `demoWrite` | Tap simulé | « Continuer » | — |
| 10 | `demoReview` | Tap + verdict | Auto (2,6 s) | — |
| 11 | `subjects` | Choix multiple | « Continuer » | `subjects` |
| 12 | `school` | Saisie + recherche | « Continuer avec … » | `institutionId`, `institutionName` |
| 13 | `schoolPeers` | Animation | « Continuer » | — |
| 14 | `dailyTime` | Curseur 5–60 | « Continuer » | `dailyMinutes` |
| 15 | `projection` | Compteur animé | « Continuer » | — |
| 16 | `notifications` | 2 boutons | « Activer » / « Plus tard » | `notificationsOptIn` |
| 17 | `personalizing` | Attente 4,85 s | Auto | — |
| 18 | `trialOffer` | Bouton | « Continuer » | — |
| 19 | `trialReminder` | Bouton | « Voir l'offre » | — |
| 20 | `paywall` | StoreKit | Achat ou repli | `completed` |

### 12.2 Les incohérences relevées, en une liste

1. Tutoiement dans l'onboarding, vouvoiement dans l'app.
2. « Cartes dues » / « à revoir » / « à réviser » pour la même chose.
3. La démo enseigne deux boutons, la session en a quatre.
4. La démo annonce « 3 jours » là où le planificateur donne 10 minutes.
5. La démo promet la lecture des schémas, l'app en fait une option désactivée par défaut.
6. « Appuie pour retourner » sur une carte non interactive.
7. Les pavés de matières de la Bibliothèque ont l'air cliquables et ne le sont pas.
8. Un nombre d'utilisateurs tiré au hasard, présenté comme un fait.
9. Une barre de progression de personnalisation qui ne mesure rien.
10. Neuf réponses collectées, une seule utilisée.
11. Deux cours d'exemple non annoncés, avec un historique fabriqué.
12. Un sélecteur de modèle d'IA et une clé d'API dans les réglages grand public.
13. Une série qui se casse un jour où l'app n'avait rien à proposer.
14. Des intervalles calculés et jamais affichés.
15. Un mode « embarqué » de la session, écrit et jamais utilisé.

---

*Document établi à partir de l'état du dépôt sur `main` au 15 août 2026.*
