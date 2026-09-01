# Brancher les abonnements sur RevenueCat

Le paywall de Micabo est **entièrement natif** : c'est du SwiftUI écrit à la main, pas
`SubscriptionStoreView`, pas le template RevenueCat. Il affiche aujourd'hui des prix écrits en
dur dans `PaywallCatalog`, et tout achat passe par un seul point : `PaywallPurchases`.

Ce document décrit la totalité du branchement, dans l'ordre où il faut le faire. Les trois
premières parties se passent hors de Xcode et sont **bloquantes** : tant qu'un produit n'existe
pas dans App Store Connect, RevenueCat n'a rien à importer et le SDK ne renvoie aucune offre.

Rappel de ce qu'on vend :

| Offre | Identifiant produit | Prix | Essai | Sur le paywall |
| --- | --- | --- | --- | --- |
| Annuel | `com.micabo.app.pro.yearly` | 69,99 € / an | 3 jours offerts | oui |
| Hebdomadaire | `com.micabo.app.pro.weekly` | 7,99 € / semaine | aucun | oui |
| Annuel discount | `com.micabo.app.pro.yearly.discount` | 39,99 € / an — annoncé 3,30 € / mois | aucun | **non** sur le paywall ordinaire — il a son propre écran, l'offre cadeau (§13) |

Identifiant de l'app : `com.micabo.app`.

**Stripe encaisse sur le web, Apple encaisse sur iOS, RevenueCat détient le droit.** Chez
RevenueCat ce n'est pas trois produits : c'est **six**. Trois offres × deux magasins, chacun
avec **son** identifiant (Apple : `com.micabo…`, Stripe : `price_…`). Les six s'attachent à
l'entitlement `pro`. Le discount ouvre le même droit — on ne crée pas un second entitlement.

L'`app_user_id` RevenueCat est toujours l'`auth.users.id` de Supabase. Sans ça, un achat
iPhone n'ouvre pas le web, et inversement.

| Magasin | Offre | Identifiant chez RevenueCat |
| --- | --- | --- |
| App Store | Annuel | `com.micabo.app.pro.yearly` |
| App Store | Hebdomadaire | `com.micabo.app.pro.weekly` |
| App Store | Annuel discount | `com.micabo.app.pro.yearly.discount` |
| Stripe | Annuel | `price_1UAqB547TFrcO0lvSacZ91Pp` |
| Stripe | Hebdomadaire | `price_1UAqBI47TFrcO0lvTLjtkffx` |
| Stripe | Annuel discount | `price_1UAqBJ47TFrcO0lvb1vDYAPj` |

---

## 1. App Store Connect — les préalables administratifs

Sans ces trois points, les produits restent bloqués en « Manque de métadonnées » et le bac à
sable renvoie des erreurs sans rapport avec le code.

1. **Contrat Paid Applications** — Business → Agreements, signer *Paid Apps*.
2. **Coordonnées bancaires et fiscales** — Business → Bank / Tax, remplir la fiche fiscale du
   pays d'établissement. Le contrat reste « en attente » tant qu'elle manque.
3. **La fiche de l'app existe** — une app `com.micabo.app` créée dans Apps, même sans build
   envoyé.

## 2. App Store Connect — créer les trois abonnements

1. Ouvrir l'app → **Monetization → Subscriptions**.
2. **Créer un groupe d'abonnements** : `Micabo Pro`. Un seul groupe, et c'est important :
   les offres du même groupe sont mutuellement exclusives, et le passage de l'hebdomadaire
   à l'annuel se fait tout seul, sans double facturation.
   - Localisation du groupe (fr) : nom affiché `Micabo Pro`.
3. **Premier abonnement — annuel**
   - Reference Name : `Micabo Pro annuel`
   - Product ID : `com.micabo.app.pro.yearly` — **exactement** cette chaîne, c'est celle
     qu'attend `PaywallCatalog.yearly.productID`.
   - Subscription Duration : `1 Year`
   - Subscription Prices : France **69,99 €** (laisser Apple générer les autres pays, puis
     vérifier)
   - Localizations (fr-FR) : Display Name `Annuel`, Description
     `Cours et flashcards illimités, toute l'année.`
