# Refonte iOS de Micabo

De l'outil qui fabrique des cartes au compagnon qui organise une année. Diagnostic chiffré,
fluidité, repositionnement, entonnoir, et ce qu'il faut avoir livré en décembre.

Relevé le 19 septembre 2026, sur la branche `claude/micabo-ios-refonte-xobnwh`
(9 commits devant `main`), base Supabase `khuzodsrznanzhwlbjbx`.

---

## Comment lire ce document

`docs/plan-amelioration.md` reste valable sur ce qu'il couvre, mais il a été écrit sur un état
à ~10 400 lignes de Swift, sans compte, sans synchronisation, sans examens, sans bibliothèque
et **sans un seul utilisateur**. Il y en a 875 aujourd'hui. Ce document-ci ne le remplace pas :
il le corrige là où les chiffres le contredisent, et il traite ce dont l'autre ne parle pas —
la fluidité, le chapitre, le planning, l'écoute, et le fait que personne ne paie.

Trois natures de chiffres, à ne pas confondre :

| Marque | Origine | Confiance |
| --- | --- | --- |
| **mesuré** | requête SQL sur la base de production, ce jour | dur |
| **lu** | une ligne de code, citée en `fichier:ligne` | dur |
| **relevé** | App Store via Appllama, ou rapport public cité | ordre de grandeur |

Ce qui n'est marqué d'aucune des trois est une opinion, et se lit comme telle.

**Deux contraintes posées par Adrien, tenues dans tout le document.** L'offre ne bouge pas
(39,99 €/an, 6,99 €/mois, 3 jours d'essai, modèle freemium) — §6.5 dit ce que cette contrainte
coûte, avec les chiffres, et s'arrête là. Les règles figées du `README` (trois onglets, lexique
verrouillé, tutoiement) sautent quand elles gênent — §5 en casse deux.

---

## 1. Ce que disent les chiffres

### 1.1 L'entonnoir, en une table

875 comptes créés depuis le 25 août. La montée est réelle et rapide : 2, puis 6, puis 293, puis
574 comptes par semaine ; 164 le 15 septembre, 145 le 16, 98 le 17. **L'acquisition marche.**
Tout ce qui suit est ce qui se passe après. *(mesuré)*

| Étape | Comptes | Sur le total |
| --- | --- | --- |
| Compte créé | 875 | 100 % |
| A un cours en base | 116 | 13,3 % |
| A des cartes | 64 | 7,3 % |
| A révisé au moins une carte | 26 | 3,0 % |
| **A révisé deux jours différents** | **0** | **0,0 %** |
| Droit Pro | 1 | 0,1 % |

Et ce droit Pro unique porte `store = 'promotional'`, `product_id = null`,
`will_renew = false`. C'est une faveur, pas un achat.

> **Micabo n'a jamais encaissé un euro.** Le taux de conversion n'est pas de 1 %. Il est de zéro
> sur 875. *(mesuré)*

### 1.2 Le fait central : sur iPhone, personne n'a jamais révisé

Il faut séparer les deux plateformes, parce qu'elles ne racontent pas la même histoire. Deux
colonnes le permettent : `tour_seen` n'est écrit que par le site (`web/lib/actions/tour.ts:56`),
et `learning_goals` n'est rempli que par l'iPhone (`OnboardingPreferences.goals`, recopié dans
`CloudRecords.swift:131`). *(lu)*

Sur les 217 comptes qui portent la trace iOS — tous ont donc atteint `signIn`, l'étape 26
sur 29 : *(mesuré)*

| Étape | Comptes iOS | Part |
| --- | --- | --- |
| Compte créé (étape 26/29 atteinte) | 217 | 100 % |
| A terminé le parcours d'accueil | 46 | 21 % |
| A appelé le modèle au moins une fois | 67 | 31 % |
| A un cours en base | 17 | 7,8 % |
| A des cartes | 4 | 1,8 % |
| **A révisé une carte** | **0** | **0,0 %** |

Zéro. Pas « peu » : aucune. Les 144 lignes de `review_logs` et les 26 réviseurs de la table
précédente viennent tous du site.

**Ce n'est pas un trou de synchronisation.** `CloudSync` pousse les journaux de révision sans
condition, à chaque montée (`CloudSync.swift:165-166`), entre les cartes et les examens. Une
révision faite sur l'iPhone d'un compte connecté arrive en base. *(lu)*

Tout le reste de ce document découle de cette ligne. Le cœur du produit — une carte qui revient
au bon moment — **ne s'est jamais exécuté une seule fois sur iOS**.

### 1.3 La fuite qui précède tout : trois générations sur quatre n'arrivent nulle part

`ai_usage` compte les appels au modèle, écrits par `consume_ai_quota`. En croisant avec les
cours réellement en base, sur les seuls comptes iOS inscrits **après le 11 septembre** — donc
après le correctif de `pushCards` décrit en commentaire à `CloudSync.swift:183-191` : *(mesuré)*

| Comptes iOS inscrits après le 11/09 | |
| --- | --- |
| Ont appelé le modèle | 77 |
| **N'ont aucun cours en base** | **58** (75 %) |

Le quota est consommé, fal.ai est facturé, et il ne reste rien — ni pour l'utilisateur sur un
second appareil, ni pour toi dans la base. L'incident du 10 septembre est écarté : la fenêtre
choisie lui est postérieure.

**Deux causes, et on peut les séparer.** Le profil lui-même est écrit par `CloudSync`
(`ProfileRecord`, `CloudRecords.swift:122`) : si `profiles.updated_at` n'a jamais bougé depuis
`created_at`, c'est que la synchronisation a tourné une fois, à l'inscription, et plus jamais.
Sur ces 58 comptes : *(mesuré)*

| | Comptes | Ce que ça veut dire |
| --- | --- | --- |
| Profil jamais remonté depuis l'inscription | **39** (67 %) | **`CloudSync` ne retourne pas.** Le cours existe peut-être sur le téléphone, invisible, et perdu à la première réinstallation |
| Profil remonté plus tard, toujours aucun cours | **19** (33 %) | La synchronisation tourne et le cours n'existe quand même pas : généré côté serveur, jamais posé côté client |

Les deux tiers sont donc une **perte de données silencieuse**, pas un échec de génération.

J'ai écarté une troisième hypothèse en la vérifiant. Les correctifs `#293` (antislashs du LaTeX)
et `#294` (formule répétée) sont bien retenus sur la branche, mais le message de `#293` est
explicite : « **Le décodage réussissait donc du premier coup**, rendait un retour chariot collé à
"ightarrow" ». C'est du texte abîmé à l'écran, pas un cours perdu. Ces deux commits sont à
livrer pour la qualité des fiches ; ils n'expliquent pas ce tableau.

