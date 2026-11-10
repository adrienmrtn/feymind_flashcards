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

- L'appareil photo (scanner de document là où il existe) ou la photothèque, une seule page.
- L'OCR **sur l'appareil**, celui des imports.
- Un écran de conversation avec Mika, hors leçon (« Mika · Exercice »), qui reprend le chat de
  la leçon : la pièce jointe `{ title: "Exercice scanné", text: <OCR> }` et un premier message
  envoyé tout seul : « Explique-moi cet exercice pas à pas, sans me donner seulement la
  réponse. » On peut poser des questions ensuite.
- La porte est celle de Mika : une question offerte à vie, puis le paywall (`mika`).
- Une réponse rapporte `exerciseSolved` (15) la première fois, puis `mikaAnswer`.
- Une photo illisible : « Je n'arrive pas à lire la photo. Reprends-la bien à plat, avec de la
  lumière. »
- Aucun appel serveur nouveau : `mika-chat` accepte déjà un document joint en texte.

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