4. **Deuxième abonnement — hebdomadaire**
   - Reference Name : `Micabo Pro hebdomadaire`
   - Product ID : `com.micabo.app.pro.weekly`
   - Subscription Duration : `1 Week`
   - Prices : France **7,99 €**
   - Localizations (fr-FR) : Display Name `Hebdomadaire`, Description
     `Cours et flashcards illimités, sans engagement.`
5. **Troisième abonnement — annuel discount, sans l'afficher**
   - Reference Name : `Micabo Pro annuel discount`
   - Product ID : `com.micabo.app.pro.yearly.discount`
   - Subscription Duration : `1 Year`
   - Prices : France **39,99 €**
   - Localizations (fr-FR) : Display Name `Annuel`, Description
     `Cours et flashcards illimités, toute l'année.`
   - **Pas d'essai.** Ne pas l'ajouter à l'offering `default` chez RevenueCat.
6. **Les trois jours offerts, sur l'annuel seulement** : onglet *Subscription Prices* du
   produit `com.micabo.app.pro.yearly` → **Introductory Offers** → Create → Territoire :
   tous → Type : `Free`, Durée : `3 Days` → Éligibilité : *New subscribers*.
   - **Ne pas** poser d'essai sur l'hebdomadaire ni sur le discount. Le paywall dit « sans
     essai » sur ces deux lignes.
7. **Review information** : capture d'écran du paywall + note de relecture. Apple refuse un
   abonnement sans capture.
8. Statut attendu à la fin : *Ready to Submit*. Les produits ne passent *Approved* qu'avec un
   build ; le bac à sable, lui, fonctionne dès *Ready to Submit*.

## 3. App Store Connect — la clé que RevenueCat utilisera

RevenueCat a besoin de lire les transactions côté serveur, sinon les achats ne sont validés que
sur l'appareil.

1. **Users and Access → Integrations → In-App Purchase** → `Generate In-App Purchase Key`.
2. Nommer la clé `RevenueCat`, télécharger le `.p8` (**téléchargeable une seule fois**), noter
   le *Key ID* et l'*Issuer ID*.
3. **App Store Server Notifications** : dans la fiche de l'app → *App Information* → *App Store
   Server Notifications*, coller l'URL **V2** fournie par RevenueCat (étape 4.3), en Production
   comme en Sandbox. Sans elle, RevenueCat apprend une résiliation avec un jour de retard.

## 4. RevenueCat — le tableau de bord

1. **Créer le projet** `Micabo`.
2. **Ajouter l'app** : Project Settings → Apps → App Store.
   - Bundle ID : `com.micabo.app`
   - Envoyer le `.p8`, le Key ID et l'Issuer ID de l'étape 3.
   - Récupérer la **clé publique iOS** (`appl_…`). C'est celle-là qui va dans le code, pas la
     clé secrète.
3. Copier l'URL de notifications serveur affichée sur la même page et la coller dans App Store
   Connect (étape 3.3).
4. **Products** → `Import` : les trois produits App Store remontent une fois créés côté
   Apple. Les trois prix Stripe s'ajoutent avec l'intégration Stripe (étape 12) — ce sont
   des `price_…`, pas les identifiants Apple. À la fin : **six** lignes, pas trois.
5. **Entitlements** → créer `pro` → y attacher les **six** produits (3 App Store + 3 Stripe).
   C'est le seul nom que l'app lira ; il ne doit plus changer. Le discount, des deux
   magasins, donne le même droit : on ne crée pas un second entitlement.
6. **Offerings** → créer l'offering `default` et le marquer *Current*, puis y ajouter **deux**
   packages seulement :
   - `$rc_annual` → `com.micabo.app.pro.yearly`
   - `$rc_weekly` → `com.micabo.app.pro.weekly`

   Créer un second offering `discount` (pas *Current*) avec un package
   `com.micabo.app.pro.yearly.discount`. Personne ne le voit tant qu'on n'appelle pas
   `offerings.offering(identifier: "discount")`. C'est volontaire.

   L'ordre des packages dans l'offering n'est pas celui de l'affichage : `PaywallCatalog` garde
   l'annuel en premier, parce que c'est l'offre recommandée.

## 5. Xcode — le SDK est déjà déclaré

