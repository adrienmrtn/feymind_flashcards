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
**compte vide**. Ses cours restent sur l'ancien. Apple donne un pont, l'**identifiant de
passage** (`transfer_sub`), mais il ferme **60 jours après l'acceptation du transfert**, et
rien ne le rouvre. `store/apple-transfer.mjs` s'en sert (étapes 2.4 et 3.2).

**L'enjeu, en chiffres** (Supabase, 14 octobre 2026) : 1 589 comptes Apple sur 3 905, dont
**1 096 à adresse masquée**. Ce sont eux qui arriveraient sur un compte vide.

## Ce qui change, ce qui ne change pas

| | Après le transfert |
| --- | --- |
| Bundle `com.micabo.ios`, identifiant App Store `6806651497` | **Inchangés.** Le lien `APP_STORE_URL` de `web/lib/iphone.ts` reste bon. |
| Avis, notes, mises à jour des élèves | Conservés. L'app reste en vente pendant le transfert. |
| Abonnements en cours, produits, prix | Conservés. Les renouvellements continuent. Les revenus vont à Vik Studios à partir de l'acceptation. |
| Service ID `com.micabo.ios.service` (connexion Apple du site) | Suit l'App ID. Sa configuration est à revérifier (3.4). C'est celui que Supabase utilise, pas le `com.micabo.app.service` de [`oauth-setup.md`](oauth-setup.md). |
| Clé publique RevenueCat `appl_…` dans `Info.plist` | **Inchangée.** Même projet, même app RevenueCat. Seules les clés Apple y sont remplacées (3.6). |
| Code de l'app et du site | **Rien à modifier**, sauf l'équipe que Xcode écrira dans le projet (3.8). |
| Clés `.p8` : Sign in with Apple, In-App Purchase, API App Store Connect | **Ne suivent pas.** Elles appartiennent à l'équipe. Il faut les recréer chez Vik Studios. |
| Xcode Cloud, TestFlight (builds, testeurs, groupes) | **À vider avant** le transfert, puis à refaire chez Vik Studios. |
| Ventes et paiements antérieurs | Restent visibles chez Adrien Martinot. Vik Studios ne voit que ce qui suit l'acceptation. |
| Analytics de l'app | Partent chez Vik Studios. L'ancien compte n'y a plus accès : exporter avant si besoin. |
| Identifiants Apple des élèves, adresses relais | **Changent.** Migration obligatoire sous 60 jours (2.3 à 3.3). |

## Préparer son poste

Sur le Mac, avec le dépôt à jour :

```bash
cd ~/chemin/vers/feymind_flashcards
git fetch origin && git checkout main && git pull   # ou la branche du script, s'il n'est pas encore fusionné
node --version                                       # v22 ou plus ; sinon : brew install node
mkdir -p ~/micabo-transfert                          # les fichiers de migration vivent ici, hors du dépôt
```

Les fichiers que le script lit et écrit contiennent les identifiants Apple des élèves. Ils
restent dans `~/micabo-transfert`. `.gitignore` les refuse de toute façon s'ils atterrissent
dans le dépôt.

Il faut, pour le jour J : le titulaire (*Account Holder*) de chaque compte, l'accès au
tableau de bord Supabase du projet `khuzodsrznanzhwlbjbx`, à RevenueCat, et aux réglages du
dépôt GitHub.

---

## 1. Avant — dans le compte Adrien Martinot

Tout ce qui suit peut se faire les jours qui précèdent.

### 1.1 Aucune version en cours chez Apple

App Store Connect → *Apps* → Micabo → colonne de gauche, section *iOS App*. Lire l'état de
chaque version.

| Bloque le transfert | Ne bloque pas |
| --- | --- |
| *Waiting for Review*, *In Review*, *Accepted*, *Pending Developer Release*, *Pending Apple Release*, *Processing for Distribution* | *Ready for Distribution* (en vente), *Prepare for Submission*, *Rejected*, *Developer Rejected* |

- La 1.8 est en revue : attendre qu'elle passe *Ready for Distribution*.
- Elle est *Pending Developer Release* (validée, pas publiée) : la publier, bouton
  *Release This Version*.
