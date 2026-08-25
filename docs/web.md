# Le site web

Micabo devient aussi un site. Même Supabase, mêmes cours, même fiche, mêmes cartes — et
délibérément **pas la même app**. Ce document est le plan : ce que le site est, ce qu'il n'est
pas, à quoi il ressemble, comment il se déploie, et comment un abonnement acheté sur l'iPhone
est reconnu dans le navigateur.

Rien de ce qui suit n'est implémenté. C'est une note de conception, comme
[`data-flywheel.md`](data-flywheel.md), et elle est écrite avant le code parce que trois des
décisions qu'elle contient — l'identité de l'utilisateur au moment de l'achat, la clé qui
autorise les Edge Functions, et la place du compte dans le parcours — coûtent cher à changer
après.

## Ce qui existe déjà, et qui décide de tout le reste

Le schéma a été écrit pour ce jour-là. La migration des comptes le dit dans son premier
commentaire : « pour qu'un étudiant retrouve ses cours sur un autre appareil, **et plus tard sur
le web** ». Trois conséquences, et elles sont acquises :

- **L'identifiant vient du client**, donc le web crée ses cours avec le même genre d'UUID que
  l'iPhone, sans table de correspondance ;
- **`updated_at` est posé par le serveur**, donc deux appareils qui écrivent la même ligne se
  résolvent sans faire confiance à l'horloge d'un navigateur ;
- **le cloisonnement est dans Postgres**, pas dans l'app, donc un client web n'a aucun moyen de
  demander les cours de quelqu'un d'autre, même en trafiquant sa requête.

L'état réel du projet, vérifié :

| Chose | État |
| --- | --- |
| Projet Supabase | `khuzodsrznanzhwlbjbx` (`Feymind_flashcards`), `eu-north-1`, sain |
| Migrations appliquées | les quatre du dépôt |
| Fournisseurs d'authentification | **Apple, Google et courriel sont allumés** (`GET /auth/v1/settings`) |
| CORS des Edge Functions | `Access-Control-Allow-Origin: *`, préflight géré |
| Autorisation des Edge Functions | la **clé anonyme** suffit ; aucune fonction ne lit l'utilisateur |
| Limitation d'usage | **aucune**, nulle part |
| Abonnements | **corrigé** — le gratuit existe depuis la PR #37 : `ProAccess.swift`, `SheetGate`, deux paywalls natifs, et `docs/revenuecat.md`. Il n'y a en revanche **aucune table `entitlements`** : `ProAccess` lit un drapeau local, donc le site n'a rien à lire |
| Ce qui ne monte jamais | images d'occlusion, audio des cartes, couvertures, `Exam.scheduleBackup` |
| Ce que l'iPhone ne redescend jamais | `exams`, `review_logs` (montés seulement) |

