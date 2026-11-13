# Lot « Knowunity » : l'attrait d'une app qu'on ouvre tous les jours

Micabo garde **son onboarding, Mika, ses couleurs et son ton**. On lui ajoute ce qui fait
revenir un élève chaque jour dans les meilleures apps d'étude (étudiées écran par écran) :
une mascotte qui parle dans une bulle, des raccourcis d'outils, de l'XP, un objectif du jour,
une ligue entre amis, un scanner d'exercices, un minuteur, et des retours de quiz qui
récompensent. Rien n'est recopié d'une autre app : ni nom, ni illustration, ni texte.

Le contrat chiffré est dans `web/packages/core/src/xp.ts` (récompenses, objectif du jour,
ligues, semaine). Les jumeaux sont `Micabo/Services/XP/XPRules.swift` et
`android/app/src/main/java/com/micabo/app/data/Xp.kt` ; `xp-parity.test.ts` les relit.

## 1. Home, de haut en bas

Home n'a pas la même tête selon l'élève (lot « Home 4 », clés `ios.home4.*`). Celui qui a
déjà ses leçons vient **réviser** : son plan passe devant tout. Celui qui n'en a pas vient
**écrire sa première leçon**, la leçon offerte : c'est le moment d'activation et de
conversion, la barre reste la scène.

**L'élève qui a ses leçons** (`HomeDay.hasCourses`) :

1. **La rangée du haut**, sur la page : l'initiale (ouvre le Profil) ; pour un élève qui
   n'est pas Pro, la pilule « ✦ Pro » bleue (déclencheur `upgrade`, hauteur minimale de
   40 points pour les grandes tailles de texte) — la seule surface d'abonnement de Home ; à
   droite, **une seule pastille** pour la série (🔥, ouvre la feuille de la série) et l'XP de
   la semaine (⚡, ouvre la ligue).
2. **Le bonjour** (« Bonsoir Léa », la nuit dit encore bonsoir) et l'objectif du jour :
   `xpToday / DAILY_XP_GOAL` (50) en texte et **un seul anneau**.
3. **« Ton plan du jour »**, sur une carte claire de la page (`HomePlanHero`) :
   - en haut, le **prochain examen** (`NextExam.current`) : le compte à rebours dans sa pastille
     bleue, le nom, la préparation (`ExamReadiness`) ; un appui ouvre le Calendrier. Sans
     examen : « Ton plan du jour » et une pilule discrète « Ajouter un examen » qui ouvre
     `ExamEditSheet` ;
   - **la** chose à faire maintenant (`HomeDay.primary`) : la séance de révision posée au
     calendrier aujourd'hui, ni faite ni finie (`StudyPlan.today` → `HomeSession.next`), puis
     la leçon en cours tant qu'elle n'a pas avancé aujourd'hui, puis les cartes dues, puis la
     leçon ; sinon, écrire la suivante ;
   - **un** grand bouton bleu — « Démarrer la séance », « Continuer », « Réviser
     maintenant » —, Mika en buste qui dépasse de son bord (comme sur Concentration). La séance
     part comme du calendrier (`FocusPlan.revision`) ;
   - au plus une seconde ligne (`HomeDay.secondary`) : les cartes dues, ou la leçon en cours.
4. **« Aujourd'hui »** : ce qui reste à l'agenda du jour, trois lignes au plus, dessinées
   comme dans le calendrier (`AgendaRow`) — l'examen blanc conseillé, les tâches (cochées
   d'ici), les autres séances (▶) ; « Voir le calendrier ». Rien s'il ne reste rien.
5. **« Mes leçons »** : les leçons récentes en cartes qu'on fait glisser, avec leur
   progression ; « Tout voir » ouvre l'onglet Leçons.
6. **« Nouvelle leçon »**, en second : la même barre (`HomeComposerBar`, sur une ligne), le
   « + » des supports, l'envoi — par la même porte du gratuit (`LessonAllowance.sendRoute`,
   `immediatePaywall`, l'aperçu verrouillé).
7. **Les outils**, en raccourcis légers dans une seule carte : Scanner un exo, Quiz éclair,
   Minuteur (ouvre Concentration et « Préparer ma session »), Ligue.

