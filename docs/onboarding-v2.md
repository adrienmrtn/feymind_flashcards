# Parcours d'accueil v2 (iPhone) — novembre 2026

Mika pose les questions, tout s'adapte au pays et à l'année, le parcours est plus court, et
il se termine par la révélation d'un plan avant l'offre. Aucun prix, produit ni durée d'essai
n'a changé.

## 00. Lot 9 : « l'onboarding, tu as enlevé trop de trucs » (novembre 2026)

La demande du lot 5 était de « retirer 2/3 écrans un peu lourds » ; on était passé de 36 à 25
écrans, puis 24 au lot 7. **33 écrans maintenant** (32 vus en France, 31 pour un pays non
décrit) : les 36 d'avant, moins les cinq plus lourds, plus l'examen et la question d'essai.
L'ordre est verrouillé par `OnboardingFlowTests.testTheV2OrderIsLocked`. Les noms historiques
sont repris tels quels (`onboarding_step` reprend leurs courbes).

| Bloc | Écrans (lot 9) |
| --- | --- |
| Accroche | `hookLogo`, `name`, `welcome` |
| Profil scolaire | `country`, `level` *ou* `schoolType` + `year`, `exam`, `subjects` |
| Objectifs | `worries`, **`goal`**, **`startingPoint`**, `currentAverage`, `targetAverage`, `dailyTime`, `studyTime`, `notifications` |
| Mika | `building`, **`featuresIntro`**, **`mikaMission`**, `mikaSources`, `mikaPaths`, `sampleCard`, **`mikaDesign`**, `mikaTutor`, **`mikaSolution`**, **`mikaRelief`** (le compte se propose en la quittant : `OnboardingStep.accountStep`), **`socialProof`** |
| Plan et offre | `planBuilding`, `profileSummary`, **`freeTrialIntro`**, `trialOffer`, `paywall` |

**Remis, et rendus cohérents avec le parcours d'aujourd'hui**

| Écran | Ce qu'il dit maintenant | Pourquoi il revient, et ce qui a changé |
| --- | --- | --- |
| `goal` | « Et ton objectif n°1 cette année ? », une réponse | Le rythme question/réaction, comme Knowunity (« What's your main study goal »). Réponses **selon le niveau** (`LearningGoal.offered(for:)`) : collège (meilleures notes, comprendre, plus vite, prendre de l'avance, culture générale), lycée (+ « la formation de mes rêves »), université (« valider mon année », le travail), santé et concours (le concours). **Jamais l'examen** : il vient d'être dit, et `learningGoals` l'ajoute seul. Mika réagit (« je règle ton plan là-dessus »). |
| `startingPoint` | « On part de là où tu en es. Direction : **Abitur** 🎯 » | Le pont vers les moyennes, avec **le nom de l'examen du pays** (sans examen daté : « jusqu'où je peux t'emmener »). Chemin pointillé « Tu es ici » → trophée. |
| `featuresIntro` | « Maintenant, je te montre comment je vais t'aider. » | Annonce les pages de Mika ; Mika en demi sur sa ligne, la phrase se lit mot à mot. |
| `mikaMission` | « Ma mission : te faire les cours les plus interactifs possible… » | Première personne (règle du lot 7) ; Mika en demi qui écrit, plus dans une pastille. |
| `mikaDesign` | « Chaque bonne réponse te rapporte de l'XP, et ta série grandit chaque jour. » | Avant : une **deuxième** question (mur de Berlin) juste après la vraie (`sampleCard`). Maintenant : la série et l'XP de l'app (le jaune de la série), sans question. |
| `mikaSolution` | « Tout ce qu'il faut pour réviser, au même endroit. » | Les quatre portes d'une leçon (notes, quiz, flashcards, examens), cochées. |
| `mikaRelief` | « La montagne de choses à revoir ? Je la range pour toi, un chapitre à la fois. » | Plus de point rouge d'alerte (le rouge est réservé à l'erreur réelle). |
| `socialProof` | « Concrètement, ce qui change pour toi » : ton cours en photo ; « {matière} : la veille de l'examen » ; une question à 23 h | **Sans étude** (la seule reste sur `sampleCard`), **sans chiffre** (« 45 000 élèves », « 4,8 », « n°1 » ne sont sourcés par rien) et **sans avis signé inventé** : trois moments de la semaine de l'élève, avec une de ses matières. |
| `freeTrialIntro` | « Lina, je tiens à ce que tu essaies ton plan gratuitement. » | Le pont émotionnel avant la chronologie datée de l'essai (`trialOffer`, inchangée). |

