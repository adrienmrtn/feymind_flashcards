# Transférer Micabo du compte « Adrien Martinot » au compte « Vik Studios »

Le transfert lui-même tient en deux clics : l'un dans le compte qui donne l'app, l'autre dans
le compte qui la reçoit. Le travail est autour. Ce qui appartient à l'**app** la suit : son
bundle, ses abonnés, ses avis. Ce qui appartient à l'**équipe** ne la suit pas : les clés
`.p8`, Xcode Cloud, TestFlight, et surtout **les identifiants « Se connecter avec Apple » des
élèves**.

**Un seul point est irréversible.** Apple donne à chaque élève un identifiant, et une adresse
relais s'il a masqué la sienne, **propres à l'équipe**. Après le transfert, le même iPhone
présente un identifiant neuf, que Supabase ne reconnaît pas. Un élève qui avait donné son
adresse réelle est rattrapé par l'adresse. Un élève qui avait masqué la sienne arrive sur un
**compte vide**. Ses cours restent sur l'ancien. Apple donne un pont pour éviter ça, mais il
ferme **60 jours après l'acceptation du transfert**, et rien ne le rouvre. C'est l'objet de
`store/apple-transfer.mjs`, aux étapes 1.6 et 3.1.

## Ce qui change, ce qui ne change pas

| | Après le transfert |
| --- | --- |
| Bundle `com.micabo.ios`, identifiant App Store `6806651497` | **Inchangés.** Le lien `APP_STORE_URL` de `web/lib/iphone.ts` reste bon. |
| Avis, notes, classement, mises à jour des élèves | Conservés. L'app reste en vente pendant le transfert. |
| Abonnements en cours, produits, prix | Conservés. Les renouvellements continuent. Les revenus vont à Vik Studios à partir de l'acceptation. |
| Service ID `com.micabo.app.service` (connexion Apple du site) | Suit l'App ID. Sa configuration est à revérifier (3.1). |
| Clé publique RevenueCat `appl_…` dans `Info.plist` | **Inchangée.** Même projet, même app RevenueCat. Seules les clés Apple y sont remplacées (3.2). |
| Code de l'app et du site | **Rien à modifier.** Le projet n'écrit aucun `DEVELOPMENT_TEAM` (signature automatique). |
| Clés `.p8` : Sign in with Apple, In-App Purchase, API App Store Connect | **Ne suivent pas.** Elles appartiennent à l'équipe. Il faut les recréer chez Vik Studios. |
| Xcode Cloud, TestFlight (builds, testeurs, groupes) | **À vider avant** le transfert, puis à refaire chez Vik Studios. |
| Ventes et paiements antérieurs | Restent visibles chez Adrien Martinot. Vik Studios ne voit que ce qui suit l'acceptation. |
| Analytics de l'app | Partent chez Vik Studios. L'ancien compte n'y a plus accès : exporter avant si besoin. |
| Identifiants Apple des élèves, adresses relais | **Changent.** Migration obligatoire sous 60 jours (1.6, 3.1). |

---

## 1. Avant — dans le compte Adrien Martinot

### 1.1 Les conditions d'Apple

Le bouton de transfert refuse tant qu'une seule de ces conditions manque :

- **Aucune version en cours de traitement.** Aucune version ne doit être dans l'un de ces états :
  *Processing for Distribution*, *Waiting for Review*, *In Review*, *Accepted*,
  *Pending Developer Release*, *Pending Apple Release*. Si la 1.8 est en revue, attendre
  qu'elle soit en vente. Ne pas en soumettre d'autre avant la fin du transfert.
- **Les achats intégrés** sont *Approved*, *Ready to Submit*, *Developer Removed from Sale* ou
  *Rejected*. Aucun n'est *Waiting for Review*.
- **Aucun identifiant de produit commun** avec une app déjà présente chez Vik Studios.
- **Les deux comptes** sont stables (pas de changement d'adhésion en cours), et ont accepté la
  dernière version des contrats, payants et gratuits.
- **Chez Vik Studios : le contrat *Paid Apps* est actif**, avec la banque et les formulaires
  fiscaux renseignés. Sans lui, ni les abonnements ni les revenus ne peuvent arriver.
  RevenueCat le rappelle aussi.

### 1.2 Ce qu'il faut demander à Vik Studios

- Le **Team ID** : developer.apple.com → *Membership details*, dix caractères.
- L'**Apple ID du titulaire du compte** (*Account Holder*). C'est le seul qui peut accepter.
- Ajouter Adrien comme membre de l'équipe Vik Studios, rôle *Admin* (ou *App Manager* + accès
  *Certificates, Identifiers & Profiles*). Sans ce rôle, il ne pourra ni signer ni publier
  après le transfert.