### 1.4 Ce que « 1 % » désigne vraiment

Le paywall est l'étape **29 sur 29** (`OnboardingStep.swift:88`). Tout le monde qui finit
l'accueil le voit. 46 comptes iOS l'ont fini, un seul droit Pro existe et il est promotionnel.
*(lu + mesuré)*

Le 1 % est donc une estimation optimiste d'un chiffre réel de zéro. Et le vrai gisement n'est
pas là : **79 % des comptes iOS s'arrêtent entre l'inscription et la fin du paywall**, c'est-à-dire
sur `trialOffer`, `trialReminder`, `paywall` — trois écrans.

Une précision qui compte : **avant `signIn`, on ne sait rien.** Les 25 premières étapes
n'écrivent que dans `UserDefaults` ; `app_events` contient **0 ligne** — le traceur du commit
`#295` est écrit mais pas encore entre les mains des utilisateurs. Combien de personnes
installent et abandonnent avant l'étape 26 : inconnu. *(mesuré)*

### 1.5 La moitié turque

| Pays | Comptes | Ont importé | Ont révisé | Ont appelé le modèle |
| --- | --- | --- | --- | --- |
| **tr** | 428 (49 %) | 52 | 7 | 54 (12,6 %) |
| **fr** | 342 (39 %) | 45 | 12 | 94 (27,5 %) |
| other | 85 | 12 | 4 | 13 |
| es, nl, de, be, gr, ch, ca, uk | 20 au total | 4 | 2 | 4 |

*(mesuré)* Niveaux déclarés : lycée 534, licence 103, non renseigné 85, autre 75, santé 46,
master 27, prépa 3, concours 2.

Deux choses à en tirer.

**La Turquie est le premier marché de Micabo, par accident.** 428 comptes, presque tous venus
du site. C'est la moitié de la base, et personne ne l'a décidé. Un Turc en terminale prépare le
YKS ; un catalogue par programme qui ignore ça ignore la moitié des inscrits.

**Mais le Français est deux fois plus engagé** : 27,5 % appellent le modèle contre 12,6 %, et
12 révisions contre 7 sur un tiers de comptes en moins. Le trafic turc est plus gros et plus
froid.

Puisque les cinq langues sont une vraie ambition et pas une vitrine, il faut arbitrer
explicitement — je le fais en §5.2, et c'est le seul endroit du document où je choisis à ta
place.

### 1.6 Le reste, en vrac, et ce que ça dit

*(mesuré)* 146 cours, dont 4 supprimés. Sources : **PDF 80, YouTube 25, texte collé 22,
Word 7, photo 5, paquet 3**. 1 815 cartes vivantes, dont **111 seulement ont déjà été vues**
(6 %). Notes données : *Encore* 14 %, *Difficile* 32 %, *Correct* 40 %, *Facile* 14 % — donc
**46 % des cartes sont ratées ou pénibles** au premier passage. 23 comptes ont créé un examen,
2 examens blancs ont été finis. 5 comptes ont créé un dossier. `course_views` : 0.
`course_adopts` : 0. `friendships` : 1. `feedback` : 0.

Délai moyen entre l'inscription et le premier cours : **1 080 minutes, soit 18 heures.**
Personne n'importe pendant la séance d'inscription. Ils reviennent le lendemain — ou pas.

La bibliothèque et le social sont morts-nés : deux fonctionnalités livrées, zéro usage. Ce
n'est pas une raison de les tuer, c'est une raison de ne pas leur consacrer une heure d'ici
décembre.

---

## 2. Ce qui n'est pas le problème

Cette partie existe pour éviter trois chantiers inutiles. J'y suis arrivé en cherchant le
contraire.

### 2.1 Les 29 écrans d'accueil ne sont pas trop nombreux

C'était mon premier soupçon. Il est faux. *(relevé, Appllama)*

| App | Revenu mensuel | Écrans d'accueil |
| --- | --- | --- |
| Coconote (Quizlet) | 300 K$ | **38** |
| Vaia / StudySmarter | 70 K$ | **34** |
| Duolingo | 52 M$ | **32** |
| Yuno | 300 K$ | 27 |
| Minutes AI | 300 K$ | 22 |
| **Micabo** | **0 €** | **29** |
| Airlearn | 200 K$ | 15 |
| Gizmo | 200 K$ | 11 |
| Quizlet | 3 M$ | 6 |
| Photomath | 300 K$ | 4 |

Vingt-neuf écrans, c'est la norme haute d'une catégorie où les meilleurs en ont 32 à 38.
**Couper le parcours en huit écrans ne rapporterait rien et coûterait le profil.** Ce qui
distingue Vaia de Micabo n'est pas la longueur, c'est ce qu'il y a au bout — §2.4.

### 2.2 Le prix est juste

*(relevé, RevenueCat, State of Subscription Apps 2026, catégorie Éducation)* Médiane annuelle
de la catégorie : **44,99 $**. Micabo : 39,99 € ≈ 43 $. Pile dessus. Médiane mensuelle :
9,99 $ ; Micabo à 6,99 € ≈ 7,5 $, soit 25 % **en dessous**. Et 59 % des abonnements vendus en
Éducation sont annuels — l'ancrage annuel de Micabo est le bon.

En France, les concurrents qui vendent du contenu sont deux à quatre fois plus chers :
SchoolMouv à partir de 14,99 €/mois avec 7 jours d'essai, Kartable 14,99 €/mois sans engagement
ou 7,99 €/mois sur deux ans. *(relevé, web)* Micabo n'est pas cher. Il n'est pas acheté, ce qui
n'est pas la même chose.

### 2.3 Le paywall est bien écrit — mieux que ceux des concurrents

Les deux paywalls que j'ai regardés en entier, écran par écran :

**Vaia** — carrousel de six bénéfices, deux offres côte à côte : annuel « 7,50 $/mois », badge
« SAVE 62 % », « Free 7-day trial » ; mensuel « 19,99 $/mois », « Payment due today ». Le
mensuel est un leurre assumé. Puis « 7-day free trial, then $89.99 billed yearly », un bouton
sombre « Start 7-day free trial », et dessous : **« We'll notify you before the trial ends »**.

**Coconote** — « 🎁 Get unlimited notes free for 7 days », annuel 129,99 $ avec ruban
« BEST DEAL » et « 7 days free, equivalent to $10.83/month », mensuel 19,99 $,
**« ✓ No payment due now »**, CTA « Start my FREE week ».

Maintenant, Micabo, dans `SharedI18nCatalogs.swift` : *(lu)*

