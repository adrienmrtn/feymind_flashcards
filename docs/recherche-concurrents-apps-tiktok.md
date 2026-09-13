# Concurrents mobiles de Micabo — App Store et TikTok

Recherche du 13 septembre 2026. Rien n'a été modifié dans l'app ni sur le site. Ce document
sert à voir le terrain, pas à en copier le ton.

**Méthode.** Fiches App Store via l'API iTunes Search (vitrines FR, US, DE, ES, BR) et un
scraper App Store. TikTok via le scraper Clockworks (profils et vidéos récentes), recoupé avec
les enquêtes publiques (Social Growth Engineers, Virengine, Pipiads, offres d'ambassadeurs).
Les notes et avis sont **spécifiques à chaque vitrine** : 364 avis FR n'est pas 1 999 avis ES.
Les comptes TikTok évoluent vite ; les chiffres d'abonnés et de vues sont un instantané.

**App Store Connect n'est pas public.** Le portail [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
n'expose les fiches, IAP, reviews et analytics que du développeur connecté. On ne peut pas
ouvrir la fiche Connect d'un concurrent. Ce que tout le monde appelle « le lien App Store
Connect » d'une app tierce, c'est en pratique **la fiche publique** `apps.apple.com`, plus
l'identifiant numérique Apple (`trackId`) qui est la clé de l'app. Pour chaque concurrent,
ce document donne :

- la fiche App Store France (et les vitrines qui pèsent vraiment)
- l'ID Apple et le bundle ID
- le lookup iTunes, qui renvoie la même métadonnée qu'une fiche Connect publique : titre,
  langues, note, avis, version, vendeur

Exemple de lookup : `https://itunes.apple.com/lookup?id=6748599950&country=fr`

---

## 1. Où Micabo se bat réellement

Micabo n'est pas « une app de flashcards ». C'est une app iOS de **fiche** (PDF, photo, Word,
notes → un cours qu'on relit) et, si on le veut, de **cartes en répétition espacée**. Le
tutoiement, le français d'abord, le SM-2, l'extraction locale du texte : c'est le produit.

Le marché mobile autour de ça n'est pas un seul rayon. Quatre couches se superposent, et
confondre les couches fait viser le mauvais ennemi.

| Couche | Ce que l'élève veut | Concurrent type | Ce que Micabo est |
| --- | --- | --- | --- |
| **A. Clones IA du geste Micabo** | PDF / photo → fiches ou cartes, tout de suite | Flashka, Retain, Parkeur, Studyflash, Atom AI, Wellnotes, Poki | Concurrent frontal |
| **B. Géants US de la carte** | Bibliothèque + modes d'étude + IA en plus | Quizlet, Knowt, Gizmo, StudyFetch, Turbo AI | Concurrent d'acquisition US, faible en FR |
| **C. Réseaux lycée FR / DE** | Fiches des meilleurs élèves, programme officiel, brevet/bac | Knowunity, Wilgo, Revyze, Nomad, Kartable, SchoolMouv, Eliott | Concurrent d'attention, pas de méthode SRS |
| **D. Référence SRS** | Garder pour de bon, médecine, droit, langues | AnkiMobile, Noji, RemNote, Brainscape, AlgoApp | Concurrent de crédibilité, pas de génération |

Micabo est aujourd'hui l'un des rares à tenir **A + D** en même temps (génération depuis le
cours *et* un vrai planificateur). Flashka et Retain tiennent A et vendent un SRS. Anki tient
D et refuse A. Knowunity et Wilgo tiennent C et n'ont pas besoin d'un vrai SM-2 : leur
produit, c'est le programme français et le feed social.

Conséquence pour TikTok : les formats qui marchent ne sont pas ceux de la couche D. Anki n'a
pas de compte. Les formats qui marchent sont ceux de A et C — UGC étudiant, « trop facile /
c'est interdit ? », Reveal tardif de l'app, comptes localisés, parfois un carrousel en
appoint. La France n'est pas un marché secondaire de cette vague : Wilgo, Parkeur, Revyze
et Knowunity y jouent déjà, en français, sur le bac.

---

## 2. Tableau maître — fiche App Store

Notes et avis **vitrine France**, sauf mention. Gratuit + IAP sauf AnkiMobile (payant à
l'achat). Catégorie Education partout.

### 2.1 Concurrent frontal (PDF / photo → fiche ou cartes)

| App | ID Apple | Bundle | Vendeur | Note FR | Avis FR | Fiche App Store |
| --- | --- | --- | --- | --- | --- | --- |
| **Flashka - AI Flashcards Maker** | 6748599950 | `ai.flashka.ios.dev` | Flashka OU | 4,70 | 364 | [FR](https://apps.apple.com/fr/app/flashka-ai-flashcards-maker/id6748599950) · [US](https://apps.apple.com/us/app/flashka-ai-flashcards-maker/id6748599950) · [ES](https://apps.apple.com/es/app/flashka-ia-flashcards-y-quiz/id6748599950) |
| **Retain Cards: Apprentissage IA** | 6745344282 | `cards.retain.app.production` | Retain Labs GmbH | 4,33 | **3 531** | [FR](https://apps.apple.com/fr/app/retain-cards-apprentissage-ia/id6745344282) · [US](https://apps.apple.com/us/app/retain-cards-ai-flashcards/id6745344282) · [DE](https://apps.apple.com/de/app/retain-cards-ki-karteikarten/id6745344282) |
| **Parkeur - Fiches de revision** (US : NeoStudy) | 6499463714 | `com.parkeur` | Les Ignobles | 4,59 | **16 200** | [FR](https://apps.apple.com/fr/app/parkeur-fiches-de-revision/id6499463714) |
| **Studyflash: étudier avec l'IA** | 6737522601 | `com.studyflash.ai` | Studyflash GmbH | 3,99 | 479 | [FR](https://apps.apple.com/fr/app/studyflash-%C3%A9tudier-avec-lia/id6737522601) |
| **Atom AI: Révision & Flashcards** | 6752642430 | `com.newnowledge.app` | john ouguergouz | 4,62 | 313 | [FR](https://apps.apple.com/fr/app/atom-ai-r%C3%A9vision-flashcards/id6752642430) |
| **Wellnotes: Fiches IA & Mindmap** | 6739225998 | `com.antoine-gonthier.cogito` | Antoine Gonthier | 4,54 | 812 | [FR](https://apps.apple.com/fr/app/wellnotes-fiches-ia-mindmap/id6739225998) |
| **Poki: Flashcards & Fiches IA** | 6450241875 | `com.mthomas3.QuizLight` | INNOWAY | 4,60 | 1 361 | [FR](https://apps.apple.com/fr/app/poki-flashcards-fiches-ia/id6450241875) |
| **Plume - Fiches de revision** | 6737467807 | `com.geekapp.plume` | NextPixel | 4,60 | 1 015 | [FR](https://apps.apple.com/fr/app/plume-fiches-de-revision/id6737467807) |
| **Revizly : fiches de révision** | 6799069431 | `com.revizly.app` | Harry Abib | 4,50 | 4 | [FR](https://apps.apple.com/fr/app/revizly-fiches-de-r%C3%A9vision/id6799069431) |
| **Quizgecko: AI Flashcards** | 6473546188 | `mobile.quizgecko` | Version Zero Limited | 4,33 | 48 | [FR](https://apps.apple.com/fr/app/quizgecko-ai-flashcards/id6473546188) |
| **Mindgrasp** | 1638182014 | `com.apricotAI.MindgraspAI` | Mindgrasp, Inc | 4,57 | 30 | [FR](https://apps.apple.com/fr/app/mindgrasp/id1638182014) |
| **Fiches Revision Better Student** | 6738082238 | `com.swishlive.betterstudent` | clement gasner | 4,46 | 79 | [FR](https://apps.apple.com/fr/app/fiches-revision-better-student/id6738082238) |
| **Aistote : QUIZ IA** | 1668360955 | `com.roricorp.examelite` | Rori AI Teknology Ltd | 4,54 | 2 273 | [FR](https://apps.apple.com/fr/app/aistote-quiz-ia/id1668360955) |

Flashka revendique 1,5 M d'étudiants. Pack de langues de l'app : **anglais seulement**. Les
titres ASO, eux, sont localisés (ES : « IA Flashcards y Quiz »). L'Espagne est son vrai
marché de preuves sociales : **1 999 avis ES** contre 364 FR et 299 US.

Retain est Allemagne d'abord : **9 547 avis DE**, 3 531 FR, 384 US. Pack de langues réel :
DA, NL, EN, FI, **FR**, **DE**, IT, NB, PL, **PT**, **ES**, SV. C'est le seul clone A qui
shippe vraiment le français dans le binaire, pas seulement dans le titre de vitrine.

Parkeur est le jumeau français de la fiche : scan / PDF / YouTube → fiche, quiz, cartes
mémo, podcast, plan. 16 200 avis FR, vendeur Les Ignobles. En US l'app s'appelle NeoStudy.
C'est probablement l'app que l'ASO « fiches de révision IA » sert avant Flashka en France.

### 2.2 Géants US de la carte et du tuteur

| App | ID Apple | Bundle | Vendeur | Note FR | Avis FR | Avis US | Fiche |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Quizlet** | 546473125 | `com.quizlet.quizlet` | Quizlet Inc | 4,72 | **65 495** | **1 114 080** | [FR](https://apps.apple.com/fr/app/quizlet-apprendre-avec-lia/id546473125) · [US](https://apps.apple.com/us/app/quizlet-more-than-flashcards/id546473125) |
| **Coconote** (Quizlet, notes IA) | 6479320349 | `com.bbauman.Scripty` | Quizlet Inc | 4,65 | 630 | 16 784 | [FR](https://apps.apple.com/fr/app/coconote-prise-de-notes-ia/id6479320349) |
| **Knowt: AI Flashcards & Notes** | 6463744184 | `com.knowt.app` | Knowt Inc. | 4,62 | 90 | **10 573** | [FR](https://apps.apple.com/fr/app/knowt-ai-flashcards-notes/id6463744184) · [US](https://apps.apple.com/us/app/knowt-ai-flashcards-notes/id6463744184) |
| **Gizmo: AI Tutor** | 1610516671 | `io.gonative.ios.xqdyad` | SAVE ALL LTD | 4,67 | 1 645 | **13 780** | [FR](https://apps.apple.com/fr/app/gizmo-ai-tutor/id1610516671) · [US](https://apps.apple.com/us/app/gizmo-ai-tutor/id1610516671) |
| **StudyFetch** | 6663574866 | `com.studyfetch.mobile` | StudyFetch, LLC | 4,51 | 148 | **13 305** | [FR](https://apps.apple.com/fr/app/studyfetch-make-learning-easy/id6663574866) · [US](https://apps.apple.com/us/app/studyfetch-make-learning-easy/id6663574866) |
| **Turbo AI - Learn Faster** | 6502794561 | `ai.turbolearn` | TurboLearn LLC | 4,68 | 663 | **33 361** | [FR](https://apps.apple.com/fr/app/turbo-ai-learn-faster/id6502794561) |
| **StudySmarter / Vaia** | 1439949520 | `com.studysmarter` | StudySmarter GmbH | 4,61 | 2 012 | 1 529 (Vaia) | [FR](https://apps.apple.com/fr/app/studysmarter-reviser-flashcard/id1439949520) |

Quizlet Plus est l'IAP explicite. Knowt vend le contraire : Learn mode, tests et génération
IA **gratuits**, Ultra pour le tuteur Kai. Gizmo est un wrapper GoNative (`io.gonative…`) :
mobile-first, vies, ligues, « Duolingo for anything ». StudyFetch a levé 11,5 M$ (Owl
Ventures + College Board) autour de Spark.E, un tuteur ancré dans *tes* documents.
TurboLearn (Turbo AI) est le plus gros US récent de cette table après Quizlet, 33 k avis
US, pack EN only.

Knowt est le concurrent frontal **sur la promesse** (PDF → cartes, gratuit) et un nain
**sur la vitrine FR** (90 avis). Ce n'est pas une contradiction : son acquisition est US
high-school / AP, pas le bac.

### 2.3 Réseaux et programmes français / européens

| App | ID Apple | Bundle | Vendeur | Note FR | Avis FR | Fiche |
| --- | --- | --- | --- | --- | --- | --- |
| **Knowunity: Appli d'étude IA** | 1484296272 | `de.knowunity.app` | Knowunity GmbH | 4,72 | **31 625** | [FR](https://apps.apple.com/fr/app/knowunity-appli-d%C3%A9tude-ia/id1484296272) |
| **Wilgo : IA n°1 - Quiz Révision** | 6746050626 | `ai.wilgo.ios` | BONGOWAY | 4,63 | **30 611** | [FR](https://apps.apple.com/fr/app/wilgo-ia-n-1-quiz-r%C3%A9vision/id6746050626) |
| **Revyze - Apprends en scrollant** | 1614818005 | `io.revyze` | Revyze | 4,71 | **27 221** | [FR](https://apps.apple.com/fr/app/revyze-apprends-en-scrollant/id1614818005) |
| **Nomad Education Brevet Bac Sup** | 1441761075 | `com.nomadeducation.nomadeducation` | Nomad Education | 4,59 | **58 280** | [FR](https://apps.apple.com/fr/app/nomad-education-brevet-bac-sup/id1441761075) |
| **Kartable - Cours et révisions** | 825500330 | `fr.ecoleSurInternet.Kartable` | L'Ecole sur Internet | 4,50 | 20 263 | [FR](https://apps.apple.com/fr/app/kartable-cours-et-r%C3%A9visions/id825500330) |
| **SchoolMouv - Cours & révisions** | 1353761629 | `com.schoolmouv` | SAS PICARDO SHANNON | 4,59 | 11 369 | [FR](https://apps.apple.com/fr/app/schoolmouv-cours-r%C3%A9visions/id1353761629) |
| **Eliott \| Tuteur IA & Révisions** | 6475353901 | `app.eliott.eliottapp` | CULTUREME | 4,67 | 3 599 | [FR](https://apps.apple.com/fr/app/eliott-tuteur-ia-r%C3%A9visions/id6475353901) |
| **digiSchool Education 2027** | 6443938926 | `com.digischool.education` | digiSchool | 4,51 | 5 364 | [FR](https://apps.apple.com/fr/app/digischool-education-2027/id6443938926) |
| **Acuity - Revision & Devoir** | 6739139912 | `io.fstck.cogito` | FSTCK | 4,61 | 740 | [FR](https://apps.apple.com/fr/app/acuity-revision-devoir/id6739139912) |
| **Wooflash** | 6443394551 | `com.wooclap.wooflash` | Wooclap | 3,41 | 71 | [FR](https://apps.apple.com/fr/app/wooflash/id6443394551) |

Knowunity DE : 4,63 / **59 334** avis. C'est le scale player lycée en Europe : fiches
partagées, photo de devoir, planning d'examens. Pas un SRS. Wilgo se dit n°1 Education
France devant Duolingo, 600 k utilisateurs en 9 mois, **100 % gratuit**, contenu vérifié
enseignants, collège–lycée, « IA éthique » (elle n'écrit pas le devoir à ta place). Revyze
est un TikTok éducatif : vidéos courtes + quiz, 6e–Terminale en FR, GCSE/A-level en UK.
Nomad est le plus gros volume d'avis FR de toute cette liste (58 k) : contenu brevet/bac,
pas de génération depuis *ton* PDF.

Eliott est le tuteur français « familles et établissements » : Pronote, École Directe,
RGPD, hébergement UE. Wooflash est Wooclap côté révision, B2B fac, note App Store faible.

### 2.4 Référence SRS et cartes sans génération (ou presque)

| App | ID Apple | Bundle | Vendeur | Note FR | Avis FR | Fiche |
| --- | --- | --- | --- | --- | --- | --- |
| **AnkiMobile Flashcards** | 373493387 | `net.ichi2.anki` | Anki Software LLC | 4,13 | 312 | [FR](https://apps.apple.com/fr/app/ankimobile-flashcards/id373493387) — **29,99 €** à l'achat (US 24,99 $) |
| **AlgoApp - Flashcards** (ex-AnkiApp) | 689185915 | `com.ankiapp.client` | AlgoApp Inc | 4,67 | **10 488** | [FR](https://apps.apple.com/fr/app/algoapp-flashcards/id689185915) |
| **Noji: Fiche de Revision** | 1573585542 | `com.vedasapps.flashcards` | DELIGHTHUB PTE. LTD. | 4,50 | 2 409 | [FR](https://apps.apple.com/fr/app/noji-fiche-de-revision/id1573585542) |
| **Cogni: Fiche De Revision** | 6737768905 | `anki.flashcards.study.tool` | COGNIFLY LTD | 4,59 | 657 | [FR](https://apps.apple.com/fr/app/cogni-fiche-de-revision/id6737768905) |
| **RemNote - Notes & Flashcards** | 1545429784 | `com.remnote` | RemNote, LLC | 4,78 | 164 | [FR](https://apps.apple.com/fr/app/remnote-notes-flashcards/id1545429784) |
| **Brainscape - Smart Flashcards** | 442415567 | `com.brain-scape.sa.portal` | Bold Learning Solutions, Inc. | 4,69 | 926 | [FR](https://apps.apple.com/fr/app/brainscape-smart-flashcards/id442415567) |
| **Mochi - Flashcards and notes** | 1507775056 | `cards.mochi.app` | Matthew Steedman | 4,86 | 29 | [FR](https://apps.apple.com/fr/app/mochi-flashcards-and-notes/id1507775056) |

Noji a 8 839 avis BR et 13 851 US : c'est une marque SRS internationale qui se localise
« Fiche de Revision » en FR. AlgoApp capte les gens qui tapent « Anki » et ne veulent pas
payer 30 €. RemNote est notes + cartes dans le même document ; Brainscape, la notation par
confiance.

### 2.5 Adjacent (aide aux devoirs, pas le même job)

| App | ID Apple | Avis FR | Fiche | Pourquoi c'est adjacent |
| --- | --- | --- | --- | --- |
| **Gauth** | 1542571008 | 14 337 | [FR](https://apps.apple.com/fr/app/gauth-aide-aux-devoirs-en-ia/id1542571008) | Photo de l'exo → réponse. Concurrent d'attention TikTok, pas de fiche. |
| **Photomath** | 919087726 | 54 301 | [FR](https://apps.apple.com/fr/app/photomath/id919087726) | Google. Photo-maths. |
| **Memrise** | 635966718 | 31 623 | [FR](https://apps.apple.com/fr/app/memrise-parle-la-langue/id635966718) | Langues, pas tes cours. |
| **Goodnotes** | 1444383602 | 37 156 | [FR](https://apps.apple.com/fr/app/goodnotes-ai-notes-docs-pdf/id1444383602) | Prise de notes, pas SRS. |

### 2.6 Absents iOS, ou squatters

| Nom | Statut |
| --- | --- |
| **Wisdolia** | Web only. Les recherches App Store US ramènent des jeux homonymes. |
| **Revisely** | Pas d'app officielle dans ces vitrines. Voisins : Revise AI, Remembify. |
| **RevisionDojo** | Pas de listing iOS trouvé. |
| **Cards AI** (étude) | Collision de nom avec des apps de cartes de vœux. |
| **Retain Cards: AI Flashcard** (Berat Genc, id 6752827056) | Squatter ASO du nom Retain. |
| **Micabo** | Aucun hit iTunes FR sous ce nom au 13 sept. 2026. |

---

## 3. Fiches TikTok — stratégie par concurrent

Légende des formats, telle qu'on les voit vraiment sur StudyTok en 2025–2026 :

| Format | Ce que c'est | Signal technique |
| --- | --- | --- |
| **UGC visage** | Élève (ou acteur) parle à la caméra, hook texte long | Compte perso / ambassadeur, `isAd` parfois false |
| **UGC faceless** | Bureau, mains, PDF, screen recording, voix off | Souvent le plus viral (Retain) |
| **UGC IA** | Visage synthétique, même script | Coût bas, Pologne (Flashka) et FR (Wilgo) |
| **Carrousel / slideshow** | Plusieurs images, swipe vertical TikTok | `isSlideshow: true` |
| **Spark Ads** | Post organique boosté, ou clone collé en pub | `isAd` / `isSponsored` |
| **Compte officiel** | Marque unique, CTA bio | Un handle, souvent faible reach récent |
| **Armée de comptes** | 13 à 90+ comptes localisés, même formule | Le vrai moteur Flashka / Retain / Wilgo |

### 3.1 Flashka — armée localisée, reveal tardif, six langues

| | |
| --- | --- |
| Comptes | [@flashka_ai](https://www.tiktok.com/@flashka_ai) (officiel, ~3,9 k fans, 347 vidéos, 280 k cœurs) · [@flashka_ai_pl](https://www.tiktok.com/@flashka_ai_pl) (12,5 k fans, 33 vidéos, 330 k cœurs) · créateurs : `@notes.by.eliii` (ES) |
| Langues | **EN, ES, IT, FR, SV, PL** — adaptation, pas traduction mot à mot |
| Formats | UGC étudiant (crédibilité 30 s avant le produit) + carrousel study-tips (PL, officiel) + UGC IA (PL, visages synthétiques, ~183 k vues / vidéo) |
| CTA | Bio `flashka.ai` · « Try for FREE » · programme affilié Premium (coupon −20 % / commission 20 % via Rewardful) |

Virengine (juillet 2026) documente le playbook : **51 comptes**, fenêtre de trois mois,
**197 M de vues**, ~70 k downloads, ~40 k$ MRR. Le produit n'apparaît pas dans les
premières 30 secondes. L'ouverture est un morceau de vie médicale (822 pages de cardio,
classement des spécialités, « j'ai à peine révisé et j'ai eu le top »). Ensuite seulement
l'app, comme secret personnel. Le hook « tout le monde lâche ChatGPT » a fait **5,3 M de
vues** en espagnol chez `@notes.by.eliii`.

L'Italie déroule des minutes de prépa avant le reveal. La Pologne pousse des listes « trucs
fous appris en med school » avec un visage IA. L'anglais officiel mixe clip esthétique 5 s
(294 k plays dans l'échantillon), témoignage SRS (227 k), slideshow « how to be a 10/10
student », street interview. Fourchette de vues échantillon officiel : 2,5 k–294 k. Le
compte PL satellite est plus petit en volume de posts, plus dense en carrousels.

**Ce n'est pas une stratégie carrousel.** Le carrousel est un canal secondaire (tips, PL).
Le moteur, c'est une **illusion d'adoption organique simultanée** dans six langues, nichée
médecine / fac, avec reveal retardé. L'ASO suit : masse d'avis en **Espagne**, pas en
France. Le binaire EN-only n'empêche pas de vendre en ES/IT/FR/PL via le contenu.

Niche : étudiants de médecine et fac, mémorisation lourde. Pas le bac français.

### 3.2 Retain Cards — UGC Allemagne puis traduction, 90+ comptes

| | |
| --- | --- |
| Comptes | [@retain.cards](https://www.tiktok.com/@retain.cards) (officiel, 8,8 k fans, **26 vidéos**, 158 k cœurs) · [@retain_cards_official](https://www.tiktok.com/@retain_cards_official) (recrutement) · `@fey.retain.cards` · `@anastasia.retain.cards` · IG `@nele.retain.cards` · réseau Shortimize (~90 comptes) |
| Langues | **DE d'abord**, puis **FR** et **EN** — même setup, même ironie, même caption |
| Formats | UGC faceless (les 3 plus gros) + talking-head + démo produit / screen recording + **Spark Ads** (`isAd: true` sur les 4 vidéos officielles échantillonnées) + tests UGC IA |
| CTA | **« Suche Retain Cards im App Store »** — mot-clé de recherche, pas un lien bio. C'est volontaire : ça booste l'ASO. |

Social Growth Engineers, deux articles (juin puis novembre 2025) :

- J+19 post-app (mai 2025) : 28 M de vues, 7 k$ de revenu, 49 comptes, 40 ambassadeurs.
- Six mois plus tard : **90+ comptes UGC**, 72,4 M de vues lifetime, 50 k$ MRR, 30 k
  downloads. 8,4 M de vues sur 30 jours.

Formule qui scale : un format qui a marché, **traduit**, recollé. Captions types :

- « POV: you just figured out why everyone’s deleting ChatGPT. »
- « I’ve been studying for four years and only discover this now? »
- DE : « Klingt verboten… zu einfach », « Ist das wirklich erlaubt!? », « wo war das vor
  6 Jahren? »
- DE faceless : « To all lazy learners: 1. Take a picture 2. Specify your desired grade
  3. Let it quiz you » — 3 M de vues.

Le compte officiel est **maigre** (26 posts) et **payant** (ads). La distribution vit dans
le réseau d'ambassadeurs. Un clone EN `@retain.cards.offi` est mort (~400 plays). Les vues
officielles échantillonnées vont de 21 k à **4,5 M**.

Produit collé au contenu : photo / PDF / vidéo → cartes, date d'examen, plan, import Anki.
C'est le plus proche de Micabo sur le *job* (cours perso → cartes + date d'examen), avec
une acquisition DE→FR→EN que Micabo n'a pas.

**Pas une stratégie carrousel.** Faceless + talking-head. Le carrousel n'est pas le levier
documenté.

### 3.3 Wilgo — StudyTok français, bac only, 13 comptes

| | |
| --- | --- |
| Comptes | Vague de **13 comptes FR-only** depuis 2026, dont [@jeanne.wilgo](https://www.tiktok.com/@jeanne.wilgo) · programme ambassadeurs `ambassadors.wilgo.ai` (~25 vidéos / mois, formats fournis chaque semaine) |
| Langues | **Français uniquement** (cible bac). Lancement US AP en 2026 (Bio, Calc, US History, Psych, Chem). |
| Formats | **UGC visage** close-up, hook texte très long empilé en une phrase = format n°1. **Carrousel faceless** de ranking (ChatGPT vs Gemini vs Wilgo en dernière slide) chez `@jeanne.wilgo` (252,7 k). **UGC 100 % IA** : 1,4 M de vues en deux mois sur un compte. |
| CTA | La « méthode Wilgo », pas un feature dump. Preuves locales : bac blanc, moyenne, mention TB, première de la classe. |

SGE, mars 2026 : 4,8 M de vues / 30 jours malgré une cible étroite (un seul système
scolaire). Un hook traduit : « My sister got 18.5 on her mock baccalaureate because she
FINALLY listened to me… learned all her lessons in 30 minutes instead of 3 hours » —
431 k vues.

Wilgo n'est pas un clone PDF→SRS. C'est un coach de programme officiel, gratuit, ligues,
scanner de devoirs, annales. Sur TikTok français **c'est lui qui a pris le bac**, pas
Flashka. Pour Micabo, c'est le concurrent d'attention n°1 sur StudyTok FR, même si le
produit n'est pas le même : Wilgo vend le programme, Micabo vend *ton* cours.

Ici, **oui, il y a une vraie jambe carrousel** (ranking d'outils IA, faceless), mais le
moteur reste l'UGC visage + la méthode.

### 3.4 Knowunity — un compte par pays, Spark Ads, « c'est gratuit »

| | |
| --- | --- |
| Comptes | [@knowunity](https://www.tiktok.com/@knowunity) US, 18 k · [@knowunity.uk](https://www.tiktok.com/@knowunity.uk) **92 k / 24,2 M cœurs** · [@knowunity.es](https://www.tiktok.com/@knowunity.es) **67 k / 2,7 M** · [@knowunity.us](https://www.tiktok.com/@knowunity.us) 1,3 k · [@knowunity.fr](https://www.tiktok.com/@knowunity.fr) et [@knowunity.de](https://www.tiktok.com/@knowunity.de) documentés côté ads |
| Langues | **EN, ES, DE, FR** — comptes séparés, pas un compte polyglotte |
| Formats | Spark Ads témoignage « it's free » + talking-head « subo mi media » (ES) + origin story fondateurs (UK) + quiz organiques |
| CTA | Smart-link bio `a.knowunity.de/app` |

C'est l'organisation TikTok la plus propre de la catégorie : **un handle vérifié par
marché**, le même produit, le dialecte local (EVA-U / bachillerato en ES, A-levels UK,
brevet/bac FR). Pipiads : campagnes FR dès 2022 (« consulte les fiches des meilleurs
élèves »), ES 2024 (~972 k impressions sur un ad bachillerato). Les posts US récents de
l'échantillon sont modestes (348–10 k) ; les ads US plus anciens 152 k–704 k.

Pas une armée de 90 UGC. Une **marque localisée**. Le carrousel n'est pas le format
dominant dans l'échantillon ; talking-head + ads.

### 3.5 StudyFetch — Spark Ads + ambassadrice, pas le compte officiel

| | |
| --- | --- |
| Comptes | [@studyfetchai](https://www.tiktok.com/@studyfetchai) 85 k / 609 vidéos / 3,6 M cœurs · [@studyfetch](https://www.tiktok.com/@studyfetch) 14 k, **Spark Ads** · [@studyfetchangela](https://www.tiktok.com/@studyfetchangela) ambassadrice, 6,8 k / 280 vidéos / 1,4 M cœurs |
| Langues | **EN** (US campus) |
| Formats | UGC organique ancien (« freshman showed me this », 4–6,4 M) · Spark Ads caption identique « Create accurate notes from lectures… » 316 k–2,4 M · talking-head vlog Angela, pic **9,1 M** |
| CTA | `studyfetch.com` |

Le compte de marque a des posts récents morts (174 plays). La croissance vit chez
l'ambassadrice et dans les Spark Ads. C'est le schéma StudyFetch : payer le boost + un
visage campus, plutôt qu'un fondateur qui parle.

Pas de carrousel dominant. UGC + ads.

### 3.6 Quizlet — un million d'avis, un compte TikTok qui ne convertit plus

| | |
| --- | --- |
| Compte | [@quizlet](https://www.tiktok.com/@quizlet) **618 k** fans, 721 vidéos, 13,5 M cœurs, vérifié |
| Langues | EN sur le compte principal. Satellites langues abandonnés vers 2020. |
| Formats | Mèmes, carrousel (« my quizlet streak », « how did I get into college »), talking-head court, un ad 6 s |
| Vues récentes | **600–950** sur l'échantillon — un compte énorme, un reach actuel minuscule |
| CTA | Implicite (marque). Bio YouTube. |

Quizlet n'a plus besoin de TikTok pour exister : 1,1 M d'avis US, 65 k FR. Le compte est
une relique de marque. **Le carrousel est là, et il ne sauve pas le reach.** C'est la
preuve que « faire des carrousels » n'est pas une stratégie, c'est un format. Sans UGC
frais et sans ads, 618 k followers ne font rien.

### 3.7 Knowt — un social lead, lycée US, AP, @getknowt

Pas de hit sur la recherche utilisateur Clockworks (le handle n'est pas `@knowt`).
L'app elle-même pointe vers [tiktok.com/@getknowt](https://www.tiktok.com/@getknowt) et
Instagram `@getknowt`. Offre d'emploi Social Media Marketing Lead : **un post par jour**,
end-to-end TikTok + IG, audience high school, calendrier AP / SAT / ACT, KPI =
abonnements web plus que les vues.

Formats visibles IG/TikTok : tips AP, mèmes « procrastinating AP exams », CTA
**comment-to-DM** (« comment aphug and I’ll dm you the study guide »), carrousels
annoncés (« a full carousel on how to study for APHUG »). Langue : **EN**. Niche :
APUSH, AP Bio, AP Chem, APHUG — le lycée américain, pas le bac.

Le carrousel est un format secondaire annoncé, le quotidien est UGC/mème lycée. La
génération IA gratuite est l'arme produit contre Quizlet Plus ; TikTok sert à ramener
vers le web, où Knowt est plus fort que sur mobile FR.

### 3.8 Gizmo — « addicted to learning », UGC esthétique, EN

Pas de compte officiel propre dans la recherche Clockworks. Le produit se fait taguer
`@gizmo` / `#gizmoai` par des élèves UK (GCSE, A-level) : faceless, active recall, « the
app that makes my studies bearable ». Positionnement interne : habitude TikTok retournée
vers l'Anki loop (vies, XP, ligues). Langue : **EN**. Acquisition US/UK. 13 780 avis US,
1 645 FR. Wrapper GoNative : l'app iOS n'est pas native au sens Micabo.

### 3.9 StudySmarter / Vaia — DE memes, rebrand EN

| | |
| --- | --- |
| Comptes | [@studysmarter.official](https://www.tiktok.com/@studysmarter.official) 36 k, 206 vidéos, vérifié · [@vaiaapp](https://www.tiktok.com/@vaiaapp) pour le nom EN/BR |
| Langues | **DE** sur l'officiel (« Bestanden ist bestanden ») · **EN** sur Vaia (college, StudyTok aesthetic) |
| Formats | Talking-head relatable 5–12 s, mèmes examen. Vues récentes officielles 362–1 040. Vaia : hooks « You study less than me and get better grades? » + aesthetic. |
| CTA | Marque + `#studytok`. App « gratis ». |

Rebrand : FR/DE gardent StudySmarter, US/BR deviennent Vaia. 8 944 avis DE, 2 012 FR.
Toujours en train de poster (août 2026 dans l'échantillon). Reach organique officiel
faible. Ce n'est pas une machine UGC à la Retain.

### 3.10 Revyze — le produit *est* un TikTok

| | |
| --- | --- |
| Compte | [@learnwithrevyze](https://www.tiktok.com/@learnwithrevyze) (petit : 173 followers sur le handle vu) |
| Langues | **FR** (6e–Terminale) et **EN-UK** (GCSE / AQA / Edexcel / OCR) |
| Formats | Vidéos courtes in-app = le feed. TikTok externe sert à dire « révise comme tu scrolles ». |

27 221 avis FR : l'app a trouvé son public lycée. Ce n'est pas un concurrent de génération
de *tes* cartes. C'est un concurrent du temps d'écran. Si Micabo se met à faire des
carrousels pédagogiques, il se compare à Revyze, pas à Anki.

### 3.11 Les silencieux

| App | TikTok | Lecture |
| --- | --- | --- |
| **Anki** | Pas de compte officiel. Collision de nom. | La référence n'achète pas StudyTok. L'acquisition est bouche-à-oreille médecine / forums. |
| **Quizgecko, Mindgrasp, TurboLearn, Wisdolia, RevisionDojo** | Pas de compte étude officiel dans la recherche | TurboLearn a 33 k avis US : l'acquisition n'est pas ce scraper-là (ads, SEO, YouTube, autre). |
| **Parkeur** | Site : « la méthode est devenue virale », pas de handle massif documenté ici | 16 k avis FR : l'acquisition FR existe (TikTok / IG / ASO). À ouvrir à la main : recherche `@parkeur`. |
| **Eliott** | Pas de réseau UGC documenté dans cette passe | Confiance parents / établissements, pas StudyTok. |
| **Noji** | Non trouvé comme machine UGC | SRS + ASO « Fiche de Revision » + decks communautaires. |
| **Nomad, Kartable, SchoolMouv** | Marques contenu FR, TikTok possible mais ce n'est pas le playbook Flashka | Volume d'avis = années de marque éducation, pas une vague UGC 2025. |

---

## 4. Les cinq playbooks TikTok de la catégorie

Tout ce qui marche en 2025–2026 se range dans cinq machines. Micabo n'a besoin d'en
choisir qu'une pour commencer ; en mixer trois trop tôt, c'est le compte officiel Quizlet
(gros, mort).

### A. L'armée UGC localisée (Flashka, Retain, Wilgo)

On ne construit pas un compte. On construit **un réseau**. 13 (Wilgo) à 90+ (Retain) à
51 (Flashka). Chaque compte a un visage ou un bureau, poste la même émotion dans la
langue du feed, révèle l'app tard. Les comptes officiels sont des vitrines maigres
(Retain : 26 vidéos). Le volume vit chez les ambassadeurs.

Langues : on n'export pas, on **réécrit**. Flashka : six langues, médecine. Retain : DE
puis FR puis EN, même ironie. Wilgo : FR bac, puis AP US.

Coût : recrutement (formulaires inbound, VA, Discord), briefing hebdo des formats
gagnants, parfois UGC IA pour baisser le coût. Retain a poussé le CTA jusqu'à **forcer
la recherche App Store** dans la caption, pour l'ASO.

### B. La marque un compte par pays (Knowunity)

Un handle vérifié par marché, Spark Ads, smart-link. Moins de chaos que A, plus de
contrôle de marque. Marche quand le produit est déjà un réseau social lycée (fiches des
autres). Micabo n'est pas ça.

### C. L'ambassadeur unique + Spark (StudyFetch)

Un visage campus qui explose (9 M), le compte marque qui stagne, les ads qui clônent la
caption qui a marché. Moins cher que 90 comptes, plus fragile (une personne).

### D. Le carrousel / slideshow

Présent partout, **dominant nulle part** chez les apps qui ont vraiment scale.

- Flashka PL : carrousels « 10/10 student », méd-tips.
- Wilgo `@jeanne.wilgo` : ranking ChatGPT / Gemini / Wilgo, 252 k.
- Quizlet : carrousels mèmes, 600 vues.
- Knowt : carrousels AP annoncés, le quotidien est le talking-head.

Le carrousel convertit bien en **saves** (recettes, classements, « comment réviser X »).
Il convertit mal tout seul en downloads d'une app inconnue. Il est un **appoint** pour
une armée UGC, ou un format éducatif (Revyze). Ce n'est pas le levier Retain / Flashka.

### E. Le compte officiel qui poste « du brand »

StudySmarter, NaturalReader, le Quizlet 2026. Cadence réelle, vues à quatre chiffres,
parfois trois. Sans UGC externe et sans ads, StudyTok n'offre plus de distribution
gratuite à une marque Education.

---

## 5. Langues — ce que les vitrines disent, ce que TikTok fait

Deux couches distinctes, souvent en désaccord.

| App | Langues du binaire (App Store) | Langues TikTok qui travaillent | Vitrine où les avis s'accumulent |
| --- | --- | --- | --- |
| Flashka | **EN only** | EN, ES, IT, FR, SV, PL | **ES** (1 999) ≫ FR 364 ≈ US 299 |
| Retain | DA NL EN FI **FR DE** IT NB PL **PT ES** SV | **DE**, puis FR, EN | **DE** 9 547 > FR 3 531 ≫ US 384 |
| Knowt | EN only | EN (AP US) | US 10 573 ≫ FR 90 |
| Gizmo | EN only | EN (US/UK) | US 13 780 / FR 1 645 |
| StudyFetch | NL EN FR DE IT JA KO PL ZH ES | EN | US 13 305 |
| Quizlet | NL EN FR DE ID IT JA KO PL PT RU ZH… | EN (compte mortish) | US 1,1 M / FR 65 k / DE 107 k |
| Knowunity | FR DE ES PT… | EN, ES, DE, FR (comptes séparés) | DE 59 k / FR 32 k |
| Wilgo | EN pack (app FR) | **FR bac** → AP US | FR 30 611 |
| Parkeur | FR/EN | FR (non audité en profondeur) | FR 16 200 |
| Noji | EN FR DE PT ZH ES | — | US 14 k / BR 8,8 k / FR 2,4 k |
| AnkiMobile | Liste énorme | Aucun | US 2 330, FR 312, payant |

Lecture pour Micabo :

1. **Shipper le français dans le binaire** est un vrai écart vs Flashka/Knowt/Gizmo.
   Retain l'a déjà. Les avis FR de Retain (3 531) montrent que le marché FR paie pour un
   clone PDF→cartes, pas seulement pour Wilgo/Knowunity.
2. **Localiser l'ASO sans localiser le binaire** (Flashka ES) marche pour les downloads.
   Ça ne construit pas une marque française.
3. TikTok FR n'attend pas une app universelle. Wilgo a pris 4,8 M de vues / mois en ne
   parlant **que** bac, moyenne, mention, fiches. Les anglicismes StudyTok US (« deleting
   ChatGPT », « freshman showed me this ») se traduisent ; les preuves scolaires, non :
   on ne dit pas APUSH à un terminale.

---

## 6. Ce que font les hooks qui convertissent

Hors feature list. Tous les gros posts de cette recherche évitent « spaced repetition
algorithm » et « import PDF in one tap » en ouverture.

| Famille de hook | Qui | Exemple | Pourquoi ça marche |
| --- | --- | --- | --- |
| **ChatGPT fatigue** | Flashka ES, Retain 3 langues | « why everyone’s deleting ChatGPT » | L'élève a déjà l'IA générique. L'app se pose en *spécialiste du cours*. |
| **Trop facile / interdit** | Retain DE | « Ist das wirklich erlaubt!? » | Contourne le scepticisme. La démo (photo → quiz) arrive après. |
| **Je viens de découvrir ça en 4e année** | Retain | « studying for four years and only discover this now » | Honte + espoir. Âge fac / médecine. |
| **Ma sœur a eu 18,5 au bac blanc** | Wilgo | méthode Wilgo, 30 min vs 3 h | Preuve scolaire française, pas un USP. |
| **Lazy learner, 3 étapes** | Retain faceless | photo → note visée → quiz | Recette, donc save + recollage. |
| **Reveal à 30 s** | Flashka médecine | 822 pages de cardio, puis l'app | Crédibilité avant la pub. Évite le skip « c'est une pub ». |
| **Ranking d'outils** | Wilgo carrousel | ChatGPT < Gemini < Wilgo | Carrousel utile. L'app arrive en dernière slide. |
| **It's free** | Knowunity, Knowt | fiches des meilleurs / Learn mode | Contre Quizlet Plus. |
| **Streak / aesthetic** | Quizlet, Vaia, Gizmo | « my quizlet streak » | Habitude, pas conversion d'inconnus. |

Ce qui **ne** scale pas dans cette catégorie : le fondateur talking-head feature tour,
le carrousel de screenshots d'app, le « Day in the life of our startup ».

CTA qui marchent :

1. **Cherche « Nom » dans l'App Store** (Retain) — ASO + friction basse + pas de lien
   mort.
2. Smart-link bio (Knowunity, Flashka).
3. Comment-to-DM / coupon affilié (Knowt, Flashka Premium).
4. « Méthode X » plutôt que « télécharge X » (Wilgo).

---

## 7. Lecture pour Micabo — sans toucher au produit

### 7.1 Qui est vraiment en face

- **Sur le geste** (ton PDF → fiche + cartes) : Flashka, Retain, Parkeur, Atom AI,
  Wellnotes, Studyflash, Plume. Retain est le plus dangereux en Europe (avis DE+FR,
  langues, date d'examen). Parkeur est le plus dangereux en ASO français (16 k avis,
  mot « fiches de revision »). Flashka est le plus dangereux en distribution TikTok
  internationale (197 M de vues) et le plus faible en France (364 avis).
- **Sur l'attention lycée FR** : Wilgo, Knowunity, Revyze, Nomad. Ils ne font pas le
  même produit. Ils occupent le même feed. Un élève de première qui scrolle n'a pas
  « de la place » pour une quatrième app de révisions cette semaine.
- **Sur la crédibilité SRS** : Anki, Noji. Ils ne font pas de TikTok. Ils gagnent les
  PACES / médecine / langues sur les forums. Micabo a l'argument (vrai SM-2 +
  génération) ; personne sur TikTok ne le raconte, et ce n'est pas le hook qui marche.

### 7.2 Ce qu'il ne faut pas faire

- Un compte `@micabo` qui poste des carrousels de features. Quizlet a 618 k followers
  et 700 vues. StudySmarter poste encore, 400 vues.
- Traduire des scripts US mot à mot (« freshman », « GPA », « APUSH ») vers le bac.
  Retain traduit l'*ironie*, Wilgo réécrit la *preuve scolaire*.
- Ouvrir sur l'algorithme. Le marché a déjà vendu « répétition espacée » ; le feed
  scrolle. L'ouverture est une honte, une note, une photo de cours, un frère, un
  ChatGPT trop générique.
- Copier l'armée 90 comptes le premier mois. Retain a commencé par l'Allemagne et un
  format. Flashka a niché médecine. Wilgo a niché le bac.

### 7.3 Ce qui est cohérent avec Micabo

Micabo refuse déjà la mascotte Duolingo et la preuve sociale inventée
(`docs/plan-amelioration.md`). L'armée UGC Flashka/Retain **joue** l'organicité. Une
partie est de l'UGC IA, des Spark Ads, des captions recopiées. Ce n'est pas interdit ;
c'est un ton. Si Micabo parle comme un élève qui a un secret, ça peut coller au
tutoiement. Si Micabo parle comme une pub « 10× faster », ça casse la marque.

Pistes, pas un plan d'exécution produit :

1. **Un seul marché TikTok d'abord.** France, tutoiement, *ton* cours (PDF/photo), pas
   le programme officiel (c'est Wilgo) ni la fiche des autres (Knowunity). Le hook
   naturel : « j'ai arrêté de recopier mes fiches » / « ChatGPT me sortait le chapitre
   Wikipedia, pas *mon* cours » / date d'examen. C'est plus Retain-FR que Flashka-med.
2. **UGC visage + faceless, reveal tardif.** Le carrousel en appoint (classement
   d'outils, « comment je range un cours ») une fois que deux ou trois hooks UGC ont
   marché. Pas l'inverse.
3. **CTA = recherche App Store « Micabo »**, à la Retain, dès que le nom est assez
   distinct. Ça nourrit l'ASO que Parkeur et Wilgo tiennent aujourd'hui.
4. **Ne pas viser l'Espagne parce que Flashka y a des avis.** L'Espagne est le fruit
   d'une armée ES. La France a déjà Wilgo/Parkeur/Revyze ; c'est plus dur, et c'est
   *chez nous*.
5. **Langues.** Garder le français comme langue du produit (écart vs Flashka). Si un
   jour DE : c'est le marché Retain, déjà saturé en UGC. L'anglais TikTok sans binaire
   EN, c'est Flashka à l'envers — possible, mais second.

### 7.4 Carte mentale — qui gagne quoi

```
TikTok StudyTok 2026
├── Armée UGC (vues → downloads)
│   ├── Retain     DE→FR→EN    faceless + "interdit ?"     72M vues
│   ├── Flashka    6 langues   reveal 30s, médecine       197M vues
│   └── Wilgo      FR bac      "méthode", 13 comptes      4.8M/30j
├── Marque localisée
│   └── Knowunity  un compte / pays + Spark
├── Ambassadeur + ads
│   └── StudyFetch Angela + Spark
├── Carrousel (appoint)
│   ├── Wilgo ranking outils
│   ├── Flashka PL tips
│   └── Quizlet mèmes (mort)
└── Pas sur TikTok
    └── Anki, RemNote, Wooflash, Eliott (confiance / SRS / B2B)
```

---

## 8. Limites de cette recherche

- App Store Connect concurrent : inaccessible. IAP SKU par SKU non listés (l'API
  iTunes ne les donne pas). Les abonnements se déduisent des descriptions (Quizlet Plus,
  etc.).
- Scraper TikTok : 10 requêtes utilisateur sur 17, 141 vidéos. Hashtags (`#flashka`,
  `#retaincards`, `#studytok`) non scrapés (plafond d'usage Apify). Knowt / Gizmo /
  Parkeur / Eliott : pas de profil profond.
- Formats vidéo : inférés (`isSlideshow`, `isAd`, durée, caption), pas d'analyse
  frame-by-frame.
- Chiffres SGE / Virengine : enquêtes marketing, pas des filings. Ordres de grandeur
  (vues, MRR) à traiter comme tels.
- Les avis App Store ne sont pas des utilisateurs uniques, et une app peut reset son
  listing. Wilgo « n°1 Education FR » est un claim de marque, recoupé par 30 k avis
  en peu de mois — plausible, pas audité ici.
- Date : 13 septembre 2026. StudyTok se déplace en semaines.

### Sources

- API iTunes Search, vitrines `fr`, `us`, `de`, `es`, `br`, 13 sept. 2026
- Apify `freshactors/app-store-scraper` (runs FR `KlfqzEeeAscJMq09s`, US, DE, BR, ES)
- Apify `clockworks/tiktok-scraper` (run `qGVBJtt9SMvfv12HS`)
- [SGE — Retain, Allemagne](https://www.socialgrowthengineers.com/ai-flashcard-app-taking-over-germany)
- [SGE — Retain, 3 langues, 72 M](https://www.socialgrowthengineers.com/one-viral-format-three-languages-72m-views)
- [SGE — Wilgo, French StudyTok](https://www.socialgrowthengineers.com/how-a-study-app-took-over-french-studytok)
- [Virengine — Flashka, 197 M, 50 créateurs](https://virengine.com/flashka-s-silent-empire-how-one-app-orchestrated-197m-views-through-50-localized-creators-c9c8ab)
- Pipiads Knowunity.fr / Knowunity.es
- Fiches App Store et sites (flashka.ai, retain.cards, wilgo.ai, parkeur.app, knowt.com,
  gizmo.ai, eliott.app)
- Offre ambassadeurs Wilgo, programme affilié Flashka (Rewardful)
- `docs/plan-amelioration.md` §3, pour l'existant interne (Anki, Quizlet, Knowt, RemNote)
