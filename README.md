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
| Réviser | Écran d'ouverture : les cartes à réviser aujourd'hui dans une carte unique — le chiffre, la durée, la barre de composition et sa légende — puis les cours au programme et le prochain examen. Rien d'autre : ni salutation, ni date, ni liste de cours, ni bouton d'import |
| Profil | Statistiques, amis — demandes, liste, profil d'un ami et ses cours — et réglages |

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
Le parcours est **strictement linéaire** : chaque écran pousse le suivant, il n'y a ni retour
arrière ni balayage. Les étapes sont décrites par `OnboardingStep` et rendues par
`Micabo/Features/Onboarding/Steps/`.

| Bloc | Écrans |
| --- | --- |
| Accroche | bienvenue, pays de scolarisation, stade d'étude, annonce des questions |
| Questions | objectifs (plusieurs réponses), rapport à l'oubli |
| Démonstration | courbe de mémorisation, puis dépôt → fiche → révisions en trois écrans, puis le mode examen |
| Personnalisation | matières, établissement (avec « Passer »), temps quotidien |
| Sortie | projection annuelle, génération du parcours, preuve sociale, passage de relais, connexion, essai de 3 jours, paywall |

**L'écran des rappels a été retiré.** « On te rappelle au bon moment » proposait d'activer les
notifications sans rien demander au système : il notait une intention que personne ne lisait
ensuite, et il la posait juste avant l'écran qui construit le parcours — donc au moment où l'on
est le plus près d'entrer dans l'app. Une autorisation se demande quand elle sert, la première
fois qu'il y a des cartes à rappeler. Sa clé de réglage reste listée dans
`OnboardingPreferences.Key` pour que la remise à zéro sache encore l'effacer sur les appareils
qui ont fait l'ancien parcours.

**La note se demande sur la preuve sociale**, et nulle part ailleurs : l'écran montre des avis
et cinq étoiles, donc la demande du système arrive dans son sujet plutôt qu'au milieu d'une
révision. Elle part au premier changement d'avis — à l'ouverture, l'alerte couvrirait l'écran
avant qu'on ait vu ce qu'il raconte — et un drapeau la garde unique : le système plafonne déjà à
trois demandes par an, mais il les compte même quand il choisit de ne rien afficher.

**Le pays passe avant le stade d'étude**, et l'ordre est le fond de l'affaire : ce sont les
paliers du pays choisi qui deviennent les réponses de « tu en es où ? ». Dans l'autre sens, il
fallait servir les mêmes sept réponses françaises à tout le monde — Lycée, Prépa, Licence,
PASS, Master, Concours — ce qui ne laissait aucune réponse juste à un Américain, un
Britannique ou un Québécois. `EducationStage` porte les paliers réels de chaque pays, et un
pays qu'on ne connaît pas retombe sur une échelle générique en anglais plutôt que sur des
paliers inventés.

Chaque palier porte deux clés qui ne servent pas à la même chose : son `level`, le **registre
de rédaction** envoyé à l'Edge Function, volontairement grossier parce qu'un cégep québécois et
un lycée français demandent la même écriture ; et son `tier`, la **marche sur une échelle
comparable d'un pays à l'autre**, qui sert à retrouver l'équivalent quand on change de pays.
Le registre ne pouvait pas s'en charger : un lycéen et un collégien le partagent, et chercher
par registre ramenait un lycéen français en « Middle school » dès qu'il passait aux
États-Unis. Sans équivalent exact, on prend la marche la plus proche en montant ; la santé et
les concours ne sont pas des marches et ne se convertissent jamais.

Deux écrans offrent une échappatoire, posée en haut à droite sur la ligne du sur-titre
(`OnboardingSkip`) : l'établissement, parce que le demander à quelqu'un qui n'en a pas, qui est
entre deux écoles ou qui n'a pas envie de le dire ne doit pas fermer le parcours — passer laisse
le champ vide **et l'écrit** ; et la connexion, par un « Skip » temporaire qui referme aussi la
porte du compte pour que l'app ne repose pas la question à l'écran suivant.

