# Micabo

Application iOS native de révision : tes cours (PDF, photos, Word ou notes) deviennent une
**fiche** qu'on relit, et, si tu le veux, des cartes en répétition espacée façon Anki.

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
choix de la source (PDF, scan/photos, vidéo YouTube, Word ou texte), puis **la fiche du
cours**. Les cartes ne sont plus produites au passage : elles se demandent depuis la fiche,
et c'est le premier bouton de l'écran tant qu'il n'y en a aucune.

```
import -> lecture sur l'appareil -> cours fiché -> (facultatif) cartes -> session
```

## Lexique

Le vocabulaire est verrouillé dans `Micabo/DesignSystem/MicaboCopy.swift`, et il vaut pour
toute l'interface :

- **un seul mot par concept** — un contenu importé est un *cours*, ce que Micabo en écrit est
  sa *fiche* (ni « résumé », ni « synthèse »), une question-réponse est une *carte*
  (« flashcard » ne vit que dans le code et les noms d'Edge Functions), un passage de
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
- Un cours a deux écrans : sa **fiche**, qui est l'écran du cours, et ses **cartes**, un cran
  plus loin. Les deux portent le même en-tête que le reste de l'app — tuile du cours, matière
  et durée de lecture en sur-titre, titre — et se distinguent par leur sur-titre, pas par un
  bandeau. La fiche pose son texte à même l'ivoire et n'encadre que les objets : définitions,
  encadrés, tableaux, graphes, formules
- Le surligneur de la fiche est jaune (`MicaboColor.marker`), parce qu'un surligneur est
  jaune, et surtout parce que l'indigo est réservé à ce qui est actif : un passage surligné
  est du contenu, pas un état. Les encadrés reprennent pour la même raison les couleurs de
  retour d'information de l'app, volontairement désaturées
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
| `generate-course` | Reçoit le texte déjà extrait (et, en option, jusqu'à 6 pages JPEG), renvoie titre, matière, résumé et **la fiche** |
| `generate-flashcards` | Produit un jeu de cartes recto verso à partir de cette fiche |
| `explain-selection` | Explique un passage sélectionné dans la fiche, en s'appuyant sur le reste du cours |
| `youtube-transcript` | Métadonnées d'une vidéo puis, après confirmation, ses sous-titres. C'est la seule fonction qui n'appelle aucun modèle |

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
supabase functions deploy explain-selection
supabase functions deploy youtube-transcript
```

`youtube-transcript` n'a pas besoin de `FAL_KEY` : elle ne parle qu'à YouTube. Elle lit le
lecteur par son API interne, avec repli sur la page HTML, et c'est la partie la plus fragile
du dépôt : YouTube change de forme sans préavis. Les deux chemins existent pour cette raison,
et un échec y est toujours traduit en refus nommé plutôt qu'en écran cassé.

La version à plat de la fiche (`contextText`) est **calculée par la fonction**, pas demandée
au modèle : deux rédactions du même contenu finiraient par se contredire, et celle-ci est
déterministe. Un client plus ancien qu'un serveur redéployé continue donc de fonctionner, et
un client à jour reconstitue le contexte depuis la fiche si le serveur ne l'envoie pas.

### 3. Renseigner le projet dans l'application

L'URL et la clé publique par défaut sont dans `Micabo/Services/AppConfig.swift`. Elles restent
modifiables à l'exécution depuis `Profil`, `Réglages`, sans recompiler.

Tant que `FAL_KEY` n'est pas configurée, l'import reste utilisable : Micabo propose de
construire la fiche hors ligne, à partir du texte brut.

## Import : extraire bien, sans faire exploser la facture

Le texte n'est **jamais** envoyé à un OCR cloud. Tout se passe sur l'iPhone.

| Source | Comment le texte est lu | Coût |
| --- | --- | --- |
| PDF avec calque texte | PDFKit | Gratuit |
| PDF scanné (images) | Vision OCR, jusqu'à 40 pages, `fr-FR` + `en-US` | Gratuit, hors ligne |
| Photos / scan multi-pages | Appareil photo (`VNDocumentCamera`) ou photothèque, puis le même OCR | Gratuit |
| Word `.docx` | ZIP local + `word/document.xml` | Gratuit |
| Texte collé | Tel quel | Gratuit |
| Vidéo YouTube | Sous-titres de la vidéo, récupérés par l'Edge Function `youtube-transcript` | Gratuit, mais **pas sur l'appareil** |

La vidéo est la seule exception à la règle ci-dessus, et l'écran d'import le dit : le lien
part à l'Edge Function, qui va chercher les sous-titres. Rien d'autre ne quitte le
téléphone, et l'audio n'est jamais envoyé nulle part.

L'option **Analyser les schémas et images** est le seul extra payant : jusqu'à 6 JPEG
partent alors au modèle de vision fal.ai. Elle est décochée dès que le texte extrait
est suffisant, et proposée si le document ressemble à un scan pauvre en texte.

Les anciens `.doc` binaires ne sont pas lus : exporte-les en `.docx` depuis Word.

## Importer une vidéo YouTube

On colle un lien, on voit la vidéo, on confirme, et on obtient une fiche. Le parcours est
celui des autres sources, avec une étape en plus au début.

```
lien collé -> aperçu -> confirmation -> transcription -> fiche -> (facultatif) cartes
```

**Micabo lit les sous-titres, jamais l'audio.** Une vidéo qui n'en a pas est refusée, et ce
n'est pas une limite technique : transcrire une heure d'audio coûte cher, prend des minutes,
et rend un texte moins fiable que des sous-titres écrits à la main. Mieux vaut le dire tout
de suite que faire attendre pour un mauvais résultat.

### L'aperçu, et pourquoi il existe

Coller une URL est le seul import où l'on ne voit pas ce qu'on importe : un identifiant de
onze caractères ne dit rien, et se tromper d'onglet est banal. L'aperçu montre donc la
vignette, le titre, la chaîne, la durée et la piste de sous-titres retenue, **avant** de
dépenser quoi que ce soit. Il sert aussi à refuser : une vidéo trop longue ou sans
sous-titres s'affiche quand même, avec la raison écrite dessous, plutôt que de renvoyer une
alerte sur un écran vide.

L'aperçu ne télécharge aucune transcription. C'est ce découpage qui permet d'écarter une
vidéo de trois heures sans avoir lancé un seul appel de génération.

### Quelle piste de sous-titres

La langue de l'utilisateur d'abord, la piste par défaut de la vidéo ensuite. À langue égale,
les sous-titres **écrits à la main** passent devant ceux générés automatiquement : ils sont
ponctués, et un texte ponctué donne de meilleures cartes. Les langues envoyées viennent de
`Locale.preferredLanguages`, réduites à leur code de langue, et `fr` vaut pour `fr-CA`.
Quand la piste retenue est automatique, l'aperçu l'annonce : un texte transcrit à la machine
n'est pas ponctué, et l'utilisateur doit savoir d'où vient un texte irrégulier.

### Les refus, et leurs phrases

| Cas | Message |
| --- | --- |
| Lien qui n'est pas une vidéo YouTube | « Ce lien n'est pas une vidéo YouTube. » |
| Vidéo privée, supprimée ou à accès restreint | « Cette vidéo n'est pas accessible. » |
| Aucun sous-titre | « Cette vidéo n'a pas de sous-titres. Micabo ne peut pas la lire. » |
| Transcription trop courte | « Cette vidéo est trop courte pour générer des cartes. » |
| Vidéo trop longue | « Cette vidéo dure 2 h 14. Micabo lit les vidéos jusqu'à 1 h 30. » |

Deux règles tiennent ces messages. Le **code** renvoyé par l'Edge Function décide, jamais la
forme de son message : le serveur peut reformuler ses journaux sans qu'un mot change dans
l'application. Et les phrases vivent en un seul endroit, `YouTubeImportError`, y compris
celle du garde de `ImportReadiness`, qui ne réécrit pas la sienne.

La limite est **toujours annoncée** quand une vidéo est trop longue : un refus qui ne dit pas
jusqu'où on peut aller laisse essayer au hasard. Le plafond est de 1 h 30, appliqué par
l'application depuis la durée de l'aperçu et revérifié par la fonction avant de télécharger
le texte.

Le lien lui-même est validé **sur l'appareil**, avant tout appel : une adresse Vimeo ou un
morceau de texte se refusent sans réseau, et le message s'affiche sous le champ plutôt que
dans une alerte, là où l'erreur a été faite. Un identifiant collé seul n'est pas accepté :
onze caractères alphanumériques peuvent être n'importe quoi.

### Quand le réseau lâche en cours de route

L'import se fait en trois temps, et chacun garde ce qu'il a obtenu : l'aperçu, puis la
transcription, puis l'analyse. « Réessayer » **reprend** au lieu de recommencer, donc une
transcription réussie ne repart pas sur le réseau parce que l'analyse a échoué.

Rien n'est écrit en base avant que l'analyse ait réussi : le cours est enregistré d'un seul
coup, avec sa fiche. Il n'existe aucun état intermédiaire où un cours serait à moitié là.
« Réessayer » n'apparaît d'ailleurs que quand réessayer peut marcher : une vidéo sans
sous-titres n'en aura pas plus au second essai.

### Ce qui arrive dans le pipeline

Une fois transcrite, **une vidéo n'est plus une vidéo** : c'est un `ImportedDocument` dont le
texte a été obtenu autrement. Elle repart donc dans le chemin d'un PDF, sans branche à elle,
et c'est pour cette raison que la fiche puis les cartes marchent sans une ligne de plus. La
vignette de la vidéo devient la couverture du cours, et la piste retenue est notée sous le
titre du document importé.

## Le cours fiché

Un import produit une **fiche** : la page qu'on relit la veille du contrôle. C'est le
résultat de l'import, et l'écran d'un cours. Les cartes viennent après, si on les demande.

### Ce qu'est une fiche

Huit blocs, décrits par `Micabo/Models/CourseSheet.swift`, et pas un de plus. Chacun a un
rendu dessiné pour lui : c'est la seule façon de tenir une belle page, parce qu'un format
ouvert où le modèle inventerait ses propres structures donnerait une mise en page
différente à chaque cours.

| Bloc | Ce qu'il porte | Comment il est rendu |
| --- | --- | --- |
| `heading` | Titre de partie (niveau 1) ou de sous-partie | Filet court dans la teinte du cours, puis grand titre resserré |
| `paragraph` | Deux à quatre phrases rédigées | Corps 16,5 pt, interligne 7,5, posé à même l'ivoire |
| `definition` | Un terme et son sens | Bloc blanc, filet vertical dans la teinte du cours, terme en demi-gras |
| `callout` | `essentiel`, `attention`, `exemple` ou `astuce` | Fond assorti à l'intention, intitulé en capitales |
| `steps` | Un mécanisme dont l'ordre compte | Pastilles numérotées dans un bloc blanc |
| `table` | Une comparaison, 2 à 4 colonnes | Colonnes de largeur égale, en-tête teinté, filets entre les lignes |
| `chart` | Des valeurs comparables, même unité | Barres horizontales, valeur écrite en clair, ni axe ni grille |
| `formula` | Une formule qui se retient | Centrée sur fond ivoire, avec la légende de ses symboles |

La règle de composition tient en une phrase : **le texte est posé sur le papier, les objets
sont dans des surfaces.** Un paragraphe n'est pas une carte, et une fiche entièrement
encartée ne se lirait pas.

### Le balisage en ligne

Quatre marques, et chacune a une raison d'exister sur une fiche de révision
(`Micabo/Services/SheetMarkup.swift`) :

| Écriture | Rendu | À quoi ça sert |
| --- | --- | --- |
| `**terme**` | gras | le mot que l'examen attend, une à trois fois par paragraphe |
| `*nuance*` | italique | un mot étranger, un titre d'œuvre, une réserve |
| `==l'essentiel==` | surligné | ce qu'on relit en dernier, **cinq passages au maximum sur toute la fiche** |
| `$E = mc^2$` | formule | transposée par `FormulaRenderer`, comme sur les cartes |

Hanken Grotesk n'embarque pas d'italique : elle est penchée à la main par une matrice de
fonte, ce qui reste préférable à un changement de famille en plein paragraphe. Le
surlignage, lui, n'est pas le fond rectangulaire par défaut d'un fragment attribué, qui
donnerait une bande grasse sur toute la hauteur de ligne : `MarkerLayoutManager` le dessine
en rectangle arrondi, resserré en hauteur et débordant sur les côtés, comme la trace d'un
marqueur passé à la main.

Un délimiteur sans fermeture reste un caractère ordinaire. Sans cette règle, un cours de
statistiques où l'astérisque signale un résultat significatif partirait en italique jusqu'au
bout du paragraphe.

**Le balisage ne quitte jamais la fiche.** `SheetMarkup.plain(_:)` en donne la version nue,
et c'est elle qui part au modèle pour écrire des cartes : `TextSanitizer.clean`, qui vaut
pour les cartes, continue de tout retirer, puisque rien ne le rend là-bas.

### Sélectionner un passage et demander une explication

C'est le geste central de l'écran, et il n'a donc pas de bouton : **on sélectionne du texte,
et « Expliquer » apparaît dans le menu du système**, devant « Copier », là où l'utilisateur
cherche déjà.

Les paragraphes sont pour cela composés dans un `UITextView` (`SheetProse`) et non dans un
`Text` SwiftUI : `.textSelection(.enabled)` autorise le copier mais ne dit jamais ce qui a
été sélectionné. Le passage part alors à `explain-selection` **avec la fiche à plat en
contexte**, parce que « la Rubisco » n'a de sens que dans son cours, et la réponse s'ouvre
dans une feuille qui cite le passage surligné avant même d'avoir répondu. Elle se termine sur
« En faire une carte » : ce qu'on vient de comprendre est exactement ce qu'on oubliera.

Un mot, une phrase, jusqu'à 600 caractères. En dessous de deux caractères, ou sans une seule
lettre, l'entrée n'apparaît pas : `SheetSelection` évite de dépenser un appel pour une
sélection attrapée par erreur.

### Ce qui empêche une fiche d'avoir l'air écrite par une IA

Le prompt de `supabase/functions/generate-course/prompt.ts` interdit nommément les tirets
cadratins, les listes à puces en série, les phrases de remplissage (« il est important de
noter que », « en effet », « en conclusion ») et les méta-commentaires sur le document.

Mais une consigne se respecte à peu près, alors que **les plafonds se respectent toujours** :
`supabase/functions/_shared/sheet.ts` limite les blocs d'étapes à deux par fiche, les
passages surlignés à cinq, les colonnes d'un tableau à quatre, et retire les puces et les
dièses de markdown qui ont fui hors de leur structure. `CourseSheet.sanitized()` refait le
même travail côté application, sur les fiches comme sur ce qu'un serveur plus ancien renvoie.

Un bloc d'un type inconnu, un tableau à une seule colonne, un graphe à une seule barre ou
tout à zéro disparaissent au lieu de casser la page. Un bloc mal formé ne fait pas échouer la
fiche entière : c'est la différence entre une fiche à laquelle il manque un encadré et un
écran vide.

### Sans clé, sans réseau

`OfflineSheetBuilder` construit une fiche à partir du seul texte extrait. Elle ne met **rien**
en valeur : deviner ce qui compte dans un cours qu'on n'a pas lu produirait une fiche qui a
l'air travaillée et qui souligne n'importe quoi, ce qui est pire qu'une fiche sobre. Ce qu'on
peut reconnaître sans comprendre, en revanche, est structuré : les titres, et les définitions
écrites « terme : sens ».

### Stockage

La fiche est enregistrée en JSON sur le cours (`Course.sheetData`), parce qu'elle se lit et
s'écrit toujours d'un bloc, jamais par morceaux. `Course.contextText` garde en parallèle la
version à plat, une notion par ligne, qui sert de contexte au modèle. Un cours importé avant
la fiche n'en a pas : son écran propose alors de l'écrire à partir du texte d'origine, et
« Refaire la fiche » fait la même chose sur un cours qui en a déjà une. Ni l'un ni l'autre ne
renomme le cours : un titre corrigé à la main ne doit pas être écrasé par celui que le modèle
trouve au second passage.

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

Les cartes ne sont plus une conséquence de l'import : ce sont une demande, et une demande se
règle. `GenerateCardsSheet` s'ouvre sur le volume (8, 12 ou 20) et sur les formats, juste
au-dessus du bouton `Générer les cartes` qui les utilise, et le choix est retenu d'un cours à
l'autre (`QuestionMixPreferences`). Le recto verso, lui, ne se coupe pas : c'est le format qui
marche sur n'importe quel cours.

`CardGeneration` est le seul chemin d'écriture des cartes, qu'on parte de la fiche ou de
l'écran des cartes : c'est là que vivent le repli hors ligne et la création automatique des
cartes inverses pour les cours de langue. Deux écrans qui écriraient chacun leur version
finiraient par ne plus produire les mêmes cartes.

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
- **Analyse interrompue** — l'import se fait en deux temps : la fiche, puis l'enregistrement.
  Si l'analyse échoue, rien n'est créé et on propose de construire la fiche sans IA. Comme
  les cartes ne sont plus écrites pendant l'import, il n'y a plus d'état intermédiaire où un
  cours existerait à moitié.
- **Vidéo illisible** — les cinq refus de l'import YouTube sont décrits plus haut, avec leurs
  phrases. Trois d'entre eux tombent avant le moindre appel de génération : le lien invalide
  sans réseau du tout, l'absence de sous-titres et la durée hors limite dès l'aperçu.
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
  Models/          entités SwiftData, fiche d'un cours et réponses de l'IA
  Persistence/     enregistrement des cours et contenu de démonstration
  SRS/             planificateur SM-2, file d'attente, statistiques
  Services/        client IA, balisage de la fiche, PDF / OCR / DOCX, nettoyage de texte
  Features/        un dossier par écran, dont Course/ pour le cours fiché
supabase/functions/  Edge Functions Deno
scripts/             génération de l'icône
```

## Tests

`MicaboTests/CourseSheetTests.swift` verrouille la fiche : le balisage en ligne et ses cas
limites, le décodage tolérant, le nettoyage, l'aplatissement vers le contexte des cartes, la
fiche hors ligne et ce qui vaut une sélection.

`MicaboTests/YouTubeImportTests.swift` verrouille l'import vidéo : les formes de lien
acceptées et refusées, **les cinq phrases de refus au mot près**, la traduction des codes du
serveur, le choix de la piste de sous-titres et ce que l'aperçu décide sans rien télécharger.

```bash
xcodebuild test -project Micabo.xcodeproj -scheme Micabo -destination 'platform=iOS Simulator,name=iPhone 16'
```
