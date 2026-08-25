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
| Abonnements | aucune table, aucun droit, aucun RevenueCat. `SubscriptionStoreView` est décoratif, et tout compte connecté est de fait Pro |
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

Le fond de l'affaire, c'est que Micabo **a déjà une identité visuelle**, et que cette identité
est du papier. C'est ce qui la sauve : personne qui génère une page d'accueil ne tombe sur de
l'ivoire chaud. Les tells d'une page faite à la chaîne sont connus et tiennent en une liste
courte — tout est centré, trois colonnes de fonctionnalités à tuiles arrondies, un dégradé
violet-bleu en fond de bandeau sombre, des cartes en verre dépoli qui flottent, Inter en quatre
graisses, des sous-titres `gris 400`, un emoji par section. Ne pas les faire ne suffit pas ; en
faire autre chose, si.

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

Deux points ouverts, tous deux dans [Questions](#questions) : la police des **nombres** (SF
Rounded n'existe pas sur le web, et « un grand nombre en arrondi ressemble à un score » est un
choix d'intention de l'app, pas un détail), et la langue du site.

### Le survol

Le survol est demandé, et c'est justement ce qui distingue un site soigné d'un site généré — à
condition qu'il obéisse à la règle de mouvement de l'app : **rien ne rebondit.** Courbes
monotones, 120 à 180 ms, et **une seule chose par élément**.

| Élément | Ce qui change |
| --- | --- |
| Rangée de cours | le fond passe de transparent à blanc. Rien ne bouge |
| Carte, tuile | monte de 2 px, son ombre s'approfondit. **Pas de mise à l'échelle** — un texte qui grossit se rend flou pendant sa propre transition |
| Bouton | s'assombrit, et son libellé ne se déplace pas d'un pixel |
| Lien | un filet de 1 px **se trace depuis la gauche**. C'est la seule fioriture du site, et c'est le survol qui a le plus l'air fait à la main |
| Vignette de la démonstration | le balayage de lecture repart, une fois |

Et `prefers-reduced-motion` coupe tout, y compris l'animation de défilement.

Le défilement, justement : la section de transformation est **liée à la barre de défilement**
(`animation-timeline: view()`) et non déclenchée une fois au croisement. La différence se sent —
une animation qu'on pilote appartient à la page, une animation qui part toute seule appartient à
un modèle de site. Là où ce n'est pas supporté, l'état final s'affiche, et c'est tout.

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

### Ce que je recommande

**RevenueCat comme source de vérité unique, avec deux rails d'achat derrière : StoreKit sur iOS,
Stripe sur le web, branchés sur le même projet RevenueCat.**

Pourquoi RevenueCat plutôt que « Stripe + les notifications serveur d'Apple, à la main » :

- à la main, il faut implémenter les *App Store Server Notifications V2* — vérification JWS,
  puis toute la machine à états : renouvellement, changement d'intention de renouvellement,
  période de grâce, relance de facturation, remboursement — **et** les webhooks Stripe, **et** la
  réconciliation des deux. C'est le code le plus propice aux bugs qu'on puisse écrire, ses bugs
  sont invisibles (un étudiant perd son accès en silence), et ce n'est pas le produit ;
- côté iOS il n'y a **rien** aujourd'hui : `SubscriptionStoreView` est décoratif, aucun test de
  droit n'existe nulle part. Puisque tout est à écrire, l'écrire contre RevenueCat coûte le même
  travail que contre StoreKit 2 directement, et donne la partie multiplateforme en prime ;
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

Une précision : **je n'ai pas d'accès MCP à Vercel dans cette session** — seulement Supabase. Je
ne peux donc ni lire ni régler le projet moi-même. Soit vous cliquez les six étapes, soit vous me
donnez un jeton Vercel en secret et je le fais à la CLI.

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

## L'ordre du travail

| Phase | Contenu | Livrable visible |
| --- | --- | --- |
| **A** | Monorepo, `web/`, Root Directory sur Vercel, port du thème, `packages/core` **avec ses tests**, Redirect URLs Supabase | rien — et c'est normal |
| **B** | La page d'accueil, en entier, vrais composants, vrai document de démonstration, feuille d'impression | le site public |
| **C** | Connexion, liste des cours, lecture d'une fiche, lecture des cartes | on se connecte et on lit ses cours |
| **D** | Import (dépôt, collage, YouTube), génération de fiche et de cartes, session au clavier | le web produit |
| **E** | `entitlements`, webhook RevenueCat, encaissement, verrou, branchement RevenueCat sur iOS | le web encaisse |
| **F** | Liens de partage de fiche, première fiche sans compte | la boucle de croissance |