- `app.paywall.reminderBody` : « **Aucun paiement n'est dû aujourd'hui.** »
- `app.paywall.reminderTitle` : « **On t'envoie un e-mail avant la fin de l'essai.** »
- `app.paywall.perMonth` : « par mois » — le même cadrage mensuel de l'annuel
- `app.paywall.study1Source` : « Cepeda et al., Psychological Bulletin, 2006 », plus
  Karpicke & Roediger 2008 et Murre & Dros 2015

Les deux lignes de confiance du marché sont déjà là, mot pour mot. Et **aucun concurrent relevé
ne cite ses sources scientifiques.** Un flux de remise séparé existe déjà
(`DiscountFlowView.swift`), équivalent du second paywall de Vaia.

Un seul écart réel : **3 jours d'essai contre 7** chez les deux. L'offre est figée, j'en reparle
une fois et une seule en §6.5.

### 2.4 Ce que Vaia fait et que Micabo ne fait pas

Le parcours de Vaia, dans l'ordre : *(relevé)*

```
1 vidéo · 2-4 INSCRIPTION · 5-9 visite guidée · 10 prénom · 11 avis 5 étoiles
12 « comment tu nous as connus » · 13 niveau + pays · 14 établissement · 15 diplôme
16 filière · 17 année de début · 18-19 preuve sociale · 20 objectifs · … 34
```

Deux différences, et une seule compte.

**Vaia fait créer le compte à l'écran 2. Micabo à l'étape 26.** Conséquence directe : chez Vaia,
un abandon à l'écran 18 laisse un compte, un profil et un e-mail. Chez Micabo, un abandon à
l'étape 20 ne laisse **rien** — ni ligne, ni trace, ni adresse. C'est pour ça que §1.4 ne peut
rien dire de ce qui précède l'étape 26.

Et surtout : **Vaia collecte exactement le même profil que Micabo** — pays, niveau,
établissement, filière, objectifs — mais Vaia a un catalogue à pointer avec (`Textbook`,
`Explore`, `Problem Practice`, 83 écrans au total). Micabo pose les mêmes questions, écrit
neuf clés dans `UserDefaults`, puis **ouvre une application vide**.

C'est exactement l'intuition « on doit pouvoir utiliser l'app même sans rien à importer ».
Elle est juste, et c'est la partie 5.

### 2.5 Le planificateur est bon

`SM2Scheduler` reproduit fidèlement les réglages d'Anki, dispersion des échéances comprise.
Aucun concurrent IA relevé n'a ça. Ce n'est dit nulle part dans le produit, et ça ne se verra
jamais tant que personne ne révise deux jours de suite.

---

## 3. La fluidité

L'iPhone 13 n'est pas une machine lente : A15, 4 Go, 60 Hz. Une app SwiftUI qui rame dessus a
une cause identifiable, pas un problème de budget.

Beaucoup a déjà été fait, et il ne faut pas le refaire : le carrousel `TabView` en style page
est mort (`RootTabView.swift:31`), le `ZStack` à opacité zéro qui gardait cinq écrans vivants
derrière l'actif aussi (`RootTabView.swift:18-19`), les cartes ne sont plus dans un `@Query` sur
l'onglet Réviser (`TodayView.swift:46-57`), la session n'écrit plus carte par carte
(`StudySession.swift:482-505`), les listes sont paresseuses, le traceur ne touche ni disque ni
réseau au point d'appel.

Il reste ceci.

### 3.1 La cause principale : `Course` est observé par cinq à huit vues, avec 30 Ko par ligne

`Course` porte **trois** charges de texte, toutes stockées en ligne : *(lu + mesuré)*

| Attribut | Déclaration | Poids mesuré en base |
| --- | --- | --- |
| `rawText: String` | `Course.swift:63` | **16 Ko en moyenne, 76 Ko au maximum** |
| `contextText: String` | `Course.swift:65` | **6,7 Ko en moyenne, 33 Ko au maximum** |
| `sheetData: Data?` | `Course.swift:70` | **7,9 Ko en moyenne, 35 Ko au maximum** |
| `coverImageData` | `Course.swift:72` | *en `.externalStorage` — le seul qui puisse l'être* |

Soit **environ 30 Ko de texte par ligne**, chargés avec elle à chaque matérialisation.

**Et `.externalStorage` n'est pas le remède — je me suis trompé en le proposant.** Trois
raisons, chacune suffisante :

1. **L'option ne s'applique pas à un `String`.** `.externalStorage` traduit
   `allowsExternalBinaryDataStorage` de Core Data, réservé aux attributs *Binary Data*. Les
   quatre usages du dépôt portent tous sur un `Data?` (`Course.swift:72`,
   `Flashcard.swift:140` et `:152`, `Exam.swift:72`). Or `rawText` et `contextText` — les
   deux tiers du poids — sont des `String`.
2. **Sur `sheetData`, elle serait inerte.** L'externalisation est conditionnelle à la taille,
   et aucune fiche de production n'approche le seuil : médiane 6,3 Ko, p99 26 Ko, maximum
   34,6 Ko, **zéro ligne au-dessus de 128 Ko** sur 164 cours. Core Data garderait tout en
   ligne.
3. **Il n'y a jamais eu d'oubli.** `git log --follow` sur `Course.swift` ne rend qu'un
   commit, et cette version porte déjà les deux états côte à côte. L'attribut est sur les
   `Data` partout et nulle part ailleurs : c'est exactement ce que l'API autorise.

Au passage, l'idée que `.externalStorage` rendrait le chargement paresseux est une
extrapolation : Apple documente un stockage hors base, pas un chargement différé.

Le poids par ligne est donc à prendre tel quel, et **le levier est ailleurs** : le nombre
d'observateurs, et ce qu'on leur fait porter.

Or `Course` est dans un `@Query` dans les cinq onglets : *(lu)*

```
CoursesListView.swift:15   @Query(sort: \Course.updatedAt, order: .reverse)
TodayView.swift:29         @Query(sort: \Course.updatedAt, order: .reverse)
ExamsView.swift:17         @Query(sort: \Course.updatedAt, order: .reverse)
DecksListView.swift:15     @Query(sort: \Course.updatedAt, order: .reverse)
ProfileView.swift:30       @Query private var courses: [Course]     ← ni tri ni filtre
```

`propertiesToFetch` : **zéro usage dans tout le dépôt.** Les onglets d'un `TabView` système
sont créés paresseusement mais **restent vivants après la première visite**.

Et il y en a un sixième, que j'avais manqué : `DiscountBadgeHost` porte lui aussi un `@Query`
et il est monté en permanence par-dessus les onglets (`RootTabView.swift:66-72`). En régime
normal, ce sont donc **six** requêtes `Course` vivantes, et **sept ou huit** quand
`SettingsView.swift:41`, `ExamDetailView.swift:22` ou `ExamEditorSheet.swift:29` sont ouverts
par-dessus. *(lu)*