**Rien à faire, sauf ouvrir Xcode.** Le paquet est dans `project.pbxproj` :
`https://github.com/RevenueCat/purchases-ios`, *Up to Next Major* depuis `5.0.0`, produit
`RevenueCat` sur la cible `Micabo`. Xcode le résout au premier ouvrage du projet.

`RevenueCatUI` n'y est pas, et n'y sera pas : le paywall est écrit à la main, et le module
d'interface tire une centaine de fichiers dont aucun ne sert ici.

Le projet utilise un `PBXFileSystemSynchronizedRootGroup` : les fichiers Swift n'ont pas
besoin d'être déclarés, mais un paquet SPM, si. C'est la seule modification du
`project.pbxproj` de tout le branchement, et elle est faite.

Tout le code d'achat est écrit derrière `#if canImport(RevenueCat)`. Conséquence utile : le
dépôt **compile dans les deux états**, avec ou sans le paquet résolu. Sans lui, les paywalls
disent « L'abonnement n'est pas encore ouvert » ; avec lui, ils vendent.

## 6. La seule chose qui reste à coller : la clé publique

**Une valeur, un fichier.** `Micabo/Info.plist`, clé `RevenueCatPublicKey` :

```xml
<key>RevenueCatPublicKey</key>
<string>appl_LA_CLÉ_PUBLIQUE_IOS</string>
```

Elle se trouve dans RevenueCat → Project Settings → Apps → Micabo (App Store) → *Public SDK
key*. Elle commence par `appl_`.

Ce n'est pas un secret : elle est lisible dans n'importe quel binaire téléchargé depuis l'App
Store. La clé **secrète** de RevenueCat, elle, n'entre jamais dans le dépôt.

Tant que la chaîne est vide, `PurchasesBridge.configureIfPossible()` ne configure pas le SDK
et les deux paywalls disent « L'abonnement n'est pas encore ouvert ». C'est voulu : un SDK
configuré avec une chaîne vide journalise à chaque appel sans jamais rien vendre.

## 7. Ce qui est déjà écrit côté app

Rien à recoder. Pour relecture, voici où c'est :

| Quoi | Où |
| --- | --- |
| Achat, restauration, offerings | `Micabo/Features/Paywall/PaywallPurchases.swift` |
| Configuration au lancement | `MicaboApp.init()` → `PurchasesBridge.configureIfPossible()` |
| `logIn` / `logOut` | `MicaboApp`, sur `.onChange(of: auth.user?.id)` |
| Lecture du droit | `ProAccess.refresh()` — SDK puis table |
| Fermeture sans redémarrage | `ProAccess.observePurchases()` → `customerInfoStream` |

Trois décisions qui portent ce code :

**Le discount s'achète sans code particulier.** `buy(_:)` cherche le produit dans l'offering
courant **puis dans tous les autres**. Le jour où tu ouvres un chemin vers l'offering
`discount`, il n'y a rien à changer ici.

**`unavailable` n'ouvre plus rien.** C'était le cas avant, faute de boutique : sans ça le
bouton du paywall aurait été inerte et le parcours intestable. Maintenant un échec dit
qu'il a échoué. Sinon chaque panne de réseau serait un abonnement offert —
`web/packages/core/test/freemium-parity.test.ts` échoue si quelqu'un le remet.

**Le SDK et la table s'arbitrent, le plus généreux gagne.** RevenueCat répond depuis son cache
local, donc il sait hors ligne et il sait avant le webhook ; la table vaut pour un achat fait
sur le web. Aucune des deux ne répond ? On ne devine pas : `assumeProWithoutRow` est à `false`,
comme `ASSUME_PRO_WITHOUT_ROW` sur le web, et le test de parité relit les deux.

## 8. Xcode — afficher les prix de la boutique et non ceux du code

Les prix écrits dans `PaywallCatalog` sont ceux de la France. Un utilisateur suisse ou canadien
doit voir les siens, et un changement de tarif ne doit pas demander une mise à jour de l'app.

```swift
extension PaywallPlan {
    init?(package: Package, kind: Kind) {
        guard let price = package.storeProduct.price as Decimal? else { return nil }
        self.init(
            kind: kind,
            productID: package.storeProduct.productIdentifier,
            title: kind == .yearly ? "Annuel" : "Hebdomadaire",
            price: price,
            period: kind == .yearly ? .year : .week,
            trialDays: kind == .yearly ? PaywallCatalog.freeTrialDays : 0
        )
    }
}
```