La réparation des Edge Functions **bloque la phase D** : on ne livre pas un point d'entrée d'IA
appelable depuis un navigateur, sans jeton et sans plafond.

## Questions

Il y en a douze, et les six premières changent le code qu'on écrit.

1. **Le domaine.** `micabo.app` est-il acheté ? Je propose un seul domaine avec l'app sous
   `/app` — les liens de partage et la vitrine profitent alors du même domaine, et le cookie de
   session est plus simple qu'avec un sous-domaine.
2. **Le nom.** Le projet Supabase s'appelle `Feymind_flashcards` et des branches parlent de
   `feymind`. **Micabo** est-il définitif ? Il va se retrouver dans l'URL, les balises de partage
   et le Service ID Apple.
3. **Le parcours d'accueil du web.** Envoyez-le. Deux choses à me dire avec : est-ce qu'il tourne
   **avant** ou **après** la connexion, et est-ce qu'il écrit dans `profiles` (pays, stade,
   matières, rythme) ? Mon hypothèse est oui, les mêmes colonnes, et l'iPhone **saute alors son
   propre parcours** pour quelqu'un qui a commencé sur le web. C'est un changement du premier
   lancement de l'app, donc je veux une confirmation.
4. **Les « 500 000 étudiants »** de l'écran de preuve sociale : est-ce un vrai chiffre ? Sur un
   site indexé, c'est une affirmation commerciale. S'il est aspirationnel, je mets un vrai chiffre
   ou rien.
5. **Les nombres arrondis.** SF Rounded n'existe pas sur le web, et « un grand nombre en arrondi
   ressemble à un score » est un choix d'intention de l'app. Trois options : (a) Nunito, la plus
   proche des arrondies libres, (b) renoncer à la seconde famille sur le web et utiliser Hanken
   Grotesk en chiffres tabulaires, (c) acheter une police arrondie. Laquelle ?
6. **L'abonnement — la décision qui me manque le plus.** (a) RevenueCat comme source de vérité
   avec **Stripe Checkout** sur le web : le plus de contrôle, le plus de code. (b) RevenueCat avec
   son **Web Billing** : le plus rapide, paywall hébergé, aucun webhook à écrire, mais moins de
   prise sur la page de paiement et sur la TVA/les factures. (c) **Stripe seul** sur le web et
   StoreKit seul sur iOS, réconciliés à la main : le moins de commission, de très loin le plus de
   code et de risque. Je recommande **(b) pour ouvrir, (a) plus tard** si la page de paiement doit
   devenir la vôtre.
7. **Le même prix partout ?** 39,99 €/an et 6,99 €/mois sont déclarés dans `Micabo.storekit`. Sur
   le web, le même prix rapporte ~38,80 € au lieu de ~28 € après la commission d'Apple la première
   année. On garde des prix identiques — simple et honnête, l'écart de marge est invisible pour
   l'étudiant — ou le web est moins cher ?
8. **Le gratuit.** Le paywall promet « cours et cartes illimités », ce qui suppose un palier
   gratuit limité — et rien n'est limité aujourd'hui. **Qu'est-ce qui est gratuit ?** Ma
   proposition : 3 fiches, les cartes sur toutes, les sessions sans limite, le mode examen réservé
   au Pro. Ça décide à la fois du plafond d'`ai_usage` et de la section prix du site.
9. **Une fiche gratuite sans compte** : oui ou non ? C'est le plus gros levier de conversion du
   site **et** le plus gros risque de facture fal.
10. **Le partage de fiche.** Des liens publics, sans authentification, indexables ? Je les ferais
    **non listés par défaut** : accessibles par le lien, en `noindex`, avec un « publier »
    explicite pour les rendre indexables. À noter : `courses.visibility` a déjà trois valeurs — un
    lien web public est un quatrième état, et je préfère le modéliser franchement plutôt que
    surcharger `public`.
11. **La langue du site.** Français seul à l'ouverture, ou français et anglais ? L'app écrit déjà
    les fiches dans la langue du pays de scolarisation, donc la question est ouverte — mais elle
    change le routage (`/en/…`) et elle coûte beaucoup moins cher tranchée maintenant.
12. **L'ouverture du site touche l'app iOS** (jeton utilisateur sur les Edge Functions, plus les
    deux descentes manquantes de `CloudSync`). D'accord pour une soumission App Store dans la même
    fenêtre ? Les fonctions accepteront les deux clés pendant une version pour ne pas casser les
    app déjà installées.