Donc : **chaque écriture SwiftData réveille six `@Query` ou plus, dont chacune rematérialise la
table `Course` entière sur l'acteur principal, texte brut compris.**

Ce mécanisme est déjà décrit, mot pour mot, dans le dépôt — pour les cartes, à
`TodayView.swift:48-52` :

> « SwiftData rematérialisait alors la table entière sur l'acteur principal à chaque écriture
> […] Avec quelques cours, c'est des milliers d'objets reconstruits plusieurs fois par seconde
> pendant une session ou une synchro : **c'est ça qui faisait ramer l'app.** »

Le diagnostic était juste. Il a été appliqué à `Flashcard` — plus aucun `@Query` sur
`Flashcard` dans tout le dépôt — et pas à `Course`, dont le `@Query` est toujours là, à
`TodayView.swift:29`, **dans le fichier même qui documente le problème**. *(lu)*

Et l'écart entre les deux modèles est plus grand que je ne l'avais écrit : **de 40 fois**
(poids Postgres, où le texte long est compressé) **à 97 fois sur l'appareil**, où SQLite ne
compresse pas — et c'est ce chiffre-là qui compte, puisque c'est ce que SwiftData décode.
*(mesuré)*

**Ce qui déclenche ces écritures, en revanche, n'est pas ce que je croyais.** La
synchronisation ne tourne **pas** à chaque passage au premier plan. Les trois appels de
`MicaboApp.swift:103`, `:120` et `:131` sont, dans l'ordre : un `.task` qui ne joue qu'une fois
par lancement de processus, un changement de compte, et l'ouverture d'un lien `micabo://`. Le
seul `onChange(of: scenePhase)` du fichier (`:70-76`) ne fait que vider la file d'analytics. Et
une descente sans changement n'écrit rien : `context.save()` est un no-op sur un contexte
propre. *(lu)*

Les réveils viennent donc d'ailleurs : une synchro qui rapporte effectivement quelque chose, un
import, la fin d'une session, un examen créé. C'est moins fréquent que « à chaque retour dans
l'app » — mais c'est exactement pendant ces moments-là qu'on regarde l'écran.

**Et c'est pour ça que la fluidité passe avant tout le reste.** Une précision qui change la
lecture : aujourd'hui, **94,8 % des comptes qui ont un cours en ont exactement un** (moyenne
1,19 ; médiane 1 ; p90 1). *(mesuré)* Le parc actuel pèse donc ~30 Ko × 6, pas « 72 Ko × 5 » —
et personne ne rame encore beaucoup. À 40 cours, c'est **1,2 Mo décodé six fois, à chaque
écriture, sur le fil qui dessine**. Le lag n'est pas à côté du repositionnement : il est
proportionnel à son succès, et il n'a pas encore commencé.

**Ce qu'il faut faire**, dans cet ordre :

1. **Réduire le nombre d'observateurs.** C'est le levier principal, et il est gratuit. Les
   listes (`CoursesListView`, `DecksListView`) gardent leur `@Query` ; `TodayView`,
   `ExamsView` et `ProfileView` passent au motif `DayLoad` déjà écrit à
   `TodayView.swift:46-57` — lecture à la demande, sur événement, pas d'observation. Et
   `DiscountBadgeHost`, qui est monté en permanence par-dessus les onglets
   (`RootTabView.swift:66-72`), ne doit pas observer `Course` du tout.
2. **Une projection légère pour les listes.** Un `CourseRow` (id, titre, matière, emoji,
   accent, nombre de cartes dues, date) construit une fois et gardé en `@State`, au lieu de
   promener des `Course` complets dans la hiérarchie de vues. C'est ce qui empêche les 30 Ko
   de circuler.
3. **Sortir les trois textes du modèle observé.** Le seul mécanisme SwiftData qui donne
   vraiment un chargement différé est la relation : un `@Model CourseBody` portant `rawText`,
   `contextText` et `sheetData`, relié à `Course` par une relation à un, n'est matérialisé
   que lorsqu'on ouvre la fiche. C'est plus lourd qu'un attribut à changer — une migration
   réelle — mais c'est le seul qui allège la ligne pour de bon.
4. **`ProfileView.swift:30` n'a pas besoin de la table** — mais pas non plus d'un simple
   compte, contrairement à ce que ce document affirmait. Il lui faut **deux choses** : un
   cardinal sur tous les cours (la bande « N cours »), et **trois champs par cours ayant au
   moins une carte** — identifiant, titre, emoji — pour le panneau « par cours ». Les trois se
   prennent au passage sur les cartes déjà lues, sans toucher à `Course`.

### 3.2 Le décodage d'image dans un `body`

`OcclusionFigure.swift:15` : *(lu)*

```swift
var body: some View {
    if let data = card.imageData, let image = UIImage(data: data) {
```

`UIImage(data:)` est synchrone, il décode le JPEG, et il est dans le `body` — donc à chaque
évaluation, sans cache. Sur iPhone 13, un décodage de photo coûte 10 à 40 ms : des images
perdues garanties au retournement d'une carte à occlusion.

**Correction d'une première rédaction de ce document.** J'avais cité trois autres sites du même
motif. Vérification faite, deux n'en sont pas : `ImportView.swift:750` et
`OcclusionEditorSheet.swift:258` sont **déjà dans des fonctions `async`**, donc hors du fil
principal. Il n'en reste qu'un, et il compte : `ImportView.swift:577`, la vignette de
couverture, qui vit sur le même écran que le curseur de longueur de fiche — **chaque cran du
doigt redécodait la couverture en pleine résolution** pour la réduire à 44 points de large.

**Correctif appliqué** (`DecodedImageCache`) : le décodage part hors du fil principal, passe par
`preparingForDisplay()` — sans quoi `UIImage(data:)` rend une image paresseuse dont la vraie
décompression aurait lieu au premier dessin, c'est-à-dire sur l'acteur principal, c'est-à-dire
là où on ne la veut pas — et le résultat est gardé dans un `NSCache`. Les deux vues relisent le
cache **synchronement** avant de dessiner, pour qu'une image déjà décodée n'attende pas une
passe.

### 3.3 Le lancement

`MicaboApp.init()`, avant la première image, sur le fil principal : *(lu)*

```swift
FontLoader.registerFonts()                              // 8 TTF, ~420 Ko, en boucle
PurchasesBridge.configureIfPossible()                   // SDK RevenueCat
container = Self.makeContainer()                        // conteneur + migrations
SampleContentPurge.purgeIfNeeded(in: container.mainContext)   // une passe SwiftData
SubjectCasePass.runIfNeeded(in: container.mainContext)        // une seconde passe
```