Et remplacer `PaywallPrice.text(_:)` par `storeProduct.localizedPriceString`, qui rend déjà la
somme dans la devise et le format du pays. Le calcul de la remise (`savingsPercent`) continue de
fonctionner : il ne lit que `annualCost`, donc les prix réels.

Tant que l'offering n'a pas répondu, l'écran garde les valeurs écrites en dur : c'est ce qui
évite un paywall vide pendant la seconde d'attente du réseau.

## 9. Les portes sont fermées

Elles lisent toutes le même objet, `ProAccess` (`Micabo/Services/ProAccess.swift`), et ce qu'il
ferme est décrit dans le README : un cours importé, 70 % de chaque fiche, cinq cartes par
session, pas d'entraînement libre.

Ce qui a changé avec le branchement :

- `refresh()` lit le SDK puis la table, et ne devine plus ;
- `observePurchases()` suit `customerInfoStream`, donc un abonnement résilié se referme sans
  redémarrage ;
- `unavailable` n'appelle plus `unlock()` dans les deux paywalls ;
- l'interrupteur « Micabo Pro » de `Réglages → Test` n'existe qu'en `DEBUG`. Dans une version
  livrée, un interrupteur qui mentirait sur l'état réel d'un abonnement payé est pire que pas
  d'interrupteur du tout.

`lock()` et `setPro(_:)` restent : la réponse du serveur passe par là, et l'interrupteur de
relecture en `DEBUG` aussi.

## 10. Tester

1. **En local, sans réseau Apple** : `Micabo/Resources/Micabo.storekit` décrit les trois mêmes
   produits, et le scheme le référence déjà. Il ne fait pas passer par RevenueCat, mais il
   valide les prix, les durées, et les trois jours d'essai **sur l'annuel seulement**.
2. **Bac à sable** : App Store Connect → Users and Access → Sandbox → créer un testeur, puis se
   connecter avec sur l'appareil dans Réglages → App Store → Compte de test. Les durées y sont
   accélérées — trois jours d'essai valent quelques minutes.
3. **Vérifier côté RevenueCat** : l'achat de test apparaît dans Customer History en quelques
   secondes. S'il n'apparaît pas, c'est la clé `.p8` ou l'URL de notifications qui manque, pas
   le code. L'`app_user_id` affiché doit être un UUID Supabase, jamais un `$RCAnonymousID`.
4. **TestFlight** : les achats y passent par le bac à sable, avec le compte App Store réel du
   testeur. C'est le seul environnement qui reproduit le parcours complet.

---

## 11. Stripe — les trois offres web (trois `price_…`)

Stripe n'écrit jamais dans `entitlements`. Il encaisse. RevenueCat voit l'abonnement Stripe
via l'intégration officielle, et **son** webhook (`supabase/functions/revenuecat-webhook`)
écrit la ligne. Une seule plume.

