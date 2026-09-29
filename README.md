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
| Cours | Tout ce qui est importé, avec recherche, tri et filtre par matière. Second rayon « Découvrir » : les cours que ton école et tes amis partagent, masqué sans compte |
| Réviser | Écran d'ouverture : les cartes à réviser aujourd'hui dans une carte unique — le chiffre, la durée, la barre de composition et sa légende — puis les cours au programme et les examens. Rien d'autre : ni salutation, ni date, ni liste de cours, ni bouton d'import |
| Profil | **Un tableau de bord** : la série et la courbe des quinze derniers jours dans un panneau, les trois totaux dans une bande, la porte des amis. Et les réglages, en haut à droite |

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
et c'est le premier bouton de l'écran tant qu'il n'y en a aucune. Une fois écrites, **elles
s'ouvrent d'elles-mêmes** : on retombait avant sur la fiche, qu'il fallait faire défiler
jusqu'en bas pour trouver la rangée « Cartes » et découvrir ce qui venait d'être produit.

```
import -> lecture sur l'appareil -> cours fiché -> (facultatif) cartes -> session
```

**Ce qu'on regarde pendant que Micabo travaille** (`GenerationOverlay`) montre la page en
train de se faire : un filet de titre, des lignes, un passage en couleur, un tableau, un graphe,
qui se posent l'un après l'autre pendant qu'un balayage de lecture descend en boucle. C'est la
même image que celle du parcours d'accueil, et c'est voulu — ce qu'on a promis à l'inscription
est ce qu'on montre en train d'arriver. L'écran d'avant cochait quatre étapes sur un minuteur
de 2,2 secondes : le problème n'était pas la laideur, c'était que les coches n'étaient reliées
à rien. Rien n'est du faux texte, seulement des formes, et la page ne se vide jamais pour
repartir : une page qui s'effacerait toutes les trois secondes se lirait comme un travail qui
recommence, donc comme un échec.

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
Les étapes sont décrites par `OnboardingStep`, dans l'ordre, et rendues par
`Micabo/Features/Onboarding/Steps/`. **Le parcours est un quiz, puis une démonstration, puis
une offre** : il pose ses questions d'abord, parce qu'un élève lit un parcours qui parle de
lui ; il rend ensuite, en montrant un cours fiché — le sien, importé pour de vrai, ou un cours
de démonstration — et trois cartes ; la preuve sociale et l'offre ne viennent qu'après ça,
quand il y a quelque chose à comparer.