**L'élève tout neuf** : la rangée du haut ; sur le papier de la page, la bulle de Mika (le salut à
l'heure et au prénom, qui s'écrit lettre après lettre), Mika en buste qui sort de derrière la
barre, et la barre « comme une conversation » ; « Comment ça marche » en trois pas ; les
outils.

Les gestes du plan partent dans `home_plan_tapped` (`step`, `slot`, `exam`), sans texte de
l'élève. Les missions, la carte « Reprendre » et les trois chiffres ont quitté Home ; le
Profil garde les statistiques.

## 2. L'XP

- **Où elle se gagne** (`XP_REWARDS`) : bonne réponse 10, mauvaise 2, carte révisée 3,
  cercle terminé 25, leçon créée et livrée 30, examen blanc rendu 60, réponse de Mika 5,
  exercice expliqué 15, séance du minuteur menée au bout 40. Plafond 5 000 par jour.
- **Où elle se garde** : sur l'appareil, un journal par jour local (15 derniers jours) et un
  total à part. La semaine commence le lundi, en jour local.
- **Ce qu'on voit** : un petit « +10 XP » qui monte et s'efface à chaque gain (et une haptique
  légère), la pastille qui se met à jour. Quand l'objectif du jour est atteint, une feuille
  de fête avec Mika, une fois par jour.
- **La synchro** : `xp_total`, `xp_week`, `xp_week_start` (le lundi, `AAAA-MM-JJ`) montent
  avec la ligne `profiles`, là où le profil monte déjà. **La colonne peut ne pas exister
  encore** (migration `20261110120000_xp_league.sql` pas déployée) : si l'envoi échoue sur une
  colonne `xp_*`, on renvoie le profil sans ces trois champs. La synchro ne casse jamais à
  cause de l'XP.

## 3. La ligue de la semaine