1. **Créer le compte Stripe** (mode test d'abord) et activer les paiements en euros.
2. **Product → Add product**, trois fois. Chez Stripe le produit a un `prod_…` et un
   `price_…` : c'est le **prix** que RevenueCat affiche, pas l'identifiant Apple. Une
   lookup key / metadata `product_id` relie les deux magasins :
   - Produit `Micabo Pro annuel` — lookup / metadata `product_id` =
     `com.micabo.app.pro.yearly`
     - Prix récurrent : **69,99 €**, facturation **annuelle**, devise EUR
     - **Pas d'essai sur le prix Stripe.** `startCheckout` envoie déjà
       `subscription_data[trial_period_days]=3` depuis le catalogue. Le poser
       aussi sur le prix ferait 3 + 3, ou un conflit. Apple, lui, porte l'essai
       sur le produit App Store — ce n'est pas le même tuyau.
   - Produit `Micabo Pro hebdomadaire` — `com.micabo.app.pro.weekly`
     - Prix : **7,99 €**, facturation **hebdomadaire**
     - **Pas d'essai**
   - Produit `Micabo Pro annuel discount` — `com.micabo.app.pro.yearly.discount`
     - Prix : **39,99 €**, facturation **annuelle**
     - **Pas d'essai**. Ne pas l'utiliser dans `startCheckout` pour l'instant.
3. Les identifiants de **prix** (`price_…`, pas `prod_…`) sont ceux du tableau
   ci-dessus, déjà dans `pricing.STORE_PRODUCTS`. Ce sont les prix **TVA
   incluse** du compte **live** Micabo. Une variable d'environnement
   (`STRIPE_PRICE_YEARLY`, `STRIPE_PRICE_WEEKLY`,
   `STRIPE_PRICE_YEARLY_DISCOUNT`) les remplace si un preview doit
   encore encaisser sur le sandbox.
4. Coller `STRIPE_SECRET_KEY` dans **Vercel → Environment Variables**
   (Production) : `sk_live_…`. Preview peut rester en `sk_test_…` avec
   les `STRIPE_PRICE_*` sandbox.
5. **Customer Portal** : Settings → Billing → Customer portal → **l'activer**. Sans ça
   `manageSubscription()` reçoit un 400 de Stripe et le dit à l'écran.

   Il est déjà écrit : pour un droit `store = stripe`, il retrouve le client par son
   adresse (`GET /v1/customers?email=…`) puis ouvre une session de portail. Un achat
   App Store part chez Apple, un achat Play Store chez Google, un accès offert n'a pas de
   portail — c'est `entitlements.store` qui décide, et un bouton qui ouvre le mauvais
   magasin donne un écran vide et un message au support.

   Pourquoi par l'adresse et pas par un `cus_…` gardé en base : la table `entitlements` n'a
   qu'une plume, le webhook RevenueCat, et il ne transporte pas ce champ. Une colonne que
   personne n'écrit est une colonne qui mentira.

## 12. Lier Stripe à RevenueCat (le droit multiplateforme)

1. RevenueCat → Project Settings → Integrations → **Stripe**.
2. Coller la *restricted key* Stripe (permissions : lire les customers, les subscriptions,
   les invoices, les checkout sessions — rien d'écrire côté charges).
3. **Webhook Stripe → RevenueCat** : Stripe Dashboard → Developers → Webhooks → Add
   endpoint, URL fournie par RevenueCat (page Stripe de RC), événements au minimum :
   `checkout.session.completed`, `customer.subscription.created`,
   `customer.subscription.updated`, `customer.subscription.deleted`,
   `invoice.paid`, `invoice.payment_failed`.
4. Dans RevenueCat, **Products** : les trois prix Stripe apparaissent avec leur
   `price_…` (pas l'identifiant Apple). Les six lignes — App Store + Stripe — se
   rattachent à l'entitlement `pro`. Le discount Stripe aussi.
5. **Le pont d'identité**, et c'est la seule ligne qui compte : dans
   `web/lib/actions/checkout.ts`, `client_reference_id` porte déjà `user.id` (Supabase).
   RevenueCat lit ce champ et pose le customer Stripe sous **ce** `app_user_id`. Si on
   oublie ce champ, RC crée un client orphelin et le webhook refuse d'écrire.
6. Côté iOS, `Purchases.logIn(supabaseUserId)` **avant** `purchase`. Un achat fait sous
   `$RCAnonymousID` puis `logIn` plus tard peut transférer, mais le webhook a déjà pu
   refuser l'événement anonyme. On ne s'y fie pas.
7. RevenueCat → Project Settings → Integrations → **Webhooks** : URL
   `https://<projet>.supabase.co/functions/v1/revenuecat-webhook`, Authorization =
   le secret `REVENUECAT_WEBHOOK_SECRET` déjà attendu par la fonction. Événements :
   tous les changements d'entitlement.
8. Vérifier la table `entitlements` après un achat test : une ligne, `user_id` = UUID
   Supabase, `is_pro` vrai, `store` = `app_store` ou `stripe` selon l'appareil.

---

## 13. L'offre cadeau — le chemin d'achat du discount

Le tarif réduit a maintenant **son** écran, et un seul : personne n'y arrive depuis le
paywall ordinaire. Le critère d'éligibilité est le premier cours importé.

| | iOS | Web |
| --- | --- | --- |
| Déclencheur | La fiche du premier cours | La première page d'app chargée après l'import |
| Ce qui s'ouvre | Un cadeau plein écran, **trois appuis** pour le déballer | La carte de l'offre, directement |
| Le paywall | Une languette posée en bas, l'écran d'où l'on vient reste visible dessous | Une carte de 500 px, posée sur le tableau de bord |
| Minuterie affichée | 24 heures, **au centième** | 24 heures, **au centième** |
| Après fermeture | Languette avec le même décompte 24 h, un appui rouvre | Pastille en bas à droite, idem |

**Une seule mise en page, des deux côtés** : minuterie violette, le pourcentage en bleu
ciel, « Révise plus vite avec Pro », la carte de prix avec son sceau festonné, le bouton
bleu pleine largeur, et la somme réellement prélevée juste dessous. Pas de liste
d'avantages : le cadeau a déjà annoncé l'offre, et un écran qui argumente encore au moment
du prix est un écran qui n'a pas confiance en son prix.

**Le bleu ciel n'existe nulle part ailleurs dans le produit**, et c'est le point. L'offre
est un événement, pas un écran de plus : peinte dans le vert de Micabo, elle se lirait comme
une fonctionnalité — donc comme quelque chose qui sera encore là demain. Les valeurs sont
dans `web/app/globals.css` et `MicaboColor` (`offerSky`, `offerWash`, `offerUrgency`).

**Une seule durée, un seul instant d'origine.** Pop-up et pastille montrent les mêmes
vingt-quatre heures, calculées depuis l'instant où le cadeau a été ouvert — pas depuis
l'import. Deux horloges se contrediraient : le pop-up dirait « terminé » alors que
l'offre courrait encore.

**La minuterie descend au centième**, et ce n'est pas de la précision : une minuterie qui
bouge à chaque image se regarde, une minuterie qui saute d'une seconde à l'autre se lit une
fois puis s'oublie. Le web bat toutes les 60 ms, l'app passe par un `TimelineView` à 20
images par seconde. La pastille des vingt-quatre heures, elle, reste à la seconde : des
centièmes qui défilent dans un coin de l'écran sont un clignotant.

Les nombres vivent à deux endroits qui ne peuvent pas diverger :

- `web/packages/core/src/discount.ts`
- `Micabo/Features/Paywall/DiscountOffer.swift`

`web/packages/core/test/freemium-parity.test.ts` relit le Swift et compare. Trois appuis,
3600 s, 86 400 s, 3,30 €, et la même écriture du décompte — « 00 : 29 : 48 . 69 ».

**Le prix mensuel est écrit, pas calculé.** 39,99 ÷ 12 fait 3,3325, que les formateurs
rendraient « 3,33 € ». Les deux clients écrivent 3,30 € / mois **et** affichent
« 39,99 € facturés une fois par an » juste à côté : un mensuel sans son annuel serait une
allégation qu'on ne facture pas. Le 69,99 € barré est l'annuel plein, pas la somme de
cinquante-deux semaines — d'où 43 % et non 90 %.

**Ce que l'appareil retient**, et rien de plus : `micabo.discount.startedAt` et
`micabo.discount.seen`, en `localStorage` sur le web, en `UserDefaults` sur l'app. Aucune
colonne en base : la table `entitlements` n'a qu'une plume, le webhook RevenueCat, et une
colonne que personne d'autre n'écrit finit par mentir. Conséquence assumée : l'offre repart
sur un second appareil.

### Ce qu'il reste à faire dans les tableaux de bord

1. **RevenueCat** — l'offering `discount` doit contenir un package qui porte
   `com.micabo.app.pro.yearly.discount`. `PaywallPurchases.buy(_:)` cherche le produit dans
   `offerings.current` **puis dans tous les offerings**, donc un offering non *Current*
   suffit. Rien à coder.
2. **Vercel** — `STRIPE_PRICE_YEARLY_DISCOUNT` seulement si Preview n'est
   pas le compte live. À défaut, le catalogue sert de repli
   (`price_1UAqBJ47TFrcO0lvb1vDYAPj`).
3. **Apple** — le produit doit être au moins *Ready to Submit*, sinon le bac à sable rend
   `unavailable` et le bouton le dit.

### Revoir l'offre pendant les tests

Elle ne se présente qu'une fois par appareil.

- Web : `?debug=cadeau` sur n'importe quelle page de `/app`.
- iOS : Réglages → Test → **Rejouer le cadeau** (DEBUG seulement), puis ouvrir une fiche.