### 1.3 Le secret partagé des abonnements

App Store Connect → Micabo → *App Information* → *App-Specific Shared Secret* → **Generate**.
Le transmettre à Vik Studios, qui en a besoin pour accepter. Apple le demande pour toute app
qui vend des abonnements auto-renouvelables.

### 1.4 Vider TestFlight

Micabo → TestFlight :

1. Faire expirer tous les builds.
2. Retirer tous les testeurs, internes et externes, et supprimer les groupes.
3. *Test Information* : vider **chaque champ, dans chaque langue**.

Noter avant la liste des testeurs externes : elle sera à recréer.

### 1.5 Vider Xcode Cloud

Micabo → onglet **Xcode Cloud** → *Settings* → supprimer les données Xcode Cloud de l'app.

Noter avant :

- Le **dernier numéro de build** envoyé. Il servira en 3.4.
- Les réglages du flux : branche, déclencheurs, action *Archive*, destination TestFlight.

`ci_scripts/ci_post_clone.sh` ne dépend d'aucune équipe. Il resservira tel quel.

### 1.6 Les identifiants de passage des élèves Apple

C'est l'étape qu'on ne rattrape pas. Elle peut se faire **avant** d'initier le transfert, et
c'est là qu'elle est la plus sûre.

**Une clé Sign in with Apple de l'équipe Adrien Martinot.** C'est celle qui a servi à
fabriquer le secret du fournisseur Apple dans Supabase
([`oauth-setup.md`](oauth-setup.md), § 2.3). Si le `.p8` est perdu, en créer une nouvelle :
developer.apple.com → *Keys* → **+** → *Sign in with Apple*, App ID principal
`com.micabo.ios`.

**L'export.** Supabase → *SQL Editor* :

```sql
select user_id, provider_id from auth.identities where provider = 'apple';
```

puis *Export → CSV*. Enregistrer le fichier sous `apple-users.csv`, **hors du dépôt**. Il
contient les identifiants Apple des élèves.

**Les identifiants de passage**, sur un Mac avec Node 22 :

```bash
export APPLE_TEAM_ID=<Team ID d'Adrien Martinot>
export APPLE_KEY_ID=<Key ID de la clé Sign in with Apple>
export APPLE_PRIVATE_KEY="$(cat ~/Downloads/AuthKey_XXXXXXXXXX.p8)"

node store/apple-transfer.mjs check
node store/apple-transfer.mjs transfer --target <Team ID de Vik Studios> apple-users.csv > apple-transfer.csv
```

`apple-transfer.csv` ne contient que `user_id,transfer_sub`. Le garder pour l'étape 3.1. La
commande se relance sans risque : le même compte donne toujours le même identifiant de
passage. Elle signale les lignes en échec et sort en code 2 tant qu'il en reste.

Un élève qui s'inscrit avec Apple **entre cet export et l'acceptation** n'est pas dans le
fichier. Pour le rattraper, refaire l'export et la commande juste avant l'acceptation (2.2).

### 1.7 Ce qu'on garde pour soi

- *Sales and Trends* et *Payments* restent consultables dans l'ancien compte. Rien à faire.
- *App Analytics* part avec l'app : exporter ce qu'on veut garder.
- Les **codes promo** déjà émis restent valables quatre semaines à partir de leur création.
  Après le transfert, on ne peut plus en générer.

---

## 2. Le transfert

### 2.1 Initier — titulaire du compte Adrien Martinot

App Store Connect → *Apps* → Micabo → *App Information* → en bas, **Transfer App**. Saisir
l'Apple ID du titulaire de Vik Studios et son Team ID. App Store Connect vérifie les
conditions de 1.1 et nomme celle qui manque.

### 2.2 Juste avant d'accepter — couper Apple dans Supabase

Entre l'acceptation et la migration (3.1), un élève qui se connecte avec Apple présente déjà
son nouvel identifiant. S'il avait masqué son adresse, Supabase lui ouvre un second compte,
vide. On évite ces doublons en coupant le fournisseur le temps de la migration :

Supabase → *Authentication* → *Sign In / Providers* → **Apple** → désactiver.

- Les élèves **déjà connectés** ne voient rien : leur session est celle de Supabase, pas
  d'Apple.