**Correction, après lecture des deux dernières.** J'avais écrit que la lecture avait lieu quand
même. C'est faux : `SampleContentPurge.purgeIfNeeded` et `SubjectCasePass.runIfNeeded`
commencent toutes deux par `guard !defaults.bool(forKey: key) else { return }` — le drapeau est
lu **avant** le contexte, et sur un lancement normal elles rendent la main sans toucher à
SwiftData. Elles ne coûtent qu'une fois, à la mise à jour qui les introduit. *(lu)*

Il ne reste donc, à chaque lancement, que l'enregistrement des polices et la configuration du
SDK d'abonnement. **Et je recommande de ne toucher ni à l'une ni à l'autre pour l'instant.**
Les polices doivent être enregistrées avant le premier texte, sous peine de repli visible sur
la police système ; `UIAppFonts` est la voie documentée mais déplace le coût sans forcément le
réduire, et une erreur ici casse toute la typographie de l'app. Le SDK porte un commentaire
explicite : il doit être configuré avant qu'un écran puisse demander une offre.

C'est la partie du §3 qui **demande une mesure avant un correctif**, pas l'inverse. Sans la
trace Instruments du §3.5, changer l'un des deux revient à déplacer du code sans savoir si on
déplace du temps.

### 3.4 Les catalogues de langue

`SharedI18nCatalogs.swift` (9 510 lignes) et `IosI18nCatalogs.swift` (3 510 lignes) contiennent
**9 480 paires clé-valeur** en littéraux de dictionnaire Swift, cinq langues chacun. Un
`static let` est paresseux, donc une seule langue est construite — mais elle l'est d'un bloc, à
la première lecture d'une chaîne, c'est-à-dire pendant la première image. Un `plist` chargé en
`mmap`, ou un découpage par écran, coûte moins.

### 3.5 Comment vérifier

Rien de ce qui précède ne se valide à l'œil. Trois mesures, avant et après, sur un iPhone 13
avec vingt cours importés :

- **Hitches** dans Instruments (gabarit *Animation Hitches*) au défilement de `CoursesListView`
  et au changement d'onglet. C'est la seule mesure qui corresponde à « ça rame ».
- **Temps jusqu'à la première image** (`os_signpost` autour de `MicaboApp.init`).
- **Nombre de matérialisations de `Course` par seconde** pendant un import et pendant une
  synchro qui rapporte des lignes — un compteur temporaire dans `Course.init` suffit à prouver
  le §3.1 avant de le corriger. C'est la mesure qui départage « six observateurs » de « trente
  kilo-octets par ligne » : si le compteur s'affole mais que les temps restent bons, le poids
  n'est pas le problème et seul le nombre d'observateurs compte.

Sans ces trois nombres, on ne saura pas si le correctif a marché, et le prochain document
répétera le même diagnostic.

---

## 4. Réparer la livraison

Avant tout repositionnement : aujourd'hui, l'app promet une fiche et ne la livre pas trois fois
sur quatre, et n'a jamais fait réviser personne. Aucun catalogue, aucun planning et aucun
paywall ne rattrape ça.

### 4.1 La génération qui n'arrive nulle part

58 comptes sur 77 (§1.3), dont 39 parce que la synchronisation ne revient jamais. L'ordre de
travail découle directement de ce partage :

1. **Faire revenir `CloudSync`** — les deux tiers du problème, et on sait maintenant
   pourquoi. La synchronisation part à **trois moments seulement** : un `.task` qui ne joue
   qu'une fois par lancement de processus (`MicaboApp.swift:103`), un changement de compte
   (`:120`), et l'ouverture d'un lien `micabo://` (`:131`). **Pas au retour au premier plan** —
   le seul `onChange(of: scenePhase)` du fichier (`:70-76`) ne fait que vider la file
   d'analytics. *(lu)*

   Le scénario qui produit les 39 comptes se lit alors tout seul : on ouvre l'app (synchro, à
   vide, avant l'import), on importe, on lit sa fiche, on ferme. **Il n'y a aucun déclencheur
   entre l'import et la prochaine ouverture de l'app** — et pour la moitié de ces gens, il n'y
   a jamais de prochaine ouverture. Le cours reste sur le téléphone.

   Il manque donc le déclencheur qui compte : **la fin d'un import**, et à défaut le passage
   à l'arrière-plan. Un cours qui vient d'être écrit doit monter dans la seconde.
2. **Dire quand la montée échoue.** `pushCards` a déjà appris à ne pas avaler un refus
   (`CloudSync.swift:186-191`). Il faut la même chose sur `courses`, et une ligne dans les
   Réglages qui dit « 3 cours ne sont pas encore sauvegardés », avec un bouton qui réessaie.
   Aujourd'hui, un utilisateur dont rien ne monte n'a aucun moyen de l'apprendre.
3. **Ne consommer le quota qu'après une fiche posée.** `consumeQuota` est appelé après la
   validation du document (`generate-course/index.ts:229`) — le correctif du 8 septembre est
   bien là — mais toujours **avant** l'appel au modèle et avant que le client n'ait rien
   enregistré. C'est la fenêtre des 19 autres comptes. Un accusé de réception du client, ou un
   décompte différé, la ferme.
4. **Un cours sans fiche reste un cours.** `OfflineSheetBuilder` existe déjà
   (`Services/OfflineSheetBuilder.swift`) : il sait faire une fiche de repli depuis le texte
   brut. Mieux vaut une fiche pauvre qu'un écran perdu.
5. **Livrer `#293` et `#294`** pour la qualité des formules — mais sans en attendre d'effet sur
   ce tableau (§1.3).

### 4.2 La première session qui n'a jamais lieu

Zéro révision sur 217 comptes. Le chemin actuel, tel que le README le décrit :

```
import -> lecture sur l'appareil -> cours fiché -> (facultatif) cartes -> session
```

Quatre étapes, dont une facultative, avant la première carte. Et le délai mesuré entre
l'inscription et le premier cours est de **18 heures** : la session n'a donc pas lieu dans la
séance d'inscription, où l'élan existe. Elle a lieu le lendemain, où il n'existe plus.

Le commit `#290` (« Une fiche, pas un cours : la liste devient la forme par défaut ») a rendu
les cartes facultatives, et `e8f871c` l'explique bien. Sur le papier, c'est juste : la fiche est
le livrable. Dans les chiffres, **45 % des gens qui importent n'ont jamais de cartes** — donc
jamais de session, donc jamais de deuxième jour, donc jamais d'abonnement.

Ce n'est pas un argument pour revenir en arrière. C'est un argument pour que **la première
session ne dépende pas d'un import** — la partie 5.

---

## 5. Le compagnon