Une feuille ou un écran :
- en tête, un trophée, le nom de la ligue (Bronze, Argent, Or, Saphir, Diamant, d'après
  `leagueFor(xp de la semaine)`), « Encore {n} XP pour la ligue {suivante} », et
  « Fin dans {j} j » (jusqu'à lundi minuit, heure locale) ;
- le classement : `rpc('friends_league')` (élève + amis acceptés, triés par XP de la semaine),
  la ligne de l'élève en évidence, rang, initiale ou avatar, nom, XP ;
- sans compte, sans ami, ou si l'appel échoue (fonction pas encore déployée) : la seule ligne
  de l'élève (XP locale), et deux boutons, « Ajouter des amis » (l'écran Amis existant) et
  « Inviter des amis » (partage d'un lien vers https://micabo.app).
- Accessible aussi depuis le Profil, au-dessus des amis.

## 4. Scanner un exo

Le scanner d'exercices (`Micabo/Features/Solver`, clés `ios.solve.*`, 26 langues), ouvert par
la tuile « Scanner un exo » de Home (`ScanExerciseView` ne fait plus que l'ouvrir). Toujours
ouvert : l'énoncé se lit sur l'appareil, et l'historique comme les fils de Mika restent à
l'élève ; la porte vient à la demande de solution.

1. **La capture**, plein écran sur fond noir : la visée (AVFoundation, pas le scanner de
   documents de VisionKit, qui cherche une page entière), un **cadre réglable** (coins pour
   l'agrandir, glisser pour le déplacer, extérieur assombri) et la consigne « Cadre une seule
   question » ; la lampe ; « Photos » (la photothèque, le cadre posé sur toute l'image) ;
   « Écrire » (taper ou coller l'énoncé) ; « Mes exercices » et « Demande à Mika ». Après la
   photo, l'image se fige, on ajuste le cadre, « Lire l'énoncé ». Le cadre est ramené dans la
   photo (`SolverCrop`) et seul ce morceau est lu, **sur l'appareil**
   (`OnDeviceOCR.recognizeExercise` : la langue de l'app d'abord, puis la détection de Vision ;
   `recognize(in:)` ne change pas pour les imports). Moins de douze caractères lus : « Je
   n'arrive pas à lire », Mika triste en buste, « Reprendre » ou « Écrire ».
2. **La matière** est devinée sur l'appareil (`SolverSubjectGuess` : mots et unités dans les
   langues les plus parlées, signes de calcul) parmi Maths, Physique-chimie, SVT, Autres
   matières ; l'élève la change d'un appui ; Mika la confirme dans sa réponse (`[SUBJECT]`)
   tant que l'élève ne l'a pas choisie.
3. **La solution pas à pas** (`SolverSolutionView`) : l'énoncé reconnu (corrigeable ; une
   solution déjà là s'efface alors), puis, sur « Résoudre pas à pas », les **étapes en cartes
   numérotées** qui se dévoilent une à une (« Étape suivante (2/3) » en bas, la carte suivante
   en pointillés, « Tout afficher »), les formules composées (`SolverFormula` : le moteur de
   `MathTypesetter` dessiné en image, repli sur la transposition), la **réponse encadrée**.
   Sous chaque étape, « Je ne comprends pas cette étape » : Mika la réexplique dans une bulle
   sous la carte. Puis « Un exercice similaire pour m'entraîner » : Mika invente l'énoncé,
   l'élève répond, la correction dit juste ou faux et pourquoi, « Voir la réponse »,
   « Un autre exercice ». Enfin « Une question sur cet exercice ? » ouvre le fil de la matière.
4. **Le protocole**, sans fonction nouvelle : `mika-chat`, l'énoncé en document joint (texte
   seulement), la consigne en message de l'élève **écrite dans la langue de l'app** (la
   fonction répond dans la langue du dernier message). Mika écrit des balises en anglais
   (`[SUBJECT]`, `[STEP]` titre puis explication, `[ANSWER]` ; `[EXERCISE]` ; `[RIGHT]` /
   `[WRONG]`), lues par `SolverParser` : balises en gras, numérotées ou traduites acceptées,
   repli sur les lignes numérotées puis les paragraphes, et sinon le texte tel quel ; les
   échappées LaTeX perdues dans le JSON (`\frac` lu comme un saut de page) sont réparées. La
   réponse brute est gardée et relue à chaque ouverture.
5. **La porte** est celle de Mika (`MikaQuota`) pour **chaque** appel (solution, étape
   réexpliquée, exercice similaire, correction, fil) : une question offerte à vie, puis le
   paywall `mika` ; pour un abonné, le plafond du jour. Le premier scan d'un élève qui a sa
   question offerte reçoit la solution entière (la valeur avant le paywall) ; la question
   suivante ouvre le paywall. Sans question offerte, l'énoncé reconnu reste à l'écran et les
   étapes, floutées, attendent Pro (« Débloquer la solution ») ; un abonnement pris là lance la
   solution tout seul. Rien n'est consommé avant que la réponse n'arrive.
6. **L'XP** : `exerciseSolved` (15) à la première solution d'un exercice, `mikaAnswer` pour
   tout le reste (`XPRules` ne change pas).
7. **Mes exercices** : les exercices demandés (vignette de la photo recadrée, matière, date,
   « À résoudre » s'ils attendent Pro), filtre par matière, appui long pour supprimer,
   réouverture de la solution.
8. **Demande à Mika** (`TutorChatView`) : Mika en buste sur le papier de l'app, **un fil par
   matière** ; un exercice résolu y arrive (l'énoncé, puis la réponse, avec « Voir la
   solution ») ; le fil part avec ses huit derniers tours et, en document joint, le dernier
   exercice du fil et sa solution. Deux idées de questions par matière dans un fil vide.
9. **Ce qui se garde** : `SolvedExercise` et `TutorMessage` (SwiftData, en fin de schéma),
   sur le téléphone seulement, effacés par `LocalWipe` à la sortie d'un compte.
10. **Les statistiques** : `solver_captured` (`source`, `subject`), `solver_unreadable`,
    `solver_solved` (`subject`, `steps`, `structured`, `source`), `solver_step_help`,
    `solver_practice_checked` (`result`), `tutor_asked` (`subject`), plus `mika_asked` et
    `mika_blocked` comme le chat de la leçon. Jamais un énoncé ni un message.

## 5. Le minuteur

Plein écran : Mika au centre d'un anneau qui se vide, 25:00, Pause / Reprendre, Arrêter
(confirmation). Au bout : la feuille de fête, `focusSession` (40 XP), et le temps compte dans
les heures de révision si l'app mesure déjà ce temps ailleurs. L'écran reste allumé pendant
la séance.

## 6. Les retours de quiz et de cartes

Le retour qui existe (vert, rouge, « pourquoi ») reste. On y ajoute la pastille « +10 XP » ou
« +2 XP », et sur une bonne réponse un mot qui félicite (« Bien joué ! », « Exact ! »,
« Parfait ! », au hasard). Pas de nouvelle feuille si l'écran en a déjà une.

## 7. La leçon offerte peut venir d'un import

Le serveur l'accepte déjà (`begin_lesson(p_onboarding)`, `generate-lesson` lit
`onboarding: true`). Un élève qui n'est pas Pro et n'a pas encore utilisé sa leçon offerte
peut créer cette leçon depuis un PDF, des photos ou YouTube : l'app envoie `onboarding: true`
avec cette génération-là. Les pastilles d'import n'affichent plus la couronne tant que la leçon
offerte reste.

**Depuis, sur iPhone : le paywall à la fin de la lecture.** Une fois la leçon offerte utilisée,
les imports restent ouverts et sans couronne (`LessonAllowance.locksImport`) : la lecture se
fait sur l'appareil. À l'envoi, des supports lus mènent à l'aperçu verrouillé
(`LessonAllowance.sendRoute`, `LockedLessonPreview`) : ce que Mika a vraiment lu (supports,
pages, mots, titre deviné, premières lignes floutées), « Écriture de ta leçon : avec Pro », puis
le paywall `lessonReady`. Abonné, la génération part avec les mêmes supports ; rien n'est
demandé au serveur avant, qui refuserait (`free_limit`, `import_pro`). Un sujet seul ouvre son
paywall tout de suite, comme avant (`LessonAllowance.immediatePaywall`).

## 8. Ce qui ne bouge pas

L'onboarding (ses écrans et leur ordre), le paywall et les achats, les prix, les thèmes
jour et nuit, Mika et ses humeurs. Chaque nouvelle phrase existe dans **toutes** les langues
de la plateforme.

## 9. Mika, dessiné dans le code — et un seul langage pour les onglets

**Le personnage (lot 10).** Verdict de l'élève sur le build 173 : « la mascotte est pas belle »,
« mal incarné », « pas fluide ». La pieuvre noire en 3D, livrée en images fixes, est partie.
Mika est un petit personnage **plat et vectoriel, dessiné par SwiftUI**, que l'utilisateur a
validé (« j'aime bien le nouveau Mika ») : un corps bleu, de grands yeux blancs aux pupilles
d'encre, des joues roses, cinq tentacules (les deux de l'arrière un cran plus sombres), et le
bras droit qui tient le crayon jaune, une étincelle à côté de la mine.

- **La géométrie fait foi dans `design/mika-v3/mika.js`** (la fonction `mika(o)` : un viewBox
  de 400 × 400, les pieds posés vers y = 344 ; la tête est un chemin de quatre cubiques, les
  tentacules des traits ronds de 46). `apercu.html` montre les douze expressions sur le marine
  puis sur le thème clair ; `mika-expressions.png` en est la planche. L'iPhone retrace ce
  dessin trait pour trait (`MikaArt.swift`), et un test compare les deux, pixel pour pixel
  (`testTheDrawingMatchesTheMockup`).
- **Les couleurs suivent le thème** (`MikaPalette`) :

  | | Marine (défaut) | Clair |
  | --- | --- | --- |
  | Corps | `#5C88FF` | `#3870FE` |
  | Tentacules arrière | `#3F6BE8` | `#2A5BE0` |
  | Disque de l'avatar et du nid | `#171C2C` | `#E4ECFF` |

  Dans les deux : l'encre `#14182B` (pupilles, bouche, mine), les joues `#FF8FA8` à 80 %, le
  crayon `#F7B41F`, la gomme `#E3596C`, le bois `#F6DDB6`, l'étincelle `#F7B41F`, le reflet
  blanc à 26 %. L'ombre au sol (une ellipse plate) est une option (`shadow: true`). Plus de
  lueur de nuit ni de joues « cuites » dans des images.
- **Plus aucune image d'expression** : le catalogue `Assets.xcassets/Mika`, `MikaArt.swift`
  généré, `scripts/mika-assets.py` et le workflow `mika-encode.yml` sont retirés (l'ancien kit
  reste sur la branche `assets/mika-kit`). Une seule image vient encore du dessin, exportée du
  SVG par `node design/mika-v3/export.js` : le Mika de l'écran de lancement (`LaunchMika`).
- **L'icône de l'app** porte le nouveau Mika : en buste, la bouche ouverte, sur un bleu nuit
  uni `#101737` (la variante Y de `design/mika-v3/icone.html`, qui garde aussi les pistes non
  retenues). `node design/mika-v3/export.js --icone Y` refait `AppIcon.png` au pixel près
  (1024 px, sans transparence). La marque posée dans l'app (`BrandMark`) porte encore l'ancien
  Mika ; `--icone Y --marque` la refera quand on le décidera.

**La règle des deux places** (écrite aussi en tête de `MikaMascot.swift`). Mika parle à la
première personne, et il n'a que deux places :

1. **La bulle** : un petit Mika en entier (76 points) à gauche, sa bulle à droite, en haut
   de l'écran (`MikaAsk`). C'est lui qui pose les questions du parcours, propose la séance sur
   Home, présente l'offre.
2. **Le moment** : un grand Mika en entier (170 à 240 points), au centre : il se présente,
   prépare le plan, fête une réussite, attend une génération, tient un écran vide. Vectoriel,
   il est net à toutes les tailles.

Jamais deux fois sur un écran, jamais sur un bouton, jamais dans une liste. **Trois
cadrages** : en entier (`MikaMascot(mood:size:)`, `size` est le côté de la fenêtre
`-10 -30 420 420` de la maquette, où son corps tient les trois quarts de la hauteur) ; en demi
(`MikaPeek`), du haut de la tête jusque sous les joues et la bouche, coupé net à y = 248 par le
bord où il se pose, sans montée — pour une carte ou une ligne dont il dépasse ; en avatar
(`MikaAvatar`), le visage en gros plan dans un disque de la couleur d'une surface, partout où
il ferait moins de 40 points. **Jamais directement sur un fond bleu**, où il disparaîtrait :
`MikaMascot(…).mikaBackdrop(.disc)` glisse un disque derrière lui, `backdrop: .blue` lui donne
un liseré blanc d'autocollant.

**Le moteur : une pose est un vecteur.** Ce qui n'allait pas avant : des images (puis des
vidéos à 24 images par seconde) dans une interface à 120 Hz, et un fondu entre deux images
pour tout mouvement. Maintenant :

- **Une pose** (`MikaPose`) est une quarantaine de nombres : l'ouverture des yeux, les yeux
  rieurs, les yeux écarquillés, le clin d'œil, le regard (x, y), la courbure, la largeur et
  l'ouverture de la bouche, la bouche ronde, le penché, l'écrasement, le crayon (tenu, angle,
  pivot, prise), l'étincelle, ce qui flotte autour de lui (les trois points, les traits
  d'écriture, les « z », les confettis), le clignement, et ses deux bras, chacun en cinq points
  de contrôle rangés en polaire autour de l'épaule (le bras tourne autour d'elle au lieu de se
  raccourcir en ligne droite).
- **`MikaFigure` est `Animatable`** : sa pose est son `animatableData`. Quand elle change dans
  une animation, SwiftUI calcule la pose intermédiaire à chaque image et le `Canvas` se
  redessine, à la cadence de l'écran, avec les courbes de `MicaboMotion`. Passer d'une humeur à
  l'autre est une **métamorphose** : l'ellipse blanche de l'œil s'aplatit pendant qu'un trait
  d'encre apparaît puis se courbe (vers le haut pour un œil rieur, vers le bas pour le sommeil ;
  le sourire, le clin d'œil et le clignement passent par le même mécanisme), la bouche s'ouvre
  depuis son trait, le crayon rentre dans le poing quand le bras se range.
- **Coût nul au repos** : rien ne se redessine tant que la pose ne change pas. Pas d'horloge
  d'images, pas de minuterie hors du clignement.
- **À la cadence de l'écran** : pendant un geste, le canevas se redessine à chaque image. Sur
  un iPhone ProMotion, les animations qu'une app calcule elle-même plafonnent à 60 images par
  seconde sans la clé `CADisableMinimumFrameDurationOnPhone` d'`Info.plist` : elle est posée
  (test `testTheAppAsksForTheScreenCadence`), et vaut pour toutes les animations SwiftUI de
  l'app.
- **Un geste, une fois, sur place** (`MikaMood.beats` : une suite de poses et de courbes) :

  | Humeur | Geste | Pose qui reste |
  | --- | --- | --- |
  | `wave` | le bras gauche se lève, balance deux fois, revient | le repos |
  | `celebrate` | les deux bras en l'air (le seul rebond), une gerbe de confettis de 1,2 s | les bras levés, les yeux rieurs |
  | `happy` | un petit écrasement de joie | les yeux rieurs, la bouche ouverte |
  | `wink` | l'œil droit se ferme en arc, la tête penche un peu | le repos |
  | `surprise` | les yeux s'écarquillent, la bouche s'arrondit | la surprise |
  | `sad`, `shake` | le regard tombe, le crayon se range ; « non » : la tête penche d'un côté puis de l'autre | la tristesse |
  | `sleep` | les yeux se ferment, « z z » | le sommeil |
  | `look`, `appear` | le regard de côté ; l'arrivée regarde puis sourit | attentif ; le repos |
  | `proud` | le crayon se lève, les yeux rient | la fierté |
  | `think`, `write` | les deux **attentes**, les seules boucles : ses trois points pulsent ; le crayon oscille près de sa tête | tant que l'humeur dure |

  Aucun geste ne le déplace : le penché fait glisser la tête sans qu'aucun point ne monte ni ne
  descende, l'écrasement part du sol (`MikaArt.bodyTransform`, test
  `testNoGestureMovesMikaUpOrDown`). Pas de saut, pas de translation, pas d'apparition qui
  grandit (test `testNoMikaJumpsAnywhere`, qui relit les sources de l'app).
- **À l'appui** (`reactsToTap`) : un écrasement de 3 % et un clin d'œil, puis il revient.
- **La vie au repos** : un clignement toutes les 3 à 6 secondes (au hasard), seulement pour un
  Mika de 64 points et plus, les yeux ouverts, visible à l'écran.
- **Un seul Mika en mouvement** (`MikaStage`) : le dernier qui commence un geste pose le
  précédent sur la fin du sien, et personne ne cligne pendant qu'un autre joue. **Hors écran,
  tout s'arrête** (la vue disparaît, ou sort de ce que sa page montre) : le metteur en scène
  (`MikaDirector`) pose Mika d'un coup sur la fin de son geste, et plus rien ne repart ; de
  retour, une attente reprend, un geste déjà joué ne se rejoue pas.
- **« Réduire les animations »** : ni geste, ni boucle, ni clignement ; un changement d'humeur
  est un fondu bref vers l'expression. `\.mikaStill`, `frozenAt`, `animates: false`, les tests :
  l'expression fixe de l'humeur (`MikaMood.pose`), celle des douze dessins de la maquette.

**Ajouter une humeur.**

1. **La dessiner dans la maquette** : une ligne dans la table `set` de
   `design/mika-v3/apercu.html` (et, s'il faut une forme nouvelle, dans `mika.js`), puis
   `node design/mika-v3/export.js` pour refaire la planche.
2. **Sa pose** (`MikaArt.swift`) : un `static let` de `MikaPose`, écrit depuis le repos
   (`idle.with { $0.eyeHappy = 1 … }`) avec les nombres de la maquette. Si elle demande un trait
   que les poses n'ont pas (un accessoire, une autre bouche), ajouter **un nombre** à
   `MikaPose.Lane` (et à `count`), son accesseur, et le dessiner dans `MikaArt.scene` de façon
   qu'il s'interpole : de 0 (absent) à 1 (entier), jamais « oui ou non ».
3. **Son humeur** (`MikaMascot.swift`) : un cas de `MikaMood`, sa `pose`, et son geste dans
   `beats` — une suite de `MikaBeat(pose, courbe)` qui finit sur la pose qui reste. Tout se
   passe sur place : ni `tilt` de plus de 3 degrés, ni `squash` de plus de 3 %.
4. **Les tests** : l'ajouter à `MikaMockup.expressions` si la planche la porte, et ses nombres
   à `testThePosesAreTheMockupOnes`. Les tests généraux la couvrent d'office : elle a une pose,
   elle s'interpole avec toutes les autres, aucun temps de son geste ne déplace Mika, rien ne
   tourne hors écran.
5. **La regarder** sur les planches `mika10-*` (`MikaRenderTests`) : en entier, en demi, sur le
   marine et le clair, à côté de la maquette.

**L'écran de lancement et la première image.** L'écran de lancement (`UILaunchScreen` dans
`Info.plist`) est le marine `#0B0F1C` (`LaunchBackground`, le même dans les deux thèmes) et
Mika au centre de l'écran (`LaunchMika`, 200 points). La première image de l'app
(`LaunchCurtain` dans `RootView`) repose le même fond et la même image au même endroit, puis
fond sur l'écran qui suit (test `testTheLaunchScreenAndTheFirstFrameMatch`).

**Les planches** (`MikaRenderTests`, rendus `mika10-*`) : la maquette au-dessus du même tableau
dessiné par l'app, avec l'écart en pixels sous chaque dessin ; chaque humeur en entier et en
demi ; les tailles 36, 84, 150, 240 et 300, les demis et les avatars ; les métamorphoses et les
gestes image par image ; la gerbe de confettis ; les fonds (liseré, disque, arabe) ; l'écran de
lancement ; Mika à sa place dans un quiz, un écran vide, une attente.

**Le même langage dans tous les onglets** :

- **Le titre de page** : 26 points, le plus gras (`MicaboPageHeading`, le mois du Calendrier,
  le bonjour de Home) ;
- **Les titres de section** : `StudySectionTitle` partout (19 points), y compris les groupes
  de réglages du Profil, qui ne sont plus en petites capitales ;
- **Les cartes** : `homeCard` — blanche le jour, anthracite la nuit, un filet, la même ombre
  douce ; 26 points de rayon pour une grande carte (`MicaboStage.cardRadius`), 20 pour une
  tuile ou une rangée-carte (`tileRadius`) ; `homeCardClipped` quand Mika sort du bord bas ;
- **Le grand bouton** : bleu, texte blanc, un seul par écran.

Home garde exactement sa hiérarchie et sa logique (§ 1, `HomeDay`, `StudyPlan`,
`home_plan_tapped`) : seul le dessin change. La carte de l'examen du Calendrier, la journée de
Concentration, la carte profil et les cartes de Leçons prennent les mêmes mesures.

## 10. Lot 7 : toutes les matières, « Corriger un texte », chercher dans le contenu

Clés `ios.ku7.*` (26 langues), sans fonction serveur nouvelle : tout passe par `mika-chat` ou se
fait sur l'appareil.

- **Aide aux devoirs, toutes matières** : la tuile « Scanner un exo » devient « Aide aux devoirs ».
  Deux familles s'ajoutent à `SolverSubject` (`languages` : langues et littérature ;
  `humanities` : histoire, géographie, philosophie, économie), avec leur devinette sur l'appareil,
  leur fil de « Demande à Mika » et leurs idées de questions. La consigne (`ios.ku7.prompt.solve`)
  traite une question de cours, d'analyse ou de langue comme un raisonnement pas à pas, et
  `HomeworkLevel` ajoute le palier de l'élève dans les mots de son pays (« Gymnasium », « High
  school », « Collège »…). Le registre envoyé à la fonction ne change pas.
