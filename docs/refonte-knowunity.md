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

1. **La rangée du haut.**
   - À gauche, pour un élève qui n'est pas Pro : une pilule « ✦ Pro » en dégradé de l'app,
     qui ouvre le paywall (déclencheur `upgrade`). Rien pour un abonné.
   - À droite : la pastille XP (« ⚡ 120 », l'XP de la semaine, avec l'emoji de la ligue),
     qui ouvre la ligue ; puis la pastille de série, qui existe déjà.
2. **La question, Mika perché, la barre et les imports** : inchangés.
3. **« Aujourd'hui »**, une carte :
   - un anneau `xpToday / DAILY_XP_GOAL` (50) et le titre « Objectif du jour » ;
   - « {n} cartes à réviser », qui ouvre la révision des cartes dues (ou disparaît à 0) ;
   - « Continuer {leçon} », qui ouvre la leçon en cours (la carte « Reprendre » actuelle peut
     y être fondue) ;
   - sans aucune leçon : « Crée ta première leçon », qui met le curseur dans la barre ;
   - objectif atteint : « Objectif atteint ! » et l'anneau plein.
4. **« Outils »**, une grille 2 × 2 de tuiles (icône colorée, nom, une ligne) :
   - **Scanner un exo** : « Mika t'explique pas à pas » (§ 4) ;
   - **Quiz éclair** : « 5 questions sur tes leçons ». Ouvre l'entraînement de la dernière
     leçon ouverte ; sans leçon, la tuile invite à en créer une ;
   - **Minuteur** : « 25 min de concentration » (§ 5) ;
   - **Ligue** : « Ton classement de la semaine » (§ 3).
5. **Les trois chiffres**, inchangés.

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
avec cette génération-là. Une fois la leçon offerte utilisée, les imports ouvrent le paywall
comme avant. Les pastilles d'import n'affichent plus la couronne tant que la leçon offerte
reste.

## 8. Ce qui ne bouge pas

L'onboarding (ses écrans et leur ordre), le paywall et les achats, les prix, les thèmes
jour et nuit, Mika et ses humeurs. Chaque nouvelle phrase existe dans **toutes** les langues
de la plateforme.
