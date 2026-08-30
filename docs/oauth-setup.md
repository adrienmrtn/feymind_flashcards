# Activer la connexion Apple et Google

Tout ce qui suit se passe **hors du dépôt** : dans le portail développeur Apple, dans la
console Google Cloud, et dans le tableau de bord Supabase. Le code de l'app est déjà branché
et n'a pas besoin d'être modifié.

Une seule chose à savoir avant de commencer : `GET /auth/v1/settings` du projet répond
aujourd'hui `"apple": false, "google": false`. C'est cet appel que l'écran de connexion lit au
lancement, et c'est pour ça que les deux boutons n'y apparaissent pas encore. **Ils
apparaîtront d'eux-mêmes** dès que les étapes ci-dessous seront faites, sans nouvelle version
de l'app.

## Ce qui est déjà en place côté code

| Élément | Où | Valeur |
| --- | --- | --- |
| Schéma de retour iOS | `Micabo/Info.plist`, `AuthRedirect.scheme` | `micabo://auth-callback` |
| Entitlement Apple | `Micabo/Micabo.entitlements` | `com.apple.developer.applesignin` |
| Identifiant d'app | `project.pbxproj` | `com.micabo.app` |
| Bouton Apple | `AuthView` | `SignInWithAppleButton`, nonce haché en SHA-256 |
| Flux Google | `OAuthFlows.swift` | `ASWebAuthenticationSession` + PKCE |
| Détection des fournisseurs | `SupabaseAuthClient.providers()` | lue au lancement |

---

## 1. Google

### 1.1 Créer l'écran de consentement