- Ensuite, **ne rien soumettre** jusqu'à la fin du transfert.

### 1.2 Les abonnements

Micabo → *Monetization* → *Subscriptions* → le groupe → chacun des trois produits :
`com.micabo.app.pro.weekly`, `com.micabo.app.pro.yearly`, `com.micabo.app.pro.yearly.discount`.

- États acceptés : *Approved*, *Ready to Submit*, *Developer Removed from Sale*, *Rejected*.
- *Waiting for Review* : attendre la décision d'Apple.
- *Missing Metadata* ou *Developer Action Needed* : compléter le produit, ou le retirer de la
  vente.

Côté Vik Studios, **aucune app** ne doit déjà utiliser l'un de ces trois identifiants.

### 1.3 Les contrats, des deux côtés

App Store Connect → **Business** (l'ancien *Agreements, Tax, and Banking*), une fois dans
chaque compte :

- **Adrien Martinot** : aucun bandeau de nouveau contrat à accepter. *Free Apps* et
  *Paid Apps* sont *Active*.
- **Vik Studios** : *Paid Apps* doit être **Active**. Le titulaire accepte le contrat, puis
  renseigne le compte bancaire et les formulaires fiscaux (W-8BEN-E pour une société hors
  des États-Unis). Apple met parfois plusieurs jours à valider la banque : **c'est la
  première chose à lancer.**
- Aucun des deux comptes ne doit être en cours de changement : renouvellement d'adhésion en
  attente, passage d'individuel à organisation, changement de titulaire.

### 1.4 Ce qu'il faut obtenir de Vik Studios

- Le **Team ID** : developer.apple.com/account, connecté sur Vik Studios (menu d'équipe en
  haut à droite) → *Membership details* → *Team ID*, dix caractères.
- L'**adresse du compte Apple du titulaire** de Vik Studios. Lui seul peut accepter.
- **Ton accès** : App Store Connect (Vik Studios) → *Users and Access* → **+** → ton adresse →
  rôle **Admin** → *Invite*. Accepter l'invitation reçue par courriel. Sans ce rôle, tu ne
  pourras ni créer les clés ni publier après le transfert.

### 1.5 Le secret partagé des abonnements

Micabo → *General* → *App Information* → *App-Specific Shared Secret* → *Manage*. Copier le
secret affiché, ou *Generate* s'il n'y en a pas.

- L'envoyer au titulaire de Vik Studios, par un canal privé. Apple le demande avant
  l'acceptation pour toute app qui vend des abonnements.
- Le coller aussi dans RevenueCat : *Project Settings* → *Apps* → Micabo (App Store) → champ
  *App-Specific Shared Secret* → *Save*. RevenueCat s'en sert en secours pendant qu'on
  change ses clés.

### 1.6 Un compte de test pour vérifier à la fin

Sur un iPhone, avec un compte Apple de test : ouvrir Micabo, *Continuer avec Apple*, choisir
**Masquer mon adresse e-mail**, puis créer un cours. C'est exactement le cas que la migration
protège. À la fin (3.9), ce compte doit retrouver son cours.

### 1.7 Vider TestFlight

Micabo → onglet **TestFlight**.

1. **Noter le dernier numéro de build** : sous *iOS*, le plus grand nombre entre parenthèses,
   par exemple `1.8 (57)`. Il resservira en 3.8.
2. **Builds** : ouvrir chaque version (1.0 … 1.8), cliquer chaque build → *Expire Build* en haut
   à droite. À la fin, tous les builds sont *Expired*.
3. **Internal Testing** : pour chaque groupe → onglet *Testers* → tout sélectionner → *Remove*.
   Puis supprimer le groupe.
4. **External Testing** : noter les adresses des testeurs, ou le lien public. Puis supprimer
   chaque groupe.
5. **All Testers** (colonne de gauche) : retirer les testeurs qui restent.
6. **Test Information** (colonne de gauche) : **pour chaque langue** du menu de langue, noter
   puis vider tous les champs : description, adresse de retours, URL marketing, URL de
   confidentialité, et la partie *Beta App Review Information* (contact, compte de démo,
   notes). *Save*.

### 1.8 Vider Xcode Cloud

1. **Noter le flux d'abord.** Xcode → ouvrir `Micabo.xcodeproj` → *Report navigator* (⌘9) →
   onglet *Cloud* → clic droit sur Micabo → *Manage Workflows* → ouvrir le flux. Faire une
   capture d'écran de chaque section : *General*, *Environment*, *Start Conditions*,
   *Actions*, *Post-Actions*.
2. **Puis supprimer.** App Store Connect → Micabo → onglet **Xcode Cloud** → *Settings* →
   supprimer les données Xcode Cloud de l'app → confirmer. Les flux et l'historique des
   builds Xcode Cloud disparaissent. C'est ce qu'Apple demande.

`ci_scripts/ci_post_clone.sh` ne dépend d'aucune équipe. Il resservira tel quel.

### 1.9 La clé Sign in with Apple d'Adrien Martinot

developer.apple.com/account (équipe Adrien Martinot) → *Certificates, Identifiers &
Profiles* → *Keys*.

- **Si tu as encore le fichier** `AuthKey_XXXXXXXXXX.p8` de la clé qui a servi au secret
  Supabase ([`oauth-setup.md`](oauth-setup.md), § 2.3), c'est celle-là. Le Key ID est dans
  le nom du fichier.
- **Sinon, en créer une.** **+** → nom `Micabo migration` → cocher *Sign in with Apple* →
  *Configure* → *Primary App ID* : `com.micabo.ios` → *Save* → *Continue* → *Register* →
  *Download*. Le téléchargement n'est possible qu'une fois. Noter le Key ID affiché.

Noter aussi le **Team ID d'Adrien Martinot** (*Membership details*). Ranger le `.p8` dans
`~/micabo-transfert`, puis vérifier qu'Apple accepte la clé :

```bash
cd ~/micabo-transfert
export APPLE_TEAM_ID=<Team ID d'Adrien Martinot>
export APPLE_KEY_ID=<Key ID de la clé>
export APPLE_PRIVATE_KEY="$(cat AuthKey_<Key ID>.p8)"
node ~/chemin/vers/feymind_flashcards/store/apple-transfer.mjs check
```

Réponse attendue : `✓ Apple accepte la clé`. Une réponse `invalid_client` veut dire que le
Team ID, le Key ID et le `.p8` ne vont pas ensemble, ou que la clé n'a pas la capacité
*Sign in with Apple* sur `com.micabo.ios`.

### 1.10 Les adresses d'envoi déclarées pour le relais

developer.apple.com (équipe Adrien Martinot) → *Certificates, Identifiers & Profiles* →
*Services* → *Sign in with Apple for Email Communication* → *Configure*. Noter les domaines et
adresses listés sous *Email Sources*. Ils seront à redéclarer chez Vik Studios (3.5). Si la
liste est vide, il n'y aura rien à faire.

---

## 2. Le jour J, dans cet ordre

Compter une heure. Les deux titulaires doivent être disponibles, et il faut enchaîner avec
l'étape 3 dans la foulée.

### 2.1 Initier le transfert — titulaire d'Adrien Martinot

Peut se faire quelques jours avant : Vik Studios a 60 jours pour accepter.

App Store Connect → *Apps* → Micabo → *App Information* → tout en bas, **Transfer App**.
Saisir l'adresse du titulaire de Vik Studios et le Team ID de Vik Studios → *Continue*. App
Store Connect vérifie les conditions de l'étape 1 et nomme celle qui manque. Accepter les
conditions → *Transfer*. L'app passe en attente de transfert et reste en vente.

### 2.2 Couper Apple dans Supabase

Supabase → projet `khuzodsrznanzhwlbjbx` → *Authentication* → *Sign In / Providers* →
**Apple** → désactiver l'interrupteur → *Save*. **Ne toucher à aucun autre champ** : les
Client IDs resservent en 3.3.

- Les élèves **déjà connectés** ne voient rien : leur session est celle de Supabase, pas
  celle d'Apple.
- Un toucher sur *Continuer avec Apple* affiche « La connexion avec ce fournisseur n'est pas
  encore activée… ». Google et le courriel marchent normalement.

**Pourquoi maintenant :** plus personne ne peut ouvrir de compte Apple, donc l'export qui
suit est complet. Et après l'acceptation, un élève à adresse masquée qui se reconnecterait
avant la migration ouvrirait un second compte, vide.

### 2.3 Exporter les comptes Apple

Supabase → *SQL Editor* → *New query* :

```sql
select user_id, provider_id from auth.identities where provider = 'apple';
```

*Run* → bouton **Export** au-dessus des résultats → *Download CSV* → enregistrer sous
`~/micabo-transfert/apple-users.csv`.

**Contrôle du nombre :**

```sql
select count(*) from auth.identities where provider = 'apple';
```

doit être égal au nombre de lignes du fichier moins l'en-tête (`wc -l apple-users.csv`
renvoie ce nombre + 1). S'il en manque, l'éditeur a limité les résultats affichés : retirer
la limite de lignes (le sélecteur à côté de *Run*) et exporter de nouveau.

