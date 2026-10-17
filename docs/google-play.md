# Google Play : la chaîne d'envoi

L'app Android vit dans `android/` : Kotlin et Jetpack Compose, une seule activité. Elle fait
ce que fait l'iPhone, sur le même backend Supabase (compte invité, `generate-lesson`,
`mika-chat`, `youtube-transcript`) :

- le parcours d'accueil (prénom, langue, pays, marche d'études, inquiétudes, buts, moyenne,
  objectif, temps par jour, Mika, avis), l'essai gratuit et son rappel, puis le paywall ;
- l'accueil : un sujet tapé, ou jusqu'à cinq supports lus sur le téléphone — PDF (PDFBox,
  OCR ML Kit pour un scan), Word, photos ou scanner de documents ML Kit, YouTube, texte
  collé — et « As-tu un examen ? » ;
- la leçon en chemin : intro, notes en écrans courts, quiz de palier et final, entraînement
  et nouvelles questions, flashcards à répétition espacée (SM-2), Mika sur la leçon ;
- les onglets Leçons (recherche, renommer, supprimer), Examens (compte à rebours, examen
  blanc chronométré noté au barème du pays) et Profil (série de jours, réglages, apparence) ;
- les achats par RevenueCat et Google Play Billing (entitlement `pro`) ;
- les événements dans `app_events` (`platform = 'android'`) ;
- 26 langues, tirées des catalogues de l'iPhone par `android/tools/generate_strings.py`.

Pas encore sur Android : l'import audio (transcription sur le téléphone), la connexion à un
compte (Google) et la synchronisation des leçons entre appareils, les amis.

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
