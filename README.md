# Feymind

Application iOS native de révision : vos cours PDF ou vos notes deviennent des flashcards en répétition espacée façon Anki.

<img src="Feymind/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Icône Feymind" />

## Ce que fait l'application

| Onglet | Rôle |
| --- | --- |
| Réviser | La pile de flashcards dues aujourd'hui, tous cours confondus |
| Mes cours | Les cours importés, avec recherche et tri |
| Accueil | Tableau de bord : révisions du jour, statistiques, cours récents, bouton d'import |
| Bibliothèque | Cours partagés par la communauté (en attente de l'authentification) |
| Profil | Statistiques, amis (en attente de l'authentification) et réglages |

Le parcours principal : bouton `+` sur l'accueil, choix PDF ou texte, import, génération des flashcards,
visualisation et édition, puis entraînement.

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

L'application appelle des Edge Functions Supabase. Le code source est dans `supabase/functions/`.

| Fonction | Rôle |
| --- | --- |
| `generate-course` | Analyse le texte et les pages du PDF pour en tirer un titre, un résumé et un contexte |
| `generate-flashcards` | Produit un jeu de cartes recto verso à partir du contenu importé |
| `explain-passage` | Explique un passage sélectionné, dans le contexte du cours |

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
```

### 3. Renseigner le projet dans l'application

L'URL et la clé publique par défaut sont dans `Feymind/Services/AppConfig.swift`. Elles restent
modifiables à l'exécution depuis `Profil`, `Réglages`, sans recompiler.

Tant que `FAL_KEY` n'est pas configurée, l'import reste utilisable : Feymind propose de construire
les cartes hors ligne, à partir du texte brut.

## Répétition espacée

`Feymind/SRS/SM2Scheduler.swift` implémente SM-2 avec les réglages par défaut d'Anki :

- paliers d'apprentissage 1 min puis 10 min, réapprentissage 10 min
- sortie d'apprentissage à 1 jour, bouton « Facile » à 4 jours
- facilité de départ 2,5, plancher 1,3, bonus « Facile » 1,3, multiplicateur « Difficile » 1,2
- une rechute coûte 0,20 de facilité et renvoie la carte en réapprentissage
- dispersion aléatoire des échéances au-delà de 2,5 jours

Les quatre boutons `À revoir`, `Difficile`, `Correct`, `Facile` affichent l'intervalle réel qu'ils
appliqueront. Les tests de `FeymindTests/SM2SchedulerTests.swift` verrouillent ces valeurs.

## Flashcards

Après l'import, l'application ouvre directement la liste des flashcards. Vous pouvez les modifier,
en ajouter, en supprimer, puis lancer l'entraînement.

Les textes acceptent un balisage court côté contenu source : `**gras**`, `*italique*`, `==surligné==`, `` `code` ``.
Les tirets cadratins sont interdits côté prompt et retirés côté client comme côté serveur.

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
