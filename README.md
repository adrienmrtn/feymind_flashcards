# Micabo

Application iOS native de révision : tes cours (PDF, photos, Word ou notes) deviennent des cartes en répétition espacée façon Anki.

<img src="Micabo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Icône Micabo" />

## Ce que fait l'application

Trois onglets, pas plus, avec **Réviser au milieu** : c'est là que l'app ouvre, et c'est à un
balayage de n'importe où. Le bouton de session y est ancré en bas de l'écran : entre le
lancement et la première carte, il n'y a qu'un appui.

| Onglet | Rôle |
| --- | --- |
| Cours | Tout ce qui est importé, avec recherche, tri et filtre par matière. Second rayon « Découvrir » pour la bibliothèque partagée, masqué tant que `LibraryAccess.isAvailable` est faux |
| Réviser | Écran d'ouverture : les cartes à réviser aujourd'hui, la série, les cours au programme et la répartition de la file. Rien d'autre : ni date, ni liste de cours, ni bouton d'import |
| Profil | Statistiques, amis (en attente de l'authentification) et réglages |

Le parcours d'import tient en trois écrans : bouton `+` flottant en bas à droite de Cours,
choix du format (PDF, scan/photos, Word ou texte), génération des cartes, puis session.

## Lexique

Le vocabulaire est verrouillé dans `Micabo/DesignSystem/MicaboCopy.swift`, et il vaut pour
toute l'interface :

- **un seul mot par concept** — un contenu importé est un *cours*, une question-réponse est une
  *carte* (« flashcard » ne vit que dans le code et les noms d'Edge Functions), un passage de
  révision est une *session*, et l'action est *réviser* : ni « entraînement », ni « exercice »
- **tutoiement systématique**, de l'onboarding aux messages d'erreur
- **un bouton garde son nom du début à la fin d'un parcours** — celui qui ouvre une session
  s'appelle « Réviser N cartes », qu'on parte de l'onglet Réviser ou d'un cours

## Parcours d'accueil

Au premier lancement, `RootView` affiche `OnboardingFlowView` à la place de la barre d'onglets.
Le parcours est **strictement linéaire** : chaque écran pousse le suivant, il n'y a ni retour
arrière ni balayage. Les étapes sont décrites par `OnboardingStep` et rendues par
`Micabo/Features/Onboarding/Steps/`.

| Bloc | Écrans |
| --- | --- |
| Accroche | bienvenue, « conçu par des étudiants », langue, annonce des questions |
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

Trois règles valent pour tout le tunnel :

- **la jauge est unique** — même barre du premier écran au paywall, sans jamais disparaître,
  et toujours l'indigo de `MicaboColor.progress`. Elle ne s'inverse (`MicaboColor.onInk`) que
  sur les fonds sombres, où un indigo posé sur l'indigo ne se verrait plus. Tout ce qui indique
  une progression ailleurs dans l'app (session de révision, anneaux, curseurs, indicateurs
  d'attente) prend cette couleur.
- **aucun bouton ne reste muet** — l'enfoncement (échelle 0,975) part en 80 ms, et un bouton
  derrière lequel tourne une opération passe en état chargement, annonce ce qu'il fait et
  refuse les appuis suivants.
- **deux écrans voisins ne se ressemblent pas** — les compositions alternent (plein cadre,
  visuel qui déborde, liste, grand chiffre, graphe) et trois écrans quittent le crème :
  l'accroche et la courbe de l'oubli passent sur l'encre (`OnboardingSurface.ink`), la
  personnalisation sur l'indigo. En revanche le texte reste **fer à gauche** partout et le
  bouton **collé au bas de la zone sûre** : la variété s'arrête aux couleurs et aux volumes.

`OnboardingStep.surface` est la seule source de vérité sur ce point, et `OnboardingScaffold`
porte la bascule : `surface:` change le fond, la couleur des textes, celle du bouton (clair sur
fond sombre) et le fondu de la barre du bas. Les écrans hors scaffold lisent la même valeur
depuis leur étape et la reposent dans `\.onboardingSurface`.

**Le haut de l'écran suit la couleur de l'écran.** Le fond de l'étape monte jusqu'en haut de la
zone d'état : la jauge, l'heure et la batterie reposent sur l'encre quand l'écran est sombre, sur
l'indigo quand il est indigo, jamais sur une bande crème rapportée. Le thème clair est donc posé
par `RootView` sur l'app elle-même, pas au-dessus du parcours : celui-ci passe en sombre le temps
de ses écrans d'encre pour que l'heure du téléphone reste lisible.

L'écran de personnalisation est le seul indigo plein cadre. Il fait tourner trois signaux
d'activité en même temps — une barre qui avance image par image, un pourcentage qui compte, et
une accroche qui change à chaque étape — pour qu'on ne puisse jamais le croire figé.

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
ces intervalles en liste, sous un titre qui dit ce qu'elle représente : **ce sont exactement les mêmes
valeurs**, lues dans `RetentionCurve.intervalLabels`, parce que deux écrans voisins qui parlent des
mêmes révisions ne peuvent pas annoncer deux échéanciers différents. Les travaux cités (Ebbinghaus
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
- **Un seul en-tête pour toute l'app** : `MicaboScreenHeader`, sur fond crème, sur-titre en
  capitales grises puis grand titre serré (32 pt). Aucun écran n'a droit à son bandeau : un
  écran poussé ou une feuille ajoute un bouton rond au-dessus du sur-titre, et une page qui
  doit porter une couleur — le détail d'un cours — la porte dans sa **tuile**. Plus de barre
  de navigation système nulle part : les titres système ont tous été remplacés.
- Deux mises en page de liste : posée à même le fond avec un filet entre les rangées (Cours),
  ou regroupée dans un bloc blanc sous un intitulé en capitales (Réglages, Au programme)
- Pastilles d'état au bout d'une rangée : indigo pour ce qui attend, ocre pour une échéance,
  gris pour « à jour »
- L'indigo ne sert qu'à ce qui est actif : onglet courant, filtre choisi, cartes à réviser
- Le seul aplat d'encre est le bouton d'action principal, ancré en bas de l'écran
- Barre de trois onglets en pied d'écran, symbole plein sur l'onglet actif. Elle est dessinée
  par `RootTabView`, **hors du carrousel** : les pages glissent sous elle, elle ne bouge pas.
  Elle s'efface sur les écrans poussés, où le balayage est de toute façon coupé
- Un seul bouton flottant dans l'app : le « + » d'import, en bas à droite de Cours, là où le
  pouce tombe. Il n'apparaît pas quand la liste est vide, où l'écran d'accueil porte déjà son
  propre appel à importer
- Balayage horizontal natif (pages qui suivent le doigt) pour changer d'onglet ; geste de retour du système sur les écrans poussés
- Réviser : le nombre de cartes à réviser posé à même le fond ivoire, puis les cours au programme et la répartition
- Détail cours : même en-tête que les autres écrans — tuile du cours, matière et volume en
  sur-titre, titre — puis le résumé et les cartes en bloc blanc
- Chaque cours porte un emoji sur pastel, déduit de la matière quand l'analyse n'en propose pas
- En session, une ampoule donne l'indice de la carte. Les cartes qui n'en ont pas n'affichent
  pas l'ampoule : un indice tiré de la forme de la réponse (initiale, nombre de mots) n'apprend
  rien et fait perdre confiance dans les vrais indices
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

Les anciens `.doc` binaires ne sont pas lus : exporte-les en `.docx` depuis Word.

## Contenu analysé

`generate-course` renvoie une fiche de travail à plat : une notion par ligne, sans mise en forme.
Elle n'est jamais affichée, elle sert de contexte pour rédiger les cartes et pour en ajouter
plus tard. La lecture du client reste tolérante : si la fonction déployée renvoie encore l'ancien
format en blocs structurés, seuls les textes sont conservés.

## Types de cartes

Une carte recto verso muette ne sert ni l'anatomie, ni les langues, ni la physique. Cinq
formats s'ajoutent donc au format de base, sans nouvelle dépendance ni permission système.

| Format | Ce que ça sert | Comment |
| --- | --- | --- |
| Texte à trou | Définitions, formulations exactes, vocabulaire | Le recto est une phrase du cours dont le terme clé est remplacé par un blanc, le verso est ce terme. Un seul trou par carte, et une seule graphie du blanc dans toute l'app (`ClozeGap`) : les tirets bas ne peuvent pas servir, `TextSanitizer.clean` les retire avec le balisage. |
| QCM | Se tester quand on ne sait pas encore reformuler | Trois ou quatre propositions courtes, une seule bonne (`Flashcard.choices` et `correctChoiceIndex`). En session, choisir une proposition **retourne la carte** : le choix vaut la réponse. La bonne est marquée, l'erreur aussi, et la notation reste à l'utilisateur. |
| Occlusion d'image | Anatomie, géographie, géologie | `Masquer un schéma` dans le menu d'un cours : on choisit une image, on trace les zones au doigt, on les nomme. **Une carte par zone**, image et `groupID` partagés, planification indépendante. Le cache se lève au retournement et laisse un cadre sur la zone. |
| Audio | Langues | Champ facultatif sur chaque carte (`Prononciation`) : un fichier audio est recopié dans la carte, puis lu par un bouton au recto comme au verso. Aucun micro, donc aucune autorisation. |
| Sens inverse | Langues | `Ajouter les cartes inverses`, et automatiquement à l'import quand `SubjectHeuristics.isLanguage` reconnaît un cours de langue. La carte inverse est une vraie carte : même `groupID`, **planification séparée**, et le recto annonce « sens inverse ». |

Le texte à trou et le QCM se **décochent au moment de générer**, dans « Types de questions »
juste au-dessus du bouton `Générer les cartes` ; le choix est retenu d'un import à l'autre
(`QuestionMixPreferences`). Le recto verso, lui, ne se coupe pas : c'est le format qui marche
sur n'importe quel cours.

Un format annoncé qui ne tient pas debout **retombe sur le recto verso** plutôt que de casser
l'écran : texte à trou sans trou, QCM à une seule proposition ou dont aucune ne correspond à la
réponse, occlusion sans image. La question et la réponse restent bonnes, donc la carte n'est
jamais jetée. `Flashcard.format` porte cette règle, et c'est elle que l'interface consulte —
`kind` dit ce qui était voulu, `format` ce qui est affichable.

Les formules écrites en LaTeX entre `$…$` sont transposées en Unicode par `FormulaRenderer`
(exposants, indices, lettres grecques, fractions, racines) et composées en italique à
empattements par `FormulaText`. Micabo n'embarque pas de moteur LaTeX : `$E = mc^2$` devient
« E = mc² », `$H_2O$` devient « H₂O », mais les matrices et les intégrales à bornes ne sont
pas rendues. Mieux vaut une formule lisible qu'un `\frac{}{}` affiché tel quel.

## Quand l'import échoue

Trois échecs sont traités nommément, chacun avec une sortie.

- **Document illisible** — `ImportReadiness` contrôle le texte extrait *avant* de dépenser un
  appel. Sous 120 caractères, il dit ce qui a été lu (« seuls 18 caractères ont été lus »),
  pourquoi (écriture manuscrite serrée, PDF scanné, document vide) et propose d'envoyer les
  pages au modèle de vision quand l'option est encore disponible.
- **Génération interrompue à mi-parcours** — l'import se fait en trois temps. Si l'analyse
  échoue, rien n'est créé et on propose de construire les cartes sans IA. Si elle réussit
  mais que les cartes échouent, **le cours reste enregistré** et l'alerte propose de l'ouvrir
  pour relancer la génération : le travail déjà fait n'est jamais perdu. Si aucune carte n'est
  exploitable, même traitement.
- **Doublons** — `CourseFingerprint` normalise le contenu (sans accents, sans ponctuation) et
  en garde une empreinte, enregistrée sur le cours. Réimporter le même chapitre, même sous un
  autre nom de fichier, propose d'ouvrir le cours existant plutôt que de créer un doublon. Un
  titre identique suffit aussi à déclencher la question.

`MicaboTests/CardFormatsTests.swift` verrouille les formats, leurs replis et les cas d'échec.

## Répétition espacée

`Micabo/SRS/SM2Scheduler.swift` implémente SM-2 avec les réglages par défaut d'Anki :

- paliers d'apprentissage 1 min puis 10 min, réapprentissage 10 min
- sortie d'apprentissage à 1 jour, bouton « Facile » à 4 jours
- facilité de départ 2,5, plancher 1,3, bonus « Facile » 1,3, multiplicateur « Difficile » 1,2
- une rechute coûte 0,20 de facilité et renvoie la carte en réapprentissage
- dispersion aléatoire des échéances au-delà de 2,5 jours

Les quatre boutons `À revoir`, `Difficile`, `Correct`, `Facile` affichent l'intervalle réel qu'ils
appliqueront. Les tests de `MicaboTests/SM2SchedulerTests.swift` verrouillent ces valeurs.

### En session

`StudySession` pilote la file ; `StudyView` en montre quatre états, et pas seulement la pile
de cartes.

- **Annuler** — un bouton dans la barre du haut, actif dès la première note. Il ne recalcule
  pas une note inverse : `CardScheduling` photographie l'état de répétition espacée avant
  chaque note, l'annulation le remet à l'identique, supprime le journal écrit et rend la file
  telle qu'elle était. Mettre une carte de côté s'annule de la même façon.
- **Corriger ou écarter sans sortir** — sous la carte, `Modifier` ouvre l'éditeur de la carte
  affichée et `Mettre de côté` la sort de la session. Les deux restent à portée avant comme
  après la réponse : c'est souvent en lisant le verso qu'on voit qu'une carte est fausse.
- **Reprise d'une session interrompue** — l'état est écrit après chaque note
  (`StudySessionStore`, une entrée dans les réglages). Au lancement suivant, l'app propose
  « Tu en étais à la carte 12 sur 22 » avec **Reprendre** ou **Recommencer** ; passé 12 heures,
  la reprise n'est plus proposée et les cartes repartent dans la file du jour. Fermer la
  session ne perd donc rien.
- **Rien à réviser** — quand la file du jour est vide, un écran le dit, félicite sobrement et
  annonce la prochaine échéance, au lieu de basculer en douce sur des cartes non dues.
- **Répondre à un QCM retourne la carte** — le choix vaut la réponse, on ne redemande pas un
  appui pour la même chose. La bonne proposition passe au vert, celle qui a été choisie à tort
  au rouge, et la notation reste à l'utilisateur : c'est lui qui sait s'il a deviné.
- **Entraînement libre** — `StudyMode.practice` révise un cours entier sans toucher au
  planning : aucune échéance déplacée, aucun journal écrit, rien à reprendre. L'écran l'annonce
  en permanence (« Entraînement libre · ton planning n'est pas modifié ») et une carte ratée
  revient dans le tour. C'est l'action proposée quand un cours n'a rien à réviser.

`MicaboTests/StudySessionTests.swift` verrouille l'annulation, l'entraînement libre et la reprise.

### Le rythme quotidien commande la charge

`Micabo/SRS/DailyLoad.swift` fait le lien entre le temps que l'utilisateur s'accorde et ce que
l'app lui sert — sans ce lien, le curseur de l'onboarding ne serait qu'un décor.

- le curseur va de **5 min à 2 h**, par paliers de 5 minutes jusqu'à la demi-heure puis de
  15 minutes au-delà (il glisse sur les paliers, pas sur les minutes)
- il affiche le rythme correspondant (« le rythme de croisière », « le rythme intensif »…)
- il en dérive un **plafond de cartes neuves par jour** : une carte neuve revient huit fois
  avant d'être acquise, donc `minutes × 4 ÷ 8`. Quinze minutes donnent 8 cartes neuves,
  deux heures en donnent 60.
- ce plafond est appliqué pour de vrai par `StudyQueueBuilder.Limits.daily()` dans chaque
  session, il est réglable dans `Réglages › Révision`, et l'écran Réviser compte la file
  plafonnée — il annonce même les cartes neuves gardées pour les jours suivants
- `MicaboTests/DailyLoadTests.swift` verrouille les paliers, les libellés et le plafond

## Structure

```
Micabo/
  App/             point d'entrée et conteneur SwiftData
  DesignSystem/    jetons de style, lexique et composants réutilisables
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
