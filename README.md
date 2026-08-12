# Micabo

Application iOS native de révision : vos cours PDF ou vos notes deviennent des flashcards en répétition espacée façon Anki.

<img src="Micabo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Icône Micabo" />

## Ce que fait l'application

| Onglet | Rôle |
| --- | --- |
| Réviser | La pile de flashcards dues aujourd'hui, tous cours confondus |
| Mes cours | Les cours importés, avec recherche et tri |
| Accueil | Tableau de bord : révisions du jour, statistiques, cours récents, bouton d'import |
| Bibliothèque | Cours partagés par la communauté (en attente de l'authentification) |
| Profil | Statistiques, amis (en attente de l'authentification) et réglages |

Le parcours principal tient en trois écrans : bouton `+` sur l'accueil, choix PDF ou texte,
génération des flashcards, visualisation et édition, puis entraînement.

## Parcours d'accueil

Au premier lancement, `RootView` affiche `OnboardingFlowView` à la place de la barre d'onglets.
Le parcours est **strictement linéaire** : chaque écran pousse le suivant, il n'y a ni retour
arrière ni balayage. Les étapes sont décrites par `OnboardingStep` et rendues par
`Micabo/Features/Onboarding/Steps/`.

| Bloc | Écrans |
| --- | --- |
| Accroche | bienvenue, langue, annonce des questions |
| Questions | objectif, rapport à l'oubli, matières, établissement, preuve sociale, temps quotidien |
| Démonstration | courbe de mémorisation, preuves scientifiques, import → génération → révision en trois écrans manipulables |
| Sortie | projection annuelle, notifications, personnalisation, essai de 3 jours, paywall |

Les réponses sont écrites au fil de l'eau dans `OnboardingPreferences` (clés `micabo.onboarding.*`)
et survivent donc à une fermeture en cours de route. `Réglages` propose **Refaire l'onboarding**,
qui efface ces clés et relance le parcours sans toucher aux cours.

Après le choix des matières, **Tu étudies où ?** propose un autocomplete hybride : un catalogue
embarqué (`LocalInstitutions.json`, ~600 établissements FR/EU prioritaires) pour l'instantané,
puis la RPC Supabase `search_institutions` sur la table `institutions` (~14 500 lignes : unis
mondiales, grandes écoles FR, lycées FR). Le texte libre reste accepté ; l'`id` est stocké
quand un résultat matche. L'écran suivant anime un compteur (30–70) : « X personnes de … utilisent déjà Micabo ».

L'écran courbe s'appuie sur `RetentionCurve` : une décroissance exponentielle de la rétention, remise
à 100 % à chaque révision, avec une stabilité qui augmente à chaque passage. Les travaux cités
(Ebbinghaus 1885, Landauer & Bjork 1978, Cepeda et al. 2006, Karpicke & Roediger 2008,
Dunlosky et al. 2013) sont réels et rapportés sans arrondir leurs résultats.

Le paywall utilise `SubscriptionStoreView` de StoreKit 2. Aucun produit n'est publié :
`Micabo/Resources/Micabo.storekit`, référencé par le scheme, permet de faire tourner l'écran en
local. Quand aucun produit ne se charge, un repli affiche l'offre et laisse entrer dans l'app.

## Direction visuelle

- Fond ivoire (`#FAF9F6`), surfaces blanches, encre `#1A1917`, accent indigo `#5B5BD6`
- Typographie Hanken Grotesk embarquée (Regular / Medium / SemiBold / Bold)
- Coins mesurés : 9 pt (miniatures), 14 pt (boutons), 18 pt (cartes) — pas de capsules partout
- Barre d'onglets **native** iOS ; bouton « + » flottant en bas à droite sur l'accueil
- Réviser : carte sombre avec le nombre de cartes dues en très grand
- Détail cours : en-tête pastel plat dérivé de la teinte du cours, liste compacte à pastilles
- Chaque cours porte une couverture miniature : première page PDF, sinon initiales sur pastel
- Animations en cascade et retours haptiques centralisés dans `Haptics`

## Pile technique

- SwiftUI, iOS 17 minimum, projet Xcode natif (`Micabo.xcodeproj`)
- SwiftData pour le stockage local (aucune donnée n'est envoyée hors des appels IA)
- PDFKit pour l'extraction du texte, le rendu des pages et la couverture
- Supabase Edge Functions comme relais vers fal.ai (`google/gemini-flash-1.5`)

## Ouvrir le projet

```bash
open Micabo.xcodeproj
```

Le projet utilise les groupes synchronisés avec le système de fichiers : tout fichier ajouté dans
`Micabo/` est automatiquement compilé, sans manipulation du `.pbxproj`.

## Configuration de l'IA

L'application appelle deux Edge Functions Supabase. Le code source est dans `supabase/functions/`.

| Fonction | Rôle |
| --- | --- |
| `generate-course` | Lit le texte et les pages du PDF, renvoie titre, matière, résumé et fiche de travail |
| `generate-flashcards` | Produit un jeu de cartes recto verso à partir de cette fiche |

### 1. Ajouter la clé fal.ai

Dans le tableau de bord Supabase, `Edge Functions` puis `Secrets`, créez :

```
FAL_KEY = votre clé fal.ai
```

### 2. Déployer les fonctions

```bash
supabase link --project-ref votre-ref
supabase functions deploy generate-course
supabase functions deploy generate-flashcards
```

### 3. Renseigner le projet dans l'application

L'URL et la clé publique par défaut sont dans `Micabo/Services/AppConfig.swift`. Elles restent
modifiables à l'exécution depuis `Profil`, `Réglages`, sans recompiler.

Tant que `FAL_KEY` n'est pas configurée, l'import reste utilisable : Micabo propose de construire
les cartes hors ligne, à partir du texte brut.

## Contenu analysé

`generate-course` renvoie une fiche de travail à plat : une notion par ligne, sans mise en forme.
Elle n'est jamais affichée, elle sert de contexte pour rédiger les cartes et pour en ajouter
plus tard. La lecture du client reste tolérante : si la fonction déployée renvoie encore l'ancien
format en blocs structurés, seuls les textes sont conservés.

## Répétition espacée

`Micabo/SRS/SM2Scheduler.swift` implémente SM-2 avec les réglages par défaut d'Anki :

- paliers d'apprentissage 1 min puis 10 min, réapprentissage 10 min
- sortie d'apprentissage à 1 jour, bouton « Facile » à 4 jours
- facilité de départ 2,5, plancher 1,3, bonus « Facile » 1,3, multiplicateur « Difficile » 1,2
- une rechute coûte 0,20 de facilité et renvoie la carte en réapprentissage
- dispersion aléatoire des échéances au-delà de 2,5 jours

Les quatre boutons `À revoir`, `Difficile`, `Correct`, `Facile` affichent l'intervalle réel qu'ils
appliqueront. Les tests de `MicaboTests/SM2SchedulerTests.swift` verrouillent ces valeurs.

## Structure

```
Micabo/
  App/             point d'entrée et conteneur SwiftData
  DesignSystem/    jetons de style et composants réutilisables
  Models/          entités SwiftData et réponses de l'IA
  Persistence/     enregistrement des cours et contenu de démonstration
  SRS/             planificateur SM-2, file d'attente, statistiques
  Services/        client IA, extraction PDF, nettoyage de texte
  Features/        un dossier par écran
supabase/functions/  Edge Functions Deno
scripts/             génération de l'icône
```

## Tests

```bash
xcodebuild test -project Micabo.xcodeproj -scheme Micabo -destination 'platform=iOS Simulator,name=iPhone 16'
```