Ce que tu décris — organisation globale, personnalisation par matière, cours découpés en
chapitres, plannings, révision passive — n'est pas un empilement de fonctionnalités. C'est un
changement d'objet : Micabo arrête de traiter *un document* et commence à tenir *une année*.

Trois choses manquent pour ça, dans cet ordre de dépendance : le chapitre, le contenu, le temps.

### 5.1 Le chapitre n'existe pas

C'est la découverte structurante du document. *(mesuré)*

```sql
select jsonb_object_keys(sheet) from public.courses;  -- une seule clé : "blocks"
```

`sheet` ne contient que `blocks`. Les « chapitres repliables » du commit `#289` sont **une
lecture des blocs de type `heading`**, pas une entité. 1 205 blocs `heading` sur 143 fiches,
soit 8,5 titres par cours en moyenne — la matière est là, mais elle n'a ni identité, ni
progression, ni échéance, ni carte rattachée.

La preuve que ça bloque déjà : `exams.chapter_ids` existe dans le schéma et **les 31 examens
ont tous un tableau vide**. La colonne a été prévue pour une entité qui n'a jamais été créée.

**Rien de ce que tu veux ne tient sans cette entité.** « Les cours se divisent par chapitre »,
un planning qui dit quoi réviser mardi, une progression par chapitre, une écoute chapitre par
chapitre : tout référence un chapitre. Il faut donc, d'abord :

```
Chapter
  id, course_id, position
  title              ← promu depuis le heading de niveau 1
  block_range        ← les blocs de la fiche qui lui appartiennent
  card_ids           ← les cartes nées de ces blocs
  state              ← jamais ouvert / en cours / su
  mastery            ← calculé depuis review_logs, par chapitre
```

Le travail n'est pas énorme : les titres sont déjà là, la découpe est déterministe, et la
migration se fait à la lecture. Mais **c'est le préalable de toute la partie 5**, et c'est
pour ça qu'il est en premier.

C'est aussi la première règle figée du `README` qui saute : « un contenu importé est un *cours*,
ce que Micabo en écrit est sa *fiche* » devient un lexique à trois termes — cours, chapitre,
fiche.

### 5.2 Le catalogue : où je choisis à ta place

Tu as demandé les deux — catalogue par programme **et** génération à la demande. Elles ne
coûtent pas la même chose et ne servent pas au même moment.

**Ce que je propose, et pourquoi.** Le catalogue est cher à produire et à tenir : un programme
par pays, par niveau, par matière, révisé chaque année. Avec 428 comptes turcs, 342 français,
534 lycéens et 149 en supérieur, faire les deux pays correctement, c'est deux programmes
complets — et le turc, que personne dans l'équipe ne peut relire.

Donc : **catalogue pré-généré sur un seul périmètre, génération à la demande partout ailleurs.**

Le périmètre : **lycée français, Première et Terminale, les six matières les plus demandées.**
C'est là que sont les 534 lycéens, c'est le public que tu peux relire toi-même, et c'est le
marché où les concurrents (Kartable, SchoolMouv) prouvent qu'on paie pour du contenu conforme
au programme — deux à quatre fois ton prix.

Ce n'est pas un abandon de la Turquie. C'est l'ordre : le catalogue français valide la mécanique
en octobre, la Turquie la reçoit en novembre si elle marche. Un catalogue turc bâclé sur le YKS
coûterait sa crédibilité sur le marché le plus gros.

**La génération à la demande** couvre tout le reste, et c'est elle qui tient la promesse « même
sans rien à importer » pour un étudiant en licence à Istanbul : un champ, un sujet, une fiche et
ses cartes en trente secondes. Tu acceptes la hausse de coût, donc la question n'est pas le prix
unitaire mais le plafond : un compte gratuit doit pouvoir en obtenir **assez pour réviser deux
jours de suite** — c'est le seuil que personne n'a jamais franchi (§1.1) — et pas plus.

Les fiches générées à la demande et jugées bonnes remontent au catalogue. Le catalogue se
construit par l'usage au lieu d'être écrit à l'avance : c'est exactement ce que
`docs/data-flywheel.md` décrit, et c'est la seule façon de couvrir cinq langues sans cinq
équipes éditoriales.

### 5.3 Le temps : plannings

Le planning n'est pas un calendrier. C'est la réponse à « qu'est-ce que je fais maintenant »,
et Micabo a déjà tout ce qu'il faut pour la donner : `weekly_minutes` (sept valeurs, un zéro
est un jour de repos, `CloudRecords.swift:113-116`), `daily_minutes`, `availability_exceptions`,
les échéances SM-2, et les dates d'examen.

Ce qui manque, c'est que ça tienne **sur plusieurs cours et par chapitre** plutôt que par
paquet de cartes dues. Concrètement : un onglet qui dit « mardi : chapitre 3 de SVT, 12 minutes,
parce que ton contrôle est le 14 » — pas « 23 cartes dues ».

C'est la seconde règle figée qui saute : le `README` dit « il n'y aura pas de quatrième onglet ».
Il y en a déjà cinq (`RootTabView.swift:34-46`) — la règle est morte avant ce document, il faut
juste cesser de l'écrire.

### 5.4 L'écoute

C'est la brique que tu as choisie en premier, et c'est celle qui différencie le plus. Aucun des
concurrents relevés ne la fait sérieusement.

La fiche est déjà structurée en blocs typés (`paragraph`, `heading`, `definition`, `callout`,
`formula`, `list`) : elle se lit à voix haute proprement, ce qu'un PDF ne permet pas. Ce qu'il
faut : une voix par langue, une session audio qui se pilote depuis l'écran verrouillé, des
`heading` comme points de chapitrage, et — la partie qui compte — **une question posée à voix
haute toutes les quelques minutes, dont la réponse compte comme une révision.** Sans ça, c'est
un podcast ; avec, c'est du rappel actif, et ça alimente `review_logs`.

Le coût TTS est réel et récurrent, mais l'audio se cache par chapitre : une fiche lue une fois
sert à tous ceux qui ouvrent le même chapitre du catalogue.

### 5.5 La relecture espacée de la fiche

L'autre brique que tu as retenue, et la moins chère de toutes : Micabo sait déjà quand une carte
doit revenir. Le même calcul, appliqué aux **blocs** d'un chapitre plutôt qu'aux cartes, donne
une relecture espacée du cours — trois paragraphes à relire, pas vingt-trois cartes à noter.

Son intérêt réel : **c'est une porte d'entrée sans effort.** 46 % des cartes sont ratées ou
pénibles au premier passage (§1.6). Une session de cartes est un examen ; une relecture de trois
paragraphes n'en est pas un. Pour quelqu'un qui n'a jamais révisé deux jours de suite — c'est
à dire, à ce jour, tout le monde — c'est la marche la plus basse qu'on puisse poser.

