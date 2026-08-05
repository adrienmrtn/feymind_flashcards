# Feymind

Application iOS native de révision : vos cours PDF ou vos notes deviennent un cours illustré, puis des flashcards en répétition espacée façon Anki.

<img src="Feymind/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Icône Feymind" />

## Ce que fait l'application

| Onglet | Rôle |
| --- | --- |
| Réviser | La pile de flashcards dues aujourd'hui, tous cours confondus |
| Mes cours | Les cours importés, avec recherche et tri |
| Accueil | Tableau de bord : révisions du jour, statistiques, cours récents, bouton d'import |
| Bibliothèque | Cours partagés par la communauté (en attente de l'authentification) |
| Profil | Statistiques, amis (en attente de l'authentification) et réglages |

Le parcours principal : bouton `+` sur l'accueil, choix PDF ou texte, import, génération du cours,
lecture du cours, bouton « S'entraîner », génération des flashcards, édition, puis entraînement.

## Pile technique

- SwiftUI, iOS 17 minimum, projet Xcode natif (`Feymind.xcodeproj`)
- SwiftData pour le stockage local (aucune donnée n'est envoyée hors des appels IA)
- PDFKit pour l'extraction du texte et le rendu des pages
- Supabase Edge Functions comme relais vers fal.ai (`google/gemini-flash-1.5`)

## Ouvrir le projet

```bash
open Feymind.xcodeproj
```

Le projet utilise les groupes synchronisés avec le système de fichiers : tout fichier ajouté dans
`Feymind/` est automatiquement compilé, sans manipulation du `.pbxproj`.

## Configuration de l'IA

L'application appelle trois Edge Functions Supabase. Le code source est dans `supabase/functions/`.

| Fonction | Rôle |
| --- | --- |
| `generate-course` | Transforme le texte et les pages du PDF en cours structuré en blocs |
| `generate-flashcards` | Produit un jeu de cartes recto verso à partir du cours |
| `explain-passage` | Explique un passage sélectionné, dans le contexte du cours |
| `generate-podcast` | Script à deux voix + synthèse MiniMax Turbo (podcast court) |

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
supabase functions deploy explain-passage
supabase functions deploy generate-podcast
```

### 3. Renseigner le projet dans l'application

L'URL et la clé publique par défaut sont dans `Feymind/Services/AppConfig.swift`. Elles restent
modifiables à l'exécution depuis `Profil`, `Réglages`, sans recompiler.

Tant que `FAL_KEY` n'est pas configurée, l'import reste utilisable : Feymind propose de construire
le cours et les cartes hors ligne, à partir du texte brut.

## Répétition espacée

`Feymind/SRS/SM2Scheduler.swift` implémente SM-2 avec les réglages par défaut d'Anki :

- paliers d'apprentissage 1 min puis 10 min, réapprentissage 10 min
- sortie d'apprentissage à 1 jour, bouton « Facile » à 4 jours
- facilité de départ 2,5, plancher 1,3, bonus « Facile » 1,3, multiplicateur « Difficile » 1,2
- une rechute coûte 0,20 de facilité et renvoie la carte en réapprentissage
- dispersion aléatoire des échéances au-delà de 2,5 jours

Les quatre boutons `À revoir`, `Difficile`, `Correct`, `Facile` affichent l'intervalle réel qu'ils
appliqueront. Les tests de `FeymindTests/SM2SchedulerTests.swift` verrouillent ces valeurs.

## Format des cours

L'IA renvoie un cours découpé en blocs typés, rendus nativement en SwiftUI :

`heading`, `paragraph`, `list`, `keyPoints`, `callout`, `definition`, `formula`, `table`, `quote`,
`divider`, `flow`, `cycle`, `tree`, `comparison`, `timeline`, `chart`.

Les textes acceptent un balisage court : `**gras**`, `*italique*`, `==surligné==`, `` `code` ``.
Les tirets cadratins sont interdits côté prompt et retirés côté client comme côté serveur.

Dans la vue du cours, sélectionner un passage permet de **surligner** (jaune, menthe ou lilas)
ou de **demander à l'IA**. Les surlignages de l'étudiant sont stockés localement.

Un bandeau **Écouter en podcast** génère un dialogue court entre deux voix françaises
(MiniMax Speech-02 Turbo, ~0,06 $/1k caractères). Les voix sont modifiables, la durée cible
reste volontairement courte (3 à 7 min) pour limiter le coût.

## Structure

```
Feymind/
  App/             point d'entrée et conteneur SwiftData
  DesignSystem/    couleurs, typographies, composants réutilisables
  Models/          entités SwiftData et format des blocs de cours
  Persistence/     enregistrement des cours et contenu de démonstration
  SRS/             planificateur SM-2, file d'attente, statistiques
  Services/        client IA, extraction PDF, nettoyage de texte
  Features/        un dossier par écran
supabase/functions/  Edge Functions Deno
scripts/             génération de l'icône
```

## Tests

```bash
xcodebuild test -project Feymind.xcodeproj -scheme Feymind -destination 'platform=iOS Simulator,name=iPhone 16'
```