- Le bouton Apple reste affiché dans l'app. Un toucher répond « La connexion avec ce
  fournisseur n'est pas encore activée… ». Google et le courriel marchent normalement.
- Prévoir l'acceptation et l'étape 3.1 **le même jour**, pour que la coupure dure quelques
  heures.

Si des élèves se sont inscrits avec Apple depuis l'étape 1.6, refaire maintenant l'export et
`transfer`.

### 2.3 Accepter — titulaire du compte Vik Studios

App Store Connect → *Apps* → bandeau du transfert en attente → **Accept**, avec le secret
partagé de 1.3. Le délai d'acceptation est de 60 jours. **Le compte à rebours des 60 jours de
la migration Apple part de cette acceptation.**

---

## 3. Après — dans le compte Vik Studios

### 3.1 Les comptes Apple des élèves — le jour même

**Une clé Sign in with Apple de Vik Studios.** developer.apple.com (équipe Vik Studios) →
*Keys* → **+** → nom `Micabo Sign in with Apple`, cocher *Sign in with Apple*, App ID principal
`com.micabo.ios`. Télécharger le `.p8`. Il ne se télécharge qu'une fois.

**L'échange :**

```bash
export APPLE_TEAM_ID=<Team ID de Vik Studios>
export APPLE_KEY_ID=<Key ID de la nouvelle clé>
export APPLE_PRIVATE_KEY="$(cat ~/Downloads/AuthKey_YYYYYYYYYY.p8)"

node store/apple-transfer.mjs check
node store/apple-transfer.mjs exchange apple-transfer.csv > apple-migration.sql
```

Coller `apple-migration.sql` **tel quel** dans Supabase → *SQL Editor* → *Run*. Tout passe ou
rien ne passe. Le tableau affiché donne l'état de chaque compte :

| État | Sens |
| --- | --- |
| `migré` | L'identité Apple porte le nouvel identifiant. Si l'élève avait masqué son adresse, la nouvelle adresse relais remplace l'ancienne, sur l'identité et sur le compte. |
| `en double` | L'élève s'est reconnecté avec Apple avant la migration, et un second compte s'est ouvert (`autre_compte`). Le SQL n'y touche pas : fusionner deux comptes se décide au cas par cas. Le plus souvent, l'autre compte est vide et se supprime, puis on relance le SQL. |
| `sans identité Apple` | Le compte a été supprimé, ou n'a plus Apple. Rien à faire. |

Le SQL se rejoue sans risque. Si `exchange` signale des échecs, le relancer plus tard sur le
même fichier, puis recoller le SQL. Certains comptes ne s'échangent qu'après une première
connexion de l'élève sur la nouvelle équipe. **Dernier délai : 60 jours après
l'acceptation.**

**Rebrancher Apple dans Supabase.** *Authentication* → *Sign In / Providers* → **Apple** :

| Champ | Valeur |
| --- | --- |
| Client IDs | `com.micabo.app.service, com.micabo.ios`. Inchangés, Service ID en premier. |
| Secret Key (for OAuth) | **Generate Secret** avec le `.p8`, le Key ID et le Team ID **de Vik Studios**. |

Réactiver, enregistrer. L'ancien secret était signé par une clé de l'ancienne équipe : il ne
vaut plus rien pour cette app. Le nouveau expire dans **six mois**. Noter la date.

**Le Service ID.** Identifiers → `com.micabo.app.service` → *Sign in with Apple* →
*Configure*. Vérifier que les valeurs ont suivi :

| Champ | Valeur |
| --- | --- |
| Primary App ID | `com.micabo.ios` |
| Domains and Subdomains | `khuzodsrznanzhwlbjbx.supabase.co` |
| Return URLs | `https://khuzodsrznanzhwlbjbx.supabase.co/auth/v1/callback` |

**Le relais des adresses masquées.** developer.apple.com → *Services* → *Sign in with Apple
for Email Communication* → *Configure* : déclarer le domaine d'envoi des courriels de Micabo
(celui du SMTP de Supabase, voir [`courriel.md`](courriel.md)). Sans cette déclaration, un
courriel envoyé à une adresse relais est rejeté par Apple, lien de connexion compris.

### 3.2 RevenueCat — le jour même

Même projet, même app *App Store*, même clé `appl_…`. On ne remplace que les clés d'Apple.

