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
| Annuel discount | `com.micabo.app.pro.yearly.discount` | 39,99 € / an | aucun | **non** — produit créé, offering à part, pas encore de chemin d'achat |

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
| Stripe | Annuel | `price_1UA57iQMgx8zg1707oLVaVD8` |
| Stripe | Hebdomadaire | `price_1UA59JQMgx8zg1703xvj1Cgk` |
| Stripe | Annuel discount | `price_1UA59vQMgx8zg170euqLCM3N` |

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

## 5. Xcode — ajouter le SDK

1. File → Add Package Dependencies → `https://github.com/RevenueCat/purchases-ios`
2. Dependency Rule : *Up to Next Major Version*, à partir de `5.0.0`.
3. Ajouter le produit **`RevenueCat`** à la cible `Micabo`. Ne pas ajouter `RevenueCatUI` : le
   paywall est écrit à la main, et le module d'interface tire une centaine de fichiers dont
   aucun ne sert ici.
4. Le projet utilise un `PBXFileSystemSynchronizedRootGroup` : les fichiers Swift n'ont pas
   besoin d'être déclarés, mais **un paquet SPM, si**. C'est la seule modification du
   `project.pbxproj` de tout le branchement.

## 6. Xcode — configurer le SDK au lancement

Dans `Micabo/App/MicaboApp.swift`, à la fin de `init()` :

```swift
import RevenueCat

// …
init() {
    FontLoader.registerFonts()
    // …
    Purchases.logLevel = .warn
    Purchases.configure(withAPIKey: "appl_LA_CLÉ_PUBLIQUE_IOS")
}
```

La clé publique iOS n'est pas un secret : elle est lisible dans n'importe quel binaire d'App
Store. La clé **secrète** de RevenueCat, elle, ne doit jamais entrer dans le dépôt.

Si l'utilisateur est connecté (Apple ou Google, via `AuthController`), lier son identifiant
**avant le premier achat**. `userId` est l'`auth.users.id` de Supabase, pas l'identifiant
Apple, pas un UUID inventé par l'app. C'est la même chaîne que `client_reference_id` côté
Stripe. Sans ça, RevenueCat crée un `$RCAnonymousID` et le webhook refuse d'écrire (422).

```swift
Purchases.shared.logIn(userId)
```

à appeler au passage à l'état connecté, et `Purchases.shared.logOut()` à la déconnexion.

## 7. Xcode — remplacer le corps de `PaywallPurchases`

C'est **le seul fichier de l'app à modifier** :
`Micabo/Features/Onboarding/Steps/PaywallCatalog.swift`.

```swift
import RevenueCat

enum PaywallPurchases {
    static func buy(_ plan: PaywallPlan) async -> PaywallOutcome {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard
                let offering = offerings.current,
                let package = offering.availablePackages.first(where: {
                    $0.storeProduct.productIdentifier == plan.productID
                })
            else { return .unavailable }

            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            return result.customerInfo.entitlements["pro"]?.isActive == true ? .purchased : .unavailable
        } catch {
            return .unavailable
        }
    }

    static func restore() async -> PaywallOutcome {
        do {
            let info = try await Purchases.shared.restorePurchases()
            return info.entitlements["pro"]?.isActive == true ? .purchased : .unavailable
        } catch {
            return .unavailable
        }
    }
}
```

Le reste du paywall n'a pas à changer : `PaywallStepView` sait déjà distinguer un achat, une
annulation et une boutique muette.

**Attention à un point du comportement actuel** : tant que rien n'est branché,
`PaywallStepView` traite `unavailable` comme une entrée dans l'app, faute de quoi le dernier
écran du parcours n'aurait pas de sortie. Une fois RevenueCat en place, ce cas doit **cesser**
de faire entrer et afficher une erreur — sinon un échec réseau offrirait l'abonnement. C'est un
`switch` de trois lignes dans `PaywallStepView.buy(_:)`.

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

## 9. Fermer les portes de l'app

**Les portes existent déjà**, et elles lisent toutes le même objet : `ProAccess`
(`Micabo/Services/ProAccess.swift`), créé au lancement dans `MicaboApp` à côté de
`AuthController`. Ce qu'il ferme est décrit dans le README, section « Le gratuit et le payant » :
un cours importé, 70 % de chaque fiche, cinq cartes par session, pas d'entraînement libre.

Il n'y a donc que **deux endroits** à changer dans ce fichier :

```swift
// 1. refresh() lit l'entitlement au lieu des réglages de l'appareil
func refresh() async {
    let info = try? await Purchases.shared.customerInfo()
    isPro = info?.entitlements["pro"]?.isActive == true
}

// 2. et l'app se tient au courant sans qu'on le lui demande
private func observe() {
    Task {
        for await info in Purchases.shared.customerInfoStream {
            isPro = info.entitlements["pro"]?.isActive == true
        }
    }
}
```

Le flux est ce qui fait qu'un abonnement résilié se referme tout seul, sans redémarrage.

Trois choses disparaissent le même jour :

1. **`ProAccess.unlock()` appelé sur `unavailable`** — dans `PaywallFlowView.buy(_:)` et
   `SessionPaywallView.buy()`. Aujourd'hui c'est ce qui rend le bouton d'abonnement testable
   sans boutique ; demain, un échec réseau offrirait l'abonnement.
2. **`ProAccess.lock()` et `setPro(_:)`** — ils n'existent que pour l'interrupteur de relecture.
3. **La rangée « Micabo Pro » de `Réglages → Test`** — un interrupteur qui ment sur l'état réel
   d'un abonnement payé est pire que pas d'interrupteur du tout.

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
   ci-dessus, déjà dans `pricing.STORE_PRODUCTS`. Une variable d'environnement
   (`STRIPE_PRICE_YEARLY`, `STRIPE_PRICE_WEEKLY`, plus tard
   `STRIPE_PRICE_YEARLY_DISCOUNT`) les remplace si le mode test n'est pas le
   même compte.
4. Coller `STRIPE_SECRET_KEY` dans **Vercel → Environment Variables**
   (Production + Preview) : `sk_test_…` d'abord, `sk_live_…` le jour J.
5. **Customer Portal** : Settings → Billing → Customer portal → l'activer. C'est ce que
   `manageSubscription()` ouvrira pour un achat `store = stripe`. Un achat App Store ne
   doit **jamais** ouvrir ce portail.

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

Le discount : un produit Apple **et** un prix Stripe, les deux attachés à `pro`, offering
`discount` prêt. Le bouton, le lien, le critère d'éligibilité — plus tard, comme convenu.