| Bloc | Écrans |
| --- | --- |
| Accroche | le splash (logo seul 1,3 s, puis la phrase, « j'ai déjà un compte », Commencer, le menu de langue), le prénom (obligatoire), « Bienvenue, {prénom} » |
| Quiz | pays (menu, pays de l'appareil pré-choisi), niveau ou filière puis année, matières, ce qui inquiète (plusieurs réponses), objectifs (plusieurs réponses), « on s'en occupe » (deux barres, 36 % contre 80 %), moyenne actuelle, moyenne visée avec sa carte d'écart, temps par jour sur sa courbe, heure de révision (ciel, soleil, lune), rappels (semaine qui se coche, bannière, demande système) |
| Mika | le profil se prépare (blob, pourcentage, grille de points, 6,5 s, enchaîne seul), « voyons comment Micabo peut t'aider », cinq écrans de fonctionnalités (maquette, titre, ligne), « voyons ensemble une fiche » |
| Le cours | connexion (avec « Passer »), « tu as tes supports ? », les cases de dépôt **ou** un cours de démonstration à choisir, Mika écrit le cours, le cours fiché qu'on parcourt en entier |
| Les cartes | « envie de t'entraîner ? », trois cartes (recto verso, QCM, texte à trou), « bien joué » |
| L'offre | « on a aidé 45 000+ élèves » avec les avis, le gratuit contre Premium, la chronologie de l'essai, la promesse du rappel, le paywall |

### La navigation

**Les pages glissent au bouton, et la barre du haut ne bouge pas.** Rien ne se feuillette au
doigt : le rond fléché avance, la pilule de retour recule, et chaque changement d'étape est un
glissement pleine largeur — la page qui arrive entre par la droite, celle qui part recule d'un
tiers sous elle, voilée d'un rien (`OnboardingPager`). La pilule de retour et la jauge sont
posées **par-dessus** la pile des pages (`OnboardingTopBar`) : la jauge avance d'un cran sur
place pendant que la page arrive. Les écrans qui sont un moment à eux seuls — le splash, les
deux chargements, le cours, les cartes, le bravo, le paywall — la retirent
(`OnboardingStep.showsChrome`).

**On revient du pays jusqu'aux rappels, et nulle part ailleurs.** Le prénom et la bienvenue ne
se défont pas ; après les rappels, tout est un résultat, une démonstration, un compte ou une
offre. Les écrans sautés le restent dans les deux sens.

**Le rond fléché avance partout** (`OnboardingArrowButton`) : un rond d'encre en bas à droite,
gris tant qu'aucune réponse n'est donnée. Les seuls boutons à libellé sont ceux qui disent
autre chose qu'« avancer » : Commencer, le bouton à tenir du temps par jour, « oui » avant les
cartes, « rejoindre la communauté », le bouton d'achat.

**Les vibrations** : un tick à l'atterrissage de chaque page, la sélection sur chaque réponse
et chaque cran de curseur, un coup net à la fin des chargements, du bouton tenu, de la
troisième carte et sur le bravo.

### Mika

Mika est l'assistant, et il a une forme : un blob au dégradé violet, rose, orange, qui respire
(`MikaBlob`, quatre ondes lentes sur un cercle). Le dégradé n'apparaît qu'à trois endroits — le
blob, le sous-titre de son chargement, le chiffre des élèves aidés — et tout le reste du
parcours reste blanc, encre, violet (`OnboardingPalette`).

`MikaLoadingView` sert deux fois : quand le profil se prépare, sur un temps joué de six
secondes et demie qui ralentit trois fois sans jamais s'arrêter (`MikaProgressCurve`), et quand
un cours se construit pour de vrai, sur une jauge asymptotique qui finit le chemin à l'arrivée
du cours. Les deux enchaînent seuls : un coup net, le blob rapetisse, la page suivante.

### Le cours

**« Tu as tes supports ? » est la seule branche du parcours.** Oui mène aux cases de dépôt de
la création d'un deck (`DeckMaterialsStepView`, telle quelle), puis `DeckBuilder` écrit la
fiche, découpe le plan et prépare les cartes — c'est le premier cours de l'élève, offert. Non
mène à quatre cours de démonstration (`OnboardingDemoCatalog`, en français et en anglais :
la guerre froide, la photosynthèse, les dérivées, l'énergie), plus riches qu'une fiche
réelle — schémas, tableaux, graphes, frises, encadrés, dessinés par `DemoSheetView` — et qui
entrent dans la bibliothèque comme cours d'exemple (`sample`), convertis en texte. Un cours
d'exemple ne consomme pas l'import offert.

Le cours s'ouvre ensuite en entier (`CourseReviewStepView`) : le plan, les chapitres, sans
cadenas Pro, sans actions de révision, avec le rond fléché qui flotte. À la sortie du
parcours, la liste des cours l'ouvre (`FirstDeckHandoff`) ; « créons ton premier cours » ne
reste que pour qui n'en a pas.

Les trois cartes d'entraînement viennent du cours (`TrainingCard.pick`, une de chaque format)
ou du jeu embarqué, avec le schéma sur la première. Rien n'est noté ni enregistré.

### Les textes

Les chaînes du parcours vivent dans `IosI18nCatalogs`, en français et en anglais. Les tables
allemande, espagnole et turque portent l'anglais pour les phrases nouvelles, en attendant leur
validation ; le test de parité des clés tient.

Les réponses sont écrites au fil de l'eau dans `OnboardingPreferences` (clés
`micabo.onboarding.*`) et survivent à une fermeture en cours de route. `Réglages` propose
**Refaire l'onboarding**, qui efface ces clés et relance le parcours sans toucher aux cours.
`MicaboTests/OnboardingFlowTests.swift` verrouille l'ordre, les sauts, le retour, la barre du
haut et la jauge.

## Le gratuit et le payant

**La version gratuite laisse faire un cours entier à moitié.** C'est le compromis de tout le
modèle : assez pour que Micabo tourne sur ses propres notes de cours et prouve qu'il sert à
quelque chose, pas assez pour s'en servir toute l'année. Un essai qui ne montre rien ne convertit
personne, un essai qui montre tout non plus.

Les trois nombres vivent dans **`FreeTier`**, et nulle part ailleurs. Éparpillés dans les écrans,
ils auraient dérivé au premier ajustement, et le gratuit se serait mis à dire deux choses
différentes selon la porte par laquelle on l'a rencontré.

| Ce qui est ouvert | Ce qui s'arrête | Où |
| --- | --- | --- |
| Le premier cours importé | Le deuxième | Le « + » de Cours, les états vides de Cours et de Réviser |
| Les 70 % de chaque fiche | La fin, floutée et fondue dans le papier | `CourseSheetView` |
| La génération de cartes, sans limite | — | `GenerateCardsSheet` |
| Les 5 premières cartes d'une session | La sixième | `StudyView` |
| Réviser ce qui est dû | L'entraînement libre, en entier | Réviser, la fiche, les cartes |

**`ProAccess`** est le seul objet qui réponde à « est-ce que cette personne est abonnée ? ». Il
est créé une fois dans `MicaboApp` et posé dans l'environnement, comme `AuthController` : deux
écrans qui décideraient chacun de leur côté finiraient par ne pas être d'accord, et un
utilisateur qui vient de payer verrait encore un cadenas quelque part.

**La fiche se coupe en blocs, pas en caractères** (`SheetGate`). Trancher un paragraphe au
septième dixième de son texte donnerait une phrase interrompue au milieu d'un mot, ce qui
ressemble à un bug d'affichage plutôt qu'à une limite assumée. Les blocs restants sont **bel et
bien composés**, puis floutés et fondus dans l'ivoire sur trois cents points : une fiche coupée
net se lit comme une fiche courte, et une fiche courte ne donne envie de rien, là où une fiche
dont on voit la suite se dissoudre donne envie de la lire. Ni le doigt ni le lecteur d'écran
n'entrent dans la zone floutée — un texte illisible qu'on peut sélectionner reste un texte qu'on
peut copier.

**La session s'arrête après la note, jamais avant.** Une carte lue, retournée et notée doit être
comptée : couper avant la note ferait disparaître le travail à l'instant même où l'on demande de
payer. Une session qui se termine exactement sur la cinquième carte est épargnée — elle a été
révisée en entier, et poser un paywall par-dessus l'écran de fin reviendrait à facturer ce qu'on
vient d'offrir.

`SessionPaywallView` est le seul écran d'abonnement qui **interrompt quelque chose en cours**, et
le seul écrit autrement. Il ne propose pas, il tranche, et ses deux issues sont écrites en toutes
lettres : s'abonner, ou revenir à l'accueil. Aucune des deux ne se cache derrière la croix — une
sortie qu'il faut deviner n'est pas une sortie. La croix, elle, demande confirmation (« Tu es sûr
d'abandonner ta progression ? », dont le bouton principal est **Revenir**) : c'est le seul endroit
de l'app où une croix pose une question, et c'est justifié, elle abandonne une session commencée.
« Revenir à l'accueil » passe par `TabRouter.goHome()`, qui vide les trois piles — une session
lancée depuis la fiche d'un cours est deux écrans plus loin que Réviser.

**Les refus arrivent avant le travail, pas après.** Le deuxième import se refuse au moment où
l'on ouvre le choix du type de document, et non une fois le PDF choisi et l'analyse attendue : un
paywall qui tombe après le travail est un paywall qui fait désinstaller. De même, les boutons
« Entraînement libre » portent leur cadenas avant l'appui plutôt que de faire surgir un paywall à
la place d'une session.

**Le « + » de Cours, lui, ne porte pas de cadenas**, et c'est l'exception qui confirme la règle.
Un bouton verrouillé annonce un refus avant qu'on ait demandé quoi que ce soit : il transforme
le seul geste de l'écran en porte fermée, et on cesse de le regarder. Il garde son signe, et
c'est l'appui qui ouvre le paywall — on demande, on obtient une réponse, et la réponse dit ce
qu'elle coûte. Un cadenas sur un bouton d'action n'a de sens que là où le bouton en côtoie
d'autres qui, eux, marchent.

Les cours **repris dans la bibliothèque** ne comptent pas dans le quota d'import : ils n'ont rien
coûté à produire, et faire payer un import qu'on n'a pas fait serait incompréhensible.

L'abonnement n'est branché sur aucune boutique. `Réglages → Test → Micabo Pro` est un
**interrupteur de relecture**, pas une fonctionnalité : sans lui, les écrans de blocage ne se
verraient qu'une fois, le bouton du paywall ouvrant tout. Il disparaîtra le jour où RevenueCat
décidera à sa place. `MicaboTests/FreemiumTests.swift` verrouille les trois nombres et la coupure
de la fiche.

## Direction visuelle

Du fond, des cartes, et de l'air entre elles. Le fond est assez marqué pour que le blanc se
détache seul : les surfaces n'ont donc pas de bordure, mais une ombre en deux couches qui les
pose sans les faire léviter. Tout ce qui se liste est une **rangée** — une tuile pastel, un
intitulé, un sous-titre, puis un accessoire à droite.

**Une liste d'objets est faite de cartes ; une liste de réglages reste un bloc.** C'est la
seule distinction de mise en page de l'app, et elle est fonctionnelle. Un cours, un paquet,
ce qu'il y a au programme : chacun est une chose qu'on ouvre, qu'on range, qu'on supprime, et
un bloc unique coupé par des filets les présentait comme les lignes d'un même formulaire.
Chaque rangée est donc devenue une carte, avec son ombre et son air autour
(`MicaboRowGroup`, mise en page `.cards`). Les Réglages, eux, gardent le bloc : douze lignes
qui appartiennent au même sujet et dont aucune ne s'ouvre — là, le filet dit la bonne chose,
et douze cartes indépendantes se liraient comme douze décisions à prendre (`.grouped`).

**L'encre n'est plus noire.** `#111827` est un noir de texte imprimé : posé sur du gris clair
il durcit chaque rangée, et les listes avaient l'air gravées. Le navy désaturé qui le remplace
garde tout son contraste et rend l'écran respirable. Les encres secondaires suivent, et
`inkTertiary` cesse d'être la copie exacte d'`inkSecondary` — deux niveaux de gris qui
portaient le même code hexadécimal ne hiérarchisaient rien.

**L'accent est le bleu de Micabo, `#2563EB`.** Il ne sert qu'à ce qui est actif ou
sélectionné : onglet courant, filtre choisi, cartes à réviser, bouton d'action. Deux bleus, et
la distinction compte : `accent` est assez sombre pour porter du texte de onze points sur un
fond pastel, `accentVivid` ne remplit que de **grandes** surfaces sur lesquelles rien n'est
écrit. Un ambre (`cautionVivid`, `#FFC53D`) le complète pour la série et les échéances : ce
sont les seules choses de l'app qu'on peut perdre, et elles méritent de ne pas être bleues
comme le reste.

**Deux familles de caractères, et chacune a son domaine** (`MicaboFont`). Outfit écrit
l'interface — titres d'écran, intitulés de rangée, libellés de bouton, sur-titres, onglets, et
tous les nombres qui se lisent comme un résultat : c'est une géométrique large, qui tient le
gras sans s'épaissir. Hanken Grotesk écrit **ce qu'on lit vraiment** : le corps d'une fiche,
ses encadrés, le verso d'une carte, les propositions d'un QCM. Plus étroite et plus sobre,
elle tient l'œil d'une ligne à l'autre là où une géométrique fatigue au-delà de quelques
lignes. Le partage n'est pas « la plus jolie pour les titres » : **l'une nomme, l'autre
raconte**. Les deux étaient déjà dans le dépôt et aucune ne servait — `MicaboFont.hanken()`
renvoyait `.system()`, donc l'app entière était en San Francisco et les quatre fichiers Hanken
voyageaient dans le bundle sans jamais être appelés.

- Fond `#F4F6FA`, surfaces blanches, encre `#232B3E`, **accent bleu `#2563EB`**, bleu vif
  `#3B82F6` pour les remplissages, ambre `#FFC53D` pour la série et les échéances
- Typographie **Outfit** (Regular / Medium / SemiBold / Bold) pour l'interface et les nombres,
  **Hanken Grotesk** (mêmes coupes) pour le texte de lecture. Les deux sont embarquées et
  déclarées dans `UIAppFonts` ; `FontLoader` les enregistre avant le premier rendu
- Coins : 14 pt (tuiles, boutons, champs), 18 pt (rangées-cartes, encadrés), 22 pt (blocs et
  cartes), 28 pt (feuilles). **Le bouton est volontairement moins rond que la carte** : une
  carte est une surface sur laquelle on pose, un bouton est une commande qu'on presse, et un
  bouton trop rond perd ses angles d'appui
- Ombres en deux couches (`MicaboElevation`) : un contact d'un point sous l'objet, et une
  diffusion large qui le décolle. Elles sont teintées de l'encre et non du noir — une ombre
  noire sur un fond bleuté vire au gris sale. Le seul bouton d'action principal porte une
  ombre de sa propre couleur, et c'est le seul objet de l'app qui a le droit de rayonner
- **Un seul en-tête pour toute l'app** : `MicaboScreenHeader`, posé à même le fond, sur-titre en
  capitales grises puis grand titre serré (32 pt). Aucun écran n'a droit à son bandeau : un
  écran poussé ou une feuille ajoute un bouton rond au-dessus du sur-titre, et une page qui
  doit porter une couleur — le détail d'un cours — la porte dans sa **tuile**. Plus de barre
  de navigation système nulle part : les titres système ont tous été remplacés.
- Pastilles d'état au bout d'une rangée : vert pour ce qui attend, ocre pour une échéance,
  gris pour « à jour »
- Le seul aplat d'encre est le bouton d'action principal, ancré en bas de l'écran
- Barre de cinq onglets en pied d'écran, symbole plein sur l'onglet actif. Elle est dessinée
  par `RootTabView`, **hors des pages** : elles se remplacent sous elle, elle ne bouge pas
  d'un pixel. Depuis que le balayage entre onglets a disparu, c'est le seul moyen de changer
  de page. Elle s'efface sur les écrans poussés, où changer d'onglet depuis le fond d'une pile
  ne voudrait rien dire
- **La barre est plate, opaque, et collée au bas.** Elle a été une pastille en verre qui
  flottait : un flou noyé sous un aplat à 72 %, autant dire un bandeau opaque, et un bandeau
  opaque qui touche ce qu'une page ancre au-dessus de lui donne un bouton qu'on croit coupé.
  C'est maintenant une bande pleine largeur, un filet du dessus, le fond de la page qui
  continue sous l'indicateur d'accueil. Sa hauteur est déclarée (`MicaboLayout.tabBarHeight`)
  et non mesurée sur ses libellés, parce que c'est cette hauteur que les pages réservent, et
  l'air qu'elle laisse au-dessus d'elle l'est aussi (`MicaboLayout.tabBarGap`)
- Un seul bouton flottant dans l'app : le « + » d'import, en bas à droite de Cours, là où le
  pouce tombe. Il n'apparaît pas quand la liste est vide, où l'écran d'accueil porte déjà son
  propre appel à importer
- **Ce qui est ancré en bas d'une page d'onglet passe par `tabBarClearance`**, à l'intérieur
  du `NavigationStack` de la page. Le « + » de Cours et le bouton de session de Réviser
  passaient **sous** la barre d'onglets, et le remède qu'on avait appliqué — remplacer
  l'`overlay` par un `safeAreaInset` côté racine — n'avait rien changé, parce que les deux
  tombent au même endroit. La cause est ailleurs : **un `safeAreaInset` ne franchit pas la
  frontière d'un `NavigationStack`**, qui rétablit sa zone sûre depuis la fenêtre. La barre
  étant posée par la racine, à l'extérieur des trois pages, son inset la dessine sans jamais
  rien réserver *dans* les pages ; tout ce qu'une page ancrait en bas se posait donc au bas de
  sa propre zone sûre, c'est-à-dire exactement là où la barre est peinte. Le modificateur fait
  les deux choses du bon côté de la frontière : il pose l'accessoire de la page et laisse la
  hauteur de la barre en creux sous lui (`MicaboLayout.tabBarSpace`), sans prendre les appuis —
  une surface transparente qui les avalerait rendrait les cinq onglets inertes. Le Profil, qui
  n'ancre rien, la réserve aussi : sa dernière rangée se collait à la barre. Les écrans
  qui masquent la barre — une fiche, ses cartes, les examens, une feuille — gardent l'`overlay`
  et la constante `bottomBarClearance` : sous eux, il n'y a que le repose-doigt
- Geste de retour du système sur les écrans poussés. **On ne balaye plus d'une page à l'autre** : les onglets s'atteignent par la barre du bas, et elle seule
- Réviser porte le nom de l'écran, la date en sur-titre et la série en pastille ; puis une carte unique qui donne le chiffre du jour, sa durée, sa répartition et sa légende. Le titre était une salutation — « Bonsoir, Adrien » — c'est-à-dire la plus grosse typographie de la page employée à ne rien dire, et le chiffre du jour repoussé d'autant
- Un cours a deux écrans : sa **fiche**, qui est l'écran du cours, et ses **cartes**, un cran
  plus loin. Les deux portent le même en-tête que le reste de l'app — tuile du cours, matière
  et durée de lecture en sur-titre, titre — et se distinguent par leur sur-titre, pas par un
  bandeau. La fiche pose son texte à même le fond et n'encadre que les objets : définitions,
  encadrés, tableaux, graphes, formules
- Ce que la fiche met en avant porte **une bande jaune** (`MicaboColor.sheetMarker`), et garde
  son encre. Le passage marqué a été du texte bleu pendant une version, parce qu'un fond de
  texte posé par TextKit prend toute la hauteur de ligne, interligne compris : la bande
  touchait celle de la ligne du dessus et changeait d'épaisseur d'une ligne à l'autre. Mais du
  texte bleu au milieu d'un paragraphe se lit comme un lien, d'autant que le bleu est déjà
  l'accent de l'app. La bande est donc revenue, et son épaisseur est calée sur la hauteur des
  capitales de la fonte du passage plutôt que sur celle de la ligne
  (`SheetMarkerLayoutManager`, et `.sheet-marker` en `em` sur le web). Les encadrés, eux,
  gardent les couleurs de retour d'information de l'app, volontairement désaturées
- Chaque cours porte un emoji sur pastel, déduit de la matière quand l'analyse n'en propose
  pas (`CourseEmoji`). **Une matière, un emoji** : la table servait le même dessin à six
  matières voisines — quatre matières de santé pour un stéthoscope, dix langues pour une
  bouche qui parle — et six matières ne trouvaient rien du tout. Sur l'écran des matières, où
  quarante-neuf pastilles s'enroulent en sept familles, un emoji répété fait relire les
  libellés un par un, ce qui est exactement le travail qu'il devait éviter. Chaque langue
  vivante porte son drapeau, et les entrées les plus générales ferment la table derrière les
  matières qu'elles englobent : « Code de la route » contient « code », et sortait un
  ordinateur portable. Le catalogue des matières vit dans `SubjectCatalog`, hors de la vue qui
  l'affiche, pour que la règle se vérifie
- **La matière ne crie pas.** Le modèle rend la casse du titre qu'il a lu : un polycopié titré
  « HISTOIRE » donnait une matière « HISTOIRE », qui hurle sur une pastille de filtre au milieu
  d'un écran qui ne crie jamais — et deux cours de la même matière écrits différemment font
  deux matières dans les filtres. `TextSanitizer.subject` lui rend sa casse mot par mot, en
  laissant les sigles tranquilles : un mot de quatre lettres ou plus avec au moins deux
  voyelles est un mot, le reste garde ses capitales. C'est ce qui distingue « DROIT » de
  « STAPS », « PASS », « SVT » ou « HGGSP », qui sont les noms réels de filières françaises —
  écrire « Svt » est une faute qu'on lit tout de suite, laisser « ARTS » en capitales n'est
  qu'un cas non corrigé. La règle s'applique à l'import, à la reprise d'un cours partagé, à la
  création d'un paquet et à la descente du cloud ; une passe unique au lancement
  (`SubjectCasePass`) corrige les cours déjà là, sans toucher leur date de modification
- En session, une ampoule donne l'indice de la carte. Les cartes qui n'en ont pas n'affichent
  pas l'ampoule : un indice tiré de la forme de la réponse (initiale, nombre de mots) n'apprend
  rien et fait perdre confiance dans les vrais indices
- **Tout ce qui se touche vibre, une fois et une seule.** Le retour d'appui est porté par les
  styles de bouton (`micaboPressEffect`), qui sont le seul passage obligé : il n'y a pas de
  bouton sans style, donc il n'y a plus de bouton muet — et la vibration part à
  l'enfoncement, quand le doigt attend une réponse, pas à l'action. Chaque style dit sa
  texture (`Haptics.Press`) : l'encre du bas d'écran frappe moyen, une rangée frappe léger,
  une réponse de question fait le cran d'un sélecteur, écarter une carte fait la double
  vibration du système. Les appels écrits à la main ne restent que pour ce qui n'est pas un
  appui — le résultat d'une opération, le rythme d'une animation, un glissement, une touche
  de clavier — et les contrôles du système passent par une liaison qui vibre
  (`Binding.buzzing()`), faute d'un style où l'accrocher
- Animations en cascade, et tout le vocabulaire haptique dans `Haptics`

Les composants vivent dans `Micabo/DesignSystem/Components/` : `MicaboRows.swift` (tuile,
pastille, rangée, blocs, intitulés de section) et `MicaboHeaders.swift` (en-têtes d'écran,
barre de retour, champ de recherche).

### Remplacer l'icône de l'application

Le catalogue n'attend qu'**un seul fichier**, en 1024 × 1024, RGB, sans transparence et sans
coins arrondis (iOS les arrondit lui-même) :

```
Micabo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

Déposer le fichier à ce chemin suffit : `Contents.json` ne déclare qu'une entrée universelle,
il n'y a donc ni déclinaison de tailles à générer ni référence à ajouter dans le projet.

## Feuille de route

`docs/plan-amelioration.md` réunit l'audit du produit (parcours d'accueil, écrans, textes, design
system), la comparaison avec Anki, Quizlet, Knowt, RemNote, Brainscape et Duolingo, et le plan de
travail qui en découle, en quatre lots.

## Pile technique

- SwiftUI, iOS 17 minimum, projet Xcode natif (`Micabo.xcodeproj`)
- SwiftData pour le stockage local (aucune donnée n'est envoyée hors des appels IA)
- PDFKit pour le texte embarqué d'un PDF, Vision (OCR) pour les scans et les photos
- Lecture locale des `.docx` (ZIP + `word/document.xml`), sans dépendance
- Supabase Edge Functions comme relais vers fal.ai (`google/gemini-2.5-flash-lite`)

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
cd supabase/functions && deno task verify && cd -
supabase link --project-ref votre-ref
supabase functions deploy generate-course
supabase functions deploy generate-flashcards
supabase functions deploy explain-selection
supabase functions deploy youtube-transcript
```

#### Déployer sans terminal, depuis le web

Le déploiement par l'API — celui du tableau de bord Supabase, ou d'un agent branché dessus —
ne veut pas des sources : il exige que **toutes les dépendances relatives** arrivent avec le
point d'entrée, soit deux cents kilo-octets de modules par fonction. D'où `pin.sh` : il écrit
un point d'entrée de six lignes qui **importe le dépôt sur un commit**, et la construction
inline le graphe entier au déploiement. Rien n'appelle GitHub à l'exécution.

```bash
cd supabase/functions
./pin.sh                 # les six fonctions, sur HEAD
./pin.sh <commit>        # sur un autre commit, déjà poussé
deno check --allow-import --no-lock dist/generate-course.pin.ts
```

Le contenu de `dist/<fonction>.pin.ts` se colle ensuite dans l'éditeur du tableau de bord
(Edge Functions → la fonction → Deploy a new version), en gardant `verify_jwt` activé. Deux
conditions, et elles ne se devinent pas : **le commit doit être poussé** et lisible sans jeton,
sinon la construction ne peut pas le lire ; et le fichier déployé n'est pas le code, c'est le
commit qui le nomme — un déploiement qui pointe un vieux commit sert du vieux code sans qu'aucun
message ne le dise. Après coup, `./smoke.sh` répond en trois secondes : une fonction dont le
module ne charge pas rend `WORKER_ERROR` avant d'entrer dans le moindre `try`.

**`deno task verify` d'abord, et ce n'est pas une politesse.** Une fonction qui ne passe pas
la vérification de types n'est pas déployée, et l'application ne le sait pas : elle reçoit un
404 et affiche « Fonction Supabase introuvable ». C'est exactement ce qui est arrivé à
`youtube-transcript`, restée non déployée à cause de deux `null` non gardés dans
`_shared/youtube.ts` : l'import de vidéo était donc cassé pour tout le monde, sans qu'une
seule ligne du chemin YouTube soit en cause. La tâche vérifie les quatre points d'entrée et
lance les tests des modules partagés.

Le diagnostic se refait en une commande, et c'est la bonne façon de savoir ce qui tourne
vraiment :

```bash
for FN in generate-course generate-flashcards explain-selection youtube-transcript; do
  curl -s -X POST "$SUPABASE_URL/functions/v1/$FN" \
    -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" -d '{}' | head -c 80; echo " ← $FN"
done
```

Une fonction déployée répond par **son propre refus** (« Le document ne contient pas assez de
contenu à analyser. »), ce qui prouve qu'elle tourne. Une fonction absente répond
`{"code":"NOT_FOUND"}`. C'est cette différence, et pas les logs, qui dit en trois secondes si
un déploiement est passé.

`youtube-transcript` n'a pas besoin de `FAL_KEY` : elle ne parle qu'à YouTube. Elle lit le
lecteur par son API interne, avec repli sur la page HTML, et c'est la partie la plus fragile
du dépôt : YouTube change de forme sans préavis. Les deux chemins existent pour cette raison,
et un échec y est toujours traduit en refus nommé plutôt qu'en écran cassé.

La version à plat de la fiche (`contextText`) est **calculée par la fonction**, pas demandée
au modèle : deux rédactions du même contenu finiraient par se contredire, et celle-ci est
déterministe. Un client plus ancien qu'un serveur redéployé continue donc de fonctionner, et
un client à jour reconstitue le contexte depuis la fiche si le serveur ne l'envoie pas.

### 3. Appliquer les migrations

```bash
supabase db push
```

`supabase/migrations/` porte deux migrations : l'annuaire des établissements, et **les comptes
et le stockage des cours**. La seconde crée cinq tables, leurs règles de cloisonnement et le
déclencheur qui crée un profil à l'inscription. Elle est écrite pour être rejouable : chaque
objet est créé avec `if not exists` ou remplacé.

Pour savoir où en est un projet, sans ouvrir le tableau de bord :

```bash
curl -s -o /dev/null -w "%{http_code}\n" "$SUPABASE_URL/rest/v1/courses?select=id&limit=1" \
  -H "apikey: $KEY"
```

`200` avec un tableau vide veut dire que la migration est passée **et** que le cloisonnement
fonctionne : la table existe, et un client anonyme n'y voit rien. `404` veut dire que la
migration n'a pas encore été appliquée sur ce projet.

### 4. Renseigner le projet dans l'application

L'URL et la clé publique par défaut sont dans `Micabo/Services/AppConfig.swift`. Elles restent
modifiables à l'exécution depuis `Profil`, `Réglages`, sans recompiler.

Tant que `FAL_KEY` n'est pas configurée, l'import reste utilisable : Micabo propose de
construire la fiche hors ligne, à partir du texte brut.

## Comptes et sauvegarde

Micabo a fonctionné sans compte pendant tout son développement : tout vivait dans SwiftData,
sur un seul téléphone, et « Tout reste sur cet appareil » était écrit dans l'écran Profil.
Effacer l'app effaçait deux ans de fiches.

**Le compte se demande à la fin du parcours d'accueil.** C'est une décision : demander un
effort avant d'avoir donné une raison ne marche pas, et les vingt écrans d'accueil existent
pour donner cette raison. On peut le passer une fois, là, quand on n'a encore rien à perdre.

L'écran de compte de `RootView` est resté, mais comme **rattrapage** : il se demandait là, à la
sortie du parcours, ce qui donnait deux écrans de connexion à la suite. Il ne s'affiche
maintenant que pour quelqu'un qui a fini le parcours sans compte et sans passer explicitement,
c'est-à-dire après une déconnexion depuis les réglages — et il ne propose plus de continuer
sans compte : après une déconnexion volontaire, proposer de rester dehors revient à proposer
d'abandonner ce qu'on vient de mettre en sécurité.

**C'est le même écran que celui du parcours, et pas une copie.** Apple, Google, le courriel,
les trois avantages et le message d'échec vivent dans `SignInPanel`, que les deux
écrans montent. La reconnexion était le plus mal tenu de l'app — adresse, mot de passe, lien
de connexion, mot de passe oublié, bascule connexion/inscription, et une sortie sans compte —
ce qui n'est pas un hasard : on ne la voit presque jamais.

### Ce qui est stocké

| Table | Contenu |
| --- | --- |
| `profiles` | Les réponses de l'inscription : stade d'étude, pays, matières, rythme, longueur de fiche. C'est ce qui fait qu'une réinstallation retrouve un étudiant en santé en Belgique, et non un lycéen français par défaut |
| `courses` | **L'original et le transformé dans la même ligne** : `raw_text` est le document tel qu'il a été lu, `sheet` est la fiche que le modèle en a écrite |
| `flashcards` | Les cartes, **état de répétition espacée compris** : une révision faite sur le téléphone doit compter sur le web, sinon la carte revient deux fois |
| `review_logs` | Chaque révision, en ajout seul : une révision est un fait daté, elle ne se corrige pas |
| `exams` | Les examens et leur plan |
| `directory` | **La vitrine d'un profil** : nom d'utilisateur et établissement, et rien d'autre. Tenue par un déclencheur depuis `profiles` |
| `friendships` | Une ligne par relation : qui a demandé à qui, et où ça en est |

Ce qui **ne** monte pas : les images d'occlusion, les couvertures et les enregistrements audio.
Ce sont des mégaoctets par cours, et une colonne `bytea` transforme une base Postgres en disque
dur. Leur place est le stockage objet de Supabase, et c'est la première chose à ajouter après
cette synchro (voir `docs/data-flywheel.md`).

### Trois décisions de schéma

1. **L'identifiant vient du client.** L'app crée un `UUID` local au moment de l'import, bien
   avant de savoir s'il y a un compte, et c'est ce même identifiant qui devient la clé primaire
   distante. Sans ça, il faudrait une table de correspondance, et deux appareils qui remontent
   le même cours créeraient deux lignes. Avec, une remontée est répétable à volonté :
   `resolution=merge-duplicates` met à jour au lieu de refuser un doublon, ce qui permet de tout
   renvoyer après trois jours hors ligne sans tenir de journal de ce qui a changé.
2. **Rien ne se supprime vraiment.** `deleted_at` remplace le `DELETE` : un appareil resté hors
   ligne doit apprendre qu'un cours a disparu, et une ligne effacée ne peut rien lui apprendre.
3. **Le dernier qui écrit gagne**, arbitré par `updated_at` — posé par un trigger, jamais par le
   client, dont on n'a pas à croire l'horloge. C'est le bon compromis ici : les données de
   Micabo sont personnelles et modifiées à un endroit à la fois. Deux appareils qui révisent la
   même carte dans la même minute sont un cas théorique ; l'un des deux resté trois jours hors
   ligne est le cas réel, et l'horodatage le tranche correctement.

### Le cloisonnement

Chaque table porte la même règle : `(select auth.uid()) = user_id`. `auth.uid()` est lu dans le
jeton, donc l'app n'a aucun moyen de demander les cours de quelqu'un d'autre, même en
trafiquant sa requête. Vérifié depuis un client anonyme : la lecture rend une liste vide,
l'écriture est refusée par la politique.

Un bug de session ne peut donc pas faire fuiter des données — il ne peut que rendre une liste
vide, et c'est exactement le comportement qu'on veut d'un échec.

## La bibliothèque, les amis, et qui voit quoi

Ouvrir la bibliothèque veut dire ouvrir une brèche dans la règle ci-dessus, et une brèche dans
une règle de cloisonnement se conçoit avant de s'écrire. Quatre décisions la tiennent.

**La visibilité est portée par le cours, pas par le compte.** Le même étudiant partage
volontiers son chapitre de SVT et garde ses notes de psychanalyse pour lui ; un réglage global
l'aurait forcé à choisir entre tout ouvrir et tout fermer, c'est-à-dire à tout fermer. Trois
valeurs (`CourseVisibility`) : `public` se lit par les camarades du même établissement **et**
par les amis — quelqu'un qui change d'école ne perd pas l'accès aux cours de ses amis ;
`friends` ne se lit que par les amis ; `private` par personne. Le défaut est `public`, assumé :
une bibliothèque où personne ne dépose rien n'intéresse personne.

Le réglage se choisit **à l'import**, et se change ensuite là où le cours se lit, dans le menu
de sa fiche. Les deux moments comptent, et le premier manquait : quand on sait, en déposant le
document, qu'on ne veut pas le partager, un cours qui part public le temps qu'on y pense est un
cours qui a été visible — le refermer après ne rattrape pas la minute passée. Le choix se garde
d'un import à l'autre (`CourseVisibility.importKey`), parce que c'est une habitude plutôt qu'une
propriété du document. Le paquet de cartes y gagne plus encore : n'ayant pas de fiche, il n'avait
aucun écran où l'on pouvait le refermer, donc il restait public à vie.

**On ne relâche que le `SELECT`.** Les politiques existantes ne bougent pas : personne ne peut
modifier le cours de quelqu'un d'autre. Une seconde politique de lecture s'ajoute à la première,
et deux politiques se cumulent — c'est ce cumul qui a cassé la synchro le premier jour, voir
plus bas.

**Les préférences d'un profil ne sortent jamais.** Le cloisonnement de Postgres filtre des
lignes, pas des colonnes : une politique de lecture sur `profiles` aurait exposé la ligne
entière, donc le stade d'étude, le pays, les objectifs et le rythme quotidien. `directory` ne
porte que le nom d'utilisateur et l'établissement, et un déclencheur la tient à jour. Trois
colonnes dupliquées contre la certitude qu'une préférence ne peut pas fuir. Le prix se paye en
une requête de plus : il n'y a pas de clé étrangère entre `courses` et `directory`, donc pas de
jointure, donc l'app demande les auteurs à part.

**Les cartes ne sortent pas non plus.** Reprendre un cours copie sa fiche, et l'étudiant écrit
ses propres cartes. C'est plus utile pour lui, et ça évite d'exposer l'état de répétition
espacée de quelqu'un d'autre, qui dit exactement ce qu'il sait mal.

### Les deux fonctions qu'appellent les politiques

`are_friends` et `share_institution` sont **sans privilège** (`security invoker`), et ce n'est
pas un détail : une politique s'évalue avec les droits de celui qui interroge, donc une fonction
`security definer` aurait dû rester exécutable par `authenticated`, et n'importe qui aurait pu
l'appeler en RPC pour sonder le graphe des amitiés de tout le monde. Sans privilège, elles ne
lisent que ce que l'appelant peut déjà lire — ses propres amitiés, l'annuaire — donc elles ne
répondent que sur lui.

Corollaire à ne pas casser : `share_institution` lit `directory` et non `profiles`. Si elle
lisait `profiles`, cloisonné au propriétaire, elle rendrait toujours faux et le partage entre
camarades ne marcherait plus du tout, sans que rien ne le signale.

### Ce que la brèche a cassé, et comment

La descente de la synchro n'avait **pas de filtre** : elle demandait `courses` et s'appuyait sur
le cloisonnement pour ne recevoir que ses lignes. La seconde politique de lecture a donc suffi à
faire entrer les cours des camarades dans « Mes cours ». Et le second effet était pire que le
premier : la montée renvoie chaque cours local avec son identifiant et **son** `user_id`, ce qui
revient à réécrire la ligne d'un camarade ; la politique d'écriture la refuse, la synchro échoue,
le repère n'avance pas, et les mêmes lignes reviennent à chaque lancement.

La leçon tient en une phrase, et elle vaut pour la prochaine politique qu'on ajoutera : **une
requête qui compte sur le cloisonnement pour ne pas ramasser les lignes des autres est une
requête qu'une politique ajoutée un jour recasse.** Les deux descentes portent maintenant leur
filtre `user_id`, y compris celle des cartes, dont la table n'a pourtant qu'une seule politique.

### Reprendre le cours de quelqu'un

`CourseRepository.adopt` fait trois choses qui se payent si on les prend à l'envers. **Un nouvel
identifiant**, parce que l'identifiant local devient la clé primaire distante et que garder
celui de l'auteur ferait écrire une ligne qui lui appartient. **Privé par défaut**, parce que
reprendre un cours ne donne pas le droit de le rediffuser sous son propre nom — c'est le seul
chemin de l'app qui crée un cours non public. **Sans les cartes**, pour la raison dite plus haut.

Reprendre deux fois le même cours est le geste le plus facile à faire par erreur : il ne coûte
qu'un appui. L'empreinte le reconnaît, comme pour un import, et le titre prend le relais quand
le texte est trop court pour en avoir une — un paquet de cartes partagé se serait sinon laissé
reprendre indéfiniment.

Rien de ce qui vient des autres n'est gardé sur l'appareil. Un cours partagé change sans qu'on
le sache, peut redevenir privé, et un ami peut se retirer : une copie locale les figerait, donc
mentirait. Ce qui entre vraiment dans l'app, c'est le cours qu'on reprend, et celui-là devient
le nôtre.

### Le nom d'utilisateur

On ne s'ajoute pas en ami avec un UUID, et une adresse électronique n'a pas à circuler dans un
annuaire d'école. Le nom d'utilisateur est donc un **identifiant** et pas un pseudonyme
d'affichage : minuscules, sans accent, sans espace, pour qu'il se dicte sans ambiguïté.

Il est **donné à l'inscription**, dérivé de ce que le fournisseur OAuth a fourni — « Adrien
Martinot » devient `adrien-7910` — pour qu'on n'ait rien à choisir avant d'avoir compris à quoi
ça sert. La coupe se fait sur un tiret et jamais au milieu d'un mot : `adrien-martino` avait
l'air d'un nom mal orthographié.

Les règles sont écrites deux fois, dans `Username` et dans une contrainte de la base
(`profiles_username_shape`), et les tests verrouillent la première **sur** la seconde : un nom
que l'app accepte et que la base refuse donne un aller-retour pour rien et un message que
personne ne comprend. Le champ ne refuse rien de ce qui peut être sauvé — ce qu'on tape est mis
en forme à l'enregistrement, et la ligne du dessous annonce ce que ça va donner.

Le nom voyage **seul**, sans le reste du profil : la synchro envoie le profil entier à chaque
passage, et s'il voyageait avec, un appareil dont la copie locale est en retard écraserait le nom
qu'on vient de changer sur l'autre.

### L'authentification

GoTrue en HTTP direct (`SupabaseAuthClient`), comme les Edge Functions, plutôt qu'un SDK :
l'authentification tient en quatre appels — ouvrir une session depuis un jeton Apple, en
ouvrir une depuis un code OAuth, la rafraîchir, la fermer — qu'on relit en une fois, là où une
dépendance externe coûterait un gestionnaire de paquets, une surface de mise à jour et un
binaire.

**Il n'y a plus de mot de passe.** Micabo se connecte par Apple, Google, ou un lien envoyé
par courriel — le même trio que sur le web. Le mot de passe et la réinitialisation restent
partis. Le lien ouvre `micabo://auth-callback` : PKCE si le courriel rend un `code`,
`token_hash` sinon.

La session vit dans le **trousseau**, et pas dans les réglages : un jeton de rafraîchissement
donne accès au compte sans mot de passe, et dans `UserDefaults` il se lirait en clair dans une
sauvegarde. `ThisDeviceOnly` l'empêche en plus de partir dans iCloud, donc restaurer un vieux
backup sur un autre téléphone ne connecte personne. Le jeton d'accès est rafraîchi à un seul
endroit, `AuthController.validAccessToken()`, une minute avant son échéance : personne d'autre
n'a à savoir qu'un jeton expire.

**L'écran de connexion affiche les fournisseurs, toujours.** Il interrogeait le projet au
lancement (`GET /auth/v1/settings`) pour ne montrer que les fournisseurs activés — un appel
réseau de plus au démarrage, et un écran qui pouvait n'avoir plus rien à proposer du tout. Un
fournisseur éteint côté Supabase le dit clairement dans son message d'erreur, ce qui est plus
utile qu'un bouton absent dont personne ne peut deviner la cause.

Les étapes complètes de cette configuration, iOS et web, sont dans
**[`docs/oauth-setup.md`](docs/oauth-setup.md)**. Ce qu'il faut retenir en une ligne : Apple
demande que le **bundle de l'app et le Service ID soient tous les deux** dans le champ
« Client IDs », parce que le jeton du bouton natif porte le premier et celui du retour web le
second.

Et **[`docs/data-flywheel.md`](docs/data-flywheel.md)** propose ce qu'il faudrait garder en plus
pour que ces données deviennent un avantage : rien n'y est implémenté, c'est une note de
conception.

**[`docs/web.md`](docs/web.md)** en est une autre, et elle part du même schéma : le site,
l'iPhone est la poche et le web est le bureau, ce que le partage d'une fiche ouvre, et comment un
abonnement acheté d'un côté se reconnaît de l'autre. Rien n'y est implémenté non plus, mais trois
de ses décisions coûtent cher à changer après coup — l'identité de l'utilisateur au moment de
l'achat, la clé qui autorise les Edge Functions, et la place du compte dans le parcours.

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

L'**analyse des schémas** est le seul extra payant : jusqu'à 6 JPEG partent alors au modèle
de vision fal.ai. Ce n'est plus une case à cocher d'avance — cocher une option payante avant
de savoir si elle sert est une décision qu'on ne peut pas prendre, et l'écran la posait en
premier. Elle s'allume toute seule quand le texte extrait est trop mince, et l'échec la
propose comme sortie quand un scan n'a rien rendu d'exploitable.

Les anciens `.doc` binaires ne sont pas lus : exporte-les en `.docx` depuis Word.

**Un refus d'appareil photo est un refus.** La tuile « Scanner des pages » ne s'affiche que
si l'iPhone sait scanner *et* que la caméra n'a pas été refusée ou verrouillée par le
contrôle parental (`CameraAccess`). Le premier appui pose la question système, celle qui
porte `NSCameraUsageDescription` ; un « Refuser » fait disparaître la tuile au profit de la
photothèque, avec une ligne qui dit pourquoi et rappelle que les photos se lisent pareil.
Le scanner de VisionKit n'est **jamais** présenté sans autorisation : présenté à vide, il
affiche sa propre boîte « Camera Unavailable » et son bouton **Réglages**, c'est-à-dire le
renvoi vers les Réglages après un refus que la règle 5.1.1(iv) de l'App Store interdit — et
ce bouton appartient au contrôleur d'Apple, il ne s'enlève pas. Rien dans l'app n'ouvre les
Réglages, et la question n'est jamais posée deux fois. L'état se relit au retour
d'arrière-plan, de sorte que quelqu'un qui rouvre la caméra de lui-même retrouve la tuile
sans relancer l'app. `MicaboTests/CameraAccessTests.swift` verrouille la règle, dans les
cinq langues.

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

### Pour qui elle est écrite, et à quelle longueur

Le même chapitre de génétique ne s'écrit pas pareil pour un terminale et pour un PASS, et la
différence n'est pas une question de longueur : c'est le vocabulaire attendu, la profondeur des
mécanismes, et ce qu'un correcteur ira chercher. Le **stade d'étude** était demandé au deuxième
écran de l'inscription et ne servait qu'à cadrer le discours du parcours d'accueil ; il commande
maintenant la rédaction. `audienceBrief` (`supabase/functions/generate-course/prompt.ts`) traduit
les sept réponses de `StudyLevel` en consigne : programme du secondaire et attendus du bac pour
un lycéen, raisonnements complets et cas limites en prépa, densité, valeurs seuils et pièges de
QCM en santé, limites et débats du champ en master, plans de réponse et pièges classiques pour un
concours. Sans réponse connue, le modèle écrit pour un début de cursus supérieur et ne suppose
aucun prérequis que le document ne donne pas.

Le stade se corrige dans **Profil → Réglages → Tes études**, parce qu'on change d'année et
qu'une réponse donnée en trente secondes le premier jour ne doit pas se payer pendant deux ans.

La **longueur** se choisit au même endroit, et aussi sur l'écran d'import, juste avant le bouton
qui l'utilise : la réponse dépend du document qu'on vient de déposer.

Elle s'y règle au **curseur, et il est continu** : de huit à trente-quatre blocs, sans pas
déclaré. Il n'en avait que trois, et trois crans ne font pas un curseur — ils se comptent, se
visent, et ne se distinguent en rien de trois boutons sauf qu'ils sont plus durs à atteindre.
Le volume exact part maintenant dans la requête (`blocks`), et la fonction Edge le fait primer
sur les bornes du format : pousser le curseur de dix-huit à vingt-deux donne bien quatre blocs
de plus, et pas la même fiche « équilibrée » que la fois d'avant.

Le nom du format devient une **conséquence** — il dit dans quelle famille on vient de tomber —
et la durée de lecture affichée à côté bouge d'un cran à l'autre, y compris à l'intérieur d'une
famille. C'est ce qui fait qu'on sent le curseur travailler au lieu de le voir sauter. Les trois
familles restent la seule chose que la fonction Edge nomme, et la seule que le profil
synchronise :

| Format | Blocs demandés | Pour quoi |
| --- | --- | --- |
| L'essentiel | 8 à 12 | Se relit dans le couloir, cinq minutes avant l'épreuve |
| Équilibrée | 14 à 22 | Le format de référence : remplace la relecture du cours sans le recopier |
| Approfondie | 24 à 34 | Remplace le cours pour quelqu'un qui a manqué la séance |

Le volume ne vit plus dans le prompt système, qui renvoie à la consigne de longueur, et la
seconde tentative en cas d'échec suit le même format au lieu de retomber sur douze blocs
invariables. Un document long reste tenu à la borne basse : au-delà, la fiche ne se lirait plus.
« Refaire la fiche », dans le menu du cours, ouvre directement les trois longueurs, parce que
c'est en lisant une fiche qu'on la trouve trop courte, et le choix devient le réglage courant.

### Ce qu'est une fiche

Huit blocs, décrits par `Micabo/Models/CourseSheet.swift`, et pas un de plus. Chacun a un
rendu dessiné pour lui : c'est la seule façon de tenir une belle page, parce qu'un format
ouvert où le modèle inventerait ses propres structures donnerait une mise en page
différente à chaque cours.

| Bloc | Ce qu'il porte | Comment il est rendu |
| --- | --- | --- |
| `heading` | Titre de partie (niveau 1) ou de sous-partie | Filet court dans la teinte du cours, puis grand titre resserré |
| `paragraph` | Deux à quatre phrases rédigées | Corps 14,85 pt, interligne 6, posé à même l'ivoire |
| `definition` | Un terme et son sens | Bloc blanc, filet vertical dans la teinte du cours, terme en demi-gras |
| `callout` | `essentiel`, `attention`, `exemple` ou `astuce` | Fond assorti à l'intention, intitulé en capitales |
| `steps` | Un mécanisme dont l'ordre compte | Pastilles numérotées dans un bloc blanc |
| `table` | Une comparaison, 2 à 4 colonnes | Colonnes de largeur égale, en-tête teinté, filets entre les lignes |
| `chart` | Des valeurs comparables, même unité | Barres horizontales, valeur écrite en clair, ni axe ni grille |
| `formula` | Une formule qui se retient | Centrée sur fond ivoire, avec la légende de ses symboles |

La règle de composition tient en une phrase : **le texte est posé sur le papier, les objets
sont dans des surfaces.** Un paragraphe n'est pas une carte, et une fiche entièrement
encartée ne se lirait pas.

**Un objet n'en suit jamais un autre.** Six blocs sur huit sont des objets, et le modèle les
alignait : une définition, un encadré, un tableau, un graphe, collés les uns aux autres. Chaque
bloc était peut-être juste, mais la page se feuilletait au lieu de se lire, et on ne savait plus
ce qui répondait à quoi. Le prompt tient donc la forme d'une partie — le titre, un paragraphe
qui pose la notion, l'objet qui l'éclaire s'il y en a un, un paragraphe qui en tire la
conséquence — avec un objet pour deux paragraphes au plus, un seul encadré « essentiel » qui
ferme la fiche, un tableau seulement quand le document oppose vraiment deux choses, et un
graphe seulement quand la comparaison chiffrée est ce qu'il faut retenir.

Et comme une consigne se respecte à peu près là où un plafond se respecte toujours,
`normalizeSheet` écarte le troisième objet d'une file (`SHEET_LIMITS.objectRun`). Un titre ou
un paragraphe remet le compteur à zéro. L'encadré « essentiel » en est **exempté** : le prompt
lui demande de fermer la fiche, donc il arrive volontiers après deux objets, et un garde-fou qui
emporterait la seule chose qu'on avait exigée serait pire que le défaut qu'il corrige.

Le garde-fou est côté serveur, donc à la création : les fiches déjà en base gardent leur forme
jusqu'à ce qu'on demande « Refaire la fiche », parce que jeter un tableau d'une fiche
enregistrée serait perdre du contenu que l'étudiant a payé.

### Le réglage typographique

Tout vit dans `SheetTypography` : c'est ce qui permet de resserrer la page d'un cran sans
chasser des nombres dans six fichiers.

**Toute l'échelle a perdu un dixième**, corps comme titres. Réduire le corps seul aurait fait
grossir les titres par contraste : ce qui compte sur une page, c'est le rapport entre les
tailles, pas leur valeur absolue. Le corps passe donc de 16,5 à 14,85 pt, le titre de partie de
22 à 19,8, et un sous-titre vaut exactement la taille du corps — il se distingue par son poids
et par l'air au-dessus de lui, pas en grossissant.

**Les espaces verticaux ont baissé plus que ça** : interligne de 7,5 à 6, espace entre blocs de
15 à 11, air au-dessus d'un titre de partie de 26 à 20, marge intérieure d'un objet de 15 à 13.
Une fiche est une page dense par nature — on la relit la veille au soir — et le blanc qui aère
un écran d'accueil fait ici scroller pour rien.

### Le balisage en ligne

Cinq marques, et chacune a une raison d'exister sur une fiche de révision
(`Micabo/Services/SheetMarkup.swift`, porté en TypeScript dans `sheet/markup.ts`) :

| Écriture | Rendu | À quoi ça sert |
| --- | --- | --- |
| `**terme**` | gras | le mot que l'examen attend, un à trois par paragraphe, jamais zéro dans un paragraphe qui introduit une notion |
| `*nuance*` | italique | un mot étranger, un titre d'œuvre, une réserve, le terme voisin qu'on ne doit pas confondre : **cinq à dix passages** sur la fiche |
| `==l'essentiel==` | surligné en jaune | ce qu'on relit en dernier, **dix à vingt passages sur la fiche**, jamais deux dans le même paragraphe |
| `==menthe\|71 %==` | surligné en menthe | la même marque, dans l'une des cinq teintes du code couleur ci-dessous |
| `$E = mc^2$` | formule | composée par le moteur mathématique, comme sur les cartes |

**Le code couleur du surligneur.** Une couleur dit une *sorte* d'information, la même d'un bout
à l'autre d'une fiche : jaune la définition ou la thèse, menthe le chiffre et son unité, bleu le
mécanisme et ses conditions, rose l'exception et la confusion classique, lilas le repère (un
nom, une œuvre, une date). C'est ce qui permet de retrouver tous les chiffres d'un chapitre en
diagonale, et c'est la seule raison d'avoir cinq feutres plutôt qu'un. Le modèle marquait tout
en jaune, à charge pour l'étudiant de recolorer : personne ne recolore une fiche de soixante
blocs, et une page d'un seul feutre ne dit rien de plus qu'une page sans feutre. Il pose donc
les couleurs, et l'étudiant recolore par-dessus. Les cinq noms vivent dans `SHEET_HIGHLIGHTS`
et le code dans le prompt de `generate-course` ; un test du prompt compare les deux listes,
parce qu'une couleur inventée laisserait « framboise| » dans la phrase.

**La même fiche des deux côtés.** Le site et l'app appellent la même Edge Function, avec le
même prompt et les mêmes champs : `test/generation-parity.test.ts` relit le Swift et le
TypeScript et échoue si l'un envoie un champ que l'autre ignore. C'est ce qui s'était produit
avec les consignes libres de l'étudiant, envoyées par le site et pas par l'app.

**Le marquage se mesure, il ne se demande pas.** Le prompt réclame ces marques depuis
`course-v2.0.0` ; pendant des semaines, les fiches sortaient nues et personne ne savait où ça
cassait. Trois causes, trouvées en instrumentant plutôt qu'en réécrivant la consigne :

1. **Les seuils étaient comptés par paragraphe.** « Un à trois termes en gras par paragraphe »
   ne veut rien dire quand un paragraphe de mémo fait six cents caractères. Un cours court était
   correctement marqué, un document long ne l'était pas, et les deux respectaient la consigne à
   la lettre. Les seuils sont donc des densités : un gras tous les 250 caractères, un surlignage
   tous les 800, un italique tous les 2 000.
2. **La seconde passe recopiait.** Elle tourne quand la fiche porte moins de la moitié de ce que
   sa longueur appelle, et repose les marques sans droit de toucher au texte. Appelée sur
   Flash-Lite à température 0,1, elle rendait quinze textes sur quinze **inchangés** : recopier
   l'entrée était la réponse la plus probable. Flash à 0,4, par lots de six, avec « un texte
   rendu à l'identique est une erreur » et un exemple avant/après.
3. **La forme n'était pas vérifiée.** Un surligneur peut s'ouvrir au milieu d'un mot et se
   fermer deux cents caractères plus loin : au rendu c'est une bande de couleur sur trois
   phrases, et le contrôle qui comparait les textes *marques retirées* ne pouvait pas le voir.
   `mark-shape.ts` juge la pose - ouverture et fermeture au bord d'un mot, dans le même bloc, sur
   une longueur plausible - et retire les marqueurs fautifs sans toucher au texte.

Deux garde-fous encadrent la repasse, et ils sont la raison pour laquelle on peut laisser un
modèle repasser sur une fiche déjà écrite : un texte dont le contenu a bougé d'un caractère est
écarté, et un texte qui **perd** une marque l'est aussi. Le pire cas d'une repasse ratée est la
fiche d'avant. La réponse porte les compteurs de chaque étape (`meta.marks`, `meta.repaint`,
`meta.shape`) : c'est ce qui a permis de séparer les trois causes en trois appels au lieu de
trois déploiements à l'aveugle.

Mesuré après correction, six fiches, deux formats de document :

| | gras | densité | surlignages | italiques |
| --- | --- | --- | --- | --- |
| Mémo long (6 500 caractères) | 27 à 32 | un tous les 204 à 241 caractères | 4 à 7 | 2 à 3 |
| Chapitre court (3 200 caractères) | 13 à 21 | un tous les 152 à 251 caractères | 3 à 6 | 1 à 2 |

Avant : un gras tous les 770 caractères, deux surlignages malformés, aucun italique.

**Le surligneur est une bande jaune, et il a fait un aller-retour.** Un fond de texte posé par
TextKit prend toute la hauteur de la ligne, interligne compris : sur un paragraphe de fiche, où
l'interligne vaut près de la moitié du corps, la bande touchait celle de la ligne du dessus et
grossissait dès qu'une ligne portait un exposant. La marque est donc devenue de l'encre bleue
le temps d'une version — sauf qu'un passage bleu au milieu d'un paragraphe se lit comme un lien,
et le bleu est déjà l'accent de l'app. La bande est revenue, et le défaut est traité là où il
devait l'être : `SheetMarkerLayoutManager` la dessine à la **hauteur des capitales** de la
fonte du passage, ce qui lui donne la même épaisseur partout dans la fiche quelle que soit
l'interligne du paragraphe ; le web fait le même calcul avec un padding en `em`
(`.sheet-marker`). Le balisage n'a jamais bougé : `==` est écrit dans les fiches déjà en base.
L'encre du passage n'est pas touchée, ni son poids — une bande, une encre de couleur et du gras
sur le même passage, ça fait trois marques pour une intention.

La marque est forte, donc **elle reste comptée** : dix à vingt passages sur une fiche qui peut
aller à quatre-vingt-dix blocs, jamais deux dans le même paragraphe, plafond à vingt-quatre côté
serveur (`SHEET_LIMITS.highlights`, recopié à l'identique dans les trois clients). Une page
entièrement surlignée ne se relit pas mieux qu'une page nue.

**Elle a longtemps été absente des fiches, et c'était le prompt.** Il ne parlait de mise en
valeur qu'en plafonds — « cinq marques au maximum », « trois mots en gras c'est trois de trop »,
plus une consigne interdisant « les emphases partout » — et le modèle lisait l'ensemble comme un
ordre de sobriété : il n'en produisait aucune. Le prompt donne donc un plancher, et surtout
**où** marquer : la phrase d'enjeu du premier paragraphe, la phrase que l'étudiant devra
réciter dans chaque partie, le résultat chiffré qu'un correcteur attend, et l'encadré
« essentiel ».

**Le code n'ajoute plus de marque, il n'en retire que le surplus.** Il y a eu un plancher des
deux côtés — `ensureHighlights` sur le serveur, `SheetHighlighter` dans l'app — qui marquait
trois passages quand le modèle n'en avait marqué aucun. Le principe se défendait : une consigne
de mise en forme est la première chose qu'un modèle lâche quand il se concentre sur le contenu.
Le résultat, non : le code ne sait pas ce qui compte dans un cours, il savait seulement repérer
la première phrase de la bonne longueur, et une marque tombée sur la phrase d'à côté fait
réviser la phrase d'à côté. Les deux planchers sont partis. Reste le plafond de six, qui ne va
que dans un sens.

Hanken Grotesk n'embarque pas d'italique : elle est penchée à la main par une matrice de
fonte, ce qui reste préférable à un changement de famille en plein paragraphe.

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
dans une feuille qui cite le passage sélectionné avant même d'avoir répondu. Elle se termine sur
« En faire une carte » : ce qu'on vient de comprendre est exactement ce qu'on oubliera.

Un mot, une phrase, jusqu'à 600 caractères. En dessous de deux caractères, ou sans une seule
lettre, l'entrée n'apparaît pas : `SheetSelection` évite de dépenser un appel pour une
sélection attrapée par erreur.

### Ce qui empêche une fiche d'avoir l'air écrite par une IA

Le prompt de `supabase/functions/generate-course/prompt.ts` interdit nommément les tirets
cadratins, les listes à puces en série, les phrases de remplissage (« il est important de
noter que », « en effet », « en conclusion ») et les méta-commentaires sur le document.

Mais une consigne se respecte à peu près, alors que **les plafonds se respectent toujours** :
`supabase/functions/_shared/sheet.ts` limite les blocs d'étapes à deux par fiche, les passages
marqués à six, les objets qui se suivent à deux, les colonnes d'un tableau à quatre, et retire
les puces et les dièses de markdown qui ont fui hors de leur structure. Un garde-fou réglé sous
ce qu'on exige efface exactement ce qu'on vient de demander : chaque plafond suit donc le
prompt, dans les deux sens. `CourseSheet.sanitized()` refait le même travail côté application,
sur les fiches comme sur ce qu'un serveur plus ancien renvoie — à une exception près, la file
d'objets, qui n'est coupée qu'à la création : jeter un tableau d'une fiche déjà enregistrée
serait perdre du contenu que l'étudiant a payé.

Un bloc d'un type inconnu, un tableau à une seule colonne, un graphe à une seule barre ou
tout à zéro disparaissent au lieu de casser la page. Un bloc mal formé ne fait pas échouer la
fiche entière : c'est la différence entre une fiche à laquelle il manque un encadré et un
écran vide.

### Se méfier des mots mal lus

Un court écrit manuscrit parlait d'**abréaction**. L'OCR a lu « absraction », et le modèle en a
tiré une définition entière de l'abstraction : fausse, parfaitement crédible, et révisée telle
quelle pendant des semaines. C'est la faute la plus grave que Micabo puisse commettre, parce
qu'elle ne ressemble pas à une erreur.

Le prompt porte donc une section entière là-dessus, et elle ne demande pas de la prudence en
général :

- **vérifier qu'un terme existe avant de le définir**, et quand un mot inexistant ne diffère
  que d'une ou deux lettres d'un terme réel de la matière, écrire le terme réel ;
- retenir **le mot que le contexte réclame**, pas celui dont l'orthographe est la plus proche.
  « Absraction » est plus près d'« abstraction », qui existe pourtant ; c'est « abréaction »
  que le voisinage de « catharsis » et de « refoulement » impose ;
- **ne rien construire** sur un mot douteux quand le contexte ne tranche pas : pas de bloc
  `definition`, pas de phrase bâtie autour. Il n'apparaît simplement pas dans la fiche ;
- ne jamais signaler la correction dans la fiche, et ne jamais écrire « le texte semble
  dire ». On écrit ce qui est juste, ou on se tait.

La **provenance** du texte part avec lui, parce que les erreurs typiques d'une photo passée à
l'OCR (rn/m, l/i/1, accents perdus) ne sont pas celles d'une transcription de sous-titres
(noms propres, chiffres, ponctuation). Et un document de moins de 1 800 caractères reçoit un
avertissement de plus : il n'a aucune redondance pour rattraper une erreur de lecture, donc un
seul terme mal compris fausserait toute la fiche.

### Une fiche écrite pour une matière

Une fiche de philosophie sans auteurs ni œuvres n'est pas une fiche de philosophie, et une
fiche d'économie qui ne donne qu'une lecture d'un débat est fausse par omission. Ces exigences
ne peuvent pas vivre dans le prompt général : elles se contredisent d'une matière à l'autre, et
les empiler toutes ferait un prompt que le modèle survole.

`supabase/functions/_shared/discipline.ts` détecte donc la matière et n'ajoute **qu'une**
consigne :

| Matière | Ce que la fiche doit porter |
| --- | --- |
| Philosophie | Auteurs, œuvres, thèses ; les positions qui s'opposent ; thèse, argument, exemple distingués |
| Économie | Les écoles nommées, les visions qui s'opposent sur chaque controverse, le prérequis de première quand la notion en dépend |
| Droit | La source de chaque règle (article, code, arrêt), principe / conditions / exceptions, hiérarchie des normes |
| Santé | Nomenclature exacte, valeurs seuils, unités, confusions classiques et pièges de QCM |
| Histoire | Chaque fait avec sa date, causes et conséquences, le fait distingué de son interprétation |
| Maths | Chaque théorème avec ses hypothèses, démonstrations conservées, équivalence distinguée de l'implication |
| Physique-chimie | Unités partout, domaine de validité de chaque loi |
| SVT | L'échelle annoncée (molécule, cellule, organisme, écosystème) et jamais mélangée |
| Lettres | Les passages cités, les procédés nommés avec leur effet, l'œuvre située |
| Langues | Chaque terme dans sa langue suivi de sa traduction, genre et construction signalés |
| Informatique | Entrées, sorties, complexité ; les étapes en blocs `steps` |

La détection est côté serveur, et pas dans l'application, pour une raison : **à l'import, la
matière n'est pas encore connue**, c'est le modèle qui la trouve. On la devine donc sur le titre
et le début du texte, avec au moins deux mots-clés distincts — un seul rangerait un cours
d'histoire en économie parce qu'il parle de marchés. Quand l'application la connaît déjà, elle
l'envoie et c'est elle qui gagne, pour la fiche comme pour les cartes.

### Pour qui, et dans quel système scolaire

`audienceBrief` traduit le **stade d'étude** en consigne de rédaction, et le **pays de
scolarisation** en système de référence. Le second n'est pas une politesse : « les attendus du
bac » ne veut rien dire pour un lycéen belge, un étudiant québécois ne passe pas de concours de
première année de santé, et au Québec « baccalauréat » désigne un diplôme universitaire. Une
fiche qui renvoie à un examen qui n'existe pas là où on étudie perd sa raison d'être. Le pays
est la première question du parcours et se corrige dans les réglages ; sans réponse, la France
est supposée, ce que l'app faisait déjà en silence.

**Les deux consignes ont des domaines séparés, et il a fallu les y tenir.** Le registre décrit
une façon d'écrire et ne nomme aucune épreuve ; le pays nomme les épreuves et les diplômes.
Elles disaient « ce qui tombe au bac » et « PASS, LAS », ce qui, depuis que l'application
propose le Royaume-Uni et les États-Unis, arrivait collé à un « ne parle jamais du
baccalauréat » : le modèle recevait deux ordres contraires dans le même paragraphe. Une ligne
finale tranche désormais en faveur du pays.

La **langue** part avec, et en tête du message : `_shared/language.ts` porte la consigne, et
elle est placée avant le document parce qu'en queue, derrière soixante mille caractères, le
modèle la perd et retombe sur le français du prompt système. Les prompts système restent en
français — ce sont eux qui portent les règles, les noms de blocs et les exemples, et les
traduire doublerait la surface à maintenir pour la même consigne.

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

## Un paquet de cartes, sans cours

Tout partait d'un import, donc d'une fiche, et on ne pouvait pas simplement se faire un paquet
de vocabulaire, de dates ou de formules. C'est pourtant la moitié de ce qu'on révise : des
choses déjà comprises qu'il faut retenir, et pour lesquelles il n'y a aucun cours à ficher.

La feuille du « + » sépare donc deux blocs — cinq sources qui produisent une fiche, et un paquet
qui n'en produit pas. `CreateDeckView` ne demande que le nom, la matière si on veut, et un texte
facultatif : **collé**, il sert de matière aux premières cartes ; **vide**, le paquet s'ouvre nu
et se remplit à la main. Les deux mènent à l'écran des cartes, qui sait déjà ajouter, corriger,
masquer un schéma et générer.

Un paquet (`CourseSource.deck`) reste un cours pour tout le reste de l'app : il entre dans la
file du jour, dans les plans d'examen et dans les filtres de la liste. Deux choses seulement le
distinguent, et elles découlent de sa source : son écran ne promet pas une fiche qui ne viendra
jamais (`CourseSource.expectsSheet`), et « Générer avec l'IA » disparaît d'un paquet nu, où il ne
mènerait qu'à une erreur. Il n'a pas non plus d'empreinte : deux paquets du même nom ne sont pas
un doublon, puisque rien n'a été importé.

### Reprendre un paquet Anki

Le web ouvre la même porte (`/app/paquet`, `lib/actions/decks.ts`), et il en ouvre une seconde que
l'iPhone n'a pas : **un `.apkg` déposé dans la page**. C'est le seul import du produit qui ne
dépense rien — les cartes sont déjà écrites, il n'y a personne à faire rédiger — et c'est ce qui
permet d'arriver avec quatre ans de vocabulaire au lieu de recommencer.

Un `.apkg` est un ZIP dont la collection **est une base SQLite**. Le réflexe serait `sql.js`, donc
un mégaoctet et demi de WebAssembly pour exécuter des requêtes qu'on n'écrit pas : `lib/import/`
relit quatre tables entières, sans jointure et sans index, donc le format de fichier est lu à la
main (`sqlite.ts` : en-tête, `sqlite_master`, descente d'arbre B, pages de débordement, codage des
enregistrements). Une seule dépendance s'ajoute, `fzstd`, et seulement en import dynamique : Anki
moderne écrit `collection.anki21b`, compressé en zstd, et personne qui dépose un PDF n'a à payer
ce décodeur. Les deux schémas d'Anki sont lus - les paquets vivent dans un JSON de la table `col`
avant 2.1.28, dans une table `decks` après.

Ce qui **ne suit pas** est aussi un choix. Les intervalles d'Anki sortent de ses propres options de
paquet : recopiés ici, ils donneraient des échéances que la file d'étude ne sait pas expliquer, et
une carte due dans huit mois le jour de l'import. Tout repart neuf. Les médias non plus ne suivent
pas — une image d'Anki vit dans le ZIP sous un nom numéroté — donc les notes qui ne sont qu'une
image sont comptées et annoncées, plutôt que versées vides. Les textes à trous, eux, sont fidèles :
`{{c1::…}}` donne **une carte par numéro**, les autres trous découverts, exactement comme Anki, et
avec la graphie du blanc du produit (`ClozeGap`).

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
règle. `GenerateCardsSheet` s'ouvre sur **un compteur par format**, juste au-dessus du bouton
`Générer les cartes` qui les utilise, et le choix est retenu d'un cours à l'autre
(`QuestionQuotaPreferences`).

**Un nombre par format, et non un volume plus des interrupteurs.** Les interrupteurs disaient
« j'accepte des QCM » et laissaient le modèle décider combien : on demandait vingt cartes et on
en recevait deux à trous. Un étudiant qui prépare un contrôle sait ce qu'il veut travailler, et
il le commande à la carte près : cinq QCM et cinq textes à trou. Le quota (`QuestionQuota`) part
en clair dans la requête, la consigne le répète format par format, et la fonction **trie la
réponse par format** au lieu de garder les trente premières cartes venues. Un format réglé à
zéro n'apparaît pas du tout, et le total reste borné entre 3 et 30 : le bouton « plus » s'éteint
au plafond, plutôt que de rogner un format après validation. Les anciens réglages ne sont pas
perdus : le volume et les deux interrupteurs sont relus une dernière fois et répartis entre les
formats gardés.

Reste un rattrapage, et il est volontaire : quand un format est resté en deçà de sa commande, le
total est complété avec les cartes écartées au tri. Un QCM dont les propositions étaient
inexploitables est retombé en recto verso, et cette carte-là est juste ; renvoyer huit cartes au
lieu de douze parce que le modèle a mal compté serait payer son erreur deux fois.

**Les cartes sont écrites courtes.** Le prompt ouvre sur la concision plutôt que de la
mentionner en passant, et il la chiffre : quinze mots au recto, vingt au verso, une seule idée
par carte, pas de reprise de la question dans la réponse, pas de « il s'agit de ». Une carte se
répond de mémoire en trois secondes ; une carte bavarde se relit, ce qui n'est pas la même chose
et n'apprend rien.

`CardGeneration` est le seul chemin d'écriture des cartes, qu'on parte de la fiche ou de
l'écran des cartes : c'est là que vivent le repli hors ligne et la création automatique des
cartes inverses pour les cours de langue. Deux écrans qui écriraient chacun leur version
finiraient par ne plus produire les mêmes cartes.

Un format annoncé qui ne tient pas debout **retombe sur le recto verso** plutôt que de casser
l'écran : texte à trou sans trou, QCM à une seule proposition ou dont aucune ne correspond à la
réponse, occlusion sans image. La question et la réponse restent bonnes, donc la carte n'est
jamais jetée. `Flashcard.format` porte cette règle, et c'est elle que l'interface consulte —
`kind` dit ce qui était voulu, `format` ce qui est affichable.

### Les écritures scientifiques

Les formules s'écrivent en LaTeX entre `$…$`, et le bloc `formula` d'une fiche en porte une
seule, sans délimiteurs. **Elles sont composées pour de vrai** : SwiftMath sur l'iPhone
(`MathTypesetter`, `MathFormula`), KaTeX sur le web (`lib/math/typeset`). Une fraction a une
barre et deux étages, une somme met ses bornes au-dessus et en dessous de son signe, une
matrice a ses parenthèses à la bonne hauteur.

**La transposition Unicode reste le plancher.** `FormulaRenderer` sur l'iPhone et
`latexToUnicode` dans `@micabo/core` transforment `x^2` en « x² » et `\frac{a}{b}` en « a/b ».
Ce n'est plus le rendu ordinaire, c'est le filet : une fiche est écrite par un modèle, donc du
LaTeX incomplet arrivera, et le choix est alors entre un cadre vide et une formule un peu
moins belle.

| Où | iPhone | Web |
| --- | --- | --- |
| Bloc `formula` d'une fiche | composé, mode display | composé, mode display |
| Une carte qui **est** une formule | composé | composé |
| Une formule prise dans une phrase | transposée en Unicode | composée en ligne |

La dernière ligne est la seule différence de rendu assumée entre les deux plateformes, et elle
tient à une contrainte de SwiftUI : un paragraphe de fiche est composé en une seule suite de
fragments dans un `UITextView`, ce qui donne la sélection du système et « Expliquer ». Une
formule composée est une **vue**, pas un fragment de texte : l'insérer voudrait dire hacher le
paragraphe en morceaux empilés et perdre la sélection continue. Une phrase en trois morceaux
se lit moins bien qu'un `x²`.

Côté iPhone, tout ce qui touche au moteur passe par `MathTypesetter`, derrière
`#if canImport(SwiftMath)` : le dépôt compile avec ou sans le paquet résolu, comme pour
RevenueCat. Sans lui, le produit garde exactement le rendu d'avant.

### Les paquets sont épinglés dans le dépôt

`Micabo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` est **versionné**,
et il doit le rester. La machine de construction résout les dépendances avec la résolution
automatique coupée : sans ce fichier, elle s'arrête sur « a resolved file is required », en
nommant les paquets qu'elle aurait dû aller chercher elle-même.

C'est aussi ce qui rend une construction reproductible : deux constructions du même commit
prennent la même révision de RevenueCat, et une version publiée un mardi ne change pas de
dépendance parce qu'un mainteneur a poussé un correctif le mercredi. Le fichier se met à jour
depuis Xcode - **Fichier > Paquets > Mettre à jour vers les dernières versions** - et le
résultat se commite comme du code.

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
compte à rebours. **Cette rangée est toujours là**, même sans un seul cours. Elle
n'apparaissait qu'une fois qu'il y avait des cartes, au motif que planifier ne mène à rien
sans elles : c'était confondre une fonctionnalité qui ne s'applique pas encore avec une
fonctionnalité qui n'existe pas, et une entrée d'accueil qui n'apparaît qu'après un import ne
s'apprend pas — on ne découvre pas ce qu'on n'a jamais vu.

La page sait donc se présenter à vide, et elle distingue les deux situations. Sans cours, elle
propose d'en importer un et ouvre l'import. Avec des cours mais sans carte, elle renvoie à la
génération : ce n'est pas un deuxième cours qu'il faut. Dans les deux cas son bouton du bas
disparaît, parce qu'il menait à une feuille qu'on ne pouvait pas confirmer — la confirmation
demande au moins une carte active, donc la page compte les cartes, comme la feuille, et non
les cours.

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

`Micabo/SRS/SM2Scheduler.swift` implémente le SM-2 **legacy** d'Anki, réglages par défaut :

- paliers d'apprentissage `1 10`, réapprentissage `10`
- Again / Hard / Good / Easy sur une neuve : 1 min, 6 min, 10 min, 4 j
- Good n'est diplômé qu'après le dernier palier (1 jour)
- facilité de départ 2,5, plancher 1,3, bonus « Facile » 1,3, multiplicateur « Difficile » 1,2
- une rechute coûte 0,20 de facilité et renvoie la carte en réapprentissage à 10 min
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
- **Chaque note annonce quand la carte revient** — sous « À revoir », « Difficile », « Correct »
  et « Facile », le délai que la note programme : `1 min`, `6 min`, `10 min`, `4 j` sur une neuve. Il manquait, et
  c'était le principal reproche fait à la session : on notait sans savoir si la carte revenait
  dans dix minutes ou le mois prochain, donc sans pouvoir arbitrer entre « difficile » et
  « correct ». Anki l'affiche depuis toujours, pour la même raison. Les libellés viennent du
  planificateur lui-même (`SM2Scheduler.previewLabels`), **date d'examen comprise** : un bouton
  qui annoncerait trois semaines alors que la carte reviendra avant le jour J mentirait. En
  entraînement libre, où rien ne bouge, les boutons se contentent de leur libellé.
- **Entraînement libre** — `StudyMode.practice` révise un cours entier sans toucher au
  planning : aucune échéance déplacée, aucun journal écrit, rien à reprendre. L'écran l'annonce
  en permanence (« Entraînement libre · ton planning n'est pas modifié ») et une carte ratée
  revient dans le tour. C'est l'action proposée quand un cours n'a rien à réviser.

### Le bilan de fin de session

Trois chiffres en tenaient lieu : « acquises », « à revoir », « réussite ». Le premier rangeait
« difficile » avec « facile », c'est-à-dire effaçait la distinction qu'on venait de faire carte
par carte ; le troisième était le premier moins le second en pourcentage, donc la même
information une troisième fois. Et rien ne répondait à la question qu'on se pose en refermant
l'app : **est-ce que c'est fini ?**

L'écran répond maintenant dans cet ordre :

1. **la répartition des quatre notes**, une barre par note, dans les couleurs des boutons qu'on
   vient d'appuyer. Elles sont publiées par `GradeButtons` : deux échelles de couleurs pour les
   mêmes quatre notes finiraient par ne plus se répondre. Une note jamais donnée n'a pas de
   ligne, parce qu'une liste de zéros ne dit rien ;
2. **ce que la session a produit** : les cartes passées en révision (`graduatedCount`), le taux
   de réussite, le temps passé ;
3. **quand ça revient** : le délai avant la première carte, et combien repassent aujourd'hui.
   Trois cartes qui reviennent dans dix minutes ne terminent pas une session de la même façon
   que tout ce qui repart à quatre jours.

L'annulation rend ce détail comme elle rendait les deux compteurs. Et une sauvegarde de session
écrite avant que ce détail existe se reprend toujours : ses deux chiffres suffisent, et tout ce
qui n'était pas « à revoir » y devient « correct ».

**Il se construit sous les yeux.** C'est le seul écran de récompense de l'app, et il tombait
d'un bloc, chiffres finaux compris : vingt minutes de travail s'affichaient comme une facture.
Les nombres partent de zéro et montent, les barres se remplissent en cascade, la pastille
grandit en entrant, et les impulsions haptiques suivent la montée des chiffres — le même geste
que la projection du parcours d'accueil. Tout est posé en une seconde, parce qu'un bilan qui se
fait attendre est un bilan qu'on quitte avant la fin ; la durée, elle, ne compte pas, parce
qu'un « 12 min » qui monterait de zéro se lirait comme un chronomètre qui tourne encore. Et
l'animation ne se rejoue pas : un chiffre qui remonte à chaque retour sur l'écran cesse d'être
une récompense pour devenir un décor.

### Ce qu'une note écrit, et quand

**Une note ne touche pas le disque.** Chacune enregistrait : un `save()` SwiftData, donc une
transaction SQLite, sur le fil principal, à l'intérieur du bloc d'animation qui faisait entrer
la carte suivante — l'animation ne pouvait pas commencer avant la fin de l'écriture. Et le
`save()` coûtait deux fois, la seconde étant la plus lourde : il publie les changements au
contexte, donc les **trois pages d'onglets rafraîchissent leurs requêtes** — elles restent
montées toutes les trois — et chacune recompte ses séries, ses files et ses histogrammes sur
tout l'historique. Quatre notes par seconde déclenchaient douze recalculs.

Les actions s'accumulent donc en mémoire et partent par paquets de cinq, posés après l'image
plutôt que dedans. Le risque est borné et se répare seul : une app tuée au milieu d'un paquet
perd ses notes, et les cartes concernées se retrouvent simplement dues à la prochaine session.
La fin de la file, la sortie de session et le passage en arrière-plan forcent l'écriture, ce qui
couvre tous les cas où l'on quitte pour de bon. L'instantané de la file, lui, reste écrit à
chaque note : c'est un petit JSON dans les réglages.

Les ressorts sont partis avec. Un ressort dépasse sa cible puis y revient, et sur le geste le
plus répété de l'app ce retour se sent comme un retard : on voyait la carte suivante s'installer
pendant presque une demi-seconde après avoir appuyé. `StudyMotion` tient les deux courbes qui
restent, courtes et monotones comme celles du parcours d'accueil, et la carte sortante s'efface
en reculant pendant que l'entrante arrive du bas — un changement d'identité sans transition ne
donnait qu'un fondu, et un fondu ne dit pas qu'on a avancé d'une carte.

`MicaboTests/StudySessionTests.swift` verrouille l'annulation, l'entraînement libre, la reprise,
le détail des notes et l'échéance annoncée.

### Le rythme quotidien commande la charge

`Micabo/SRS/DailyLoad.swift` fait le lien entre le temps que l'utilisateur s'accorde et ce que
l'app lui sert — sans ce lien, le curseur de l'onboarding ne serait qu'un décor.

- le curseur va de **5 min à 2 h**, par paliers de 5 minutes jusqu'à la demi-heure puis de
  15 minutes au-delà (il glisse sur les paliers, pas sur les minutes)
- il est posé **à même le fond, sans bloc autour**. Il vivait dans une carte blanche, avec sa
  conséquence dans un second encadré juste dessous : deux cadres empilés pour la seule commande
  de l'écran, et un grand nombre enfermé dans une boîte se lit comme la valeur d'un formulaire
  plutôt que comme une décision qu'on prend. Sa teinte suit du même coup la règle de la
  palette : le menthe vif tenait sur le blanc du bloc, mais sur le crème un filet de quatre
  points dans cette teinte ne se distingue plus de sa piste
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

## Les langues de l'app

Cinq : **anglais, français, allemand, espagnol, turc.** Elles se choisissent dans les
réglages et au premier écran du parcours, et le choix vit dans `UserDefaults` sous
`micabo.ui_locale` — le même contrat que le cookie du site, à ceci près que les deux clients
ne se synchronisent pas encore.

C'est la **langue de l'interface**, et pas celle des fiches. Une fiche écrite en allemand le
reste quand l'app passe en anglais : `ContentLanguage` se déduit du pays de scolarisation, et
elle se décide à l'import.

Deux catalogues, et la frontière est nette :

| Table | Où | Ce qu'elle porte |
| --- | --- | --- |
| `SharedI18nCatalogs` | `Services/I18n/Generated/` | Les clés communes au site et à l'iPhone. **Générée**, jamais éditée à la main. |
| `IosI18nCatalogs` | `Services/I18n/` | Ce qui n'existe que sur le téléphone : le parcours d'accueil, l'import, les pannes du cloud. Écrite à la main, dans les cinq langues. |

La table partagée se régénère depuis `web/lib/i18n/catalogs` :

```bash
node --experimental-strip-types --import ./scripts/ts-extensions.mjs \
  scripts/export-i18n-catalogs.ts
```

**Le repli est le piège, pas la clé manquante.** `L10n.t` cherche la clé dans la table iOS de
la langue, puis dans la table partagée, puis dans le français — et rend donc toujours *une*
phrase. Une app à moitié traduite ne plante pas : elle bascule de langue au milieu d'un
écran, et personne ne le voit passer en revue de code. C'est pourquoi trois tests tiennent la
table plutôt qu'un : `testIosCatalogsHaveTheSameKeys` vérifie que les cinq tables ont les
mêmes clés, `testNothingFallsBackToFrench` et `testSharedCatalogIsNotFrenchInEnglish` que
l'anglais n'est pas le français recopié. La parité des clés prouve qu'une entrée existe ;
elle ne prouve pas qu'elle a été traduite.

**Un écran n'écrit jamais sa propre phrase de repli.** `@Environment(UiLocaleStore.self)`
rend un optionnel, et il est nil pour de bon : une barre d'outils posée dans un
`UIHostingController` n'hérite pas de l'environnement SwiftUI de l'écran qui la présente.
Chaque appel portait donc son repli écrit à la main — `i18n?.t("app.common.delete") ??
"Supprimer"` — quatre cent cinquante-huit fois, en français. L'extension sur
`Optional<UiLocaleStore>` répond à sa place : `i18n.t("app.common.delete")` rend la langue
résolue, store ou pas. `testTheOptionalStoreStillSpeaksTheChosenLanguage` le vérifie sans
store du tout.

Trois choses **ne se traduisent pas**, et c'est délibéré :

- **les paliers d'études d'un pays**, écrits dans la langue du pays. Un lycéen polonais
  cherche « Liceum », pas « Lycée » — même règle que pour « A-Levels » ou « Cégep ». Seuls
  les paliers francophones passent par le catalogue, parce qu'un lecteur anglophone qui étudie
  en France lit « Lycée » sans avoir à deviner ;
- **les matières stockées**, qui restent le français du catalogue. `SubjectDisplay` traduit à
  l'affichage ; la valeur enregistrée, elle, ne bouge jamais, sinon un cours changerait de
  matière en changeant de langue ;
- **les noms propres** : « Micabo », « PASS », « LaTeX », les prénoms des témoignages.

Les pays, eux, suivent l'app et non le téléphone : `WorldCountries` construit sa liste depuis
les régions ISO avec la locale **choisie dans Micabo**, parce qu'un lecteur qui a mis l'app en
anglais tape « Brazil », pas « Brésil ».

**Une seule copie échappe au catalogue** : les quatre phrases d'autorisation (appareil photo,
photothèque, micro, dictée). iOS les affiche lui-même, avant qu'une ligne de Swift ne tourne,
et il les lit dans `Micabo/Resources/<langue>.lproj/InfoPlist.strings`. Elles suivent donc la
langue du **téléphone**, pas le sélecteur de l'app — c'est iOS qui décide, et rien dans le
bundle ne peut le lui faire changer d'avis. `Info.plist` garde la version française, qui sert
de repli quand le téléphone ne parle aucune des cinq.

## Structure

```
Micabo/
  App/             point d'entrée, conteneur SwiftData, compte et synchro
  DesignSystem/    jetons de style, lexique et composants réutilisables
  Models/          entités SwiftData, fiche d'un cours, examens et réponses de l'IA
  Persistence/     enregistrement des cours et des examens
  SRS/             planificateur SM-2, file d'attente, mode examen, statistiques
  Services/        client IA, balisage et mise en avant de la fiche, PDF / OCR / DOCX / YouTube
    Auth/          session, trousseau, Apple et OAuth
    Cloud/         PostgREST, lignes transportées, synchronisation
  Features/        un dossier par écran, dont Course/ et Exams/
supabase/functions/  Edge Functions Deno
supabase/migrations/ schéma Postgres, règles de cloisonnement comprises
docs/                configuration OAuth, note sur la donnée
```

## Tests

`MicaboTests/CourseSheetTests.swift` verrouille la fiche : le balisage en ligne et ses cas
limites, le décodage tolérant, le nettoyage, la marque garantie et son rendu en couleur,
l'aplatissement vers le
contexte des cartes, la fiche hors ligne et ce qui vaut une sélection.

`supabase/functions/_shared/sheet.test.ts` verrouille les mêmes garde-fous côté serveur : le
plafond des marques, leur plancher, le choix du passage, les blocs qu'elles ne touchent jamais,
et la file d'objets qu'on écarte.
`discipline.test.ts` verrouille la détection de matière, y compris ce qu'elle refuse de trancher
sur un seul mot-clé.

Les Edge Functions se vérifient d'un coup, **avant tout déploiement** :

```bash
cd supabase/functions && deno task verify
```

`MicaboTests/YouTubeImportTests.swift` verrouille l'import vidéo : les formes de lien
acceptées et refusées, **les cinq phrases de refus au mot près**, la traduction des codes du
serveur, le choix de la piste de sous-titres et ce que l'aperçu décide sans rien télécharger.

`MicaboTests/ExamPlannerTests.swift` verrouille le mode examen : l'échelle de passages et ses
cas limites, les quatre chiffres de la projection, la réversibilité d'une replanification, le
plafond d'intervalle et la levée du plafond de cartes neuves.

`MicaboTests/I18nTests.swift` verrouille les cinq langues : la parité des clés entre les
tables, l'absence de repli sur le français, le branchement de chaque code dans
`table(for:)`, les noms de pays, les matières, et le compte à rebours de l'offre — qui se
compose au lieu de s'écrire, parce que le turc pose le signe du pourcentage devant le nombre.
Les tests tournent **en français** (`language = "fr"` dans le schéma) : leurs attentes sont
écrites en français, et un simulateur en anglais ferait rendre « Untitled course » là où le
test attend « Cours sans titre ».

`MicaboTests/CameraAccessTests.swift` verrouille la seule règle de l'appareil photo : une
caméra refusée, ou verrouillée par le contrôle parental, n'ouvre plus le scanner — c'est ce
qui empêche VisionKit d'afficher sa boîte « Camera Unavailable » et sa porte vers les
Réglages, que l'App Store a refusée au titre de la règle 5.1.1(iv). Le test vérifie aussi
que la ligne de repli n'envoie personne dans les Réglages, dans les cinq langues.

`MicaboTests/AuthAndSyncTests.swift` verrouille les comptes et la synchro sur des charges
utiles GoTrue réelles : le décodage d'une session, l'échéance calculée à la réception, le nom
trouvé quel que soit le nom que le fournisseur donne au champ, et surtout **la fiche qui
traverse la synchro sans être touchée**. Ce dernier test est celui à ne pas laisser tomber : si
la fiche se dégrade d'un aller-retour à l'autre, personne ne le voit avant des semaines.

```bash
xcodebuild test -project Micabo.xcodeproj -scheme Micabo -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Quel commit tourne sur ce téléphone

**Réglages → À propos → Version.** La ligne porte `1.1 (12)` et, dessous, sept caractères :
le commit d'où vient le binaire. Ils se comparent à `git log --oneline -1 origin/main` sans
discuter.

`dev` veut dire construction locale. Sur une construction Xcode Cloud, c'est
`ci_scripts/ci_post_clone.sh` qui grave `CI_COMMIT` dans `Info.plist`.

**Le numéro de build ne se décide pas dans le dépôt.** Xcode Cloud impose son propre
compteur, qui part de 1 à la première construction du flux et monte d'une unité à chaque
suivante : c'est ce nombre-là que TestFlight et l'App Store affichent, quoi que dise
`CURRENT_PROJECT_VERSION`. Le réglage du dépôt ne sert donc plus qu'aux archives faites à la
main, et rien ne demande de le monter à chaque lot.

Le seul cas qui demande une intervention est la collision — « The bundle version must be higher
than the previously uploaded version », quand d'anciens téléversements occupent déjà les petits
numéros. Elle se règle dans App Store Connect : onglet Xcode Cloud → Réglages → Build Number →
Next Build Number, avec le rôle Admin ou App Manager. `ci_scripts/ci_post_clone.sh` raconte la
tentative qui a échoué avant, celle qui patchait `CURRENT_PROJECT_VERSION` avant la
construction.

Cette ligne existe parce que la question s'est posée et que personne ne pouvait y répondre :
`MARKETING_VERSION` ne bouge pas d'un lot à l'autre, et un numéro de build est un compteur qui
ne nomme aucun code. Deux binaires très différents s'annonçaient tous les deux « 0.1.0 ».