**Restent partis (les plus lourds)** : `proofRetention` et `aiCompanion` (une deuxième et une
troisième citation d'étude), `founders` (une histoire que rien dans le dépôt ne source),
`supportUs` (une note demandée avant toute leçon : elle attend la première leçon finie) et
`trialReminder` (déjà dans la chronologie de l'essai). Un parcours interrompu sur l'un d'eux
reprend sur `startingPoint`, `planBuilding` ou `trialOffer`.

Gardés du lot 7 : la question d'essai et sa seule citation d'étude, la révélation du plan avec
sa courbe, les dates réelles de l'essai, le rappel réellement posé. Prix, produits et essai
inchangés. Rendus : `OnboardingLot9RenderTests` (`onb9-*`, français jour/nuit, allemand, arabe,
collège, université, États-Unis, iPhone SE en très grand texte). Phrases : 29 clés
`ios.onb9.*` dans les 26 langues.

**« J'vois pas le paywall »** — la cause : le compte de test du développeur est Pro à vie
(`LifetimePro`, et `ProAccess.refresh()` l'ouvre dès le lancement, la session survivant à la
réinstallation). Pro ouvert, `PaywallStepView` termine le parcours sans paywall, la leçon lue ne
se verrouille pas, aucune porte ne se ferme. Un compte qui a pris l'essai en bac à sable est dans
le même cas. Les rangées « Voir les paywalls » et « Refaire l'onboarding » étaient dans les
réglages de toutes les versions, App Store compris, et « Refaire l'onboarding » finissait
lui aussi sans paywall pour un abonné. Maintenant, une **section Test**, seulement sur un reçu de
bac à sable (TestFlight) ou une construction Xcode, jamais pour le compte de relecture d'Apple
(`PaywallTestMode`) : « Voir les paywalls », « Voir l'offre de secours » (le cadeau, puis le
tarif réduit), « Refaire l'onboarding » (depuis le début, **paywall compris même pour un compte
Pro** : `PaywallTestMode.onboardingPaywallKey`, effacé à la fin du parcours). Les achats y
passent par le bac à sable d'Apple.

## 0. Lot 7 : cohérence et psychologie (novembre 2026)

Retour après test sur iPhone : « encore 2-3 incohérences, et il faut renforcer la psychologie ».
**24 écrans** (23 en France, 22 pour un pays non décrit).

**Incohérences corrigées**

