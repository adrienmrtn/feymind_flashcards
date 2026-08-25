# Brancher les abonnements sur RevenueCat

Le paywall de Micabo est **entièrement natif** : c'est du SwiftUI écrit à la main, pas
`SubscriptionStoreView`, pas le template RevenueCat. Il affiche aujourd'hui des prix écrits en
dur dans `PaywallCatalog`, et tout achat passe par un seul point : `PaywallPurchases`.

Ce document décrit la totalité du branchement, dans l'ordre où il faut le faire. Les trois
premières parties se passent hors de Xcode et sont **bloquantes** : tant qu'un produit n'existe
pas dans App Store Connect, RevenueCat n'a rien à importer et le SDK ne renvoie aucune offre.

Rappel de ce qu'on vend :

| Offre | Identifiant produit | Prix | Essai |
| --- | --- | --- | --- |
| Annuel | `com.micabo.app.pro.yearly` | 59,99 € / an | 3 jours offerts |
| Hebdomadaire | `com.micabo.app.pro.weekly` | 7,99 € / semaine | 3 jours offerts |

Identifiant de l'app : `com.micabo.app`.

---

## 1. App Store Connect — les préalables administratifs

Sans ces trois points, les produits restent bloqués en « Manque de métadonnées » et le bac à
sable renvoie des erreurs sans rapport avec le code.

1. **Contrat Paid Applications** — Business → Agreements, signer *Paid Apps*.
2. **Coordonnées bancaires et fiscales** — Business → Bank / Tax, remplir la fiche fiscale du
   pays d'établissement. Le contrat reste « en attente » tant qu'elle manque.
3. **La fiche de l'app existe** — une app `com.micabo.app` créée dans Apps, même sans build
   envoyé.

## 2. App Store Connect — créer les deux abonnements

1. Ouvrir l'app → **Monetization → Subscriptions**.
2. **Créer un groupe d'abonnements** : `Micabo Pro`. Un seul groupe, et c'est important :
   deux offres dans le même groupe sont mutuellement exclusives, et le passage de
   l'hebdomadaire à l'annuel se fait tout seul, sans double facturation.
   - Localisation du groupe (fr) : nom affiché `Micabo Pro`.
3. **Premier abonnement — annuel**
   - Reference Name : `Micabo Pro annuel`
   - Product ID : `com.micabo.app.pro.yearly` — **exactement** cette chaîne, c'est celle
     qu'attend `PaywallCatalog.yearly.productID`.
   - Subscription Duration : `1 Year`
   - Subscription Prices : France 59,99 € (laisser Apple générer les autres pays, puis
     vérifier)
   - Localizations (fr-FR) : Display Name `Annuel`, Description
     `Cours et flashcards illimités, toute l'année.`
4. **Deuxième abonnement — hebdomadaire**
   - Reference Name : `Micabo Pro hebdomadaire`
   - Product ID : `com.micabo.app.pro.weekly`
   - Subscription Duration : `1 Week`
   - Prices : France 7,99 €
   - Localizations (fr-FR) : Display Name `Hebdomadaire`, Description
     `Cours et flashcards illimités, sans engagement.`
5. **Les trois jours offerts, sur les deux offres** : onglet *Subscription Prices* →
   **Introductory Offers** → Create → Territoire : tous → Type : `Free`, Durée : `3 Days` →
   Éligibilité : *New subscribers*.
   - À faire **deux fois**, une par produit. Un essai posé sur l'annuel seulement ferait
     mentir le second paywall, qui affiche « 3 jours offerts » sur les deux lignes.
6. **Review information** : capture d'écran du paywall + note de relecture. Apple refuse un
   abonnement sans capture.
7. Statut attendu à la fin : *Ready to Submit*. Les produits ne passent *Approved* qu'avec un
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
4. **Products** → `Import` : les deux produits remontent tout seuls une fois créés côté Apple.
   Sinon les ajouter à la main avec les deux identifiants exacts.
5. **Entitlements** → créer `pro` → y attacher les **deux** produits. C'est le seul nom que
   l'app lira ; il ne doit plus changer.
6. **Offerings** → créer l'offering `default` et le marquer *Current*, puis y ajouter deux
   packages :
   - `$rc_annual` → `com.micabo.app.pro.yearly`
   - `$rc_weekly` → `com.micabo.app.pro.weekly`

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

Si l'utilisateur est connecté (Apple ou Google, via `AuthController`), lier son identifiant pour
que l'abonnement le suive d'un appareil à l'autre :

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
            period: kind == .yearly ? .year : .week
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

Rien n'est verrouillé aujourd'hui, et le paywall se traverse sans payer. Une fois l'entitlement
en place, la lecture se fait en un endroit :

```swift
let isPro = try await Purchases.shared.customerInfo().entitlements["pro"]?.isActive == true
```

À poser dans un objet observable créé au lancement, à côté de `AuthController`, et à relire sur
`Purchases.shared.customerInfoStream`. Ce qui doit se fermer relève d'un autre arbitrage que ce
document.

## 10. Tester

1. **En local, sans réseau Apple** : `Micabo/Resources/Micabo.storekit` décrit les deux mêmes
   produits, et le scheme le référence déjà. Il ne fait pas passer par RevenueCat, mais il
   valide les prix, les durées et les trois jours d'essai.
2. **Bac à sable** : App Store Connect → Users and Access → Sandbox → créer un testeur, puis se
   connecter avec sur l'appareil dans Réglages → App Store → Compte de test. Les durées y sont
   accélérées — trois jours d'essai valent quelques minutes.
3. **Vérifier côté RevenueCat** : l'achat de test apparaît dans Customer History en quelques
   secondes. S'il n'apparaît pas, c'est la clé `.p8` ou l'URL de notifications qui manque, pas
   le code.
4. **TestFlight** : les achats y passent par le bac à sable, avec le compte App Store réel du
   testeur. C'est le seul environnement qui reproduit le parcours complet.