1. **La clé In-App Purchase, en premier.** App Store Connect (Vik Studios) → *Users and
   Access* → *Integrations* → *In-App Purchase* → *Generate*. RevenueCat → *Project
   Settings* → *Apps* → Micabo (App Store) : remplacer le `.p8`, le Key ID et l'Issuer ID.
   Tant que c'est l'ancienne clé, RevenueCat valide mal les achats et les renouvellements.
2. **Le secret partagé.** Vik Studios en génère un nouveau (*App Information* →
   *App-Specific Shared Secret*) et le colle dans RevenueCat, à la même page.
3. **La clé d'API App Store Connect**, si RevenueCat en a une pour importer produits et prix :
   la remplacer par une clé de Vik Studios.
4. **Les notifications serveur.** Micabo → *App Information* → *App Store Server
   Notifications*. L'URL **V2** de RevenueCat doit être là, en *Production* comme en
   *Sandbox*. Si un champ est vide, recoller l'URL que RevenueCat affiche.
5. **Vérifier** : un achat en bac à sable apparaît dans RevenueCat en quelques secondes.

### 3.3 Les secrets GitHub des actions « Grille de prix iOS » et « Images App Store »

Ils pointent vers une clé de l'ancienne équipe, qui ne voit plus l'app. App Store Connect
(Vik Studios) → *Users and Access* → *Integrations* → *App Store Connect API* → *Team Keys* →
nouvelle clé, rôle **App Manager**. Puis GitHub → *Settings* → *Secrets and variables* →
*Actions* : remplacer `ASC_KEY_ID`, `ASC_ISSUER_ID` et `ASC_PRIVATE_KEY`.

Vérifier en lançant **Grille de prix iOS** sans cocher « Appliquer ». La simulation lit tout
et n'écrit rien.

### 3.4 Xcode Cloud et TestFlight

1. Xcode → *Product* → *Xcode Cloud* → *Create Workflow*, équipe **Vik Studios**. Reconnecter
   le dépôt GitHub et refaire le flux noté en 1.5.
2. App Store Connect → Micabo → *Xcode Cloud* → *Settings* → *Build Number* → **Next Build
   Number** : plus grand que le dernier build noté en 1.5. Sinon, le premier envoi est refusé
   avec « The bundle version must be higher than the previously uploaded version » (voir
   `ci_scripts/ci_post_clone.sh`).
3. TestFlight : recréer les groupes et réinviter les testeurs.

En local : Xcode → cible Micabo → *Signing & Capabilities* → *Team* : **Vik Studios**. C'est un
réglage de la machine, rien à committer. La capacité *Sign in with Apple* doit apparaître :
elle est cochée sur l'App ID, qui a suivi.

### 3.5 Le nom de l'éditeur, si Vik Studios est la structure juridique

La fiche App Store affichera « Vik Studios » comme développeur et vendeur. Le site et les
conditions disent « Micabo » (`LEGAL_EDITOR`, `web/lib/legal.ts`). Si l'éditeur légal change
aussi, c'est la seule ligne à modifier.

---

## 4. Vérifier, une fois tout fait

- [ ] La fiche App Store affiche Vik Studios.
- [ ] Sur iPhone, un compte Apple **à adresse masquée** existant se reconnecte et retrouve ses
      cours. C'est le cas que la migration protège.
- [ ] La connexion Apple marche sur `https://micabo.app/connexion` (Service ID + secret).
- [ ] Un achat en bac à sable arrive dans RevenueCat. Un abonné existant reste Pro.
- [ ] Un build Xcode Cloud arrive dans TestFlight.
- [ ] L'action « Grille de prix iOS » passe en simulation.
- [ ] Un rappel est posé pour le secret Apple de Supabase (six mois) et pour la fin de la
      fenêtre de migration (acceptation + 60 jours).

## Sources

- Apple, [Overview of app transfer](https://developer.apple.com/help/app-store-connect/transfer-an-app/overview-of-app-transfer)
  et [App transfer criteria](https://developer.apple.com/help/app-store-connect/transfer-an-app/app-transfer-criteria).
- Apple, [Transferring your apps and users to another team](https://developer.apple.com/documentation/signinwithapple/transferring-your-apps-and-users-to-another-team)
  et [Bringing new apps and users into your team](https://developer.apple.com/documentation/signinwithapple/bringing-new-apps-and-users-into-your-team).
- RevenueCat, [Update after developer account transfer](https://www.revenuecat.com/docs/revenuecat-support/common-tickets/update-after-developer-account-transfer).