1. [Google Cloud Console](https://console.cloud.google.com) → créer ou choisir un projet.
2. **APIs & Services → OAuth consent screen**.
3. Type **External**, puis remplir : nom de l'app (`Micabo`), adresse de support, logo,
   domaine de l'app, politique de confidentialité, conditions d'utilisation.
4. **Scopes** : `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`. Rien de plus.
   Tout scope supplémentaire déclenche une revue Google de plusieurs semaines.
5. Laisser en **Testing** pour développer (ajouter les adresses de test), passer en
   **Production** avant la sortie. En Testing, seules les adresses listées peuvent se
   connecter.

### 1.2 Créer le client OAuth « Web »

C'est **le seul client dont Supabase a besoin**, et c'est le point qui surprend : même pour
la connexion depuis l'iPhone, c'est un client de type *Web application* qu'il faut, parce que
l'échange du code est fait par Supabase, pas par l'app.

1. **APIs & Services → Credentials → Create credentials → OAuth client ID**.
2. Type : **Web application**. Nom : `Micabo — Supabase`.
3. **Authorized redirect URIs**, exactement :
   ```
   https://<REF>.supabase.co/auth/v1/callback
   ```
   en remplaçant `<REF>` par la référence du projet (celle de l'URL Supabase).
4. Garder le **Client ID** et le **Client Secret**.

### 1.3 Brancher dans Supabase

1. Tableau de bord → **Authentication → Sign In / Providers → Google**.
2. Activer, coller le Client ID et le Client Secret, enregistrer.
3. **Authentication → URL Configuration → Redirect URLs**, ajouter :
   ```
   micabo://auth-callback
   ```
   Sans cette ligne, Supabase refuse le retour vers l'app **avant** que le code n'arrive, et
   l'écran affiche une erreur qui ne parle pas de configuration.

### 1.4 Pour le web (à faire quand le site existera)

Le même client OAuth sert au site : Supabase reste l'intermédiaire, donc l'URI de redirection
Google ne change pas. Il faut seulement ajouter les URL de retour du site dans **Redirect
URLs** :

```
http://localhost:3000/auth/callback
https://micabo.app/auth/callback
https://*-micabo.vercel.app/auth/callback
```

Le joker n'est accepté que sur un segment, et il est indispensable pour les déploiements de
prévisualisation. Côté site, le flux est le même à un détail près : la bibliothèque
`@supabase/ssr` échange le code dans une route serveur, et le cookie de session est posé là.

> **Un client « iOS » chez Google n'est pas nécessaire.** Il ne sert qu'au SDK Google Sign-In
> natif, qui rend un `id_token` échangeable en `grant_type=id_token`. C'est plus rapide d'un
> aller-retour, mais ça ajoute une dépendance externe à l'app. Le jour où ce gain compte, il
> faudra créer un client de type **iOS** avec le bundle `com.micabo.app`, l'ajouter dans le
> champ « Authorized Client IDs » du fournisseur Google de Supabase, et appeler
> `SupabaseAuthClient.signIn(idToken:provider:nonce:)` — la méthode existe déjà, c'est celle
> qu'utilise Apple.

---

## 2. Apple

Deux configurations sont nécessaires, et c'est la source de confusion la plus fréquente :
**l'app iOS** et **le service web**. La première fait marcher le bouton dans l'app, la seconde
fait marcher Supabase — et Supabase est indispensable dans les deux cas, puisque c'est lui qui
vérifie le jeton.

### 2.1 L'identifiant d'app

1. [developer.apple.com](https://developer.apple.com/account) → **Certificates, Identifiers &
   Profiles → Identifiers**.
2. Ouvrir l'App ID `com.micabo.app` (ou le créer).
3. Cocher la capacité **Sign in with Apple**, puis **Save**.
4. Dans Xcode, la capacité doit apparaître dans **Signing & Capabilities** de la cible.
   `Micabo/Micabo.entitlements` est déjà en place et déjà référencé par les deux
   configurations de build : il ne reste qu'à laisser Xcode régénérer le profil.

### 2.2 Le Service ID

C'est l'identifiant que Supabase présente à Apple. Il est distinct de l'App ID.

1. **Identifiers → +  → Services IDs**.
2. Description `Micabo Web`, identifiant `com.micabo.app.service` (n'importe quel identifiant
   distinct de l'App ID convient — il faut juste s'en souvenir, c'est le « Client ID » côté
   Supabase).
3. Une fois créé, l'ouvrir → **Sign in with Apple → Configure** :
   - **Primary App ID** : `com.micabo.app`
   - **Domains and Subdomains** : `<REF>.supabase.co`
   - **Return URLs** : `https://<REF>.supabase.co/auth/v1/callback`

### 2.3 La clé de signature

1. **Keys → +**, nom `Micabo Sign in with Apple`, cocher **Sign in with Apple**, choisir
   `com.micabo.app` comme Primary App ID.
2. Télécharger le fichier `.p8`. **Il ne peut être téléchargé qu'une fois.**
3. Noter le **Key ID** (10 caractères) et le **Team ID** (en haut à droite du portail).

### 2.4 Brancher dans Supabase

**C'est ici que le web casse aujourd'hui.** Le fournisseur Apple est allumé
(`apple: true` sur `/auth/v1/settings`), mais le champ **Secret Key** est vide.
Le bouton répond alors :

```
Unsupported provider: missing OAuth secret
```

iOS n'a pas besoin de ce secret (il envoie un `id_token` natif). Le site, si.

À coller, dans cet ordre, sur Authentication → Sign In / Providers → Apple :

1. Ouvrir le fournisseur Apple.
2. **Generate Secret** (l'outil est sur cette même page) à partir du `.p8`,
   du Key ID et du Team ID.
3. Coller le JWT généré dans **Secret Key (for OAuth)** — pas le fichier `.p8`.
4. Client IDs, **Service ID en premier** :
   ```
   com.micabo.app.service, com.micabo.app
   ```
5. Enregistrer. Réessayer le bouton Apple sur le site. Aucun redéploiement.

Le secret expire **tous les six mois**. Le régénérer au même endroit.

Tableau de bord → **Authentication → Sign In / Providers → Apple** :

| Champ | Valeur |
| --- | --- |
| Client IDs | `com.micabo.app.service, com.micabo.app` |
| Secret Key (for OAuth) | le secret **généré** depuis le `.p8` (outil sur la page Apple de Supabase), pas le fichier brut |
| Key ID | le Key ID de l'étape 2.3 |
| Team ID | le Team ID du compte |

**Le Service ID en premier.** Supabase présente le premier Client ID à Apple pour le flux
web (`signInWithOAuth`). Si `com.micabo.app` est devant, iOS marche et le site échoue.

**Les deux identifiants**, séparés par une virgule. Le jeton du bouton natif porte le
**bundle de l'app** (`com.micabo.app`) ; celui d'un retour web porte le Service ID. Si un
seul des deux est déclaré, l'un des deux chemins échoue avec « Unacceptable audience in
id_token », un message qui ne dit pas lequel.

Le secret généré expire **tous les six mois**. Sans lui, le bouton web répond
`Unsupported provider: missing OAuth secret` — le fournisseur est allumé, la clé n'est
pas posée. iOS n'a pas besoin de ce secret (il envoie un `id_token` natif).

### 2.5 Pour que Apple marche **sur le web**

Le site est en ligne. Sans les URL ci-dessous, le bouton web ouvre Apple puis revient en
erreur — c'est presque toujours ça, pas le code.

**Chez Apple**, Service ID `com.micabo.app.service` → Sign in with Apple → Configure :

| Champ | Valeur |
| --- | --- |
| Primary App ID | `com.micabo.app` |
| Domains and Subdomains | `khuzodsrznanzhwlbjbx.supabase.co` |
| Return URLs | `https://khuzodsrznanzhwlbjbx.supabase.co/auth/v1/callback` |

Ne pas mettre `micabo.vercel.app` dans les Return URLs Apple : Apple parle à Supabase, pas
au site. Le site est le `redirect_to` de Supabase.

**Chez Supabase**, Authentication → URL Configuration → Redirect URLs, les quatre lignes :

```
micabo://auth-callback
http://localhost:3000/auth/callback
https://micabo.vercel.app/auth/callback
https://micabo.app/auth/callback
```

Et le fournisseur Apple (étape 2.4) doit lister **les deux** Client IDs :

```
com.micabo.app.service, com.micabo.app
```

Le premier est le jeton du **web**. S'il manque, iOS marche et le site affiche
« Unacceptable audience in id_token ».

Apple n'accepte pas `http://localhost` comme domaine de Service ID. En local, tester
Google ou le courriel ; Apple se vérifie sur `https://micabo.vercel.app/connexion`.

---

## 3. Régler le courriel

Le projet répond aujourd'hui `mailer_autoconfirm: false` : une adresse doit être confirmée
avant la première connexion. L'app le gère (elle affiche « ouvre le lien envoyé à… » au lieu
d'un échec), mais deux réglages méritent d'être faits.

1. **Authentication → URL Configuration → Site URL** : l'URL du futur site, ou
   `micabo://auth-callback` en attendant. C'est la destination par défaut des liens envoyés
   par courriel.
2. **Authentication → Emails** : les gabarits sont en anglais par défaut. Micabo tutoie et
   parle français partout ailleurs ; un courriel de confirmation en anglais est la première
   chose que voit un nouvel utilisateur.
3. Le serveur SMTP de démonstration de Supabase est limité à quelques courriels par heure et
   n'est pas fait pour la production : brancher un vrai envoyeur (Resend, Postmark, SES) dans
   **Project Settings → Authentication → SMTP Settings** avant la sortie.

---

## 4. Vérifier

```bash
# Les fournisseurs, vus par l'app au lancement.
curl -s "https://<REF>.supabase.co/auth/v1/settings" -H "apikey: <CLÉ_PUBLIABLE>" \
  | python3 -c "import json,sys; e=json.load(sys.stdin); print({k:v for k,v in e['external'].items() if v})"
```

Le résultat attendu après les étapes 1 et 2 :

```
{'apple': True, 'google': True, 'email': True}
```

C'est exactement ce que lit `SupabaseAuthClient.providers()`, et donc ce qui fait apparaître
les deux boutons dans l'app. Aucun redéploiement n'est nécessaire.

Puis, dans l'app : le bouton Apple ouvre la feuille du système, le bouton Google ouvre un
Safari isolé et revient sur `micabo://auth-callback`. Un retour qui n'aboutit pas est presque
toujours une **Redirect URL** manquante dans le tableau de bord.

---

## 5. Les pièges, dans l'ordre où on les rencontre

| Symptôme | Cause |
| --- | --- |
| Les boutons n'apparaissent pas dans l'app | Le fournisseur n'est pas activé côté Supabase. C'est voulu : l'écran ne montre que ce qui marche. |
| `Unsupported provider: missing OAuth secret` | Apple est allumé, le champ Secret Key est vide. Coller le secret généré depuis le `.p8` (étape 2.4). |
| « Unacceptable audience in id_token » | Le bundle de l'app manque dans « Client IDs », ou le Service ID n'est pas en premier. |
| Le Safari s'ouvre puis revient sans rien | `micabo://auth-callback` manque dans les Redirect URLs. |
| « provider is not enabled » | Le fournisseur est configuré mais l'interrupteur est resté sur off. |
| La connexion Apple échoue en simulateur | Un compte iCloud est nécessaire dans les réglages du simulateur. |
| Le nom de l'utilisateur est vide après une connexion Apple | Normal au deuxième essai : Apple ne donne le nom qu'à la première autorisation. Il faut retirer l'app dans Réglages → Apple ID → Connexion avec Apple pour retester. |
| Un lien de confirmation ouvre le navigateur au lieu de l'app | La Site URL pointe vers le web. Sur mobile, les liens doivent viser `micabo://auth-callback`, ou le site doit rediriger vers ce schéma. |
