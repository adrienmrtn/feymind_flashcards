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

## 9. Mika hors du fond bleu, et un seul langage pour les onglets

« La mascotte est toujours sur fond bleu. » Les grandes apps d'étude à mascotte font l'inverse :
la mascotte vit **sur le fond de l'app** (Knowunity la pose au centre de sa page, sa bulle
au-dessus, et sur ses feuilles ; les autres la font sortir d'une carte claire ou la montrent
dans un écran vide), et la couleur de marque reste aux boutons, aux barres, aux pastilles. La
règle de Micabo, écrite aussi en tête de `MikaMascot.swift` :

**Le nouveau Mika** : une petite pieuvre noire brillante, cinq tentacules et le bras qui tient
le crayon jaune à l'étincelle (blanche à liseré bleu, lisible sur tous les fonds). Au build 166,
il était en entier partout, tout petit, posé sur des boutons et des listes, et il ramait. La
règle, écrite aussi en tête de `MikaMascot.swift` :

1. **En demi, par défaut dans l'app** (`MikaPeek`) : le haut du corps — la tête, les yeux, le
   bras au crayon, la naissance des tentacules — **dépasse d'un bord**, coupé net par lui, comme
   quelqu'un qui passe la tête. Trois tailles, une par rôle : `MikaPeek.card` (92 points) dans
   une carte, `.line` (100) sur la ligne d'une question, `.hero` (124) pour l'accueil de Home.
   Il est déjà là quand l'écran arrive (il ne monte plus de derrière son bord), fait son
   geste une fois, puis garde le sourire.
   - **Derrière le haut du bouton** d'une carte : le plan du jour de Home, la journée de
     Concentration (même taille, même retrait de 8 points depuis le bord droit) ;
   - **au bas d'une carte**, à droite, coupé par elle : la série du Profil, « Aucun examen » du
     Calendrier, l'en-tête du paywall, les cartes du tuteur et du scanner, la feuille des
     supports, l'aperçu de la leçon offerte, la connexion ;
   - **au-dessus de la barre de saisie** : le nouvel élève sur Home, sa bulle à côté ;
   - **sur une ligne** : les questions de l'onboarding (sa bulle à côté), l'essai gratuit, la
     preuve, l'en-tête d'une leçon ; sur le bleu du lancement, derrière le panneau (la seule
     scène bleue de Mika).
2. **En entier, rarement, aux moments qui comptent** (`MikaMascot`, 120 à 160 points, debout sur
   le papier, une ombre douce dessous) : l'accueil de l'onboarding (« Enchanté »), le plan
   révélé et sa préparation, la fête de l'objectif du jour et de la série, la fin d'une leçon,
   d'un quiz, d'un paquet de cartes, d'une récitation, le résultat d'un examen blanc, les écrans
   vides (Leçons, examens, quiz, conversation avec Mika), l'attente d'une génération (leçon,
   examen blanc, entraînement, emploi du temps). Là il fait coucou, fait la fête, écrit — puis s'arrête, souriant.
3. **En avatar** (`MikaAvatar`, son visage souriant dans un rond clair, fixe) partout où il ferait moins de
   40 points : les messages du tuteur, les retours d'une question, la note d'une leçon, la
   série, l'emploi du temps lu.