Les réponses sont gardées en local (`OnboardingPreferences`), et trois d'entre elles pèsent sur
le reste de l'app : le temps quotidien commande le plafond de cartes neuves, le **stade
d'étude** commande la rédaction des fiches, et le **pays** commande à la fois le système
scolaire de référence et la **langue** dans laquelle Micabo écrit. Toutes se corrigent dans les
réglages, où le pays est posé au-dessus du stade pour la même raison que dans le parcours.

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
  pictogrammes au lieu des réponses. `OnboardingChoiceRow` garde un emoji à même la ligne,
  sans fond ni cadre : un point d'accroche, pas une tuile.
- **les réponses tassées en haut de la page.** Sur un écran de question, les réponses *sont*
  le contenu : les serrer sous le titre laisse les deux tiers de l'écran vides en dessous et
  fait lire un formulaire. `expandsContent` sur `OnboardingScaffold` et
  `OnboardingAnswerList` leur donnent la page entière, à hauteur égale entre elles.
- **l'écran de la langue, en entier.** Il annonçait « Micabo parle français » avec une seule
  réponse, cochée d'avance : un écran complet pour une information, et une question dont on ne
  pouvait pas changer la réponse. La langue se déduit du pays de scolarisation, et se lit sous
  ses pastilles, à côté du système scolaire retenu — là où elle est la conséquence d'un choix
  qu'on vient de faire.
- **l'avancement automatique après le chargement.** L'écran de génération enchaînait tout seul
  six dixièmes de seconde après son dernier coche : le seul moment du parcours où l'on attend
  quelque chose se terminait par un écran arraché sous les yeux, avant qu'on ait pu lire « ton
  parcours est prêt ». Le bouton occupe sa place depuis le début, éteint, et c'est l'étudiant
  qui appuie.
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
| Dépôt | glisser la page dans la zone en pointillés | La page est **volontairement brute** : un mur de texte sans hiérarchie, titre noyé au milieu, tel qu'on reçoit un polycopié. Sans un vrai avant, l'écran suivant ne transforme rien. Elle passe **au-dessus** de la zone de dépôt, jamais dessous : un document qu'on fait glisser sous sa cible se lit comme un document qu'on perd. Une **flèche coule entre les deux** — trois chevrons qui descendent en cascade — parce que la page qui respirait sur place disait qu'il fallait la toucher, pas où l'emmener ; elle s'efface dès que le doigt prend le relais. La zone fait la moitié de la hauteur de la page : une bande de la hauteur d'un bouton se lit comme un bouton, pas comme un endroit où poser un document. Après deux secondes sans geste la page respire, et un simple appui fait la même chose. |
| Fiche | aucun | Le balayage de lecture passe sur la page brute, puis la fiche **s'écrit par-dessus, bloc par bloc** : le filet de titre, le paragraphe, la définition, le passage en couleur, le schéma. Les deux états occupent la même place, ce qui fait lire une transformation et non deux illustrations. La page est **au milieu de l'écran** : calée sous le titre avec un tiers d'écran blanc sous elle, elle se lisait comme l'illustration d'un paragraphe plutôt que comme le sujet de l'écran. Le bouton dit « S'entraîner », et c'est le seul du parcours qui brille et respire. |
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

**Les réponses portent un emoji, et les questions s'écrivent mot à mot.** Les tuiles pastel qui
vivaient à gauche des réponses ont été retirées à juste titre, elles faisaient lire des
pictogrammes au lieu des réponses ; un emoji posé à même la ligne, sans fond ni cadre, donne un
point d'accroche sans rien remplacer, et une liste de réponses scolaires cesse de ressembler à
un formulaire. Le titre des cinq écrans de question s'écrit ensuite mot à mot
(`OnboardingScaffold(animatesTitle:)`) : l'animation dure exactement le temps de lire la
question, et donne au parcours le rythme d'une conversation. Les écrans de démonstration en
sont exclus, parce que le regard doit y aller au contenu.

Trois règles valent pour tout le tunnel :

- **la jauge est unique** — même barre du premier écran au paywall, sans jamais disparaître,
  et toujours le vert vif de `MicaboColor.progress`. Elle ne s'inverse (`MicaboColor.onInk`) que
  sur les fonds sombres, où un vert posé sur le vert ne se verrait plus. Tout ce qui indique
  une progression ailleurs dans l'app (session de révision, anneaux, curseurs, indicateurs
  d'attente) prend cette couleur.