- **Corriger un texte** (`Features/Writing`, raccourci de Home) : coller, taper ou photographier
  (scanner VisionKit ou photothèque, OCR sur l'appareil) ; Mika relit à son niveau, garde la
  langue du texte et explique dans celle de l'app : `[SUMMARY]`, `[FIX] passage => correction` et
  la règle, `[TIP]` (`WritingParser`, balises en gras, numérotées ou traduites acceptées, repli
  sur le texte brut). Les corrections s'appliquent **sur l'appareil** au texte de l'élève,
  surlignées, et le texte corrigé se copie. Porte de Mika (`MikaQuota`, paywall `mika`), XP
  `mikaAnswer`. Statistiques : `home_tool_opened`, `writing_opened`, `writing_unreadable`,
  `writing_checked` (`source`, `fixes`, `applied`, `structured`, `words` en tranche),
  `writing_copied` ; jamais un texte.
- **Chercher dans le contenu** (`LessonSearch`) : la recherche de Leçons, qui promettait « un
  cours ou une carte » mais ne lisait que le titre, lit les cartes, les thèmes et le début des
  supports, sans accents ni casse, tous les mots dans n'importe quel ordre.
- **Ce qui demande un serveur**, et n'est pas fait : les fiches d'autres élèves (communauté), les
  plans d'examen « vérifiés » hébergés, un lien web de partage d'une leçon.