Ces deux dernières lignes sont les seules vraies dettes que le site va révéler. On y revient en
[Ce que le site casse côté iOS](#ce-que-le-site-casse-côté-ios).

## Le site n'est pas l'app

C'est la décision qui gouverne tout le reste, et elle se résume en une phrase : **l'iPhone est
la poche, le site est le bureau.**

On sort son téléphone dans une file d'attente, et ce qu'on veut alors est de réviser : d'où les
trois onglets avec Réviser au milieu, le bouton de session ancré sous le pouce, et un appui
entre le lancement et la première carte. On s'assied devant un écran pour **travailler** : on
dépose un polycopié, on lit une fiche en grand, on corrige vingt cartes à la suite, on pose ses
examens sur un vrai calendrier.

Donc :

| | iOS | Web |
| --- | --- | --- |
| Écran d'ouverture | **Réviser** | **Cours** |
| Navigation | trois onglets en pied d'écran | une barre latérale, et le clavier |
| Import | scan, photo, PDF, Word, YouTube | glisser-déposer, coller, YouTube |
| Session | le pouce, quatre boutons | **le clavier** : espace pour retourner, 1–4 pour noter |
| Fiche | une colonne, lecture au doigt | une colonne de lecture, **et l'impression** |
| Parcours d'accueil | 22 écrans | court, et pas le même (voir plus bas) |

Ce que le web **n'aura pas**, et il ne s'agit pas de retard :

- **le scanner de documents** — `VNDocumentCameraViewController` n'existe pas dans un
  navigateur, et un `<input capture>` sur un portable ouvre une webcam, ce qui donne une photo
  de polycopié inexploitable. Le glisser-déposer le remplace, et il est meilleur ici ;
- **l'éditeur d'occlusion et l'audio des cartes** — leurs données ne quittent jamais l'appareil
  aujourd'hui. Une carte à occlusion s'affichera donc sur le web **sans son image**, avec une
  ligne qui dit pourquoi, jusqu'à ce qu'un seau de stockage existe ;
- **les vibrations**, évidemment. Et rien ne les remplace : un site qui fait clignoter un
  élément à chaque appui pour « compenser » le retour haptique est un site qui clignote ;
- **les 22 écrans du parcours d'accueil.** Quelqu'un qui a installé une app s'est déjà engagé ;
  quelqu'un qui arrive de Google donne dix secondes.

Ce que le web aura **et que l'iPhone ne peut pas avoir** — c'est ce qui justifie le site
au-delà de la vitrine :

- **le lien vers une fiche.** Un étudiant envoie sa fiche dans le groupe de la classe, celui qui
  la reçoit la lit sans rien installer, et lit en bas « fais la tienne ». C'est la seule boucle
  de croissance que Micabo peut avoir, et elle est impossible dans une app ;
- **l'impression.** Une fiche *est* une page — le README ne dit rien d'autre depuis le début. Une
  feuille de style d'impression coûte presque rien et les fiches se relisent sur papier la veille
  au soir ;
- **le clavier**, pour l'import, l'édition en série et la session.

## La page d'accueil

turbo.ai est la bonne référence de **structure** : il dit ce qui entre, ce qui sort, et pour qui
c'est. C'est aussi la mauvaise référence de **forme** : c'est une liste de fonctionnalités
empilées en sections, et en 2026 le site de chaque outil d'IA scolaire ressemble à ça — ce qui
est précisément la tête d'un site fait à la chaîne.

La règle du parcours d'accueil s'applique mot pour mot ici : **la démonstration est le seul
argument.** Une page qui montre une chose est plus crédible qu'une page qui en promet six.

Les sections, dans l'ordre :

| # | Section | Ce qu'elle fait |
| --- | --- | --- |
| 1 | **Accroche** | Une phrase, aucun paragraphe de sous-titre, et **une zone de dépôt à la place du bouton**. Le visiteur peut poser un PDF avant d'avoir un compte |
| 2 | **La transformation** | Le mur de texte brut à gauche, la fiche à droite, et le passage de l'un à l'autre **piloté par le défilement**. Le vrai composant de fiche, le vrai document de démonstration (`OnboardingDemo`, le cycle de l'eau), pas une capture |
| 3 | **La courbe de l'oubli** | Un graphe, deux lignes de légende. Le port TypeScript de `RetentionCurve`. Seule section de pédagogie |
| 4 | **Les cartes** | Une carte qu'on retourne et qu'on note **au clavier, dans la page**. Pas une capture d'écran d'une session |
| 5 | **Le mode examen** | Le calendrier qui se remplit, cerne le jour J et pose ses six points. C'est la fonctionnalité que personne d'autre n'a, elle mérite sa section |
| 6 | **Sur ton téléphone aussi** | Le badge App Store, un cadre de téléphone, trois lignes. Court |
| 7 | **Le prix** | Deux cartes, l'annuel mis en avant, **le prix écrit**. Une grille de prix qui cache son prix se lit comme un tunnel de vente |
| 8 | **Questions** | Six à huit, et de vraies questions : mes cours sont-ils privés, ça marche en anglais, que se passe-t-il à la fin de l'essai |
| 9 | **Pied de page** | Mentions, contact, confidentialité et conditions — qu'Apple et Google exigent de toute façon |

Ce qu'on **ne met pas**, et chaque ligne est un tell :

- pas de mur de logos « ils nous font confiance » : une app d'étudiants n'a pas de clients
  d'entreprise, et un mur de logos inventés se repère en une seconde ;
- pas de carrousel de témoignages à photos d'avatars ;
- pas de bulle de chat en bas à droite ;
- pas de mur de consentement aux cookies, parce qu'on ne pose pas de cookie de pistage ;
- **aucune étoile scintillante, aucun `✨`, aucun dégradé violet.**

## Le design, et comment il n'a pas l'air fait par une IA

Le fond de l'affaire, c'est que Micabo **a déjà une identité visuelle**, et que cette identité est
du papier. Les tells d'une page faite à la chaîne sont connus et tiennent en une liste courte —
tout est centré, trois colonnes de fonctionnalités à tuiles arrondies, un dégradé violet-bleu en
fond de bandeau sombre, des cartes en verre dépoli qui flottent, Inter en quatre graisses, des
sous-titres `gris 400`, un emoji par section. Ne pas les faire ne suffit pas ; en faire autre
chose, si.

**Et il faut corriger une chose que j'avais écrite ici.** J'avais posé que l'ivoire nous sauvait,
au motif que « personne qui génère une page d'accueil ne tombe sur de l'ivoire chaud ». C'est
faux, et la source qui le dit est celle d'Anthropic sur la conception d'interfaces : le premier
des trois clichés qu'elle nomme est **« un fond crème chaud, près de `#F4F1EA`, avec un display
serif très contrasté et un accent terracotta »**. Le crème de Micabo est `#F6F4ED`. C'est le même.

Ça ne change pas la couleur — la même source dit que lorsqu'une direction visuelle est déjà
arrêtée, elle gagne, et l'ivoire de Micabo n'est pas un choix libre que je dépenserais ici : c'est
une identité livrée, documentée et argumentée. Ça change deux choses :

- **le crème cesse d'être l'argument.** Il est neutre, et il devient un passif dès qu'on lui
  ajoute les deux autres marqueurs du cliché. Donc, règle explicite : **aucun display serif sur le
  site**, et aucun accent terracotta ou brique. Le grotesque et le vert de Micabo l'en sortent
  déjà, mais il ne faut pas les lâcher en route ;
- **la distinction doit venir d'un élément signature**, pas de la palette.

### La signature

Une seule chose dont le site doit se souvenir, et elle est déjà dans le produit : **une page, deux
états, la même empreinte.** Le polycopié brut et la fiche occupent le *même rectangle*, au pixel,
et c'est la barre de défilement qui fait passer de l'un à l'autre.

Ce n'est pas une trouvaille de site web, c'est l'observation que l'app a déjà faite pour son écran
de démonstration : « Les deux états occupent la même place, ce qui fait lire une transformation et
non deux illustrations. » Deux images côte à côte donnent une comparaison ; deux états au même
endroit donnent une transformation, et la transformation *est* le produit. C'est la thèse de
l'accroche, et tout le reste de la page doit rester calme autour d'elle.

La seconde signature ne se voit pas à l'écran : **le site s'imprime.** Une fiche sort en page A4
propre, avec ses objets, sans la navigation. Personne ne soigne son `@media print` sur une page
d'accueil générée — et les fiches se relisent sur papier la veille au soir.

`MicaboTheme.swift` se porte donc **tel quel** en variables CSS, valeur par valeur :

- fond ivoire `#F6F4ED` sur **tout le site**, y compris l'accroche. Pas de bandeau sombre ;
- surfaces blanches **sans bordure et sans ombre appuyée** : le contraste des deux fonds suffit,
  c'est déjà la règle de l'app ;
- un seul accent, le vert `#0B8A66`, et le vert vif `#16C08C` réservé aux **grandes** surfaces
  remplies. Rien d'autre n'est coloré, sauf les couleurs de retour d'information et les teintes
  de couverture des cours ;
- encre `#191714`, et `#2B2822` dès qu'un paragraphe dépasse dix lignes ;
- rayons 13 / 16 / 20 / 28 px, exactement ceux de `MicaboRadius` ;
- Hanken Grotesk en `next/font/local`, depuis les fichiers déjà dans `Micabo/Resources/` ;
- largeur de contenu ~1100 px, **et ~680 px pour une colonne de fiche**, parce que c'est le seul
  endroit du produit où l'on lit vraiment.

Reste le cas des **nombres**. SF Rounded n'existe pas sur le web, et « un grand nombre en arrondi
ressemble à un score » est un choix d'intention de l'app, pas un détail : c'est **Nunito** qui le
tient, variable, et uniquement sur les chiffres — jamais un mot. Voir
[Les décisions prises](#les-décisions-prises).

### Le mouvement : la fréquence décide, pas le goût

C'est la correction la plus utile que les ressources apportent, et elle vaut plus que n'importe
quelle courbe : **ce qui décide d'animer ou non, c'est le nombre de fois par jour qu'on le voit.**
Une animation vue une fois est un cadeau ; la même vue trois cents fois est un péage.

| Fréquence | Décision |
| --- | --- |
| **100+ fois par jour** — raccourci clavier, notation d'une carte | **aucune animation. Jamais.** |
| Des dizaines de fois — survol d'une rangée, changement d'onglet | réduire au strict minimum, ou supprimer |
| Occasionnel — feuille, panneau, message | animation standard |
| Rare ou une seule fois — accueil, démonstration, réussite | on a le droit d'enchanter |

Ce qui a une conséquence directe et contre-intuitive sur ce qui était prévu : **la session au
clavier ne s'animera pas.** Espace retourne la carte, 1 à 4 la notent, et ces deux gestes se font
des centaines de fois par soirée de révision — une carte qui pivote joliment à chaque appui
deviendrait, au bout de vingt cartes, la chose qui ralentit le travail. La carte se retourne
**instantanément**.

Et la contrepartie, qui est le même raisonnement dans l'autre sens : **les cartes de l'écran de
démonstration, elles, se retourneront au survol** comme demandé. Cet écran se voit une fois dans
une vie. C'est exactement là que le budget d'enchantement doit être dépensé.

D'où deux régimes, et il faut les tenir séparés dans le code :

| | `/` — la vitrine | `/app` — le produit |
| --- | --- | --- |
| Rôle | expliquer, une seule visite | servir, tous les jours |
| Durées | peuvent dépasser 300 ms | **sous 300 ms**, et le plus souvent sous 160 |
| Survol | une carte peut monter de 2 px, l'ombre s'approfondit | **l'ombre seule change.** Rien ne se déplace |
| Séquences | entrées échelonnées, défilement piloté | aucune |

Le survol, dans le détail, et **une seule chose par élément** :

| Élément | Ce qui change |
| --- | --- |
| Rangée de cours | le fond passe de transparent à blanc. Rien ne bouge, rien ne monte |
| Carte, tuile | **l'ombre** passe de `--shadow-border` à `--shadow-border-hover`. Pas de mise à l'échelle : un texte qui grossit se rend flou pendant sa propre transition |
| Bouton | s'assombrit, et son libellé ne se déplace pas d'un pixel |
| Lien | un filet de 1 px **se trace depuis la gauche**. C'est la seule fioriture du site, et c'est le survol qui a le plus l'air fait à la main |
| Vignette de la démonstration | le balayage de lecture repart, une fois |

Tout survol qui *bouge* est enfermé dans `@media (hover: hover) and (pointer: fine)` : sur un
écran tactile, un appui déclenche un faux survol, et l'élément reste dans son état de survol après
que le doigt est parti.

### Les jetons de mouvement

Ces valeurs se copient, elles ne s'approximent pas. Cinq cubic-bezier qui se ressemblent presque
sont un défaut en soi.

```css
--ease-out:     cubic-bezier(0.23, 1, 0.32, 1);     /* entrée, sortie — le défaut */
--ease-in-out:  cubic-bezier(0.77, 0, 0.175, 1);    /* déplacement à l'écran */
--ease-drawer:  cubic-bezier(0.32, 0.72, 0, 1);     /* panneau qui glisse */
```

- **`ease-in` sur une interface est toujours une faute** : il démarre lentement, donc il retarde
  exactement l'instant que l'utilisateur regarde.
- Budgets : appui 100–160 ms, infobulle 125–200, menu 150–250, feuille 200–500. La vitrine
  s'affranchit de ces bornes, le produit non.
- **Appui** : `transform: scale(0.97)` avec `transform 160ms ease-out`. Les deux références que
  j'ai lues se contredisent d'un centième — l'une dit 0,96, l'autre 0,97 — et les deux tiennent la
  fourchette 0,95–0,98. Je prends **0,97**, le plus retenu des deux, parce que le mouvement de
  Micabo est retenu partout ailleurs.
- **Jamais `scale(0)`** : rien n'apparaît de rien. Une entrée part de `scale(0.9–0.97)` avec
  `opacity: 0`.
- Un menu, une infobulle, un popover **s'ouvrent depuis leur déclencheur**, pas depuis leur
  centre : `transform-origin: var(--transform-origin)`, que Base UI fournit. Une feuille modale est
  l'exception — elle arrive au centre, et c'est juste.
- **Transitions CSS pour tout ce qui est réversible**, images-clés seulement pour une séquence qui
  ne joue qu'une fois : une transition se recible en cours de route, une image-clé repart de zéro.
- On n'anime que `transform` et `opacity`. **Jamais `transition: all`**, et les propriétés sont
  toujours nommées. `filter: blur()` reste sous 20 px, sinon Safari décroche.
- Échelonnement : 30 à 80 ms pour une liste, ~100 ms pour une entrée de héros au premier
  chargement. Jamais sur une interaction fréquente, et jamais bloquant.
- `prefers-reduced-motion` **réduit, il n'annule pas** : on garde ce qui aide à comprendre — les
  opacités, les couleurs — on retire les déplacements.

**Et « rien ne rebondit » reste la règle de la maison.** Les références recommandent un ressort
Apple à `bounce: 0.2` ; l'app a tranché l'inverse, écrit pourquoi, et s'est réservé trois
exceptions nommées. Une décision de conception documentée ne se rejuge pas au motif qu'un guide
générique conseille autre chose : `bounce` reste à **0**.

Le défilement, justement : la section de transformation est **liée à la barre de défilement**
(`animation-timeline: view()`) et non déclenchée une fois au croisement. La différence se sent —
une animation qu'on pilote appartient à la page, une animation qui part toute seule appartient à
un modèle de site. Là où ce n'est pas supporté, l'état final s'affiche, et c'est tout.

### Les composants : on prend le comportement, on jette la peau

Une couche sans style, et une seule : **Base UI**. Les primitives viennent de **coss.com/ui**, qui
en est l'habillage, et les pièces composées — celles qui coûtent des jours à écrire — de **ReUI**,
qui les publie précisément en variante Base UI en plus de la variante Radix. Un seul socle sans
style, donc pas deux jeux de primitives qui se marchent dessus.

Six pièces de ReUI répondent à un besoin déjà écrit dans ce document, et ce sont celles qui font
gagner le plus de temps :

| Pièce | Où elle sert |
| --- | --- |
| **Stepper** | Les neuf écrans du parcours, sa barre de progression, sa validation par étape |
| **Event Calendar** (mois/semaine/jour, glisser-déposer) | Les examens — l'iPhone a déjà le glisser-déposer sur son calendrier |
| **Calendar / Date Picker** | L'écran 5, la date d'examen |
| **Combobox** asynchrone | L'école, sur la RPC `search_institutions` |
| **Dropzone** | La zone de dépôt de l'accroche, et l'import |
| **Data Grid** | La correction de vingt cartes à la suite, ce que le téléphone ne peut pas faire |

Et **`Kbd`**, de coss, pour afficher les touches de la session.

**Le piège est dans le style, et il est sérieux.** ReUI est du shadcn/ui, et le look par défaut de
shadcn — palette zinc, `--radius` par défaut, une bordure sur chaque chose, l'anneau de focus avec
son `ring-offset` — **est lui-même l'un des clichés qu'on cherche à éviter**. Copier un composant
et laisser ses jetons donne un site qui ressemble à tous les sites shadcn. La discipline est donc
littérale : **on copie le comportement, on jette la peau.** Les variables de shadcn
(`--background`, `--foreground`, `--primary`, `--radius`) sont remappées sur les vraies valeurs de
`MicaboTheme`, et tout ce qui se bat avec la direction papier — les bordures partout, l'échelle
d'ombres par défaut — est retiré, pas atténué.

### Trois détails qui font qu'une interface « sonne juste »

**Les rayons doivent être concentriques, et ceux de Micabo ne le sont pas.** La règle est
`rayon extérieur = rayon intérieur + marge intérieure`, et c'est la première cause de cette
sensation qu'« il y a quelque chose qui ne va pas » sans qu'on sache dire quoi. Or les valeurs
d'iOS — tuile 13, bouton 16, bloc 20, feuille 28 — n'ont pas été choisies l'une pour l'autre : une
tuile de 13 dans un bloc de 20 avec 16 de marge voudrait un extérieur à 29. Sur le web, **les
rayons se calculent, ils ne se recopient pas** ; les quatre valeurs restent les repères, et
l'imbriqué se dérive. Au-delà de 24 px de marge, les deux surfaces sont indépendantes et chacune
prend le rayon qu'elle veut.

**Les ombres portent la profondeur, les bordures portent la structure.** Une bordure qui n'est là
que pour décoller une carte devient un `box-shadow` en trois couches — ce qui tombe bien, c'est
déjà la doctrine de l'app (« pas de bordure, et une ombre presque invisible juste pour décoller le
bloc »). Restent des bordures les filets qui séparent : `MicaboHairline` ne devient pas une ombre.
Et le contour d'une image est **du noir pur à 10 %**, jamais une teinte de la palette : un contour
teinté attrape la couleur du fond et se lit comme de la saleté sur le bord de l'image. Sur un fond
ivoire, c'est exactement le piège qu'on tendrait en prenant `stroke`.

**Une seule bibliothèque d'icônes, et son trait suit le poids du texte** — 1,5 px à côté d'un texte
régulier, 2 px à côté d'un demi-gras. iOS utilise SF Symbols, qui n'existe pas sur le web : je
prends **Phosphor**, et pas Lucide, pour une raison précise — Phosphor a une variante pleine, donc
elle sait faire « contour par défaut, plein pour l'état actif », qui est déjà la règle de la barre
d'onglets de l'app (« symbole plein sur l'onglet actif »). Une icône est un seul SVG en
`currentColor` qui prend ses états de la couleur, jamais deux fichiers.

### Ce qui fait qu'un composant est fini

Emprunté à la discipline des systèmes de composants : un composant n'est pas fini quand il
s'affiche, il est fini quand **tous ses états** existent — repos, survol, focus visible, actif,
désactivé, chargement, erreur, et **vide**. L'état vide est celui qu'on oublie et celui qu'un
étudiant voit en premier, le jour où il n'a encore rien importé ; l'app a déjà des écrans d'accueil
vides écrits pour ça, et ils sont le modèle.

Et les fondations passent avant les composants : les jetons — couleur, typographie, espacement,
rayons, ombres, mouvement — sont posés à l'étape 1, une fois, et rien plus tard ne redéfinit une
couleur en local.

### `thinking-orbs`, ce que c'est vraiment

Il faut être clair, parce que la bibliothèque proposée n'est pas ce que son nom laisse croire :
**`thinking-orbs` n'est pas un système de design.** Ce sont neuf indicateurs d'attente animés en
pointillés pour interfaces d'agents, en deux tailles seulement (64 px et 20 px), **strictement
monochromes** — donc incapables de porter le vert de Micabo — et rendus sur un canvas 2D. Elle
ne peut pas porter la forme d'une page d'accueil, et il ne faut pas le lui demander.

Là où elle est **exactement** ce qu'il faut :

- pendant qu'on extrait le texte d'un document déposé : `state="searching"` ;
- pendant que la fiche s'écrit : `state="composing"`. Le découpage des deux états correspond
  aux deux vraies phases du pipeline, ce qui est rare pour un indicateur d'attente ;
- sur l'explication d'un passage sélectionné : `state="solving"` ;
- en 20 px, à même la ligne « Micabo lit ton cours… ».

Elle expose aussi une variante SwiftUI, donc le même indicateur pourrait plus tard remplacer les
attentes courtes de l'app — le genre de détail partagé qui fait que deux produits se ressemblent
pour de bon.

Là où elle **ne va pas** : l'attente longue. `GenerationOverlay` montre la page en train de se
faire, et le README explique pourquoi l'écran d'avant a été retiré : il « faisait patienter
devant un travail qu'on ne voyait pas ». Mettre un orbe abstrait là où l'app montre la page qui
s'écrit contredirait sa propre décision. Donc : **les orbes pour les attentes courtes, la page
qui se construit pour la longue.**

## Le site connecté

Un seul domaine, et ce n'est pas un détail de goût : le lien de partage d'une fiche, la page
d'accueil et l'app doivent partager le domaine pour que le cookie de session soit simple et que
le référencement profite au produit.

```
micabo.app/                 accueil, prix, questions
micabo.app/f/<id>           une fiche partagée, lisible sans compte
micabo.app/app              Cours — l'écran d'ouverture du web
micabo.app/app/c/<id>       la fiche d'un cours
micabo.app/app/c/<id>/cartes
micabo.app/app/reviser      la session, au clavier
micabo.app/app/examens
micabo.app/app/profil
micabo.app/auth/callback    l'échange du code OAuth
```

Le vocabulaire de `MicaboCopy.swift` vaut ici **sans exception** : un contenu importé est un
*cours*, ce que Micabo en écrit est sa *fiche*, une question-réponse est une *carte*, un passage
est une *session*, et l'action est *réviser*. Un bouton garde son nom du début à la fin d'un
parcours, et « Réviser N cartes » s'appelle pareil sur le web.

## La pile, et où le code vit

```
/Micabo              iOS, inchangé
/supabase            partagé, inchangé
/web
  /app               Next.js 15, App Router, TypeScript, Tailwind
  /packages/core     le port TypeScript des règles pures
```

Un seul dépôt, et c'est **`packages/core` qui justifie le monorepo**. Il porte les fonctions
pures, sans entrée-sortie, portées du Swift :

| Module | Source Swift | Pourquoi il doit être partagé |
| --- | --- | --- |
| Schéma de fiche + balisage en ligne | `CourseSheet.swift`, `SheetMarkup.swift`, `_shared/sheet.ts` | Une fiche rendue différemment sur deux clients est une fiche qui a l'air cassée sur l'un des deux |
| SM-2 | `SM2Scheduler.swift` | **Deux copies de la formule vont diverger, et le jour où elles divergent une carte est révisée deux fois.** C'est le module le plus important du lot |
| `DailyLoad` | `DailyLoad.swift` | `max(2, round(minutes / 2))`. Le plafond de cartes neuves doit être le même des deux côtés |
| File d'étude | `StudyQueue.swift` | L'ordre d'une session |
| Planificateur d'examen | `ExamPlanner.swift`, `ExamDeadlines.swift` | Un plan recalculé différemment sur le web déplacerait les cartes de l'iPhone |
| Courbe de rétention | `RetentionCurve` | La page d'accueil s'en sert |

Le port se vérifie : `MicaboTests/SM2SchedulerTests.swift` porte déjà les valeurs attendues
exactes — un intervalle de 10 jours à facilité 2,5 donne 25 j en « Correct », 12 j en
« Difficile » à facilité 2,35, et 34,45 j en « Facile » à facilité 2,65. Les mêmes nombres
deviennent les tests du module TypeScript. **Un port sans ses tests ne vaut rien** : c'est du
code qu'on croit identique.

## L'authentification

Tout est déjà configuré côté fournisseurs. Apple, Google et le courriel répondent `true`
aujourd'hui.

Sur le web, on utilise **`@supabase/ssr`**, et pas la réécriture à la main de GoTrue qu'a faite
l'iPhone. Le choix de l'app était bon là-bas : quatre appels HTTP contre un gestionnaire de
paquets et une surface de mise à jour. Sur le web, ce qu'il faudrait réécrire n'est pas quatre
appels, c'est la mécanique de cookies, de rafraîchissement et de middleware — exactement ce pour
quoi la bibliothèque existe. PKCE, l'échange du code dans `app/auth/callback/route.ts`, et le
cookie posé là.

Trois choses à ajouter dans le tableau de bord, et rien d'autre :

1. **Authentication → URL Configuration → Redirect URLs**
   ```
   http://localhost:3000/auth/callback
   https://micabo.app/auth/callback
   https://*-adriens-projects-145ae26c.vercel.app/auth/callback
   ```
   Le joker ne couvre **qu'un segment**, et il est indispensable : chaque branche poussée reçoit
   son déploiement de prévisualisation, dont l'URL a la forme
   `micabo-<empreinte>-adriens-projects-145ae26c.vercel.app`. Sans cette ligne, se connecter sur
   une prévisualisation est impossible, et l'erreur ne parle pas de configuration.
2. **Site URL** → `https://micabo.app`. Attention à l'effet de bord noté dans
   [`oauth-setup.md`](oauth-setup.md) : c'est la destination par défaut des liens envoyés par
   courriel. Comme l'app ne se connecte que par Apple et Google, il n'y a rien à casser.
3. **Apple** : ajouter le domaine du site dans *Domains and Subdomains* et son URL de retour dans
   *Return URLs* du Service ID `com.micabo.app.service`. Rien à créer — c'est déjà le Service ID
   du web. Côté Google, **rien à changer** : Supabase reste l'intermédiaire, donc l'URI de
   redirection Google ne bouge pas.

Un point de vigilance propre au web : les appels PostgREST doivent porter le **jeton de
l'utilisateur**, jamais la clé anonyme. C'est déjà ce que fait `SupabaseDatabase` côté iOS, et
c'est ce qui fait fonctionner le cloisonnement.

## L'abonnement, et sa mise en commun

C'est la question la plus lourde du plan, et elle se règle en séparant deux choses qu'on
confond : **où passe l'argent**, et **qui détient le droit**.

### La contrainte

Apple exige que l'abonnement vendu **dans** l'app iOS passe par StoreKit, avec sa commission de
30 % la première année puis 15 %. Apple n'exige rien sur ce qui est vendu **sur votre site**. Le
site encaisse donc à 100 % moins ~2,9 % de Stripe. La marge du web est strictement meilleure, et
elle l'est beaucoup.

Mais quel que soit le chemin de l'argent : **un utilisateur, un droit, lisible par les deux
clients.** Sinon l'étudiant qui s'abonne sur le site voit le paywall sur son téléphone, et c'est
la panne la plus coûteuse qu'on puisse livrer.

### Ce qui est retenu

**RevenueCat comme source de vérité unique, avec deux rails d'achat derrière : StoreKit sur iOS,
Stripe sur le web, branchés sur le même projet RevenueCat.**

Pourquoi RevenueCat plutôt que « Stripe + les notifications serveur d'Apple, à la main » :

- à la main, il faut implémenter les *App Store Server Notifications V2* — vérification JWS,
  puis toute la machine à états : renouvellement, changement d'intention de renouvellement,
  période de grâce, relance de facturation, remboursement — **et** les webhooks Stripe, **et** la
  réconciliation des deux. C'est le code le plus propice aux bugs qu'on puisse écrire, ses bugs
  sont invisibles (un étudiant perd son accès en silence), et ce n'est pas le produit ;
- côté iOS, les portes existent maintenant mais **rien ne les commande depuis un serveur** :
  `ProAccess` lit un drapeau dans les réglages de l'appareil, et `PaywallPurchases` répond
  `unavailable`. Il reste donc tout l'encaissement à écrire, et **[`docs/revenuecat.md`](revenuecat.md)
  décrit déjà la procédure** — jusqu'au remplacement de `refresh()` par la lecture de
  l'entitlement `pro`. Cette note-là confirme la recommandation au lieu de la contredire : il n'y
  a rien à défaire, il y a le rail web à ajouter à côté du rail App Store ;
- le prix : gratuit sous 2 500 $ de revenu suivi par mois, puis ~1 %. Ce 1 % achète le fait de ne
  pas écrire la machine à états.

### Le mécanisme, concrètement

Ce qui fait qu'un droit multiplateforme marche ou ne marche pas, c'est **l'identité de
l'utilisateur au moment de l'achat**. Une seule règle, et elle ne souffre pas d'exception :

> `app_user_id` **est** l'`auth.users.id` de Supabase, sur les deux plateformes, toujours.

Jamais d'identifiant anonyme généré par le SDK qu'on aliaserait plus tard : l'aliasing d'achats
anonymes est l'endroit où vivent tous les bugs de droits multiplateformes.

Corollaire immédiat, et il faut le décider maintenant : **on ne peut pas vendre avant la
connexion.** L'ordre du parcours iOS est déjà bon — `signIn` puis `trialOffer` puis
`trialReminder` puis `paywall`. Cet ordre devient une contrainte, et il vaut aussi pour le web.

Ensuite :

1. Les deux clients s'identifient auprès de RevenueCat avec l'identifiant Supabase.
2. RevenueCat pointe un webhook sur une Edge Function `revenuecat-webhook`.
3. Cette fonction vérifie le secret partagé et écrit **une** ligne :

   ```sql
   create table if not exists public.entitlements (
     user_id     uuid primary key references auth.users on delete cascade,
     is_pro      boolean     not null default false,
     product_id  text,
     store       text,        -- 'app_store' | 'stripe' | 'promotional'
     period_type text,        -- 'trial' | 'intro' | 'normal'
     expires_at  timestamptz,
     will_renew  boolean     not null default false,
     updated_at  timestamptz not null default now()
   );
   ```

   Cloisonnement : l'utilisateur **lit** sa ligne, **personne** ne l'écrit — la fonction passe
   par la clé de service. C'est exactement la façon dont `directory` est déjà traitée dans ce
   schéma : écriture par le serveur, politique de lecture pour l'intéressé. Le style de la maison,
   donc ça se relira sans effort.
4. Les deux clients lisent le droit à **deux** endroits : le SDK RevenueCat (instantané, tient
   hors ligne, fait foi au moment de l'achat) et `entitlements` par PostgREST (marche sans SDK, et
   c'est ce que le serveur web rend). En cas de désaccord, **le plus généreux des deux gagne** le
   temps d'une session : enfermer dehors un étudiant qui paye est pire qu'une minute offerte.

### Les pièges, écrits d'avance

- **Le piège principal, et il est classique** : quelqu'un qui a acheté sur le web ouvre l'app, et
  StoreKit ne sait rien de son achat. Si le paywall iOS interroge `Product.currentEntitlement`, la
  réponse est « non » et on présente un paywall à quelqu'un qui a déjà payé. **Le paywall iOS doit
  être piloté par le droit, jamais par StoreKit.**
- **Le bouton « Gérer mon abonnement » doit lire `store`** : `app_store` ouvre la feuille de
  gestion d'Apple, `stripe` ouvre le portail de facturation. Un bouton qui ouvre le mauvais
  magasin donne un écran vide et un message au support.
- **L'app ne doit pas orienter vers le site pour payer** — les règles d'Apple sur le sujet
  dépendent de la région et l'autorisation de lien externe est une démarche à part. En pratique :
  aucune phrase du genre « moins cher sur notre site » dans l'app. Le site, lui, vend librement.
- **L'essai de 3 jours se prend deux fois.** Apple accorde son offre d'introduction une fois par
  identifiant Apple, Stripe une fois par client : quelqu'un de déterminé obtient deux essais. C'est
  acceptable, et ça ne vaut pas la peine d'être combattu.
- **Ne jamais faire confiance au client sur le droit.** Le plafond d'usage de l'IA
  (ci-dessous) se vérifie côté serveur, sur la table, pas sur ce que le navigateur affirme.

## Ce qu'il faut réparer avant d'ouvrir le site

Ce point n'est pas négociable et il est indépendant du design.

Aujourd'hui, les quatre Edge Functions répondent à `Access-Control-Allow-Origin: *`, acceptent la
**clé anonyme** comme autorisation, n'ont **aucun** plafond ni comptage, et dépensent de l'argent
fal.ai à chaque appel. La clé anonyme est dans le dépôt, et elle sera dans le paquet JavaScript
du site.

Sur iPhone c'est à peu près tenable : il faut extraire la clé d'un IPA, et il n'y a pas de chemin
navigateur. **Sur le web, une clé dans le paquet plus `*` en CORS plus aucun plafond, c'est une
facture que n'importe qui fait monter depuis une console de navigateur**, et le premier à s'en
apercevoir sera celui qui paye fal.

Donc, avant l'ouverture :

1. **Exiger le jeton de l'utilisateur** — pas la clé anonyme — sur `generate-course`,
   `generate-flashcards` et `explain-selection`. Lire `sub` dans le jeton, et compter.
2. **Compter**, dans une table `ai_usage (user_id, day, function, count)`, avec un plafond par
   jour. C'est **là** que vit la distinction gratuit / Pro : « cours et cartes illimités » est
   déjà la première promesse du paywall, et elle n'est tenue nulle part.
3. **Resserrer le CORS** sur les origines connues plutôt que `*`.
4. `youtube-transcript` reste bon marché mais passe aussi derrière un jeton : en l'état c'est un
   proxy ouvert qui va chercher n'importe quelle URL.
5. **Côté iOS**, `SupabaseFunctions` envoie la clé anonyme et doit envoyer
   `AuthController.validAccessToken()`. Petit changement, mais il veut dire que **l'ouverture du
   site touche l'app** — et donc une soumission App Store. Les fonctions accepteront les deux
   pendant une version, sinon les app déjà installées cassent.

L'autre voie serait de relayer les appels IA par des routes Next.js, en gardant la clé fal côté
Vercel. Ça règle le web et **pas** l'iPhone, et ça coupe le chemin de l'IA en deux. Mieux vaut le
réparer une fois, dans l'Edge Function.

## La première fiche sans compte

C'est la plus grosse question de produit du site, et elle se décide avant le code.

turbo.ai laisse essayer avant de se connecter. Le parcours iOS demande au contraire le compte
après dix-sept écrans de démonstration, et c'est juste **là-bas** : quelqu'un qui a installé une
app s'est engagé. Un visiteur qui arrive d'une recherche ne s'est engagé à rien.

Proposition : **une fiche gratuite sans compte.** On dépose un PDF dans l'accroche, on regarde
la fiche s'écrire — la vraie, par la vraie Edge Function — on la lit. Ensuite, la garder, ou en
tirer des cartes, demande de se connecter, et la fiche est rattachée au compte à ce moment-là.
Supabase sait ouvrir une session anonyme (`anonymous_users` est à `false` aujourd'hui, il faudrait
l'allumer) : ça donne une vraie ligne dans `auth.users`, donc un vrai UUID, donc **le
cloisonnement continue de marcher sans une ligne de SQL en plus**, et le rattachement n'est qu'une
liaison d'identité.

Ça coûte un appel fal par visiteur, et c'est exactement pourquoi la section précédente doit être
faite d'abord : un appel par visiteur et par jour, plafond dur, et une limite de taille sur le
dépôt.

## Déployer sur Vercel

Le projet existe déjà (`adriens-projects-145ae26c/micabo`). Les étapes, dans l'ordre :

1. **Settings → Build & Development**
   - Framework Preset : **Next.js**
   - **Root Directory : `web`** ← sans ça, la compilation part de la racine du dépôt et échoue sur
     le projet Xcode. C'est le seul réglage qui casse tout si on l'oublie.
   - Laisser Vercel déduire le gestionnaire de paquets en déclarant `"packageManager": "pnpm@10"`
     dans le `package.json`, plutôt que de figer une commande d'installation.
2. **Settings → Git** : le dépôt GitHub, branche de production `main`. Toute autre branche reçoit
   son URL de prévisualisation — d'où le joker dans les Redirect URLs de Supabase.
3. **Settings → Environment Variables**, pour les trois environnements (Production, Preview,
   Development) :

   ```
   NEXT_PUBLIC_SUPABASE_URL       = https://khuzodsrznanzhwlbjbx.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY  = (celle de AppConfig.swift)
   NEXT_PUBLIC_SITE_URL           = https://micabo.app
   SUPABASE_SERVICE_ROLE_KEY      = (serveur uniquement)
   STRIPE_SECRET_KEY              = (serveur uniquement)
   STRIPE_WEBHOOK_SECRET          = (serveur uniquement)
   REVENUECAT_WEBHOOK_SECRET      = (serveur uniquement)
   ```

   **La clé de service ne porte jamais le préfixe `NEXT_PUBLIC_`** et ne se lit que dans une route
   serveur. Un préfixe `NEXT_PUBLIC_` sur cette clé publie un accès total à la base dans le
   paquet JavaScript.
4. **Settings → Domains** : `micabo.app` et `www.micabo.app` (redirection de `www` vers l'apex). Si
   le domaine est acheté ailleurs, soit on déplace les serveurs de noms chez Vercel, soit on pose
   les enregistrements A/CNAME qu'il affiche. Ensuite **et seulement ensuite**, mettre à jour la
   Site URL et les Redirect URLs de Supabase, puis les domaines du Service ID Apple.
5. **`web/vercel.json`** : uniquement pour les redirections et les en-têtes de sécurité
   (`Strict-Transport-Security`, `X-Content-Type-Options`, et une `Content-Security-Policy` une
   fois la liste des tiers arrêtée).
6. **Ne pas indexer les prévisualisations** : un `robots.ts` qui renvoie `noindex` dès que
   `process.env.VERCEL_ENV !== 'production'`. Sinon Google indexe une prévisualisation et la
   présente à la place du site.

### Ce que l'accès Vercel permet, et ce qu'il ne permet pas

Le MCP Vercel est branché, et il vaut la peine d'écrire précisément ses limites, parce que deux
d'entre elles décident de la façon dont le projet est câblé.

| Je peux | Je ne peux pas |
| --- | --- |
| Lire les projets, les déploiements, **les journaux de compilation et d'exécution** | Poser une **variable d'environnement** |
| **Créer** un projet lié au dépôt **avec son `rootDirectory`** | Changer le `rootDirectory`, le framework ou les commandes d'un projet **déjà créé** |
| Déployer, mettre en pause, régler la protection de déploiement | **Rattacher un domaine** à un projet, ou toucher au DNS |
| Vérifier la disponibilité d'un domaine, son prix, et **l'acheter** | |

Deux conséquences, et la première est heureuse :

**Le site n'aura besoin d'aucune variable d'environnement avant l'étape 5.** L'URL Supabase et la
clé publiable sont publiques par nature et sont **déjà écrites en clair dans le dépôt**
(`AppConfig.swift`) : le web fait pareil, une valeur par défaut dans `web/lib/config.ts`, que
`process.env.NEXT_PUBLIC_*` remplace si elle existe. C'est exactement le motif de l'app, et ça
veut dire qu'un déploiement compile et tourne sans que personne n'ait rien collé dans un tableau
de bord. Seuls les secrets **serveur** — clé de service, Stripe, webhook RevenueCat — sont de
vraies variables, et ils n'arrivent qu'à l'étape 5.

**Le `rootDirectory` se règle à la création, et la création a échoué.** Ce n'est plus une
hypothèse : la tentative de créer un second projet sur le même dépôt a rendu un identifiant puis
un `404` — le projet n'existe pas. Il ne reste donc que `micabo`, créé sans `rootDirectory`, et
aucune API de ce MCP ne permet de le corriger.

Et le journal de compilation dit exactement ce que ça produit :

```
Running "vercel build"
Build Completed in /vercel/output [147ms]
```

**Cent quarante-sept millisecondes, et rien de compilé.** Vercel ne trouve pas de framework à la
racine du dépôt, donc il publie l'arborescence telle quelle — le déploiement est vert, et le site
n'existe pas. C'est le piège le plus désagréable de la liste, parce qu'il ne ressemble pas à une
panne.

Il reste donc **un clic, et il est indispensable** : *Settings → Build & Development → Root
Directory → `web`*. Après lui, tout le reste suit sans rien d'autre — pas même une variable
d'environnement.

Le domaine, enfin : `micabo.app` est **libre, à 9,99 $ pour un an** ; `micabo.com` est pris ;
`micabo.io` et `micabo.co` sont à ~30 $. Je peux l'acheter depuis ici, sur devis puis
confirmation explicite — mais **je ne peux pas le rattacher au projet**, donc l'achat ne sert à
rien avant que vous fassiez ce clic-là. Autant l'acheter vous-même dans le même passage.

## Ce que le site casse côté iOS

Trois dettes que le site va révéler, et qu'il vaut mieux traiter dans **la même version** que le
passage des Edge Functions au jeton utilisateur :

| Dette | Effet sur le web | Ce qu'il faut |
| --- | --- | --- |
| `exams` et `review_logs` sont montés mais **jamais redescendus** | Un examen créé sur le site n'apparaît jamais sur l'iPhone | Ajouter les deux descentes dans `CloudSync`, avec leur filtre `user_id` |
| `Exam.scheduleBackup` est local | Le web ne peut pas **dé-planifier** un examen planifié sur l'iPhone : la sauvegarde des dates d'avant n'existe que là-bas | Une colonne `schedule_backup jsonb` sur `exams` |
| Images d'occlusion, audio, couvertures ne montent pas | Ces cartes s'affichent sans leur image | Un seau de stockage, plus tard. En attendant, une ligne honnête dans l'interface |

Et la leçon déjà écrite dans le README s'applique mot pour mot au client web : **une requête qui
compte sur le cloisonnement pour ne pas ramasser les lignes des autres est une requête qu'une
politique ajoutée un jour recasse.** Chaque descente du web porte son filtre `user_id`, y compris
celles dont la table n'a qu'une seule politique.

## Le parcours d'accueil du web

**Ce n'est pas la page d'accueil, et ce n'est pas celui de l'iPhone.** Neuf écrans contre
vingt-deux, et surtout un ordre inversé sur le point qui compte : **le compte se crée au deuxième
écran**, avant toute question. C'est juste ici et faux là-bas — quelqu'un qui a installé une app
s'est engagé, et le tunnel iOS a dix-sept écrans pour donner une raison ; sur le web, où la
question suivante est « dans quel pays », un compte demandé tôt est un compte demandé avant qu'on
ait rien à perdre. Et ça tombe bien : la règle de l'abonnement veut qu'**on ne vende jamais avant
la connexion**, et le paywall est le dernier écran.

| # | Écran | Contenu |
| --- | --- | --- |
| 0 | **Accueil** | « Bienvenue sur la première intelligence artificielle qui aide les élèves à travailler et à approcher les examens sans stress. » |
| 1 | **Le compte** | Titre « L'application que les meilleurs élèves ne veulent pas que tu connaisses. », sous-titre « Crée ton compte en 10 secondes. » Apple, Google, courriel. Mention des CGU et de la politique de confidentialité |
| 2 | **Le pays** | « Tu étudies dans quel pays ? » / « Pour te proposer le bon système scolaire. » Le pays détecté **en premier et déjà en évidence**, drapeau compris, puis les plus fréquents |
| 3 | **Le niveau** | « Qu'est-ce qui te décrit le mieux ? » Les réponses sont **celles du pays choisi** (`EducationStage`) |
| 4 | **Les matières** | L'écran du mobile, adapté au web : les sept familles de `SubjectCatalog`, un emoji par matière, sans tuile |
| 5 | **La date d'examen** | « C'est quand, ton prochain examen ? » / « Micabo te créera un parcours adapté à ton examen, pour que tu arrives plus prêt que jamais. » Un calendrier posé directement, les mois défilent, **il est toujours calé sur aujourd'hui**. Au-dessus, le raccourci « Je sais pas encore ». Dès qu'une date est prise, le bouton **« Réussir cet examen »** apparaît et brille ; au clic, « Il te reste X jours. On va bien s'organiser. » s'écrit **mot par mot**, puis « Voir comment ça marche » |
| 6 | **La démonstration** | Les trois étapes du mobile, mêmes animations, adaptées au web. Et une chose que le mobile ne peut pas faire : sur la troisième, **les cartes se retournent au survol de la souris** |
| 7 | **L'école** | « Tu étudies dans quelle école ? », le même autocomplete hybride qu'iOS — catalogue embarqué puis la RPC `search_institutions` — et le même « Passer » |
| 8 | **Le paywall** | « Ne rate pas l'occasion de devenir le meilleur de ta classe » / « Débloque tout Micabo et arrive préparé. » Les avantages en tableau, une ligne par point. Deux formules, l'annuelle en avant avec son économie et son prix ramené au mois. **Une croix pour fermer, visible tout de suite.** En bas, les liens légaux. **Vide pour l'instant** — il se remplit à l'étape 5 |

L'habillage, commun aux écrans 2 à 8 : une barre de progression en haut, un bouton retour, et le
bouton principal en bas **gris tant qu'on n'a pas répondu**.

Le bouton retour est une **divergence assumée** avec l'iPhone, où le parcours est « strictement
linéaire, ni retour arrière ni balayage ». Un navigateur a une flèche retour de toute façon : ne
pas la servir ne rend pas le parcours linéaire, ça le rend cassé.

### Ce que le parcours écrit

Les écrans 2, 3, 4 et 7 remplissent `profiles` — `country_code`, `study_level`, `subjects`,
`institution_id`, `institution_name`, `onboarding_completed_at` — dans les mêmes colonnes que
l'iPhone. Un étudiant qui commence sur le web arrive donc **déjà configuré** sur son téléphone, et
l'app doit sauter son propre parcours : `onboarding_completed_at` non nul, redescendu par
`CloudSync`, en est le signal.

L'écran 5 est le seul qui écrit ailleurs : il **crée une ligne dans `exams`**. C'est une bonne
nouvelle pour le produit et une contrainte technique immédiate — `CloudSync` monte `exams` mais ne
les redescend **jamais**. En l'état, un étudiant qui donne sa date d'examen sur le web ouvre son
téléphone et n'y trouve aucun examen. **La descente d'`exams` passe donc de dette à chemin
critique.**

### Cinq trous dans la spec, et ce que je propose

1. **`dailyMinutes` n'est demandé nulle part**, et c'est lui qui commande le plafond de cartes
   neuves (`max(2, round(minutes / 2))`). Je **n'ajoute pas d'écran** : la date d'examen est une
   bien meilleure question que « combien de minutes par jour », et l'ajouter casserait le rythme du
   tunnel. On garde le défaut de 15 minutes, soit 8 cartes neuves par jour, corrigeable dans les
   réglages — c'est déjà le défaut de l'app.
2. **« Économise 60 % » ne se calcule pas, et l'app a déjà réglé ça.** Le nombre était faux, et
   il l'est resté après le changement de prix — c'est 86 % aux prix du catalogue. Mais la bonne
   correction n'est pas d'écrire le bon nombre : `PaywallCatalog.savingsPercent` le **calcule**
   depuis les deux prix, pour la raison que son commentaire donne — « une remise annoncée à côté
   de deux prix qui la contredisent est le genre de détail qu'on ne remarque qu'une fois en
   production ». Le site fait pareil, et l'écran 8 n'écrira aucun pourcentage à la main. Voir
   [Les offres](#les-offres-et-léconomie-annoncée).
3. **La connexion par courriel ne marchera pas en production**, et pas à cause du site : le projet
   répond `mailer_autoconfirm: false`, donc l'adresse doit être confirmée avant la première
   connexion — ce qui contredit « crée ton compte en 10 secondes » — et l'envoyeur de démonstration
   de Supabase est plafonné à quelques courriels par heure. Il faut brancher un vrai envoyeur
   (Resend, Postmark, SES) dans *Project Settings → Authentication → SMTP*. En attendant, Apple et
   Google sont en premier et le courriel est en troisième position, où son échec ne bloque personne.
4. **« Restaurer mes achats » est une notion iOS.** Sur le web, avec Stripe, il n'y a rien à
   restaurer : ce qu'il faut à cette place, c'est « J'ai déjà un abonnement », qui mène à la
   connexion. Le libellé iOS reste sur iOS.
5. Les objectifs et le rapport à l'oubli du tunnel iOS **ne sont pas repris**, et c'est sans
   conséquence : `learning_goals` ne sert à rien dans la rédaction d'une fiche aujourd'hui. La
   colonne reste vide pour un compte né sur le web.

## Le verrou du gratuit

**Correction : il existe, et il n'est plus à concevoir.** Ce document a d'abord écrit que « même
système freemium que sur iOS » décrivait ce qu'on voulait plutôt que ce qu'il y avait. C'était
vrai du dépôt que j'avais sous les yeux ; la PR #37 a livré entre-temps `ProAccess.swift`,
`SheetGate`, deux paywalls natifs enchaînés, un paywall de session, `FreemiumTests` qui verrouille
les nombres, et **[`docs/revenuecat.md`](revenuecat.md)** qui détaille le branchement complet.

C'est donc l'app qui fait foi, et le site s'y aligne au chiffre près. Un cours flouté aux sept
dixièmes sur le téléphone et à la moitié sur le web serait le même produit qui dit deux choses.

| | Gratuit | Pro |
| --- | --- | --- |
| **Cours importés** | **un**, et un seul. Un cours *repris* dans la bibliothèque ne consomme pas le quota : il n'a rien coûté à produire | sans limite |
| **Fiche** | les **sept dixièmes de ses blocs**. La suite est composée, puis floutée et fondue dans le papier, avec le cadenas posé au bas du fondu | entière |
| **Session** | **cinq cartes**, la cinquième comprise | sans limite |
| **Entraînement libre** | fermé | ouvert |

La forme est celle qui convertit, et elle est déjà en place : **on génère, puis on floute.** Les
blocs restants sont *bel et bien composés* avant d'être brouillés — c'est ce qui fait la
différence entre « il y a une suite » et « ça s'arrête là ». Une fiche coupée net se lit comme une
fiche courte, et une fiche courte ne donne envie de rien.

Deux détails d'implémentation valent d'être repris tels quels, parce qu'ils sont justes :

- **la coupure se compte en blocs, pas en caractères.** Couper un paragraphe au septième dixième
  de son texte donnerait une phrase interrompue au milieu d'un mot, ce qui ressemble à un bug
  d'affichage plutôt qu'à une limite assumée. Et il reste toujours au moins un bloc lisible ;
- **le pourcentage restant est calculé**, pas écrit. « Il te reste 30 % de ce cours à lire » sort
  du ratio, donc il suivra si le ratio bouge.

### Ce que le site en fait

`packages/core/src/entitlement.ts` porte les mêmes nombres et la même coupure, et
`test/entitlement.test.ts` reprend les valeurs de `MicaboTests/FreemiumTests.swift`. Mais
**`ARMED` reste à `false`**, et la raison a changé : ce n'est plus « l'encaissement n'existe pas
encore », c'est qu'il n'y a **rien à lire**. `ProAccess` s'appuie sur un drapeau dans les réglages
de l'appareil ; il n'existe aucune table `entitlements`, donc le site ne peut pas savoir qui est
abonné. Armer le verrou maintenant enfermerait dehors un étudiant qui vient de payer sur son
téléphone — ce qui est exactement la panne que ce document met en garde contre depuis le début.

L'interrupteur bascule à l'étape 5, quand le webhook écrira le droit en base.

## Les offres, et l'économie annoncée

Les prix ont bougé avec la PR #37, et la forme de l'offre aussi : ce n'est plus un mensuel mais
un **hebdomadaire**.

| Offre | Prix | Sur douze mois |
| --- | --- | --- |
| Annuel — recommandé | **59,99 €** | 59,99 € |
| Hebdomadaire | **7,99 €** | 415,48 € |

Ce qui règle le trou n° 2 de la spec, mais pas dans le sens prévu : **l'app calcule son
pourcentage d'économie au lieu de l'écrire**, et aux prix du catalogue l'annuel économise
**86 %**, pas 60. Le commentaire de `PaywallCatalog.savingsPercent` dit exactement pourquoi :
« une remise annoncée à côté de deux prix qui la contredisent est le genre de détail qu'on ne
remarque qu'une fois en production ».

Le site fait donc pareil : `packages/core/src/pricing.ts` porte les deux offres et calcule. **Le
paywall du parcours d'accueil n'écrira aucun pourcentage à la main**, et « Économise 60 % » de la
spec devient « Économise {calcul} % ».

Deux conséquences de forme sur l'écran 8 : le « prix ramené au mois » ne vaut que pour l'annuel
— 5,00 € / mois — et l'hebdomadaire porte « facturé chaque semaine », parce qu'il n'y a pas de
mois à ramener. L'essai reste de **trois jours**.

## Le plan, en cinq étapes

| Étape | Contenu | Ce qui est vrai à la fin |
| --- | --- | --- |
| **1. Les fondations** | Monorepo `web/`, projet Vercel avec `rootDirectory`, port de `MicaboTheme` en CSS, client Supabase avec ses valeurs par défaut committées, Redirect URLs. Et **`packages/core` avec ses tests** : schéma de fiche, balisage en ligne, SM-2, `DailyLoad`, file d'étude, `ExamPlanner`, `RetentionCurve` | Un déploiement vert, et les nombres de `SM2SchedulerTests` vérifiés en TypeScript |
| **2. La page d'accueil** | Les neuf sections, les vrais composants, le vrai document de démonstration, les règles de survol, la feuille d'impression, `thinking-orbs` là où elle sert | Le site public existe et se lit |
| **3. Le parcours d'accueil** | Les neuf écrans ci-dessus, la barre de progression, le retour, le bouton gris. Écriture dans `profiles`, création de la ligne `exams`, paywall vide | On crée un compte sur le web et on en sort configuré |
| **4. L'app web** | Cours, fiche, cartes, **session au clavier**, examens, import (dépôt, collage, YouTube). Et d'abord la réparation : jeton utilisateur sur les Edge Functions, `ai_usage`, CORS resserré | Le web est un produit qu'on utilise |
| **5. L'argent, et l'accord des deux clients** | `entitlements`, webhook RevenueCat, Stripe Checkout, **le verrou armé**. Côté iOS : RevenueCat, le jeton sur les Edge Functions, et les descentes d'`exams` et de `review_logs` | Le web encaisse, et l'iPhone est d'accord avec lui |

**La réparation de l'étape 4 bloque l'import**, et pas l'inverse : on ne livre pas un point
d'entrée d'IA appelable depuis un navigateur, sans jeton et sans plafond. Et l'étape 5 est la seule
qui **touche l'app iOS**, donc la seule qui demande une soumission App Store.

### Où en est l'étape 1

Faite, à un clic près. Le monorepo est dans [`web/`](../web/README.md), les jetons sont dans
`app/globals.css`, et `packages/core` porte **104 tests** — dont ceux de `SM2SchedulerTests`,
`FreemiumTests` et `PaywallTests` repris nombre pour nombre.

Le port sur le code plutôt que sur un résumé a rattrapé trois choses, et c'est sa justification :

- **l'arrondi de `DailyLoad` va au plus loin de zéro**, donc 25 minutes donnent 13 cartes neuves
  et non 12. Sur un an, c'est une carte par jour de moins ;
- **un `**` non fermé n'est pas laissé littéral** par `SheetMarkup` : la première astérisque
  ouvre une italique que la seconde ferme, et les deux marques disparaissent. Le port reproduit
  le comportement plutôt que de le corriger — une fiche rendue autrement sur le web serait une
  fiche différente. Le jour où ça se corrige, ça se corrige des deux côtés ;
- **le gratuit et les prix avaient changé** sous mes pieds, ce qui est le sujet des deux sections
  plus haut.

Ce qui reste ouvert à la fin de l'étape : la page à la racine est **la référence des fondations,
pas la page d'accueil** — elle affiche les jetons et calcule tous ses nombres avec
`packages/core`, ce qui en fait aussi une vérification de bout en bout. Et le site n'est pas
indexable, parce qu'il n'y a rien à trouver encore.

### Où en est l'étape 2

Faite. La page d'accueil existe, sous `/` ; la référence des fondations est passée sous
`/fondations`.

**La signature fonctionne, et c'est ce qui a demandé le plus de reprises.** Le polycopié brut et
la fiche occupent le même rectangle, qui reste immobile pendant qu'on défile : le balayage de
lecture descend sur la page brute, puis la fiche s'écrit par-dessus, bloc après bloc. Deux
défauts ont dû être corrigés avant que ça tienne, et le premier était une erreur de conception de
ma part :

- **c'est la fiche qui doit dimensionner le rectangle, pas la page brute.** La première version
  faisait l'inverse — page brute en flux, fiche en `absolute inset-0` — et la fiche, bien plus
  haute que les cinq lignes qui la portaient, se faisait rogner aux deux tiers. Le rectangle était
  bien unique, et c'était le mauvais ;
- **le balayage se déplace en pixels, pas en pourcentage.** Un pourcentage de `translateY` se
  compte sur la hauteur de *l'élément déplacé* — la bande — et non sur celle de la page : le
  balayage ne parcourait qu'un quart du chemin.

Trois décisions d'honnêteté, parce qu'une page d'accueil qui promet ce qui n'existe pas coûte plus
cher que celle qui l'admet :

| Ce qui manque | Pourquoi, et ce qui est à la place |
| --- | --- |
| **La zone de dépôt de l'accroche** | Elle ne peut pas encore mener quelque part : la génération demande le jeton utilisateur et le plafond d'usage, qui sont à l'étape 4. Une zone qui accepte un document et ne le lit pas est exactement le faux appel à l'action que ce site s'interdit. Elle arrivera avec le parcours d'accueil, qui est ce qu'il y a derrière |
| **Le badge App Store** | L'app n'est pas publiée. Un badge qui ne mène nulle part est un mensonge ; le pied de page dit « l'app iOS arrive » |
| **Le bouton d'abonnement** | Il n'y a pas d'encaissement avant l'étape 5. Les prix sont écrits — une grille qui cache son prix se lit comme un tunnel de vente — et il n'y a pas de bouton |

À la place, **l'appel à l'action est une liste d'attente, et elle écrit vraiment en base.** Une
table `waitlist`, insertion anonyme et **aucune politique de lecture** : une politique de lecture
même restreinte exposerait la liste des adresses de tous les inscrits à n'importe quel visiteur.
La forme de l'adresse est vérifiée dans la politique et pas seulement dans le formulaire, parce
qu'une validation côté client se contourne avec une console. Les quatre comportements ont été
vérifiés contre le vrai projet : insertion acceptée, doublon refusé sur la casse, adresse malformée
refusée par la politique, et lecture anonyme qui ne rend rien.

Au passage, le conseiller de sécurité de Supabase signalait une erreur qui n'a rien à voir avec le
site : **`_seed_buf`**, le brouillon laissé par l'import de l'annuaire des établissements, était
exposé sans cloisonnement — un point d'écriture ouvert à tout le monde, sur la facture du projet.
Le cloisonnement y est activé sans aucune politique, ce qui la rend inerte depuis l'API tout en la
laissant utilisable par la clé de service.

Et `thinking-orbs` sert enfin là où elle doit : en 20 px, à même la ligne du bouton, pendant qu'on
parle au serveur. Monochrome, donc elle ne se bat pas avec le vert.

**Ce qui a été vérifié à l'écran**, plutôt que déduit du code : le rectangle reste immobile et la
fiche n'est plus rognée, les cartes se retournent au survol, à l'appui **et au clavier** — le
survol seul ne pouvait pas suffire, une réponse qu'on n'atteint qu'à la souris est une réponse
inaccessible — et la page tient à 400 px de large sans débordement horizontal.

## Les décisions prises

| # | Question | Réponse |
| --- | --- | --- |
| 1 | Le domaine | **`micabo.app`**, acheté par Adrien. Libre, 9,99 $/an. `micabo.com` est pris. Un seul domaine, l'app sous `/app` |
| 2 | Le nom public | **Micabo**, définitif |
| 3 | Le parcours d'accueil du web | Fourni, transcrit ci-dessus. **Le compte est au deuxième écran**, avant les questions |
| 4 | La police des nombres | **Nunito**, variable, et **uniquement pour les nombres** |
| 5 | L'encaissement | **Stripe Checkout derrière RevenueCat** |
| 6 | Le gratuit | Aligné au chiffre près sur `ProAccess.swift` : un cours, sept dixièmes de la fiche, cinq cartes par session |
| 7 | La couche de composants | **Base UI**, habillée par coss.com/ui, complétée par les variantes Base UI de ReUI |
| 8 | Les icônes | **Phosphor**, pour sa variante pleine — contour par défaut, plein pour l'actif |
| 9 | Le mouvement | La fréquence décide. **La session ne s'animera pas**, la démonstration si |

**Sur le choix 4**, puisqu'il m'était laissé : Nunito est la plus proche des arrondies libres de
l'intention de SF Rounded — de vraies terminaisons arrondies, et une graisse variable de 200 à
1000, donc un seul fichier. Le reproche qu'on peut lui faire est d'être partout ; il ne porte pas
ici, parce qu'elle ne compose **jamais un mot**. Elle ne sert qu'aux nombres qui se lisent comme un
résultat — le compte de cartes du jour, la série, les statistiques d'une session, les jours qui
restent avant l'examen — exactement le domaine de `MicaboFont.number`.

Et ce n'est pas une nouvelle décision de typographie, c'est le report d'une décision existante :
l'app fait déjà tourner ce couple exact, un grotesque pour les mots et une arrondie pour les
nombres. La règle « on n'introduit pas une police pour cocher une case » est donc respectée — deux
familles, chacune avec un domaine net, et un contraste réel entre elles plutôt que deux sans-serif
presque identiques, ce qui se lirait comme une erreur.

## Où vivent les standards

Les ressources d'interface sont **installées dans le dépôt**, sous `.agents/skills/`, plutôt que
lues une fois et oubliées. Elles portent des valeurs exactes — des cubic-bezier, des opacités, des
durées — et une valeur exacte lue de mémoire devient une valeur approximative.

| Skill | Ce qu'elle tranche |
| --- | --- |
| `better-ui` | Rayons concentriques, ombres contre bordures, contours d'images, appui à `0.97`, transitions interruptibles |
| `better-typography` | Choix et appairage des familles, échelle, chiffres tabulaires, césure et ponctuation |
| `better-layout` | Groupement, alignement, ordre de lecture, espacement, adaptativité |
| `better-accessibility` | Focus, clavier, ARIA, zones de touche, mouvement réduit |
| `better-writing` | Libellés, erreurs, états vides — à lire **avec** `MicaboCopy.swift`, qui garde le dernier mot sur le vocabulaire |
| `improve-animations` | Le catalogue de mouvement d'Emil Kowalski, dont la table des fréquences |
| `frontend-design` | La direction visuelle, et la liste des clichés à ne pas produire |

Deux précautions valent d'être écrites, parce qu'elles vont se poser en pratique :

**Ces guides ne rejugent pas les décisions de Micabo.** Leur propre règle le dit — une décision de
conception documentée se respecte. Quand `improve-animations` recommande un ressort à `bounce: 0.2`
et que le README explique sur dix lignes pourquoi rien ne rebondit, c'est le README qui gagne. Idem
pour le crème, pour le lexique, pour les trois onglets.

**Et là où ils se contredisent entre eux, on tranche et on l'écrit.** Ils divergent déjà sur
l'échelle d'appui (0,96 contre 0,97) et sur l'échelonnement (100 ms contre 30–80 ms). Un projet qui
suit deux guides sans arbitrer finit avec les deux valeurs dans son code.

Une dernière chose que je n'ai pas pu faire : **`designsystemchecklist.com` n'a jamais répondu**,
sur trois essais. J'en connais la structure — langage de conception, fondations, composants,
maintenance — mais pas ses items un par un, et je ne vais pas prétendre le contraire. Ce que j'en
retiens est l'ordre de travail, qui est de toute façon le bon : **les fondations avant les
composants**, et un composant fini est un composant qui a tous ses états. Si vous y tenez, un
export JSON de leur site suffirait à le brancher pour de vrai.

## Ce qui reste ouvert, et ce que j'en fais en attendant

Rien là-dedans ne bloque les étapes 1 à 4. Chaque ligne dit ce que je fais par défaut, pour qu'un
silence ne coûte rien.

| Point | Par défaut, je fais | Pourquoi |
| --- | --- | --- |
| Les **« 500 000 étudiants »** de l'écran de preuve sociale | **rien** : le chiffre n'apparaît pas sur le site | Sur un site indexé c'est une allégation commerciale. Mieux vaut pas de chiffre qu'un chiffre indéfendable. La section se remplit en une constante le jour où il y a un vrai nombre |
| La **langue** du site | **français seul**, mais toute la copie dans un seul module, à la manière de `MicaboCopy.swift` | Ajouter `/en` devient alors un dictionnaire de plus, pas une refonte du routage |
| Le **partage de fiche** | rien avant l'étape 5 | `courses.visibility` a déjà trois valeurs ; un lien web public est un quatrième état et je préfère le modéliser franchement plus tard que surcharger `public` maintenant |
| Le **prix du web** | identique à iOS : 59,99 €/an, 7,99 €/semaine | Simple et honnête ; l'écart de marge est invisible pour l'étudiant, et les deux offres vivent déjà dans une seule constante partagée |
| L'**économie annoncée** sur l'annuel | **calculée**, donc 86 % aujourd'hui | Elle sort des deux prix et les suivra. Rien à décider |

### Une idée qui règle une tension

La page d'accueil veut une zone de dépôt à la place du bouton, et le parcours veut un compte au
deuxième écran. Les deux se contredisent en apparence, et ils se complètent en fait : **on dépose
son polycopié sur la page d'accueil, et la fiche s'écrit pendant qu'on crée son compte.**

La génération prend une trentaine de secondes, et c'est du temps mort qu'on passe aujourd'hui à
regarder une animation. Le parcours d'accueil dure, lui, une ou deux minutes. Les faire tourner
**en parallèle** ne coûte rien, et ça change deux choses : le paywall du dernier écran tombe au
moment exact où une fiche finie attend derrière lui, et le premier écran de l'app n'est pas une
liste vide mais **son cours à soi, déjà fiché**.

Ça demande la session anonyme de Supabase (`anonymous_users` est à `false` aujourd'hui) pour que
la fiche ait un propriétaire avant que le compte existe, puis une liaison d'identité à l'écran 1.
Le cloisonnement continue de marcher sans une ligne de SQL en plus. Et ça demande le fusible
d'`ai_usage`, parce qu'une génération offerte par visiteur est une génération offerte à tout le
monde.

## Les quatre clics que je ne peux pas faire

Ni le MCP Supabase ni le MCP Vercel n'exposent la configuration d'un projet — l'un fait du SQL, des
Edge Functions et des branches, l'autre lit des déploiements et crée des projets. Ce qui suit est
donc à faire à la main, et c'est tout ce qui manque.

| # | Où | Quoi | Ce que ça débloque |
| --- | --- | --- | --- |
| 1 | Supabase → Authentication → **URL Configuration** | Les trois **Redirect URLs** (dont le joker de prévisualisation), et la **Site URL** | **La connexion sur le web.** Je peux écrire tout l'écran, je ne peux pas vérifier l'aller-retour OAuth |
| 2 | Vercel → Settings → Build & Development | **Root Directory → `web`**. Ce n'est plus conditionnel : la création d'un second projet par le MCP a échoué | **Tout le site.** Sans lui, la compilation ne trouve pas de framework à la racine, publie l'arborescence du dépôt en 147 ms et rend un déploiement **vert** — la panne ne ressemble pas à une panne |
| 3 | Vercel → Domains, puis Supabase et Apple | Acheter `micabo.app`, le rattacher, puis reporter le domaine dans la Site URL, les Redirect URLs et le Service ID Apple | Le vrai domaine. Peut attendre : les URL `*.vercel.app` suffisent pour tout construire |
| 4 | Supabase → Project Settings → **SMTP** | Un vrai envoyeur (Resend, Postmark, SES) | La connexion par **courriel** de l'écran 1. Apple et Google marchent sans |

Ce que je peux faire moi-même, en revanche, et qui couvre le reste : appliquer des migrations,
déployer des Edge Functions, lire les avis de sécurité, déployer, et **lire les journaux de
compilation** — donc corriger un build cassé sans attendre, ce qui est la capacité qui compte le
plus dans la liste.
