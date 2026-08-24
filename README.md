# Micabo

Application iOS native de révision : tes cours (PDF, photos, Word ou notes) deviennent une
**fiche** qu'on relit, et, si tu le veux, des cartes en répétition espacée façon Anki.

<img src="Micabo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Icône Micabo" />

## Ce que fait l'application

Trois onglets, pas plus, avec **Réviser au milieu** : c'est là que l'app ouvre, et c'est
l'onglet qui doit être sous le pouce. Le bouton de session y est ancré en bas de l'écran :
entre le lancement et la première carte, il n'y a qu'un appui.

| Onglet | Rôle |
| --- | --- |
| Cours | Tout ce qui est importé, avec recherche, tri et filtre par matière. Second rayon « Découvrir » pour la bibliothèque partagée, masqué tant que `LibraryAccess.isAvailable` est faux |
| Réviser | Écran d'ouverture : les cartes à réviser aujourd'hui dans une carte unique — le chiffre, la durée, la barre de composition et sa légende — puis les cours au programme et le prochain examen. Rien d'autre : ni salutation, ni date, ni liste de cours, ni bouton d'import |
| Profil | Statistiques, amis (en attente de l'authentification) et réglages |

**On ne balaye pas d'un onglet à l'autre.** Le carrousel qui vivait là était un `TabView` en
style page : un défilement horizontal qui traîne sur un tiers de geste rend chaque écran mou,
il entre en conflit avec tout ce qui se balaye à l'intérieur d'une page, et il fallait un
bricolage parcourant la hiérarchie UIKit à chaque passe de mise en page pour le couper dès
qu'un écran de détail était poussé. Les pages restent montées en même temps, simplement
masquées, pour garder leur défilement et leur pile ; le changement d'onglet est un fondu
court. Le geste de retour du système, lui, reste : ce n'est pas le même geste, et le retirer
n'aurait fluidifié que le travail du pouce.

**L'app part vide.** Deux cours de démonstration étaient insérés au premier lancement ; ils
ne montraient pas ce que fait Micabo, ils montraient ce que quelqu'un d'autre avait importé,
et le premier geste devenait de les supprimer. Les écrans d'accueil vides existaient déjà et
ne se voyaient jamais. `SampleContentPurge` efface une fois les cours marqués `sample` restés
sur les téléphones où l'app a déjà tourné ; un cours importé par l'utilisateur n'est jamais
touché. Les deux fiches écrites à la main vivent maintenant dans la cible de test, où elles
servent de référence de mise en page.

**Il n'y aura pas de quatrième onglet.** Trois onglets avec Réviser au milieu est une règle
de composition, pas un état des lieux : à quatre, il n'y a plus de milieu. Les écrans qui
arrivent se poussent donc depuis l'onglet dont ils relèvent, comme la page Examens depuis
Réviser.

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
| Accroche | bienvenue, niveau d'études, langue, annonce des questions |
| Questions | objectifs (plusieurs réponses), rapport à l'oubli |
| Démonstration | courbe de mémorisation, puis dépôt → fiche → révisions en trois écrans, puis le mode examen |
| Personnalisation | matières, établissement (avec « Passer »), temps quotidien |
| Sortie | projection annuelle, notifications, personnalisation, essai de 3 jours, paywall |

Un seul écran offre une échappatoire, et elle est posée en haut à droite sur la ligne du
sur-titre (`OnboardingSkip`) : demander son établissement à quelqu'un qui n'en a pas, qui est
entre deux écoles, ou qui n'a pas envie de le dire ne doit pas fermer le parcours. Passer
laisse le champ vide **et l'écrit**, plutôt que de garder la moitié d'un nom tapé puis
abandonné.

### Un écran, une chose

C'est la règle qui gouverne tout le tunnel, et c'est celle qui a été la plus mal tenue :
**un titre court, une ligne de sous-titre au plus, et une seule chose à regarder.** Un écran
d'inscription se lit en deux secondes ou ne se lit pas.

Ce qui a été retiré, et pourquoi, vaut d'être écrit noir sur blanc :

- **les paragraphes dans des blocs blancs à coins arrondis.** Trois rangées à picto sous un
  intitulé, c'est exactement à quoi ressemble un texte que personne n'a relu. Les trois
  promesses qui vivaient là sont désormais *montrées* par les trois écrans de démonstration.
- **l'écran « on a fait Micabo pour nous ».** Il racontait d'où venait l'app à quelqu'un qui
  ne l'a pas encore vue fonctionner : c'est demander de la confiance avant d'avoir rien
  montré. La démonstration est le seul argument du parcours.
- **l'annonce des questions à venir.** L'écran listait les trois questions suivantes avec un
  sous-titre et trois rangées à picto ; les annoncer prenait plus longtemps que d'y répondre.
  Il ne reste que la phrase, dont **le gras se pose mot par mot**
  (`OnboardingWordByWordTitle`), et le bouton n'arrive qu'une fois le dernier mot en place.
- **les icônes de décoration.** Une pastille colorée par ligne de réponse fait lire des
  pictogrammes au lieu des réponses. `OnboardingChoiceRow` n'a plus que son libellé et sa coche.
- **la liste, quand la question n'a que deux réponses.** Empilées, les deux rangées se lisent
  l'une après l'autre et laissent croire que la première compte plus. La question de l'oubli
  pose donc ses deux réponses côte à côte (`OnboardingChoiceTile`), à taille égale.
- **les choix qu'on ne peut pas faire.** L'écran de langue affichait cinq rangées à drapeau
  dont quatre grisées ; il en affiche une, et une ligne annonce la suite.
- **le flou d'apparition.** Il coûtait une passe de rendu par image, rendait le texte illisible
  pendant sa propre arrivée, et il est devenu la signature des interfaces faites à la chaîne.
  Huit points de montée et un fondu suffisent.

### Le mouvement, en un seul endroit

`OnboardingMotion` porte les quatre courbes du parcours, et une seule règle les explique :
**rien ne rebondit.** Un ressort dépasse sa cible puis revient, et vingt écrans qui dépassent
leur cible donnent un parcours qui tremble. Les courbes sont donc monotones : elles partent
vite, ralentissent, s'arrêtent net.

Le passage d'un écran à l'autre est un glissement de **vingt-huit points** avec un fondu, et
non un glissement pleine largeur : faire traverser tout l'écran à une page donne l'impression
de feuilleter un carrousel, et attire l'œil sur le mouvement plutôt que sur le contenu.

Trois oscillations seulement échappent à la règle, et chacune est déclarée là où elle vit :

- **la cloche de l'écran de rappel**, parce qu'une cloche qui sonne oscille ;
- **le bouton `isShiny`**, qui se laisse balayer d'un reflet et respire sur place, uniquement
  sur l'écran où l'on vient de regarder une animation sans rien toucher. La main y est
  immobile depuis dix secondes, il faut aller la chercher — et un bouton qui brille à chaque
  écran ne brille plus nulle part ;
- **le calendrier du mode examen**, où l'on regarde un planificateur travailler. Le cercle du
  jour J s'y trace au stylo, une onde rouge repart en boucle sous la date, le compte à rebours
  égrène ses chiffres de J-28 à J-19, et les six points de révision *tombent* sur leur case.
  La règle protège les transitions d'écran et les entrées de contenu, où un dépassement se lit
  comme un tremblement ; un point qui se pose a le droit de tomber, et c'est le seul moyen de
  faire lire six événements en une seconde et demie.

### Les trois écrans de démonstration

Ils se traversent en une dizaine de secondes et montrent **le même document à trois états** :
brut quand on le dépose, fiché après lecture, découpé en révisions ensuite. C'est ce fil qui
fait comprendre l'app, là où trois illustrations sans rapport ne montreraient que trois
animations. Le document est embarqué (`OnboardingDemo`) : un chapitre de SVT sur le cycle de
l'eau, reconnaissable à tous les niveaux. Aucune permission, aucun appel réseau, rien
d'enregistré : la démonstration tourne en avion.

| Écran | Geste | Ce qui se passe |
| --- | --- | --- |
| Dépôt | glisser la page dans la zone en pointillés | La page est **volontairement brute** : un mur de texte sans hiérarchie, titre noyé au milieu, tel qu'on reçoit un polycopié. Sans un vrai avant, l'écran suivant ne transforme rien. Elle passe **au-dessus** de la zone de dépôt, jamais dessous : un document qu'on fait glisser sous sa cible se lit comme un document qu'on perd. Après deux secondes sans geste elle respire, et un simple appui fait la même chose. |
| Fiche | aucun | Le balayage de lecture passe sur la page brute, puis la fiche **s'écrit par-dessus, bloc par bloc** : le filet de titre, le paragraphe, la définition, le passage surligné, le schéma. Les deux états occupent la même place, ce qui fait lire une transformation et non deux illustrations. Le bouton dit « S'entraîner », et c'est le seul du parcours qui brille et respire. |
| Révisions | aucun | La fiche se **découpe en quatre vignettes** — schéma, recto verso, QCM, texte à trou — qui sortent une à une, puis se remplissent toutes seules. Le bouton s'ouvre dès que les quatre sont là. |

Deux écrans ont été retirés d'ici, pour la même raison. La génération simulée cochait des
étapes pendant trois secondes : elle faisait patienter devant un travail qu'on ne voyait pas.
Et le troisième écran demandait d'appuyer sur une carte puis de se noter : c'était faire passer
un examen à quelqu'un qui n'a pas encore ouvert l'app, sur un cours qui n'est pas le sien.
**Ce qu'il y a à montrer, c'est ce que Micabo produit à partir d'un cours** — le produire est
le travail de l'app, y répondre viendra plus tard, avec ses propres cours. Le troisième écran
est donc une animation, et rien d'autre.

Le schéma compte autant que les cartes, et il a longtemps été le maillon faible : le filet de
la définition de la fiche était un `Capsule` en `maxHeight: .infinity`, ce qui rendait tout le
bloc gourmand en hauteur. La fiche s'étirait ou se comprimait selon la place que lui laissait
l'écran, et c'était toujours la figure qui payait — elle n'a pas de taille propre à défendre,
elle se tassait jusqu'à disparaître. Un trou blanc à la place d'un schéma ne prouve rien. Le
filet est maintenant posé en surimpression du texte, la fiche fait exactement sa hauteur
(`fixedSize`), et la figure est grossie et cernée d'un filet pour se lire comme un schéma.

### Ce que le mode examen promet

Après la démonstration, un écran montre un calendrier où le jour J se cerne de rouge au stylo,
prend son nom (« EXAMEN · Maths DS sur table »), égrène son compte à rebours de J-28 à J-19,
puis voit les jours qui le précèdent s'allumer un à un de points de révision, en se resserrant
à l'approche de l'épreuve. Une ligne conclut sur ce qui vient de se passer : « 6 révisions
placées avant le jour J ». C'est exactement ce que fait `ExamPlanner`, et le voir vaut mieux
que le lire.

Trois règles valent pour tout le tunnel :

- **la jauge est unique** — même barre du premier écran au paywall, sans jamais disparaître,
  et toujours l'indigo de `MicaboColor.progress`. Elle ne s'inverse (`MicaboColor.onInk`) que
  sur les fonds sombres, où un indigo posé sur l'indigo ne se verrait plus. Tout ce qui indique
  une progression ailleurs dans l'app (session de révision, anneaux, curseurs, indicateurs
  d'attente) prend cette couleur.
- **aucun bouton ne reste muet** — l'enfoncement (échelle 0,975) part en 80 ms, et un bouton
  derrière lequel tourne une opération passe en état chargement, annonce ce qu'il fait et
  refuse les appuis suivants.
- **deux écrans voisins ne se ressemblent pas** — les compositions alternent (paquet de cartes,
  pastilles, liste, graphe, calendrier, grand chiffre), et **deux écrans seulement** quittent
  le crème : l'accroche sur l'encre, la personnalisation sur l'indigo. C'est un de moins
  qu'avant, parce que la variété d'un parcours ne vient pas de ses fonds mais de ce qu'il y a
  à regarder. Le texte reste **fer à gauche** partout et le bouton **collé au bas de la zone
  sûre**.

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

La toute première question est **Tu en es où ?** : lycée, prépa, licence, PASS-santé, master,
concours ou autre. Elle vient juste après l'accroche parce qu'elle situe tout le reste, un
lycéen et un PASS n'ayant ni les mêmes matières, ni les mêmes examens, ni le même rythme. Sept
réponses en pastilles et non en rangées : sept rangées feraient un écran qu'on fait défiler
pour répondre à une question fermée.

Après le choix des matières, **Tu étudies où ?** propose un autocomplete hybride : un catalogue
embarqué (`LocalInstitutions.json`, ~600 établissements FR/EU prioritaires) pour l'instantané,
puis la RPC Supabase `search_institutions` sur la table `institutions` (~14 500 lignes : unis
mondiales, grandes écoles FR, lycées FR). Le texte libre reste accepté, mais il ne donne pas
d'`id` : seul un résultat choisi dans la liste en pose un.

Le parcours est désormais une **file droite** : aucun écran ne se saute. L'écran de preuve
sociale, qui était le seul conditionnel, a été retiré, et le mécanisme d'écran sauté avec lui.

L'écran courbe s'appuie sur `RetentionCurve` : une décroissance exponentielle de la rétention, remise
à 100 % à chaque révision, avec une stabilité qui augmente à chaque passage. Il doit se lire en trois
secondes, sans paragraphe : un titre qui annonce ce qu'on regarde, l'intervalle réel étiqueté au-dessus
de chaque point de révision (1 j, 3 j, 7 j, 16 j), et deux lignes de légende sous le graphe, une par
courbe. C'est le seul écran de pédagogie qui reste : celui qui reprenait ensuite les mêmes intervalles
en liste, sous le titre « la courbe de l'oubli prise à contre-pied », disait une deuxième fois ce que
le graphe montrait déjà.

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
  par `RootTabView`, **hors des pages** : elles se remplacent sous elle, elle ne bouge pas
  d'un pixel. Depuis que le balayage entre onglets a disparu, c'est le seul moyen de changer
  de page. Elle s'efface sur les écrans poussés, où changer d'onglet depuis le fond d'une pile
  ne voudrait rien dire
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

## Examens et mode examen

La répétition espacée optimise la mémoire à long terme. Elle repousse les cartes de plus en
plus loin, et **elle se fiche de la date du contrôle** : une carte revue hier avec un
intervalle de vingt jours retombera trois semaines après l'examen, au pire moment possible.
Le mode examen corrige exactement ça.

La page se pousse depuis l'onglet Réviser, où une rangée annonce le prochain examen et son
compte à rebours.

### Le calendrier

Un mois à la fois, la semaine commençant le lundi partout et quel que soit le réglage
régional du téléphone (`MicaboCalendar`). Une pastille ocre par examen sur son jour, trois au
maximum par case : au delà, la case ne se lit plus et le compte se lit dans la liste. Ocre
parce que c'est la couleur des échéances dans toute l'app, et un examen est une échéance.

Un appui sur un jour ouvre sa section en dessous ; un second appui la referme. Un appui sur
un débord du mois voisin fait suivre le calendrier.

Un examen se **prend dans la liste et se pose sur un jour** pour être déplacé. La liste est
la source, le calendrier la cible, et pas l'inverse : glisser depuis une pastille de trois
points de large serait injouable au doigt, et un examen déplacé par erreur emporte tout un
planning. La date reste modifiable dans la feuille d'édition, qui est le chemin fiable.

Ouvrir, modifier, supprimer se font depuis la rangée et son menu contextuel.

### Déclarer un examen

Quatre champs, dans cet ordre : **nom**, **date**, **cours au programme**, **intensité**.
L'intensité ne change pas quoi réviser mais combien de fois chaque carte repasse avant le
jour J, de deux à quatre passages. C'est le seul réglage : demander un nombre de cartes par
jour serait demander à l'étudiant de faire le calcul que l'app est là pour faire.

### La projection, avant de confirmer

Un mode qui réorganise tout un planning ne se lance pas sur un bouton « Activer ». La
projection apparaît dès que la date et un cours sont là, et elle bouge quand on change
d'intensité : c'est comme ça qu'on comprend ce que l'intensité veut dire.

| Ce qu'elle annonce | Pourquoi |
| --- | --- |
| Cartes concernées | Le volume en jeu, celui qui fait la charge |
| Jours restants | Le temps dont on dispose vraiment |
| Charge quotidienne moyenne | Ce que ça coûte par jour |
| Jour le plus chargé | Le chiffre le plus utile : c'est lui qui fait reculer d'une intensité |

Un histogramme complète les quatre chiffres, parce qu'il dit ce qu'ils ne disent pas : si la
charge est plate, ou si elle s'écrase sur les derniers jours.

### Comment la replanification marche

`Micabo/SRS/ExamPlanner.swift` est pur : il prend des valeurs, il rend des jours, et il se
teste sans base de données. Trois règles composent l'échelle de passages de chaque carte.

- **Le dernier passage tombe dans les trois derniers jours**, décalé d'une carte à l'autre.
  Tout mettre sur la veille garantirait le pic de rétention, et une session de trois cents
  cartes que personne ne fait.
- **Le premier passage est échelonné** lui aussi, pour que le premier jour ne prenne pas tout.
- **Entre les deux, les passages sont régulièrement espacés**, ce qui donne une charge
  quotidienne à peu près constante, la seule qu'on puisse tenir.

Le nombre de passages part de l'intensité, plus un pour une carte jamais vue, moins un pour
une carte acquise depuis plus de trois semaines. Jamais moins d'un : une carte du programme
se révise au moins une fois. On ne voit pas une carte deux fois le même jour, donc le nombre
de passages est borné par le nombre de jours disponibles.

L'ordre des cartes décide de leur décalage, donc du lissage : les cartes en retard passent
devant, puis les neuves, puis les moins solides. Si le temps manque, c'est ce qui doit être vu
d'abord.

### Ce qui fait tenir le plan

Replanifier les échéances au moment de déclarer l'examen **ne suffit pas** : à la première
note donnée, SM-2 renverrait la carte à trois semaines et le plan serait défait. Deux
mécanismes de plus s'en chargent.

- **Le plafond d'intervalle** (`ExamDeadlines`) : tant que l'examen approche, aucune carte
  concernée ne se replanifie au delà du jour J. `SM2Scheduler` n'en sait rien et n'a pas
  changé d'une ligne ; son résultat est rabattu sur l'échéance avant d'être appliqué. Trois
  refus : un palier d'apprentissage, qui se compte en minutes, n'est jamais rabattu ; une
  échéance déjà en deçà n'a rien à corriger ; et à moins de vingt-quatre heures il n'y a plus
  de planning à faire. Les intervalles annoncés sous les boutons de notation tiennent compte
  du plafond, et la session affiche « Mode examen » pour que des intervalles courts ne
  passent pas pour un planificateur cassé.
- **La levée du plafond de cartes neuves** : une carte sous échéance échappe au rythme
  quotidien. Sans cette exception, la projection serait un mensonge, puisqu'elle promet
  quarante cartes aujourd'hui là où le rythme n'en laisserait passer que huit. Le plafond
  garde tout son sens hors examen, où il n'y a pas de date à tenir.

### Réversible, toujours

Le plan garde une photographie des échéances d'avant (`Exam.scheduleBackup`), prise une seule
fois. Supprimer un examen, ou choisir « Rendre le planning normal », rend aux cartes leurs
échéances d'origine. Sans ça, supprimer un examen laisserait les cartes revenir tous les deux
jours pour un contrôle qui n'existe plus.

Modifier ou déplacer un examen **défait puis refait** son plan : garder des échéances
calculées pour une autre date, ou pour d'autres cours, donnerait un planning qui ne
correspond plus à rien.

Un examen désigne ses cours par leur identifiant et ne les possède pas : supprimer un cours
ne supprime pas l'examen et ne l'empêche pas de s'ouvrir, le cours disparu sort simplement de
la liste.

`MicaboTests/ExamPlannerTests.swift` verrouille l'échelle de passages, la projection, la
réversibilité et le plafond d'intervalle.

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
- une carte sous échéance d'examen y échappe : il n'y a pas de rythme de croisière à tenir
  quand il y a une date à tenir
- `MicaboTests/DailyLoadTests.swift` verrouille les paliers, les libellés et le plafond

## Structure

```
Micabo/
  App/             point d'entrée et conteneur SwiftData
  DesignSystem/    jetons de style, lexique et composants réutilisables
  Models/          entités SwiftData, fiche d'un cours, examens et réponses de l'IA
  Persistence/     enregistrement des cours et des examens
  SRS/             planificateur SM-2, file d'attente, mode examen, statistiques
  Services/        client IA, balisage de la fiche, PDF / OCR / DOCX / YouTube
  Features/        un dossier par écran, dont Course/ et Exams/
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

`MicaboTests/ExamPlannerTests.swift` verrouille le mode examen : l'échelle de passages et ses
cas limites, les quatre chiffres de la projection, la réversibilité d'une replanification, le
plafond d'intervalle et la levée du plafond de cartes neuves.

```bash
xcodebuild test -project Micabo.xcodeproj -scheme Micabo -destination 'platform=iOS Simulator,name=iPhone 16'
```
