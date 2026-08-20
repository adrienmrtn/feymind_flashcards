# Micabo

Application iOS native de révision : vos cours (PDF, photos, Word ou notes) deviennent des flashcards en répétition espacée façon Anki.

<img src="Micabo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Icône Micabo" />

## Ce que fait l'application

| Onglet | Rôle |
| --- | --- |
| Réviser | La pile de flashcards dues aujourd'hui, tous cours confondus |
| Mes cours | Les cours importés, avec recherche et tri |
| Accueil | Tableau de bord : révisions du jour, statistiques, cours récents, bouton d'import |
| Bibliothèque | Cours partagés par la communauté (en attente de l'authentification) |
| Profil | Statistiques, amis (en attente de l'authentification) et réglages |

Le parcours principal tient en trois écrans : bouton `+` sur l'accueil, choix du format
(PDF, scan/photos, Word ou texte), génération des flashcards, puis entraînement.

## Parcours d'accueil

Au premier lancement, `RootView` affiche `OnboardingFlowView` à la place de la barre d'onglets.
Le parcours est **strictement linéaire** : chaque écran pousse le suivant, il n'y a ni retour
arrière ni balayage. Les étapes sont décrites par `OnboardingStep` et rendues par
`Micabo/Features/Onboarding/Steps/`.

| Bloc | Écrans |
| --- | --- |
| Accroche | bienvenue, langue, annonce des questions |
| Questions | objectifs (plusieurs réponses), rapport à l'oubli, matières, établissement, preuve sociale, temps quotidien |
| Démonstration | courbe de mémorisation, répétition espacée, dépôt → génération → révision en trois écrans manipulables |
| Sortie | projection annuelle, notifications, personnalisation, essai de 3 jours, paywall |

### Les trois écrans de démonstration

Ils se traversent en dix secondes, sans bouton d'avancement : c'est le geste qui fait avancer.
Le document d'exemple est embarqué (`OnboardingDemo`) : **un chapitre de SVT d'une page sur le
cycle de l'eau**, avec sa figure en trois temps, choisi pour être reconnaissable à tous les
niveaux. Aucune permission n'est demandée, aucun appel réseau n'est fait, rien n'est
enregistré : la démonstration tourne en avion.

| Écran | Geste | Ce qui se passe |
| --- | --- | --- |
| Dépôt | glisser la vignette dans la zone en pointillés | La vignette ressemble à un vrai PDF (bandeau de fichier, titre, deux phrases, figure). Après deux secondes sans geste elle respire, et un simple appui fait la même chose. Le dépôt enchaîne. |
| Génération | aucun | Trois secondes : la page se balaye, trois étapes se cochent, et la page se transforme en éventail de trois cartes. Aucune latence n'est mimée. |
| Révision | appuyer sur la carte, puis se noter | Une pile de trois cartes, une ligne au recto, une ligne au verso. La note affiche la prochaine échéance et enchaîne. Deux phrases d'explication au maximum. |

L'écran de répétition espacée, lui, se découvre au doigt : un appui par bloc, sur le contenu
**ou** sur l'invitation en bas d'écran, qui est un vrai bouton ; le second appui termine aussi
la mise en gras du texte d'Ebbinghaus si elle court encore.

Deux règles valent pour tout le tunnel :

- **la jauge est unique** — même couleur (`MicaboColor.progress`) et même barre du premier
  écran au paywall, sans jamais disparaître. Tout ce qui indique une progression ailleurs dans
  l'app (session de révision, anneaux, curseurs, indicateurs d'attente) prend cette couleur.
- **aucun bouton ne reste muet** — l'enfoncement (échelle 0,975) part en 80 ms, et un bouton
  derrière lequel tourne une opération passe en état chargement, annonce ce qu'il fait et
  refuse les appuis suivants.

Les réponses sont écrites au fil de l'eau dans `OnboardingPreferences` (clés `micabo.onboarding.*`)
et survivent donc à une fermeture en cours de route. `Réglages` propose **Refaire l'onboarding**,
qui efface ces clés et relance le parcours sans toucher aux cours.

Après le choix des matières, **Tu étudies où ?** propose un autocomplete hybride : un catalogue
embarqué (`LocalInstitutions.json`, ~600 établissements FR/EU prioritaires) pour l'instantané,
puis la RPC Supabase `search_institutions` sur la table `institutions` (~14 500 lignes : unis
mondiales, grandes écoles FR, lycées FR). Le texte libre reste accepté, mais il ne donne pas
d'`id` : seul un résultat choisi dans la liste en pose un.

L'écran communauté qui suit n'apparaît **que** si un établissement a été reconnu de cette façon
(`OnboardingModel.hasRecognizedInstitution`). Sinon `advance()` le saute, sans écran de
remplacement ni excuse. Quand il s'affiche, l'effectif annoncé va de 1 à 10 personnes et il est
dérivé de l'`id` : il ne bouge pas d'un affichage à l'autre.

L'écran courbe s'appuie sur `RetentionCurve` : une décroissance exponentielle de la rétention, remise
à 100 % à chaque révision, avec une stabilité qui augmente à chaque passage. Il doit se lire en trois
secondes, sans paragraphe : un titre qui annonce ce qu'on regarde, l'intervalle réel étiqueté au-dessus
de chaque point de révision (1 j, 3 j, 7 j, 16 j), et deux lignes de légende sous le graphe — une par
courbe, « sans révision tu oublies » et « chaque rappel rallonge ta mémoire ». L'écran suivant reprend
ces intervalles en liste, sous un titre qui dit ce qu'elle représente. Les travaux cités (Ebbinghaus
1885, Landauer & Bjork 1978) sont réels et rapportés sans arrondir leurs résultats.