---

## 6. L'entonnoir

### 6.1 Ce que 10 % peut vouloir dire

*(relevé, RevenueCat 2026, catégorie Éducation)*

| Mesure | Médiane Éducation | Quartile supérieur |
| --- | --- | --- |
| Téléchargement → payant, J35 | **2,3 %** | > 5,0 % |
| Téléchargement → essai, J30 | **6,5 %** | — |
| Essai → payant, J35, **paywall dur** | **10,7 %** (toutes catégories) | — |
| Essai → payant, J35, **freemium** | **2,1 %** (toutes catégories) | — |

Donc, très directement : **10 % en installation → payant serait quatre fois la médiane de la
catégorie et au-dessus du quartile supérieur.** Ce n'est pas un objectif, c'est un record.

**10 % en essai → payant est atteignable** — c'est la médiane des paywalls durs. Micabo est
freemium, dont la médiane est 2,1 %.

L'objectif utile n'est donc pas un nombre, c'est une échelle :

| Palier | Mesure | Aujourd'hui | Cible décembre |
| --- | --- | --- | --- |
| 0 | Une révision sur iOS existe | **0** | > 0 |
| 1 | Comptes iOS ayant révisé 2 jours | **0 %** | 15 % |
| 2 | Téléchargement → essai | inconnu | 6,5 % (médiane) |
| 3 | Essai → payant | **0 %** | 2 à 4 % (freemium) |
| 4 | Téléchargement → payant | **0 %** | 2,3 % (médiane) |

**Le palier 0 vaut plus que tous les autres.** Tant qu'il n'est pas franchi, optimiser le
paywall revient à repeindre une porte qui ne s'ouvre sur rien.

### 6.2 Le parcours cible

Une seule modification structurelle, et elle ne touche pas à l'offre :

```
aujourd'hui   25 écrans (rien d'enregistré) → inscription (26) → essai (27-28) → PAYWALL (29) → app vide
cible         5 écrans (pays, niveau, matières) → INSCRIPTION → le catalogue répond
              → première fiche et première session, sur du contenu réel
              → 20 écrans restants (profil, science, projection, preuves)
              → PAYWALL, après la première session
```

Ce que ça change, point par point :

1. **L'inscription remonte à l'écran 6.** C'est la leçon de Vaia (§2.4). Un abandon devient une
   donnée au lieu d'un silence, et tu peux écrire à ces gens.
2. **Le profil déjà collecté sert immédiatement.** Un lycéen en terminale spé maths voit ses
   chapitres au bout de six écrans. C'est le « ton compagnon » que les 29 écrans actuels
   promettent sans le livrer.
3. **La première session a lieu avant le prix.** Pas sur une démo (`demoImport`, `demoSheet`,
   `demoReview` montrent le produit de quelqu'un d'autre), pas sur un import qui demande de
   sortir un PDF en pleine inscription : sur un chapitre du catalogue, choisi par le profil.
4. **Le paywall arrive au même endroit qu'aujourd'hui** — à la fin. Mais il arrive après une
   session réussie au lieu d'après une promesse.

Les 20 écrans conservés ne sont pas du remplissage : `RetentionChartStepView` et
`ProjectionStepView` sont les meilleures pages du produit, et la table du §2.1 dit que la
catégorie supporte cette longueur.

### 6.3 Ce qui se fait sans toucher à l'offre

- **La première session avant le prix** (§6.2) — la plus grosse, et elle ne coûte rien à l'offre.
- **Remplacer les trois démos par le vrai produit sur du vrai contenu.**
- **Le cadrage mensuel en évidence** : « 3,33 € par mois » plus gros que « 39,99 €/an ».
  `app.paywall.perMonth` existe déjà.
- **Les notifications — la plus rentable de cette liste.** `NotificationPermission.swift` demande
  bien l'autorisation (`UNUserNotificationCenter.current()`, lignes 31 et 51), et il n'existe
  dans tout le dépôt **ni un seul `UNMutableNotificationContent`, ni un seul déclencheur, ni un
  seul `add(request:)`**. *(lu)* Autrement dit : `NotificationsStepView` demande à l'utilisateur
  la permission de le déranger, et **aucune notification n'est jamais envoyée.** C'est pire que
  ne pas demander — l'autorisation est brûlée, et un refus est durable. Sans rappel, personne
  ne revient le lendemain, et le palier 1 est hors d'atteinte par construction.
- **Le widget.** Aucun `WidgetKit` dans le dépôt. Surface de rappel qui ne dépend d'aucune
  autorisation, donc la seule qui marche sur les gens qui ont refusé.

À noter, parce que le plan précédent le réclamait : **le nombre de pairs inventé a bien été
supprimé.** Plus aucun `Int.random` dans le parcours d'accueil, et `SocialProofStepView` montre
maintenant de vrais avis avec `requestReview()`. *(lu)* Rien à faire.

### 6.4 Ce qu'il ne faut pas faire

- **Le nombre de pairs inventé**, sous quelque forme que ce soit.
- **La mascotte.** Vaia en a une sur seize écrans. Elle détonnerait avec la sobriété de Micabo,
  qui est son seul actif de marque aujourd'hui.
- **Cacher le prix jusqu'au dernier moment.** L'ancrage clair sert mieux la confiance sur un
  public étudiant, et le paywall actuel est déjà honnête (§2.3).
- **Réanimer la bibliothèque et les amis.** 0 vue, 0 reprise, 1 amitié. Pas d'ici décembre.

### 6.5 Le plafond, dit une fois

L'offre est figée, et ce document la respecte partout. Voici ce que cette contrainte coûte, avec
les chiffres, pour que la décision soit prise en connaissance de cause :

- **Freemium contre paywall dur : 2,1 % contre 10,7 %** d'essai → payant. C'est un facteur cinq,
  et c'est le seul écart de cette taille dans tout le document.
- **3 jours d'essai contre 7** chez Vaia et Coconote. En Éducation, 78 % des essais démarrent le
  jour même : un essai de trois jours se termine avant le premier lundi de révision.
- **Pas d'offre hebdomadaire.** Elle est l'ancre standard de la catégorie (Gizmo 6,99 $,
  Coconote 9,99 $, Zutobi ne vend que ça et fait 600 K$/mois).

Aucune de ces trois n'est une recommandation : tu as tranché. Ce sont les bornes de ce que §6.2
et §6.3 peuvent produire. **Et elles ne sont pas la contrainte active aujourd'hui** — le palier 0
l'est. Quand une cohorte iOS révisera deux jours de suite et que la conversion plafonnera à 2 %,
cette section redeviendra la conversation à avoir.

