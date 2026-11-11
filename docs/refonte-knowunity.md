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
3. **« Ton plan du jour »**, sur la scène bleue de la marque (`HomePlanHero`) :
   - en haut, le **prochain examen** (`NextExam.current`) : le compte à rebours dans sa tuile
     blanche, le nom, la préparation (`ExamReadiness`) ; un appui ouvre le Calendrier. Sans
     examen : « Ton plan du jour » et une pilule discrète « Ajouter un examen » qui ouvre
     `ExamEditSheet` ;
   - **la** chose à faire maintenant (`HomeDay.primary`) : la séance de révision posée au
     calendrier aujourd'hui, ni faite ni finie (`StudyPlan.today` → `HomeSession.next`), puis
     la leçon en cours tant qu'elle n'a pas avancé aujourd'hui, puis les cartes dues, puis la
     leçon ; sinon, écrire la suivante ;
   - **un** grand bouton blanc — « Démarrer la séance », « Continuer », « Réviser
     maintenant » —, Mika en buste qui regarde par-dessus (comme sur Concentration). La séance
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

**L'élève tout neuf** : la rangée du haut ; la scène bleue avec la bulle de Mika (le salut à
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