4. **Retiré** là où il n'apportait rien : la journée vide de l'agenda (une icône de
   calendrier), « Scanne ton emploi du temps » (l'appareil photo : Mika est déjà sur la carte
   d'examen juste au-dessus), la préparation d'un examen blanc. Jamais deux fois sur un écran,
   jamais sur un bouton, jamais dans une liste.
5. **Le papier** : crème et blanc le jour, graphite la nuit. Mika y est lisible partout grâce
   à ses images mêmes (ci-dessous) ; la nuit, une lumière douce derrière lui en plus. Des
   dégradés, pas de flou.

**Lisible et attachant (build 169 : « noir sur noir on voit pas bien la pieuvre », « il est pas
assez mignon »)** — sans changer le personnage, tout est cuit dans ses images par
`scripts/mika-assets.py`, donc gratuit pendant l'animation :

- **Une lueur claire** autour de lui (blanche, 36 %, douce) : invisible sur la crème et le blanc
  du jour, elle détache le corps noir du graphite la nuit et du bleu ; **une lumière de
  contour** froide sur le haut et la gauche du corps : le noir brillant a du relief ;
- **des joues roses** discrètes sous les yeux, repérées image par image (les yeux blancs dans
  le noir de la tête) et lissées dans le temps : elles suivent la tête sans trembler, ne
  touchent jamais les yeux ;
- **il finit sur un sourire** : après un geste (coucou, clin d'œil, fête), il passe en fondu
  à sa pose souriante, les yeux plissés (`MikaMood.rest`) ;
  au repos (`.idle`), il sourit aussi ; l'avatar est son visage souriant, cadré serré ;
- **le demi montre le visage entier** : `MikaPeek` coupe sous les joues et le haut des
  tentacules (260 unités du canevas au lieu de 236), jamais à ras des yeux ;
- **les écrans vides et les questions** prennent un clin d'œil ou un regard curieux, plus une
  réflexion qui tournait sans fin (écouter, réciter, l'examen d'une nouvelle leçon, un quiz
  raté, l'emploi du temps vide).

**Fluide à coup sûr, sans saut (lot 9, après le build 170 : « il faut pas que tu fasses Mika sauter », « mal
incarné », « pas fluide, c'est chiant »)** — le moteur (`MikaCore`, `MikaStage`) :

- **Ce qui n'allait pas** (mesuré sur le kit, `scripts/mika-assets.py` lit les mêmes images) :
  les vidéos du lot 7 tournaient à 24 images par seconde dans une interface à 60/120 Hz :
  chaque image restait à l'écran pendant 5 rafraîchissements, puis Mika sautait d'un coup à la
  suivante. Sur un Mika de 150 points, le centre de sa silhouette avançait **jusqu'à 21 points
  d'une image à l'autre** dans le saut (`saut`), 19 dans la fête (`celebration`), 62 dans
  l'apparition (qui tombait du haut) et 6 dans la surprise — des à-coups visibles quel que soit
  le décodeur, et justement les sauts que l'élève ne voulait plus. Les gestes calmes (coucou,
  clin d'œil, regard, repos) ne bougeaient presque pas le corps (0,2 à 0,7 unité du canevas par
  image) : seul le visage changeait. Et le passage pose fixe → vidéo → pose fixe pouvait
  clignoter (deux images différentes, un lecteur qui démarre).
- **Décision** : **plus aucune vidéo** (2,8 Mo de `.mov` et 2,3 Mo de premières images retirés).
  Aucun clip ne passait le contrôle image par image : la fête et le saut sont des sauts, et les
  gestes calmes se refont mieux en fondus. **Mika est une image fixe nette à chaque instant**
  — l'expression du moment, à la définition du kit (2 pixels par unité, net jusqu'à 220 points
  sur un iPhone 3x) — et **tout mouvement est natif**, interpolé par Core Animation à la cadence
  de l'écran (120 Hz sur ProMotion), avec les courbes de `MicaboMotion` :
  - **le fondu enchaîné** entre deux expressions (coucou → sourire, neutre → clin d'œil →
    sourire, réflexion ↔ écriture pendant une attente) : la nouvelle se pose sur l'ancienne
    restée opaque, puis l'ancienne s'efface — le corps, commun aux deux, ne pâlit jamais. Les
    expressions qui se suivent partagent leur silhouette à plus de 80 % (test
    `testSuccessiveExpressionsShareTheirBody`) ; la surprise, au corps trop différent, se garde ;
  - **une respiration** d'échelle de 1,5 %, ancrée sous ses tentacules, une fois à l'arrivée ;
  - **un petit écrasement** de 3 % qui revient (à l'appui, à une bonne réponse, à la fête) ;
    à l'appui, un clin d'œil, puis il revient ;
  - **les étincelles de la fête** : des étoiles vectorielles à quatre branches, comme celle de
    son crayon, qui grandissent une fois autour de lui, puis restent.
  Jamais de saut, de rebond ni de translation de Mika : il ne monte plus de derrière son bord,
  ne surgit plus de petit (l'accueil, les scènes du parcours), ne monte plus avec une question
  (`onboardingAppear(rises: false)`), ne rebondit plus avec la carte de la fête ; au pied d'une
  page, sa joie est un sourire, plus un bond (test `testNoMikaJumpsAnywhere`).
- **Un geste, une fois** (`MikaMood.beats`), puis il garde sa pose ; seules la réflexion et
  l'écriture alternent leurs deux images, le temps d'une attente réseau. **Un seul Mika en
  mouvement** (`MikaStage`) : le dernier arrivé joue, le précédent se pose sur sa fin. « Réduire
  les animations » garde les fondus (ce sont des fondus) et retire respiration, écrasement et
  croissance des étincelles ; `\.mikaStill`, `frozenAt`, les tests : l'expression fixe.

**Mieux incarné** — ce que fait la mascotte de Knowunity, appliqué à Mika sans rien lui
emprunter : elle est **grande et au centre des moments clés** (l'accueil la montre immense,
coupée par le bas de l'écran ; « on prépare tout » et « c'est prêt » la posent au centre, au
-dessus du titre), **son expression change avec ce qui se passe** (les yeux qui sourient, qui
regardent, la fête), **elle parle par sa bulle ou le titre juste à côté**, et elle est **toujours
à la même place et à la même taille pour le même rôle** (dans un quiz, elle passe la tête
au-dessus du panneau de réponse). Pour Mika :

| Rôle | Forme, taille | Expression |
| --- | --- | --- |
| Premier écran (bleu) | demi, `min(56 % de la largeur, 220)`, au centre, derrière le panneau | coucou → sourire |
| Accueil « Bienvenue » | entier, 190 | coucou → sourire |
| Questions du parcours | demi `.line` (100), sa bulle à côté | l'humeur de la question ; un sourire à chaque réponse |
| Plan révélé, fête de l'objectif, fin du minuteur, série | entier, 150 à 160 | fête (sourire + étincelles) |
| Fin d'un quiz, d'un paquet de cartes, d'une récitation | entier, 150 | fête (≥ 80 %), joie (≥ 50 %), clin d'œil (en dessous) |
| Résultat d'un examen blanc | entier, 124, à côté du score | fête, ou clin d'œil « pas encore » |
| Retour d'une réponse de quiz | demi `.card` (92), au-dessus du bord du panneau, à droite, en fondu une fois le panneau posé | joie (bonne), déçu (mauvaise) |
| Attente d'une génération, et son échec | entier, 150, au même endroit | écriture ↔ réflexion ; triste |
| Écrans vides | entier, 120 | coucou, clin d'œil, attentif, sommeil selon l'écran |
| Cartes (Home, Concentration, Profil, Calendrier, paywall…) | demi `.card` / `.hero` | inchangé |
| Messages, rangées | avatar (< 40) | son visage souriant |

**Changer de Mika, en une commande** : `python3 scripts/mika-assets.py <dossier du kit>
[--sheet controle.jpg]` refait toutes ses images (expressions, avatar, `MikaArt.swift`, avec la
lueur, la lumière de contour et les joues) ; sur GitHub, pousser le kit sur `assets/mika-kit`
puis `gh workflow run mika-encode.yml --ref <branche> -f target=<branche>` (un Linux suffit,
la planche de contrôle part sur `assets/mika-build`). Une expression manquante arrête le script
avec la liste attendue ; une expression nouvelle demande sa ligne dans `MikaStill`.

**Cahier des charges d'un futur Mika** (à donner à l'illustrateur ou à l'outil) :

1. **Le mieux : une animation vectorielle pilotée par l'app.** Un fichier **Rive (`.riv`)**
   avec une *state machine* : des entrées `mood` (nombre : repos, coucou, joie, fête,
   réflexion, écriture, clin d'œil, surprise, triste, sommeil, attentif) et `tap` (déclencheur),
   un état de repos qui respire à peine, des transitions mélangées entre états (pas de coupe),
   **aucun déplacement du personnage** (pas de saut ni d'entrée par un bord : les pieds restent
   au sol), le personnage centré, tentacules au bas du cadre, 60 i/s ou plus (Rive interpole à
   la cadence de l'écran). À défaut, un **Lottie (JSON)** par geste, 60 i/s, même règles. Couleurs
   à plat ou dégradés simples, contour lisible sur crème `#FAF6EE`, graphite `#1C1E26` et bleu
   `#3870FE`.
2. **Sinon : des images fixes.** Un PNG transparent de **1024 × 1024 px** par expression,
   nommé `mika-<expression>.png` : `neutre`, `sourire`, `clin-doeil`, `coucou`, `surprise`,
   `reflexion`, `ecriture`, `triste`, `sommeil` (et, si possible, `regard-gauche`,
   `regard-droite`, `fete` — les bras levés, les pieds au sol). **Le même corps au même endroit
   dans toutes** (seuls le visage, le bras du crayon et les accessoires changent), le bas des
   tentacules vers y = 970 px, la tête centrée vers x = 510 px, 40 px d'air au moins sur les
   bords : c'est ce qui rend les fondus invisibles. Fond transparent, pas d'ombre au sol (l'app
   la dessine).
3. **Une animation en images** (si ni Rive ni Lottie) : une séquence PNG par geste à **60 i/s**,
   même canevas et même corps que les images fixes, le personnage au sol du début à la fin, la
   première et la dernière image identiques à une expression fixe. Le moteur actuel ne les lit
   pas : ce serait un nouveau lecteur, à faire seulement si elles sont parfaites image par image.

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
`home_plan_tapped`) : seul le dessin change — le plan du jour sur une carte claire, l'examen
dans sa tuile bleu pâle, le bouton bleu, Mika noir sur le blanc. La carte de l'examen du
Calendrier, la journée de Concentration, la carte profil et les cartes de Leçons prennent les
mêmes mesures.

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