### 2.4 Les identifiants de passage — `transfer`

Avec la clé d'Adrien Martinot (1.9) :

```bash
cd ~/micabo-transfert
export APPLE_TEAM_ID=<Team ID d'Adrien Martinot>
export APPLE_KEY_ID=<Key ID de la clé>
export APPLE_PRIVATE_KEY="$(cat AuthKey_<Key ID>.p8)"
node ~/chemin/vers/feymind_flashcards/store/apple-transfer.mjs transfer --target <Team ID de Vik Studios> apple-users.csv > apple-transfer.csv
```

- **La dernière ligne doit dire `N/N identifiants de passage.`**, N étant le nombre de 2.3.
- Des lignes `✗` : relancer **la même commande**. Elle réécrit tout le fichier, et le même
  élève donne toujours le même identifiant de passage. Toujours `>`, jamais `>>`. Ne pas
  passer à la suite avant `N/N`.
- `apple-transfer.csv` ne contient que `user_id,transfer_sub`. C'est **le seul pont** vers les
  nouveaux identifiants. En garder une copie en lieu sûr et privé.

### 2.5 Accepter — titulaire de Vik Studios

App Store Connect (Vik Studios) → *Apps* → bandeau du transfert en attente → l'examiner →
**Accept**. Avoir le secret partagé (1.5) sous la main.