Le paywall utilise `SubscriptionStoreView` de StoreKit 2. Aucun produit n'est publié :
`Micabo/Resources/Micabo.storekit`, référencé par le scheme, permet de faire tourner l'écran en
local. Quand aucun produit ne se charge, un repli affiche l'offre et laisse entrer dans l'app.

## Direction visuelle

Du papier, pas des cartes empilées. Le fond ivoire est assez marqué pour que le blanc se
détache seul : les surfaces n'ont donc ni bordure ni ombre appuyée. Tout ce qui se liste est
une **rangée** — une tuile pastel, un intitulé, un sous-titre, puis un accessoire à droite.

- Fond ivoire (`#F6F4ED`), surfaces blanches, encre `#191714`, accent indigo `#5B5BD6`
- Typographie Hanken Grotesk embarquée (Regular / Medium / SemiBold / Bold)
- Coins : 13 pt (tuiles), 16 pt (boutons, recherche), 20 pt (blocs et cartes), 28 pt (feuilles)
- Chaque écran s'ouvre sur un sur-titre en capitales grises puis un grand titre serré (32 pt)
- Deux mises en page de liste : posée à même le fond avec un filet entre les rangées (Cours),
  ou regroupée dans un bloc blanc sous un intitulé en capitales (Réglages, Au programme)
- Pastilles d'état au bout d'une rangée : indigo pour ce qui attend, ocre pour une échéance,
  gris pour « à jour »
- L'indigo ne sert qu'à ce qui est actif : onglet courant, filtre choisi, cartes dues
- Le seul aplat d'encre est le bloc « Réviser maintenant » de l'accueil
- Barre d'onglets en pied d'écran, symbole plein sur l'onglet actif ; bouton « + » rond dans
  l'en-tête des cours, et flottant en bas à droite sur l'accueil
- Balayage horizontal natif (pages qui suivent le doigt) pour changer d'onglet ; geste de retour du système sur les écrans poussés
- Réviser : le nombre de cartes dues posé à même le fond ivoire, puis les cours au programme et la répartition
- Détail cours : retour rond sur le fond, vignette et titre, résumé, puis les cartes en bloc blanc
- Chaque cours porte un emoji sur pastel, déduit de la matière quand l'analyse n'en propose pas
- En session, une ampoule donne un indice : celui de la carte, sinon un début de réponse
- Animations en cascade et retours haptiques centralisés dans `Haptics`

Les composants vivent dans `Micabo/DesignSystem/Components/` : `MicaboRows.swift` (tuile,
pastille, rangée, blocs, intitulés de section) et `MicaboHeaders.swift` (en-têtes d'écran,
barre de retour, champ de recherche).

## Pile technique

- SwiftUI, iOS 17 minimum, projet Xcode natif (`Micabo.xcodeproj`)
- SwiftData pour le stockage local (aucune donnée n'est envoyée hors des appels IA)
- PDFKit pour le texte embarqué d'un PDF, Vision (OCR) pour les scans et les photos
- Lecture locale des `.docx` (ZIP + `word/document.xml`), sans dépendance
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
| `generate-course` | Reçoit le texte déjà extrait (et, en option, jusqu'à 6 pages JPEG), renvoie titre, matière, résumé et fiche de travail |
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

## Import : extraire bien, sans faire exploser la facture

Le texte n'est **jamais** envoyé à un OCR cloud. Tout se passe sur l'iPhone.

| Source | Comment le texte est lu | Coût |
| --- | --- | --- |
| PDF avec calque texte | PDFKit | Gratuit |
| PDF scanné (images) | Vision OCR, jusqu'à 40 pages, `fr-FR` + `en-US` | Gratuit, hors ligne |
| Photos / scan multi-pages | Appareil photo (`VNDocumentCamera`) ou photothèque, puis le même OCR | Gratuit |
| Word `.docx` | ZIP local + `word/document.xml` | Gratuit |
| Texte collé | Tel quel | Gratuit |

L'option **Analyser les schémas et images** est le seul extra payant : jusqu'à 6 JPEG
partent alors au modèle de vision fal.ai. Elle est décochée dès que le texte extrait
est suffisant, et proposée si le document ressemble à un scan pauvre en texte.

Les anciens `.doc` binaires ne sont pas lus : exportez-les en `.docx` depuis Word.

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
  Services/        client IA, PDF / OCR / DOCX, nettoyage de texte
  Features/        un dossier par écran
supabase/functions/  Edge Functions Deno
scripts/             génération de l'icône
```

## Tests

```bash
xcodebuild test -project Micabo.xcodeproj -scheme Micabo -destination 'platform=iOS Simulator,name=iPhone 16'
```