- **aucun bouton ne reste muet** — l'enfoncement (échelle 0,975) part en 80 ms, et un bouton
  derrière lequel tourne une opération passe en état chargement, annonce ce qu'il fait et
  refuse les appuis suivants.
- **deux écrans voisins ne se ressemblent pas** — les compositions alternent (paquet de cartes,
  pastilles, liste, graphe, calendrier, curseur, carrousel), et **trois écrans seulement**
  quittent le crème : l'accroche sur la sauge, la génération du parcours sur le menthe, le
  passage de relais sur l'encre. La variété d'un parcours ne vient pas de ses fonds mais de ce
  qu'il y a à regarder. Le texte reste **fer à gauche** partout et le bouton **collé au bas de
  la zone sûre**.
- **le noir ne sert qu'une fois.** L'accroche était un aplat d'encre : c'est le contraste
  maximal de l'app posé avant qu'on ait quoi que ce soit à lire, ça donne le ton d'un outil de
  développeur là où Micabo est une app d'école, et ça oblige tout le reste du parcours à se
  lire comme un repli dès le deuxième écran. Elle est sur la **sauge**
  (`MicaboColor.canvasSage`), le crème de l'app teinté du vert du logo : assez discrète pour
  que le passage à l'écran suivant ne se voie pas, assez teintée pour ne pas passer pour un
  gris sale. Reste un seul écran d'encre, le passage de relais, le seul moment où le parcours
  s'arrête de montrer pour s'adresser à quelqu'un.

`OnboardingStep.surface` est la seule source de vérité sur ce point, et `OnboardingScaffold`
porte la bascule : `surface:` change le fond, la couleur des textes, celle du bouton (clair sur
fond sombre) et le fondu de la barre du bas. Les écrans hors scaffold lisent la même valeur
depuis leur étape et la reposent dans `\.onboardingSurface`.

**Le haut de l'écran suit la couleur de l'écran.** Le fond de l'étape monte jusqu'en haut de la
zone d'état : la jauge, l'heure et la batterie reposent sur l'encre quand l'écran est sombre, sur
le vert quand il est vert, jamais sur une bande crème rapportée. Le thème clair est donc posé
par `RootView` sur l'app elle-même, pas au-dessus du parcours : celui-ci passe en sombre le temps
de son écran d'encre pour que l'heure du téléphone reste lisible.

### La génération du parcours, et ce qui vient après

L'écran de génération est le seul en vert pleine page. Il tient en trois bandes qui ne bougent
plus une fois posées — l'accroche en haut sur une hauteur réservée d'avance, l'anneau au
centre, les quatre étapes en bas — parce que sa version précédente empilait tout en haut de
l'écran et changeait de hauteur à chaque phrase, si bien que l'écran tremblait pendant qu'il
travaillait. L'anneau fait son tour pendant que le pourcentage compte image par image : deux
façons de dire la même chose, et c'est la seule chose que cet écran a à dire.

**Il dure cinq secondes, et c'est un plancher verrouillé par un test**
(`PersonalizingStepView.duration`). Un écran qui annonce qu'il construit un parcours puis
disparaît en une seconde n'a rien construit : on ne lit ni ce qu'il dit ni ce qu'il coche, et
la promesse du parcours personnalisé passe pour du décor.

**La fin ne se saute pas d'elle-même.** L'écran enchaînait tout seul six dixièmes de seconde
après son dernier coche : le seul moment du parcours où l'on ait attendu quelque chose se
terminait par un écran arraché sous les yeux, avant qu'on ait pu lire « ton parcours est prêt ».
C'est l'étudiant qui appuie, et le bouton occupe sa place depuis le début — éteint, avec son
indicateur — pour que rien ne saute quand il s'active.

**Le fond est passé du vert plein au vert pastel.** Un aplat saturé tenu cinq secondes derrière
du texte blanc fatigue, et c'était précisément l'écran où l'on demande de patienter. Le pastel
garde la rupture de couleur, rend l'encre lisible, et se traite donc comme un fond clair :
`OnboardingSurface.isDark` ne vaut que pour l'encre, ni pour le menthe ni pour la sauge.

Les trois écrans qui suivent forment la fin du parcours, et leur ordre est délibéré :