| Où | Avant | Après |
| --- | --- | --- |
| Moyenne visée | « 4 points à prendre » compté sur la droite 10–20 interne (un Américain 3.0 → 3.8 lisait « 4 points ») | `GradeGapCard` : « 3.0 → 3.8 » dans le barème de l'élève, « Ton plan sera réglé sur cet objectif » |
| Objectifs | « Et pourquoi tu apprends ? » trois écrans après l'examen, avec « monter en compétences pour le travail » proposé à un collégien | écran `goal` retiré ; `learning_goals` se déduit de l'examen (`OnboardingModel.learningGoals`) |
| La recherche | même étude sur trois écrans : accroche « 2x plus vite » (Harvard), page « c'est prouvé » (Harvard + Karpicke), ligne du paywall (Karpicke) | accroche sans chiffre ; page `socialProof` retirée ; ligne du paywall retirée ; Karpicke & Roediger cité **une fois**, sourcé, sur la question d'essai |
| Mika | « moi c'est Mika » puis « Il peut prendre tes documents », « Mika, c'est ton prof » | les trois pages de Mika à la première personne (`ios.onb7.mika.*`) |
| Chargements | le 1er annonçait déjà « construction de ton plan », le 2e relisait « tes réponses » et concluait « Ton **parcours** est prêt ! » juste avant « ton **plan** est prêt » | 1er : profil, réponses, niveau ; 2e : Mika à la première personne, « Je construis ton plan », « Je répartis tes matières… » (`ios.onb7.planBuild.*`) |
| Rappels | Mika disait « Ne loupe jamais un jour. » (pas une question), « les élèves révisent 2× plus souvent » (non sourcé), « Dix minutes » pour qui avait choisi 15 | « Je te fais signe chaque jour à 18 h pour réviser ? », « 15 min, et ta série tient », « Un seul rappel par jour » |
| Essai | « Jour 2 : un rappel » (lu comme demain ; le rappel part le surlendemain) | « 13 novembre : un rappel », « 14 novembre : ton abonnement commence » |
| Promesse du rappel | rien n'était posé pour qui avait passé les notifications ; le paywall promettait quand même | la boîte d'iOS s'ouvre à l'achat de l'essai si elle n'a jamais été montrée (`TrialEndReminder.schedule`) ; après un refus, le paywall ne promet plus de rappel |

**Leviers ajoutés (honnêtes)**

- **Preuve concrète** (`sampleCard`, après les parcours) : une vraie question sur une matière que
  l'élève a cochée (aire du disque, formule de l'eau, chromosomes, mur de Berlin, cogito), trois
  réponses, la bonne en vert, Mika réagit, puis l'étude. Sans serveur. Aucune matière qu'il n'a pas
  choisie : sinon, « Culture générale ».
- **Petit oui** : le rond de la question d'essai, et celui des rappels, répondent à une question
  simple avant le plan et l'essai.
- **Appropriation et projection** (`profileSummary`) : « Fait avec tes réponses, rien que pour
  toi », puis la courbe d'aujourd'hui (sa moyenne) au jour de l'examen (sa note visée, sous le
  trophée). C'est un objectif dessiné, pas une prédiction.
- **Réassurance** : des dates réelles sur l'essai, le rappel réellement demandé et posé, « Rien
  n'est prélevé d'ici là ».
- Inchangés : prix, ancrage annuel/hebdo, offre de secours (décompte réel), aucune fausse preuve
  sociale, aucune fausse urgence, aucune case pré-cochée.

## 1. Les écrans, avant / après

**Avant : 36 écrans** (35 vus par un élève de France). **Après : 25** (24 en France, 23 pour
un pays non décrit). L'ordre est verrouillé par `OnboardingFlowTests.testTheV2OrderIsLocked`.

| Bloc | v2 | Retirés en v2 |
| --- | --- | --- |
| Accroche | `hookLogo`, `name`, `welcome` | — |
| Profil scolaire | `country`, `level` *ou* `schoolType` + `year`, **`exam`** (nouveau), `subjects` | — |
| Objectifs | `worries`, `currentAverage`, `targetAverage`, `dailyTime`, `studyTime`, `notifications` (lot 7 : `goal` retiré) | `proofRetention` (devenu la réaction de Mika aux inquiétudes), `founders`, `aiCompanion` (l'étude de Harvard est sur l'écran de preuve), `startingPoint` (Mika pose déjà les questions) |
| Mika | `building`, `mikaSources`, `mikaPaths`, `sampleCard` (lot 7), `mikaTutor` (le compte se propose en le quittant) | `featuresIntro`, `mikaMission`, `mikaDesign`, `mikaSolution`, `mikaRelief` |
| Plan et offre | `planBuilding`, `profileSummary` (**la révélation du plan**), `trialOffer`, `paywall` (lot 7 : `socialProof` retiré) | `supportUs`, `freeTrialIntro` et `trialReminder` (regroupés dans `trialOffer`) |

- Les écrans gardés **gardent leur nom** : `onboarding_step` continue ses courbes.
- Un parcours interrompu sur un écran retiré reprend sur celui qui le remplace
  (`OnboardingStep.replacement(forRetired:)`), pas au logo.