---

## 7. Le paysage, en une table

*(relevé, Appllama, revenus mensuels d'août 2026)*

| Produit | Revenu | Prix | Ce qu'il fait mieux |
| --- | --- | --- | --- |
| **Vaia** (StudySmarter) | 70 K$ | 31,99–89,99 $/an | Le concurrent frontal. Même profil collecté, mais un catalogue derrière |
| **Coconote** (Quizlet) | 300 K$ | 129,99 $/an, 9,99 $/sem | 38 écrans d'accueil, 1 paywall, rien d'autre. Une machine à convertir |
| **Gizmo** | 200 K$ | 77,99 $/an, 6,99 $/sem | Quiz, jeu, progression. 46 écrans de produit |
| **Quizlet** | 3 M$ | 44,99 $/an | Le catalogue communautaire, les modes d'étude |
| **Brainscape** | 70 K$ | 95,99 $/an | Notation par confiance, statistiques |
| **Duolingo** | 52 M$ | 83,99 $/an | La boucle : série, gel, widget, deuxième demande d'autorisation |
| **Kartable** | — | 14,99 €/mois | Contenu conforme au programme français + assistant IA « Alfa » |
| **SchoolMouv** | — | dès 14,99 €/mois, 7 j d'essai | 3 M d'élèves, CP→Terminale, contenu produit |
| **Knowunity** | — | freemium | Fiches partagées entre élèves, gamification |
| **Micabo** | **0 €** | 39,99 €/an | SM-2 réglé comme Anki, extraction sur l'appareil, paywall honnête |

La ligne à retenir : les trois français vendent **du contenu**, les anglo-saxons vendent **un
outil**. Micabo vend un outil au prix d'un outil, sur un marché français qui paie deux à quatre
fois plus cher pour du contenu. La partie 5 est ce qui fait passer Micabo de l'une à l'autre.

---

## 8. Ce qu'il faut mesurer

`app_events` contient zéro ligne : le traceur écrit au commit `#295` n'est pas encore chez les
utilisateurs. **C'est le premier déploiement à faire**, avant tout le reste de ce document, parce
que sans lui aucune des parties 3 à 6 n'est vérifiable.

Le minimum utile, une fois qu'il tourne :

| Événement | Ce qu'il débloque |
| --- | --- |
| `onboarding_step_view(step)` | Les 25 premières étapes, aujourd'hui invisibles (§1.4) |
| `generation_started` / `generation_failed(reason)` / `generation_saved` | Trancher entre les deux causes du §1.3 |
| `sync_push_failed(table, reason)` | L'autre moitié de la même question |
| `first_session_completed(cards, seconds)` | Le palier 0 |
| `session_completed(day_index)` | Le palier 1, le seul qui prédit un abonnement |
| `paywall_view` / `trial_started` / `trial_converted` | Les paliers 2 et 3 |

Et une requête à faire tourner chaque lundi — celle du §1.2, la seule qui compte tant que le
palier 0 n'est pas franchi :

```sql
select count(*) filter (where exists (
         select 1 from public.review_logs r where r.user_id = p.id))
from public.profiles p
where coalesce(array_length(p.learning_goals, 1), 0) > 0;
```

Tant qu'elle renvoie 0, rien d'autre n'a d'importance.

---

## 9. Jusqu'à décembre

Onze semaines. Le pic d'usage visé est celui des partiels et des bacs blancs, mi-décembre à
mi-janvier : il faut que la boucle tourne **avant**, pas pendant.

### Lot 0 — Voir et livrer (semaine 1)

Déployer le traceur `#295` et les correctifs de décodage `#293`/`#294`, déjà écrits et retenus
sur la branche. Poser les six événements du §8.

*Critère de sortie :* `app_events` se remplit, et on sait enfin où partent les 25 premières
étapes.

### Lot 1 — La fluidité (semaines 1 à 3)

`.externalStorage` sur `rawText` et `sheetData`. Un seul observateur de `Course`. La projection
`CourseRow`. Le cache d'images. Le lancement allégé. Les trois mesures du §3.5, avant et après.

*Critère de sortie :* aucune image perdue au défilement de vingt cours sur iPhone 13, mesuré à
Instruments — pas jugé à l'œil.

**Ce lot bloque tous les autres.** Chaque cours ajouté par le lot 3 aggrave le §3.1 tant qu'il
n'est pas corrigé.

### Lot 2 — La livraison (semaines 2 à 4)

Le quota après le succès. La fiche de repli quand le décodage échoue. Le refus de montée dit à
l'utilisateur. Les notifications, enfin programmées.

*Critère de sortie :* l'écart entre « a appelé le modèle » et « a un cours en base » passe sous
10 %, mesuré par la requête du §1.3.

### Lot 3 — Le chapitre et le catalogue (semaines 4 à 8)

L'entité `Chapter` (§5.1), et la migration à la lecture des 143 fiches existantes. Le catalogue
lycée France, Première et Terminale, six matières. La génération à la demande. Le parcours
d'accueil du §6.2 : inscription à l'écran 6, première session sur un chapitre du catalogue,
paywall après.

*Critère de sortie :* un compte créé sans aucun import atteint sa première session révisée en
moins de trois minutes.

### Lot 4 — Le temps et l'écoute (semaines 8 à 11)

Le planning par chapitre. La relecture espacée de la fiche (§5.5, la moins chère). L'écoute
(§5.4) si les trois lots précédents sont tenus — et **seulement** à cette condition : c'est la
brique la plus visible et la plus facile à sortir trop tôt.

*Critère de sortie :* 15 % des comptes iOS d'une cohorte hebdomadaire révisent deux jours
différents.

### Ce qui ne se fait pas d'ici décembre

La bibliothèque partagée, les amis, le catalogue turc, le mode sombre, l'iPad, FSRS. Aucun ne
change le palier 0.

---

## 10. Les décisions que je n'ai pas prises

Trois, et elles sont à toi.

1. **Le catalogue turc.** Je propose de le faire en novembre, après validation du français
   (§5.2). C'est 49 % de tes comptes qui attendent. Si tu trouves quelqu'un qui relit le turc,
   l'ordre peut s'inverser — mais pas se paralléliser.
2. **L'écoute en lot 4 plutôt qu'en lot 1.** C'est la brique dont tu as le plus envie, et c'est
   pour ça qu'elle est en dernier : elle est la plus visible, et elle ne sert à rien sur une app
   qui rame et qui ne livre pas ses fiches.
3. **Le plafond du §6.5.** Freemium, 3 jours, pas d'hebdo. Tenu partout dans ce document. Quand
   le palier 1 sera franchi et que la conversion plafonnera, ce sera la conversation à rouvrir.