| Écran | Ce qu'il dit | Pourquoi là |
| --- | --- | --- |
| Preuve sociale | « Nous avons aidé 500 000 étudiants », puis quatre avis en carrousel qui défilent seuls et se font défiler à la main | Posée en ouverture, elle demande de croire une app qu'on n'a pas vue ; posée ici, elle répond à la seule question qui reste après la génération du parcours : est-ce que ça marche pour d'autres que moi ? |
| Passage de relais | « C'est maintenant à ton tour de découvrir la méthode d'apprentissage que tous les meilleurs élèves utilisent », dont le gras se pose mot par mot | C'est le pivot : jusque-là on montrait, à partir de là c'est l'étudiant qui s'y met. D'où l'encre, et le bouton qui n'arrive qu'une fois le dernier mot posé. |
| Connexion | Continuer avec Apple, continuer avec Google, trois lignes sur ce qu'un compte sauvegarde, et un « Skip » en haut à droite | Demander un compte à l'ouverture, c'est le demander pour une app qu'on n'a pas encore vue fonctionner. Ici le parcours est construit, et le compte sert à ne pas le perdre. |

**Les deux flux sont branchés pour de vrai.** `SignInStepView` se contentait d'appeler
`model.advance()` sur les deux boutons : on croyait s'être connecté, rien n'était créé, et
l'app redemandait un compte juste après le parcours, sur un second écran de connexion. Elle
passe maintenant par `AuthController` (voir [Comptes et sauvegarde](#comptes-et-sauvegarde)) —
Apple par son bouton natif, que ses règles d'interface imposent, Google par une page web
isolée. C'est le passage à l'état « connecté » qui fait avancer, quel que soit le fournisseur
emprunté, et l'écran suivant est l'offre d'essai.

Les deux boutons sont montrés sans condition, et non plus seulement quand le projet Supabase
annonce le fournisseur : un fournisseur éteint côté serveur le dit dans son message d'erreur,
ce qui est plus utile qu'un bouton absent dont personne ne peut deviner la cause.

Le « Skip » est temporaire et il fait deux choses : il avance, et il **referme la porte du
compte** (`AccountGate.skippedKey`, la clé que relit `RootView`). Sans cette clé partagée,
passer la connexion pendant le parcours se payait par un écran de connexion à la sortie.

Les réponses sont écrites au fil de l'eau dans `OnboardingPreferences` (clés `micabo.onboarding.*`)
et survivent donc à une fermeture en cours de route. `Réglages` propose **Refaire l'onboarding**,
qui efface ces clés et relance le parcours sans toucher aux cours.

La toute première question est **Tu étudies où ?**, en pastilles à drapeau. Elle passe devant
« tu en es où ? » parce qu'elle commande ses réponses, et elle décide aussi de la langue : les
deux conséquences se lisent sous les pastilles, à côté du système scolaire retenu. « Ailleurs »
n'est pas un aveu d'échec — la liste ne peut pas couvrir le monde, et une échelle générique vaut
mieux que des paliers inventés.

Vient ensuite **Tu en es où ?**, dont les réponses sont celles du pays : lycée, prépa, licence,
PASS-santé, master, concours en France ; middle school, high school, college, pre-med, graduate
school aux États-Unis ; GCSE, A-Levels, undergraduate, medicine, postgraduate au Royaume-Uni.
Elle situe tout le reste, un lycéen et un PASS n'ayant ni les mêmes matières, ni les mêmes
examens, ni le même rythme. Les réponses **occupent la page**, en rangées qui se partagent la
hauteur à égalité. Elles tenaient avant en pastilles serrées sous le titre : tout était visible
d'un coup, mais les deux tiers de l'écran restaient vides en dessous, et une question posée dans
le coin supérieur d'une page blanche se lit comme un formulaire. Rien ne défile pour autant.

La question de l'oubli, **En général, oublies-tu ce que tu apprends ?**, a quatre réponses là
où elle en avait deux (`ForgettingHabit`). Un oui/non sur un sujet aussi personnel force la
caricature : celui qui retient bien quand il s'y prend correctement n'est ni « oui, tout le
temps » ni « non, ça va », et devant deux cases il choisit celle qui le décrit le moins mal,
ce qui ne renseigne personne. Les deux réponses du milieu sont les plus utiles — elles disent
que le problème est la méthode. La clé historique `micabo.onboarding.forgetsOften` reste tenue
à jour, les quatre réponses s'y ramenant en oui ou non.

Le **temps quotidien** annonce ce qu'il sert à décider (« Ça nous aide à créer un parcours
parfaitement personnalisé à tes besoins »), et la **projection annuelle** qui le suit met son
chiffre dans le titre : « À ce rythme, dans un an, tu auras appris 5 480 cartes sur le bout des
doigts ». Le nombre vivait avant en corps 64 sous un titre qui annonçait sa venue et un
sous-titre qui répétait le rythme choisi à l'écran précédent — trois éléments pour une seule
information. Le titre dit maintenant la chose entière, en une phrase qu'on peut répéter à
quelqu'un, et ce qui reste sous lui est la preuve : douze mois qui montent, puis le calcul posé
ligne à ligne.

Après le choix des matières, **Tu étudies où ?** propose un autocomplete hybride : un catalogue
embarqué (`LocalInstitutions.json`, ~600 établissements FR/EU prioritaires) pour l'instantané,
puis la RPC Supabase `search_institutions` sur la table `institutions` (~14 500 lignes : unis
mondiales, grandes écoles FR, lycées FR). Le texte libre reste accepté, mais il ne donne pas
d'`id` : seul un résultat choisi dans la liste en pose un.

Le parcours est une **file droite** : aucun écran ne se saute, et le mécanisme d'écran
conditionnel qui existait pour la preuve sociale a disparu avec sa première version.

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

**L'accent est le vert de Micabo, et non plus l'indigo.** L'indigo était le violet d'une app de
productivité : sérieux, un peu froid, et sans rapport avec le logo, qui porte un rond vert
menthe depuis le premier jour. Une app qu'on ouvre pour réviser gagne à être vive, et le vert
dit « c'est acquis » dans la même langue que les boutons de notation. Deux verts, et la
distinction est fonctionnelle, pas décorative : `accent` (`#0B8A66`) est assez sombre pour
porter du texte de onze points sur un fond pastel et pour qu'un filet de quatre points se
détache de sa piste, `accentVivid` (`#16C08C`) est celui du logo et ne remplit que de **grandes**
surfaces posées sur du blanc — les colonnes de l'histogramme du profil. C'est la raison pour
laquelle ni la jauge ni le curseur du rythme quotidien ne sont au vert vif : sur le crème, on ne
verrait pas où ils en sont.
`positive` reste un vert plus forestier : deux verts qui veulent dire deux choses ne peuvent
pas être le même vert. Les pastels des tuiles et les teintes de couverture des cours sont
remontés d'un cran, parce que six gris teintés ne donnaient pas de couleur à un écran, ils lui
donnaient une brume. L'icône de l'app suit (`scripts/generate_app_icon.py`).

**Les nombres qui se lisent comme un résultat sont en SF Rounded** (`MicaboFont.number`) : le
compte de cartes du jour, la série, les statistiques d'une session, les minutes d'un objectif.
Un grand nombre en grotesque serré ressemble à un indicateur de tableau de bord ; le même en
arrondi ressemble à un score, et un élève doit avoir envie de le faire monter. Le texte reste
en Hanken Grotesk : deux familles sur une page ne tiennent que si chacune a un domaine net,
l'une écrit les mots, l'autre les nombres.

- Fond ivoire (`#F6F4ED`), surfaces blanches, encre `#191714`, **accent vert `#0B8A66`** et
  vert vif `#16C08C` pour les remplissages
- Typographie Hanken Grotesk embarquée (Regular / Medium / SemiBold / Bold), et **SF Rounded
  pour les nombres** qui se lisent comme un résultat (`MicaboFont.number`)
- Coins : 13 pt (tuiles), 16 pt (boutons, recherche), 20 pt (blocs et cartes), 28 pt (feuilles)
- **Un seul en-tête pour toute l'app** : `MicaboScreenHeader`, sur fond crème, sur-titre en
  capitales grises puis grand titre serré (32 pt). Aucun écran n'a droit à son bandeau : un
  écran poussé ou une feuille ajoute un bouton rond au-dessus du sur-titre, et une page qui
  doit porter une couleur — le détail d'un cours — la porte dans sa **tuile**. Plus de barre
  de navigation système nulle part : les titres système ont tous été remplacés.
- Deux mises en page de liste : posée à même le fond avec un filet entre les rangées (Cours),
  ou regroupée dans un bloc blanc sous un intitulé en capitales (Réglages, Au programme)
- Pastilles d'état au bout d'une rangée : vert pour ce qui attend, ocre pour une échéance,
  gris pour « à jour »
- Le vert de l'accent ne sert qu'à ce qui est actif : onglet courant, filtre choisi, cartes à
  réviser
- Le seul aplat d'encre est le bouton d'action principal, ancré en bas de l'écran
- Barre de trois onglets en pied d'écran, symbole plein sur l'onglet actif. Elle est dessinée
  par `RootTabView`, **hors des pages** : elles se remplacent sous elle, elle ne bouge pas
  d'un pixel. Depuis que le balayage entre onglets a disparu, c'est le seul moyen de changer
  de page. Elle s'efface sur les écrans poussés, où changer d'onglet depuis le fond d'une pile
  ne voudrait rien dire
- **La barre est en verre, et elle flotte.** C'était une bande pleine largeur collée au bas de
  l'écran, avec un flou noyé sous un aplat crème à 72 % : autant dire un bandeau opaque, et un
  bandeau opaque qui touche ce qu'une page ancre au-dessus de lui donne un bouton qu'on croit
  coupé. C'est maintenant une pastille posée à distance des bords, sur un flou franc, un filet
  clair et sa propre ombre. Sa hauteur est déclarée (`MicaboLayout.tabBarHeight`) et non mesurée
  sur ses libellés, parce que c'est cette hauteur que les pages réservent, et l'air qu'elle
  laisse au-dessus d'elle l'est aussi (`MicaboLayout.tabBarGap`)
- Un seul bouton flottant dans l'app : le « + » d'import, en bas à droite de Cours, là où le
  pouce tombe. Il n'apparaît pas quand la liste est vide, où l'écran d'accueil porte déjà son
  propre appel à importer
- **Ce qui est ancré en bas d'une page d'onglet est posé par `safeAreaInset`, jamais par un
  `overlay`.** Un overlay se cale sur les bords de la vue et ignore la zone sûre : le « + » de
  Cours et le bouton de session de Réviser passaient donc **sous** la barre d'onglets, qui est
  dessinée par la racine par-dessus les pages. Ils étaient couverts aux deux tiers, donc à
  moitié cliquables, et c'était le premier appui de l'app. Posés en zone sûre, ils se rangent
  au-dessus de la barre, et le défilement réserve leur hauteur exacte au lieu de la deviner
  avec une constante. Les écrans qui masquent la barre d'onglets — une fiche, ses cartes, les
  examens, une feuille — gardent l'`overlay` et la constante `bottomBarClearance` : sous eux,
  il n'y a que le repose-doigt
- Balayage horizontal natif (pages qui suivent le doigt) pour changer d'onglet ; geste de retour du système sur les écrans poussés
- Réviser : le nombre de cartes à réviser posé à même le fond ivoire, puis les cours au programme et la répartition
- Un cours a deux écrans : sa **fiche**, qui est l'écran du cours, et ses **cartes**, un cran
  plus loin. Les deux portent le même en-tête que le reste de l'app — tuile du cours, matière
  et durée de lecture en sur-titre, titre — et se distinguent par leur sur-titre, pas par un
  bandeau. La fiche pose son texte à même l'ivoire et n'encadre que les objets : définitions,
  encadrés, tableaux, graphes, formules
- Ce que la fiche met en avant change **d'encre**, pas de fond (`MicaboColor.sheetEmphasis`).
  Le surligneur jaune a été retiré : une bande posée derrière le texte débordait sous les
  jambages, changeait d'épaisseur d'une ligne à l'autre, et se battait avec l'interligne au
  lieu de servir la lecture — un `NSLayoutManager` entier ne servait qu'à en arrondir les
  coins. C'est un vert plus dense que l'accent, parce qu'un mot en couleur au milieu d'un
  paragraphe doit se voir sans qu'on le cherche. Les encadrés, eux, gardent les couleurs de
  retour d'information de l'app, volontairement désaturées
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

L'icône actuelle est **dessinée par un script** (`scripts/generate_app_icon.py`) : une carte
verte sur un papier menthe, avec un rond du vert du logo. C'est un tenant-lieu, pas une
identité — le jour où le vrai logo existe, il la remplace.

Le catalogue n'attend qu'**un seul fichier**, en 1024 × 1024, sans transparence et sans coins
arrondis (iOS les arrondit lui-même) :

```
Micabo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

Déposer le fichier à ce chemin suffit : `Contents.json` ne déclare qu'une entrée universelle,
il n'y a donc ni déclinaison de tailles à générer ni référence à ajouter dans le projet. Le
script est à supprimer le jour où il ne dessine plus rien de vivant, pour qu'on ne le relance
pas par erreur sur le vrai logo.

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
cd supabase/functions && deno task verify && cd -
supabase link --project-ref votre-ref
supabase functions deploy generate-course
supabase functions deploy generate-flashcards
supabase functions deploy explain-selection
supabase functions deploy youtube-transcript
```

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

**Le compte se demande à la fin du parcours d'accueil, et il reste facultatif.** Les deux
moitiés de cette phrase sont des décisions. À la fin, parce que demander un effort avant
d'avoir donné une raison ne marche pas, et que les vingt écrans d'accueil existent pour donner
cette raison. Facultatif, parce que l'app doit continuer de s'ouvrir dans un train sans
réseau : rester local n'est pas une dérobade, c'est le mode d'origine, et il se rattrape à
tout moment depuis les réglages — la synchro remonte alors ce qui a été accumulé entre-temps.

L'écran de compte de `RootView` est resté, mais comme **rattrapage** : il se demandait là, à la
sortie du parcours, ce qui donnait deux écrans de connexion à la suite. Il ne s'affiche
maintenant que pour quelqu'un qui a fini le parcours sans compte et sans passer explicitement,
c'est-à-dire après une déconnexion depuis les réglages.

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
une bibliothèque où personne ne dépose rien n'intéresse personne. Le réglage se change là où le
cours se lit, dans le menu de sa fiche, parce que c'est en l'ayant sous les yeux qu'on sait si
on veut la laisser voir.

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
l'authentification tient en six appels, qu'on relit en une fois, là où une dépendance externe
coûterait un gestionnaire de paquets, une surface de mise à jour et un binaire.

La session vit dans le **trousseau**, et pas dans les réglages : un jeton de rafraîchissement
donne accès au compte sans mot de passe, et dans `UserDefaults` il se lirait en clair dans une
sauvegarde. `ThisDeviceOnly` l'empêche en plus de partir dans iCloud, donc restaurer un vieux
backup sur un autre téléphone ne connecte personne. Le jeton d'accès est rafraîchi à un seul
endroit, `AuthController.validAccessToken()`, une minute avant son échéance : personne d'autre
n'a à savoir qu'un jeton expire.

**L'écran de connexion n'affiche que ce qui marche.** `AuthProviders` est lu au lancement
(`GET /auth/v1/settings`) et décide de ce qu'on montre : les boutons Apple et Google
n'apparaissent que si les fournisseurs sont activés côté Supabase. Un bouton « Continuer avec
Google » qui mène à une page d'erreur coûte plus cher qu'un bouton absent, et ceux-là
apparaîtront d'eux-mêmes le jour de la configuration, **sans mise à jour de l'app**.

Les étapes complètes de cette configuration, iOS et web, sont dans
**[`docs/oauth-setup.md`](docs/oauth-setup.md)**. Ce qu'il faut retenir en une ligne : Apple
demande que le **bundle de l'app et le Service ID soient tous les deux** dans le champ
« Client IDs », parce que le jeton du bouton natif porte le premier et celui du retour web le
second.

Et **[`docs/data-flywheel.md`](docs/data-flywheel.md)** propose ce qu'il faudrait garder en plus
pour que ces données deviennent un avantage : rien n'y est implémenté, c'est une note de
conception.

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
qui l'utilise : la réponse dépend du document qu'on vient de déposer. Trois formats, et pas un
curseur de blocs, parce que ce qu'on choisit est un usage :

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

Quatre marques, et chacune a une raison d'exister sur une fiche de révision
(`Micabo/Services/SheetMarkup.swift`) :

| Écriture | Rendu | À quoi ça sert |
| --- | --- | --- |
| `**terme**` | gras | le mot que l'examen attend, une à deux fois par paragraphe, jamais zéro dans un paragraphe qui introduit une notion |
| `*nuance*` | italique | un mot étranger, un titre d'œuvre, une réserve |
| `==l'essentiel==` | texte en couleur | ce qu'on relit en dernier, **trois à cinq passages sur la fiche**, jamais deux dans le même paragraphe |
| `$E = mc^2$` | formule | transposée par `FormulaRenderer`, comme sur les cartes |

**Le surligneur jaune a été retiré, et c'était son rendu.** Un fond posé derrière le texte
débordait sous les jambages, changeait d'épaisseur d'une ligne à l'autre, et se battait avec
l'interligne au lieu de servir la lecture — il fallait un `NSLayoutManager` entier pour en
arrondir les coins, et ça ne suffisait pas. C'est maintenant **la couleur du texte lui-même**.
Le balisage n'a pas bougé : `==` est écrit dans les fiches déjà en base, le renommer les aurait
toutes cassées. Seul le rendu change, et le poids n'est pas touché non plus — le gras est déjà
une marque, et deux marques sur le même passage n'en font aucune.

Comme la marque est maintenant beaucoup plus forte, **elle est devenue rare** : trois à cinq
passages là où le prompt en demandait six à huit, plafond à six côté serveur, plancher à trois.
Neuf phrases vertes sur une page en feraient une page verte.

**Elle a longtemps été absente des fiches, et c'était le prompt.** Il ne parlait de mise en
valeur qu'en plafonds — « cinq marques au maximum », « trois mots en gras c'est trois de trop »,
plus une consigne interdisant « les emphases partout » — et le modèle lisait l'ensemble comme un
ordre de sobriété : il n'en produisait aucune. Le prompt donne donc un plancher, et surtout
**où** marquer : la phrase d'enjeu du premier paragraphe, la phrase que l'étudiant devra
réciter dans chaque partie, le résultat chiffré qu'un correcteur attend, et l'encadré
« essentiel ».

**Et la marque ne dépend plus du prompt.** Le plancher a été demandé plusieurs versions de
suite, et des fiches continuaient d'arriver sans une seule marque : une consigne de mise en
forme est la première chose qu'un modèle lâche quand il se concentre sur le contenu. Elle est
donc passée côté code, aux deux endroits où vivent les garde-fous de la fiche :
`ensureHighlights` dans `supabase/functions/_shared/sheet.ts` marque ce qui s'enregistre,
`SheetHighlighter` dans `Micabo/Services/SheetHighlighter.swift` marque ce qui se relit, ce qui
rattrape les cours importés avant la mise à jour des fonctions. Les deux garantissent
**trois passages au minimum**, ne touchent jamais une fiche déjà marquée, et choisissent dans
le même ordre : l'encadré « essentiel », l'enjeu du premier paragraphe, les définitions, puis
le reste. Une marque porte sur une phrase, ponctuation finale exclue, ramenée à sa première
proposition quand elle dépasse 170 caractères, et la phrase qui contient déjà un terme en gras
passe devant, parce que c'est là que le modèle a placé ce qui compte. Trois et pas huit : ce
que le code choisit vaut moins que ce que le modèle choisit.

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
- **Chaque note annonce quand la carte revient** — sous « À revoir », « Difficile », « Correct »
  et « Facile », le délai que la note programme : `1 min`, `10 min`, `1 j`, `4 j`. Il manquait, et
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
scripts/             génération de l'icône
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

`MicaboTests/AuthAndSyncTests.swift` verrouille les comptes et la synchro sur des charges
utiles GoTrue réelles : le décodage d'une session, l'échéance calculée à la réception, le nom
trouvé quel que soit le nom que le fournisseur donne au champ, et surtout **la fiche qui
traverse la synchro sans être touchée**. Ce dernier test est celui à ne pas laisser tomber : si
la fiche se dégrade d'un aller-retour à l'autre, personne ne le voit avant des semaines.

```bash
xcodebuild test -project Micabo.xcodeproj -scheme Micabo -destination 'platform=iOS Simulator,name=iPhone 16'
```