- `LaunchGate` n'a pas changé (parcours à chaque installation, sauf « J'ai déjà un compte »).

## 2. Mika pose les questions

Un seul gabarit pour toutes les questions (`OnboardingScaffold` → `OnboardingMikaPrompt`) :
Mika en buste, posé sur sa ligne au bord gauche ; sa bulle à côté, dont le texte s'écrit ;
les réponses dessous ; le rond en bas à droite ; la jauge en haut. Même place sur chaque
écran.

- **Sur le papier de l'app** (crème le jour, nuit la nuit), plus dans une scène bleue :
  étincelle bleue le jour, blanche avec un halo bleu la nuit. Les écrans de chargement, de
  Mika, de preuve, du plan et de l'essai ont aussi perdu leur pastille bleue
  (`OnboardingMikaOnLine`). Seul le splash reste bleu (le lancement de l'app l'est).
- **Humeur par question** (`OnboardingStep.mikaMood`) : coucou au prénom, il regarde autour
  de lui pour le pays, réfléchit sur l'année, s'étonne de l'examen, écrit les matières…
  Une réponse le fait sourire.
- **Réactions** (la bulle tape la réaction à la place de la question, sans changer de
  hauteur) : pays décrit (« je connais les classes et les examens de ton pays »), examen
  (« Bac dans 7 mois : on a le temps de bien faire 💪 », trois tons selon l'échéance, et
  « pas d'examen en vue »), inquiétudes (« Le stress des examens ? On s'en occupe
  ensemble 💙 »), matières.
- Un seul Mika animé par écran. Bulle en Dynamic Type (`@ScaledMetric`), RTL (la queue
  se retourne).

## 3. Adapté à chaque pays et à chaque année