Dès l'acceptation, Micabo passe chez Vik Studios et **le compte à rebours des 60 jours
démarre.** Noter la date.

---

## 3. Juste après — dans le compte Vik Studios

### 3.1 La clé Sign in with Apple de Vik Studios

developer.apple.com (menu d'équipe → Vik Studios) → *Certificates, Identifiers & Profiles*.

1. *Identifiers* : `com.micabo.ios` doit y être, avec *Sign in with Apple* coché. S'il
   n'apparaît pas, attendre quelques minutes après l'acceptation.
2. *Keys* → **+** → nom `Micabo Sign in with Apple` → cocher *Sign in with Apple* →
   *Configure* → *Primary App ID* : `com.micabo.ios` → *Save* → *Continue* → *Register* →
   *Download*. Noter le Key ID. Ranger le `.p8` dans `~/micabo-transfert`.

### 3.2 Les nouveaux identifiants — `exchange`, puis le SQL

```bash
cd ~/micabo-transfert
export APPLE_TEAM_ID=<Team ID de Vik Studios>
export APPLE_KEY_ID=<Key ID de la nouvelle clé>
export APPLE_PRIVATE_KEY="$(cat AuthKey_<nouveau Key ID>.p8)"
node ~/chemin/vers/feymind_flashcards/store/apple-transfer.mjs check
node ~/chemin/vers/feymind_flashcards/store/apple-transfer.mjs exchange apple-transfer.csv > apple-migration.sql
```

La dernière ligne dit `M/N comptes échangés.` Si M est plus petit que N, continuer quand
même : le SQL couvre les M comptes échangés, et les autres se rattrapent plus tard (3.2 bis).

**Coller le SQL :** `pbcopy < apple-migration.sql`, puis Supabase → *SQL Editor* → *New
query* → ⌘V → *Run*. Supabase prévient que la requête modifie des données : confirmer. Le
bloc passe en entier ou pas du tout. En cas d'erreur, rien n'a changé.

**Lire le résultat.** Une ligne par élève Apple, trois colonnes : `user_id`, `etat`,
`autre_compte`.

| `etat` | Ce qui s'est passé | Quoi faire |
| --- | --- | --- |
| `migré` | L'identité Apple du compte porte le nouvel identifiant. Si l'élève avait masqué son adresse, la nouvelle adresse relais a remplacé l'ancienne, sur l'identité et sur le compte. À sa prochaine connexion Apple, il retrouve ses cours. | Rien. |
| `sans identité Apple` | Le compte a été supprimé, ou n'a plus Apple, depuis l'export. | Rien. |
| `en double` | L'élève s'est connecté avec Apple après l'acceptation, avant ce SQL. Supabase ne l'a pas reconnu et lui a ouvert un **second compte**, `autre_compte`. Son vrai compte, `user_id`, n'est pas touché, parce que le nouvel identifiant est déjà pris par le second. | Voir ci-dessous. |

**Un compte `en double`, pas à pas :**

1. Regarder ce qu'il y a sur le second compte (remplacer `AUTRE` par la valeur
   d'`autre_compte`) :

   ```sql
   select
     (select count(*) from public.courses     where user_id = 'AUTRE') as cours,
     (select count(*) from public.review_logs where user_id = 'AUTRE') as revisions,
     (select is_pro from public.entitlements  where user_id = 'AUTRE') as pro;
   ```

2. `cours = 0`, `revisions = 0`, et `pro` vide ou `false` : le second compte est vide.
   *Authentication* → *Users* → coller l'identifiant dans la recherche → menu **⋯** de la
   ligne → *Delete user* → confirmer. Tout ce qui lui est rattaché part avec lui.
3. Recoller **le même** `apple-migration.sql` → *Run*. La ligne passe `migré`.
4. Le second compte a des cours, ou il est Pro : **ne pas le supprimer.** Les deux comptes
   sont à fusionner à la main (déplacer les cours vers le vrai compte), au cas par cas.

**« Rejouable »** veut dire qu'on peut recoller et relancer le même SQL autant de fois qu'on
veut. Il ne touche que les identités qui n'ont pas encore leur nouvel identifiant. Une ligne
déjà `migré` ne bouge plus, et rien n'est jamais créé en double. C'est ce qui permet l'étape
3 ci-dessus et l'étape 3.2 bis.

### 3.2 bis Les échanges en échec, les jours suivants

Apple refuse parfois l'échange d'un élève tant qu'il ne s'est pas connecté une fois auprès de
la nouvelle équipe. Tous les quelques jours, tant que `exchange` ne dit pas `N/N` :

1. Relancer `exchange` sur **le même** `apple-transfer.csv` (mêmes variables qu'en 3.2).
2. Recoller le nouveau `apple-migration.sql` → *Run*.
3. Traiter les éventuels `en double` comme ci-dessus.

**Dernier délai : acceptation + 60 jours.** Poser un rappel à + 50 jours.

### 3.3 Rallumer Apple dans Supabase, avec la nouvelle clé

1. **Le secret.** Outil de génération de Supabase : lien sur la page du fournisseur Apple, ou
   documentation Supabase *Login with Apple* → *Generate a client secret*. Saisir :
   - Team ID : celui de **Vik Studios** ;
   - Key ID : celui de 3.1 ;
   - Services ID : `com.micabo.ios.service` ;
   - la clé : le contenu complet du `.p8` de 3.1, lignes `BEGIN` et `END` comprises.

   Copier le JWT obtenu.
2. *Authentication* → *Sign In / Providers* → **Apple** → activer :
   - *Client IDs* : **ne pas y toucher**. Ils valent `com.micabo.ios.service,com.micabo.ios`
     (relevé le 14 octobre 2026), Service ID en premier ;
   - *Secret Key (for OAuth)* : le JWT.

   *Save*.
3. Le secret expire dans **six mois**. Poser un rappel pour le régénérer de la même façon.

L'ancien secret était signé par une clé de l'ancienne équipe. Il ne vaut plus rien pour
cette app.

### 3.4 Le Service ID du site

*Identifiers* → filtre en haut à droite : *Services IDs* → `com.micabo.ios.service` → *Sign in
with Apple* → *Configure*. Vérifier :

| Champ | Valeur |
| --- | --- |
| Primary App ID | `com.micabo.ios` |
| Domains and Subdomains | `khuzodsrznanzhwlbjbx.supabase.co` |
| Return URLs | `https://khuzodsrznanzhwlbjbx.supabase.co/auth/v1/callback` |

S'il manque quelque chose, le ressaisir → *Next* → *Done* → *Continue* → *Save*.

### 3.5 Le relais des adresses masquées

Seulement si la liste notée en 1.10 n'était pas vide. developer.apple.com (Vik Studios) →
*Services* → *Sign in with Apple for Email Communication* → *Configure* → **+** à côté
d'*Email Sources* → ajouter **exactement** les mêmes domaines et adresses → *Next* →
*Register*. Apple vérifie le SPF de chaque domaine : chacun doit passer au vert. Sans ça,
un courriel envoyé à une adresse relais de la nouvelle équipe est rejeté.

### 3.6 RevenueCat

Même projet, même app *App Store*, même clé `appl_…`. On ne remplace que les clés d'Apple,
dans cet ordre.

1. **La clé In-App Purchase.** App Store Connect (Vik Studios) → *Users and Access* →
   onglet *Integrations* → *In-App Purchase* → **+** (*Generate In-App Purchase Key*) → nom
   `RevenueCat` → *Generate* → *Download* (une seule fois). Noter le Key ID (sur la ligne de
   la clé) et l'*Issuer ID* (en haut de la page).
   RevenueCat → *Project Settings* → *Apps* → Micabo (App Store) → section de la clé In-App
   Purchase → envoyer le `.p8`, saisir le Key ID et l'Issuer ID → *Save*. Attendre l'état
   « identifiants valides », en vert.
2. **Le secret partagé.** App Store Connect (Vik Studios) → Micabo → *App Information* →
   *App-Specific Shared Secret* → *Manage* → **Regenerate**, pour que l'ancien ne serve plus →
   copier. RevenueCat, même page → *App-Specific Shared Secret* → coller → *Save*.
3. **La clé d'API App Store Connect**, seulement si la section *App Store Connect API* de
   cette page RevenueCat est remplie. App Store Connect (Vik Studios) → *Users and Access* →
   *Integrations* → *App Store Connect API* → *Team Keys* → **+** → nom `RevenueCat`, accès
   *App Manager* → *Generate* → *Download*. L'envoyer à RevenueCat avec le Key ID et
   l'Issuer ID. Si RevenueCat demande le *Vendor Number* : App Store Connect → *Payments and
   Financial Reports*, en haut à gauche.
4. **Les notifications serveur.** App Store Connect (Vik Studios) → Micabo → *App
   Information* → *App Store Server Notifications*. *Production Server URL* et *Sandbox
   Server URL* doivent contenir l'adresse RevenueCat (`api.revenuecat.com/…`). Si un champ
   est vide : copier l'URL affichée sur la page RevenueCat de l'app → *Set Up URL* → coller →
   *Version 2* → *Save*, pour les deux.

### 3.7 Les secrets GitHub des actions « Grille de prix iOS » et « Images App Store »

1. App Store Connect (Vik Studios) → *Users and Access* → *Integrations* → *App Store Connect
   API* → *Team Keys* → **+** → nom `GitHub Actions`, accès **App Manager** → *Generate* →
   *Download API Key*. Noter le Key ID et l'Issuer ID.
2. GitHub → `adrienmrtn/feymind_flashcards` → *Settings* → *Secrets and variables* →
   *Actions* → pour chaque secret, le crayon → coller → *Update secret* :
   - `ASC_KEY_ID` : le Key ID ;
   - `ASC_ISSUER_ID` : l'Issuer ID ;
   - `ASC_PRIVATE_KEY` : tout le contenu du `.p8`, de `-----BEGIN PRIVATE KEY-----` à
     `-----END PRIVATE KEY-----`.
3. **Vérifier** : *Actions* → **Grille de prix iOS** → *Run workflow* → cible `app-store`,
   *Appliquer* décoché → *Run*. Un passage vert, avec le tableau des prix actuels dans le
   résumé, veut dire que la clé marche. En cas de 401, le résumé liste ce qu'il faut vérifier.
4. Dans le compte Adrien Martinot, révoquer l'ancienne clé : *Users and Access* →
   *Integrations* → *App Store Connect API* → l'ancienne clé → *Revoke*.

### 3.8 Xcode, Xcode Cloud, TestFlight

1. **Xcode** → *Settings* → *Accounts* : ton compte Apple doit montrer l'équipe **Vik
   Studios** (invitation de 1.4 acceptée). Sinon, se déconnecter puis se reconnecter.
2. `Micabo.xcodeproj` → cible **Micabo** → *Signing & Capabilities* → *Team* : **Vik
   Studios**. Idem pour la cible **MicaboTests**. Xcode écrit alors
   `DEVELOPMENT_TEAM = <Team ID de Vik Studios>` dans `project.pbxproj`. Committer ce
   changement : il est sans risque, et toutes les constructions visent ainsi la bonne équipe.
3. **Créer le flux, sans le lancer.** Xcode → *Product* → *Xcode Cloud* → *Create Workflow…*
   → produit Micabo → équipe Vik Studios → *Grant Access* au dépôt GitHub. Cela installe
   l'app GitHub de Xcode Cloud sur `adrienmrtn/feymind_flashcards` : valider côté GitHub.
   Refaire le flux d'après les captures de 1.8 → *Save*. **Ne pas cliquer *Start Build*.**
4. **Le numéro de build.** App Store Connect (Vik Studios) → Micabo → *Xcode Cloud* →
   *Settings* → *Build Number* → *Next Build Number* : le numéro noté en 1.7, **plus 1** →
   *Save*. Sans ça, le premier envoi est refusé avec « The bundle version must be higher than
   the previously uploaded version » (voir `ci_scripts/ci_post_clone.sh`).
5. **Lancer un build** : Xcode Cloud → *Start Build*. Il doit arriver dans TestFlight avec le
   nouveau numéro. Les Réglages de l'app affichent le commit.
6. **TestFlight.**
   - *Internal Testing* → **+** → recréer le groupe. Un testeur interne doit d'abord être
     membre de Vik Studios (*Users and Access* → **+**).
   - *External Testing* → **+** → recréer le groupe, ajouter les adresses notées en 1.7, ou
     rouvrir un lien public. Le premier build repasse en revue bêta (24 à 48 h).
   - *Test Information* : ressaisir, dans chaque langue, ce qui a été noté en 1.7.

### 3.9 Vérifier

- [ ] La fiche App Store affiche Vik Studios (compter quelques heures).
- [ ] Le compte de test de 1.6 se reconnecte avec Apple sur l'iPhone et **retrouve son
      cours**.
- [ ] La connexion Apple marche sur `https://micabo.app/connexion`.
- [ ] Un achat en bac à sable sur le build TestFlight arrive dans RevenueCat (*Customers*,
      vue *Sandbox*). Un abonné existant reste Pro.
- [ ] L'action « Grille de prix iOS » passe en simulation.
- [ ] Rappels posés : secret Apple de Supabase (+ 6 mois), fin de la migration (acceptation +
      50 jours).

### 3.10 Si Vik Studios est aussi l'éditeur légal

La fiche App Store affichera « Vik Studios » comme développeur et vendeur. Le site et les
conditions disent « Micabo » (`LEGAL_EDITOR`, `web/lib/legal.ts`). Si l'éditeur légal change
aussi, c'est la seule ligne à modifier.

## Sources

- Apple, [Overview of app transfer](https://developer.apple.com/help/app-store-connect/transfer-an-app/overview-of-app-transfer)
  et [App transfer criteria](https://developer.apple.com/help/app-store-connect/transfer-an-app/app-transfer-criteria).
- Apple, [Transferring your apps and users to another team](https://developer.apple.com/documentation/signinwithapple/transferring-your-apps-and-users-to-another-team)
  et [Bringing new apps and users into your team](https://developer.apple.com/documentation/signinwithapple/bringing-new-apps-and-users-into-your-team).
- RevenueCat, [Update after developer account transfer](https://www.revenuecat.com/docs/revenuecat-support/common-tickets/update-after-developer-account-transfer).
