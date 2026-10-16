# Google Play : la chaîne d'envoi

L'app Android vit dans `android/`. Pour l'instant c'est une **coquille** : l'écran d'accueil
Micabo (logo, nom, une phrase, clair ou sombre comme l'iPhone), l'icône et la fiche Play. Elle
sert à ouvrir la fiche et la piste de test interne ; la vraie app viendra ensuite.

- Identifiant de l'app : `com.micabo.app` (définitif après le premier envoi).
- Version : `versionName` 1.9, `versionCode` = numéro du run GitHub Actions.

## Ce que fait le workflow `Android`

À chaque push qui touche `android/` (ou Actions → « Android » → Run workflow) :

1. compile `app-release.aab` ;
2. le signe avec la clé d'envoi si les secrets sont posés ;
3. le garde en artefact du run (`micabo-android-<n>`) ;
4. avec « [play] » dans le message du commit (ou en lancement manuel), l'envoie dans le
   **test interne** — une fois le compte de service relié ;
5. avec « [play-listing] » (ou la case « fiche » au lancement manuel), envoie la fiche
   depuis `android/play/metadata`.

## Les secrets (Settings → Secrets and variables → Actions)

| Secret | Contenu |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | la clé d'envoi `upload.jks`, en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | son mot de passe |
| `ANDROID_KEY_ALIAS` | l'alias de la clé |
| `ANDROID_KEY_PASSWORD` | le mot de passe de la clé |
| `PLAY_SERVICE_ACCOUNT_JSON` | le JSON du compte de service relié à la Play Console |

**La clé d'envoi ne se perd pas** : c'est elle qui prouve à Google que les builds viennent de
nous. Elle n'est jamais commitée (`android/.gitignore`).

## La toute première fois

L'API de Google Play refuse un premier envoi : le premier `.aab` se dépose à la main.

1. Play Console → l'app → Tester → Test interne → Créer une version.
2. Déposer `app-release.aab` (artefact du run `Android`), accepter la signature d'app par Google Play.
3. Ensuite, tous les envois passent par le workflow.

Tant que l'app n'a jamais été validée par Google, l'API n'accepte que le statut `draft` ;
après la première validation, poser la variable `PLAY_RELEASE_STATUS=completed`.