| Ce qui s'adapte | Où |
| --- | --- |
| Filières et années, dans la langue du pays | `SchoolSystem` (FR, TR, DE, ES) et `SchoolSystemWorld` (tous les autres) |
| Examens, avec la date d'une session ordinaire | `SchoolExams` (catalogue), `SchoolYear.exams` / `SchoolTrack.exams` |
| Matières de l'année, nom local | `SchoolYear.subjects`, puis le catalogue général dessous |
| Barème des moyennes | `StudentGradeScale` (sur la même droite 10–20 que le reste de l'app) |

**Pays décrits (40)** : les 24 de la liste (France, Royaume-Uni, Allemagne, Italie, Espagne,
Portugal, Tchéquie, Pays-Bas, Grèce, Hongrie, Pologne, Roumanie, Suède, Turquie, Belgique,
Suisse, Canada/Québec, Luxembourg, Maroc, Algérie, Tunisie, Sénégal, Côte d'Ivoire,
États-Unis) et, choisis dans « Autre pays », Autriche, Brésil, Mexique, Colombie, Chili,
Slovaquie, Danemark, Finlande, Estonie, Croatie, Slovénie, Serbie, Bulgarie, Russie, Égypte,
Arabie saoudite — soit au moins un système pour chacune des 26 langues de l'app. Un pays non
décrit garde le palier large (`level`) et « un contrôle / pas d'examen ».

Exemples d'examens : Brevet, Bac de français, Bac ; Abitur, Realschulabschluss (MSA) ;
Matura (Autriche, Pologne), Matura / maturité (Suisse, selon la langue de l'app) ; Maturità,
Esame di terza media ; PAU (Selectividad) ; GCSEs, A-levels ; SAT, ACT, AP, PSAT, MCAT ;
ENEM, Vestibular ; YKS, LGS ; ЕГЭ, ОГЭ ; Érettségi, Maturita, Bacalaureat, Πανελλαδικές,
Ylioppilaskoe, Studentereksamen, Državna matura… Les examens à sessions multiples (SAT, ACT,
MCAT, Högskoleprovet, Qudurat) proposent « dans deux mois », que l'élève corrige.

Barèmes : /20 (France, Maghreb…), Notenpunkte 05–15 en Oberstufe et 1–6 ailleurs en
Allemagne (« 1,0 = la meilleure note » sous la roue), 1–5 inversé (Autriche, Tchéquie,
Slovaquie), 9–1 en GCSE, A*–E en A-level, classes de diplôme à l'université britannique,
GPA 2.0–4.0 aux États-Unis, /10 (Italie, Espagne, Brésil, Mexique, Pays-Bas…), /30 à
l'université italienne, 1–7 au Chili, 2–6 en Bulgarie, échelle à 7 crans au Danemark, % en
Égypte, Arabie saoudite et Québec, /100 en Turquie.

**Le Calendrier** : à la fin du parcours, l'examen choisi devient un examen du Calendrier
(`OnboardingExamPlacement`, via `ExamRepository.create`) — nom, jour, moyenne visée, aucune
leçon. Une seule fois par installation, jamais pour « pas d'examen en vue » ni pour une date
passée, et pas si un examen du même nom existe déjà ce jour-là. Les rappels d'étude suivent
(`StudyNotifications.refresh`).

## 4. Le parcours de prix

Rien n'a changé dans les produits, les prix, l'essai ni l'offering.

1. **La preuve, sourcée** (`socialProof`, retirée au lot 7 : voir § 0) : l'essai de Harvard (Kestin et al., 2025) et ce
   qu'il reste d'un cours relu ou testé (Karpicke & Roediger, 2008). « 45 000 élèves »,
   « 4,8 », « #1 des assistants d'étude IA » et les avis signés sont retirés : rien dans le
   dépôt ne les sourçait (seulement les maquettes des captures).
2. **La révélation du plan** (`profileSummary`) : « Lina, ton plan est prêt 🎉 », « Bac
   dans 7 mois », puis le profil (pays, classe, examen et date, matières, temps et heure,
   moyenne d'aujourd'hui → visée dans le barème du pays) et ce que Mika va faire.
3. **L'essai** (`trialOffer`) : Aujourd'hui (accès complet) → Jour 2 (un rappel) → Jour 3
   (l'abonnement commence, avec la date), « Annule quand tu veux, en 2 touches », « Rien à
   payer aujourd'hui ». **Le rappel est réellement posé** à l'achat d'un essai
   (`TrialEndReminder`, notification locale 24 h avant la fin, si les notifications sont
   permises ; sinon l'étape dit comment l'activer). Événement `paywall_trial_reminder`.
4. **Le paywall** (`PaywallScreen`, le même dans l'app) : scène claire, Mika en buste sur le
   blanc ; titre au prénom et ligne « Ton plan est prêt. Bac dans 7 mois. » ; une rangée
   « Objectif : 16/20 » ; les bénéfices dits avec les réponses (« Pour tes matières : … »,
   « Calibrés sur ton examen : Bac ») ; une preuve sans chiffre inventé ; l'ancrage du prix
   (`PriceDisplay`, test A/B mois/semaine inchangé) ; un seul bouton ; la promesse du rappel,
   désormais tenue.
5. **À la fermeture** : l'offre de remise existante (`DiscountOffer.paywallClosed`), une
   fois par fenêtre, posée par-dessus les onglets à l'arrivée dans l'app.

## 5. Vérification

- Tests : `OnboardingFlowTests` (ordre, longueur, reprise), `OnboardingCountryTests`
  (systèmes, examens par pays, dates, barèmes, pays tapé à la main, persistance, placement
  dans le Calendrier), `PaywallTests` (chronologie, date du rappel).
- Rendus : `OnboardingV2RenderTests` (`onb5-*`) — français jour/nuit, allemand, anglais
  (États-Unis), arabe (RTL), Italie, Espagne, Autriche, Brésil.
- i18n : 70 clés `ios.onb5.*` / `ios.pay5.*` dans les 26 langues. Les durées (« 7 mois »,
  « 3 недели ») sont écrites par le système (`DateComponentsFormatter`) pour les pluriels de
  chaque langue.
