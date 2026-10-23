# Reprendre l'app Android

Ce document sert à reprendre l'app Android sans dépendre de personne : les accès à
transmettre, comment le code est rangé, comment livrer une version. Pour la chaîne d'envoi
elle-même (secrets, premier dépôt), voir [google-play.md](google-play.md).

## 1. Les accès, une fois pour toutes

Rien ne doit dépendre d'une seule personne. La liste est à cocher par celui qui a créé les
comptes, pour celui qui reprend :

| Quoi | Où | Ce qu'il faut |
| --- | --- | --- |
| **Play Console** (l'app `com.micabo.app`) | play.google.com/console → Utilisateurs et autorisations → Inviter | Inviter le repreneur avec le rôle **Administrateur** (toutes les autorisations, toutes les apps). |
| **La clé d'envoi** (`upload.jks` + son mot de passe, alias `micabo`) | Gestionnaire de mots de passe partagé (1Password, Bitwarden…) | Y ranger le fichier et le mot de passe. Les secrets GitHub ne se relisent pas : sans copie, il faudrait réinitialiser la clé (possible, voir plus bas). |
| **Les secrets GitHub** | Dépôt → Settings → Secrets and variables → Actions | Déjà posés ; le propriétaire du dépôt les gère. Liste dans [google-play.md](google-play.md). |
| **Le compte de service Google Play** (secret `PLAY_SERVICE_ACCOUNT_JSON`) | console.cloud.google.com → IAM et administration → IAM | Ajouter le repreneur comme **Propriétaire** du projet Google Cloud qui porte le compte de service. |
| **RevenueCat** (achats) | app.revenuecat.com → Project settings → Collaborators | L'inviter comme **Admin**. |
| **Supabase** (backend commun avec l'iPhone) | supabase.com → Organization → Team | L'inviter comme **Owner** ou **Developer**. |

**Clé perdue ?** L'app utilise la signature par Google Play : la clé d'envoi se remplace.
Créer une nouvelle clé (`keytool -genkeypair -keystore upload.jks -storetype PKCS12 -alias micabo
-keyalg RSA -keysize 2048 -validity 10000`), exporter son certificat (`keytool -export -rfc
-keystore upload.jks -alias micabo -file upload_certificate.pem`), puis Play Console →
Intégrité de l'application → Signature d'application → **Demander la réinitialisation de la clé
d'importation** avec ce `.pem`. Environ 48 h, puis mettre à jour les quatre secrets
`ANDROID_KEY*`.

## 2. Livrer une version

Pas besoin d'Android Studio ni du SDK Android : tout compile sur GitHub Actions
(workflow `Android`, `.github/workflows/android.yml`).

- **Chaque push** qui touche `android/` compile le bundle de publication (avec R8) et garde
  deux artefacts dans le run : le `.aab` signé et **`micabo-apk-<n>`**, un APK à installer
  directement sur un téléphone (sans les achats).
- **Envoyer au test interne** : mettre `[play]` dans le message du commit, ou Actions →
  Android → **Run workflow**. Le numéro de build (`versionCode`) est le numéro du run.
- **Envoyer la fiche du Play Store** (textes des 33 langues, captures, icône) :
  `[play-listing]`, ou la case « fiche » au lancement manuel. Les textes sont dans
  `android/play/metadata`.
- Tant que Google n'a jamais validé l'app, une version envoyée arrive en **brouillon** : la
  Play Console → Tests internes → la version → **Déployer**. Après la première validation,
  poser la variable du dépôt `PLAY_RELEASE_STATUS=completed` : elle part alors toute seule.
- **Ajouter un testeur** : Play Console → Tests internes → Testeurs → la liste → ajouter son
  adresse Google, puis lui envoyer le lien d'inscription.
- La version affichée (`versionName`) est dans `android/app/build.gradle.kts`.

## 3. Le code

Kotlin et Jetpack Compose, une seule activité, dans
`android/app/src/main/java/com/micabo/app/`. Même backend Supabase que l'iPhone ; quand un
comportement est en doute, **l'iPhone fait référence** (`Micabo/`), et les commentaires du
code Android nomment le type Swift équivalent entre accents graves.

```
MicaboApplication.kt   les services, créés une fois ; synchronisation, connexion
MainActivity.kt        l'activité ; le retour des connexions (micabo://auth-callback)
data/
  Supabase.kt          appels HTTP, compte invité, compte Google / lien par courriel (PKCE)
  LessonRepository.kt  les leçons (un JSON par leçon), la génération par generate-lesson
  CloudSync.kt         la synchronisation avec l'iPhone (tables courses, chapters,
                       flashcards, exams, review_logs ; mêmes formats que l'iPhone)
  Social.kt            amis, annuaire, classement de la semaine, cours partagés
  Imports.kt           PDF (PDFBox + OCR ML Kit), Word, photos ; YouTube.kt (pas d'audio sur Android)
  LessonComposer.kt    la barre de l'accueil et ses supports
  Billing.kt           RevenueCat / Google Play Billing (entitlement « pro »)
  GiftOffer.kt         le cadeau du paywall refermé et son tarif réduit (offering « discount »)
  Srs.kt, Streak.kt, Exams.kt, MikaChat.kt, Analytics.kt, DailyReminder.kt, Prefs.kt
ui/
  Root.kt              la pile d'écrans (Screen) et sa sauvegarde
  home/ lesson/ lessons/ exams/ friends/ settings/ onboarding/ paywall/ streak/
  components/ theme/ text/
```

**Les textes** viennent des catalogues de l'iPhone. Dans le code, on écrit
`R.string.cle_du_catalogue` (`lesson.notes.why` → `R.string.lesson_notes_why`) ; une phrase
propre à Android prend le préfixe `x_` et s'écrit dans `CUSTOM` en tête de
`android/tools/generate_strings.py`. Après tout ajout :

```
python3 android/tools/generate_strings.py
```

Le script régénère `res/values-*/strings.xml` et `plurals.xml` pour les 26 langues, et
signale les clés introuvables. Ne pas éditer ces fichiers à la main.

**Le backend** : les fonctions sont dans `supabase/functions/` (dont `transcribe-audio`, écrite
pour l'audio Android), les migrations dans `supabase/migrations/`. Un commit dont le message
contient `[supabase]` déploie les migrations nouvelles et les fonctions touchées.

## 4. Vérifier avant de livrer

- La CI Android doit être verte (elle compile tout, R8 compris).
- Rien n'est testé automatiquement sur un téléphone : installer l'APK du run, ou passer par le
  test interne, et refaire le parcours touché.
- Points à surveiller en priorité : la connexion Google et le lien par courriel jusqu'au retour
  dans l'app ; une leçon créée sur Android qui apparaît sur l'iPhone, et l'inverse ; un achat
  avec un compte testeur de licence (Play Console → Configuration → Test des licences).
