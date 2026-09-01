# Fiche App Store Connect — Micabo

Tout ce qu’il faut coller, case par case. Les textes de vitrine sont
**prêts à coller**. Les réponses de questionnaire sont celles que le
produit autorise aujourd’hui, pas celles qui sonnent mieux.

Les limites de caractères sont comptées **avec espaces**, telles
qu’Apple les compte. Un dépassement d’un caractère bloque l’enregistrement.

Langue principale : **Français (France)**. Une localisation
**English (U.S.)** est fournie en plus. Ne pas inverser : le produit
tutoie, écrit en français, et le site n’existe qu’en français.

---

## Ce que tu dois encore faire à la main

Rien de ce qui suit ne se pose depuis le dépôt.

| # | Où | Quoi |
| --- | --- | --- |
| 1 | Business → Agreements | Signer **Paid Applications**. Sans ça, les abonnements restent bloqués. |
| 2 | Business → Bank / Tax | Fiche fiscale et RIB. Le contrat reste « en attente » tant qu’elle manque. |
| 3 | App Information → DSA | Adresse postale et téléphone d’Adrien Martinot (trader UE). **Pas dans le dépôt.** |
| 4 | App Review Information | Téléphone joignable pendant la relecture. Apple appelle. |
| 5 | Compte de démo | Créer `review@micabo.app` (voir §11), le passer Pro, y laisser un cours. |
| 6 | Captures | Les prendre sur un iPhone 16 Pro Max (6,9″) et un iPad Pro 13″. Le plan est au §9. |
| 7 | Version Xcode | Passer `MARKETING_VERSION` de `0.1.0` à **`1.0.0`** avant l’archive. |
| 8 | Guideline 1.2 | Ajouter « Signaler ce cours » (courriel prérempli vers `team@micabo.app`). On peut déjà retirer un ami. Sans signalement, un contenu partagé peut faire refuser. |

---

## 1. Créer l’app (une seule fois)

Apps → + → New App.

| Champ | Valeur | Notes |
| --- | --- | --- |
| Platforms | **iOS** | iPhone et iPad. Pas de macOS, tvOS, visionOS, watchOS. |
| Name | `Micabo` | 6 / 30. Le nom public est définitif (`docs/web.md`). |
| Primary Language | **French (France)** | Permanent après la première mise en ligne. |
| Bundle ID | `com.micabo.app` | Celui du projet Xcode. Permanent. |
| SKU | `MICABO-IOS-001` | Interne, jamais affiché. |
| User Access | Full Access | |

Le nom sous l’icône (écran d’accueil) est déjà `Micabo`
(`INFOPLIST_KEY_CFBundleDisplayName`). Ne pas le changer.

---

## 2. App Information

General → App Information.

| Champ | Valeur |
| --- | --- |
| Name (fr-FR) | `Micabo` |
| Subtitle (fr-FR) | `Fiches et flashcards de cours` |
| Name (en-US) | `Micabo` |
| Subtitle (en-US) | `Sheets and cards from notes` |
| Privacy Policy URL | `https://www.micabo.app/confidentialite` |
| Privacy Choices URL | *(vide)* — pas de bandeau, pas de pistage |
| Category, primary | **Education** |
| Category, secondary | **Productivity** |
| Content Rights | **Yes** — l’utilisateur importe un PDF, des photos, un Word ou une vidéo YouTube qu’il a le droit d’utiliser. On n’a pas de catalogue de contenus licenciés. La note de relecture le dit. |
| License Agreement | **Apply a custom EULA** → `https://www.micabo.app/conditions` (les conditions du site). Ne pas laisser l’EULA Apple standard : elle ne couvre pas la génération, le partage entre amis, ni les deux rails d’abonnement. |
| Copyright | `2026 Adrien Martinot` |
| Routing App Coverage | *(vide)* |
| Korea Rating Classification Number | *(vide)* — pas un jeu, pas 17+/18+. |
| Made for Kids | **No** |
| Regulated Medical Device (UE / UK / US) | **No** — catégorie Education, pas Health/Medical, pas d’information médicale en propre. |

### Sous-titre, pourquoi celui-là

30 caractères pile pour le français (29). Il dit le produit sans répéter
le nom. « IA », « Anki », « plus vite » n’y figurent pas : le premier
est un procédé, le second un concurrent (Apple le refuse souvent dans les
mots-clés), le troisième est une promesse.

Comptes :

```
Fiches et flashcards de cours     29 / 30
Sheets and cards from notes       27 / 30
```

---

## 3. Pricing and Availability

| Champ | Valeur |
| --- | --- |
| Price Schedule | **Free** (Tier 0). L’app est gratuite. L’argent passe par les abonnements. |
| Base country | **France** |
| Availability | Tous les territoires. L’app écrit la fiche dans la langue du pays de scolarisation. |
| Pre-Order | Non |
| Volume Purchase / Apple School Manager | Plus tard. Pas pour la première version. |
| Educational discount | Non, pour l’instant |

---

## 4. Age Rating — chaque question

App Information → Age Ratings → Set Up Age Ratings.

Le barème 2026 (iOS 26+) est **4+ / 9+ / 13+ / 16+ / 18+**. L’ancien
12+ / 17+ reste affiché pour les systèmes d’avant. Les réponses
ci-dessous doivent produire **4+** (ou 9+ si Apple compte le partage
entre amis comme UGC « large »). Ne pas surclasser.

### 4.1 In-app controls and capabilities

Cocher **uniquement** ce qui est vrai. Une case en trop change le
descripteur public, et depuis juillet 2026 « Social Media » impose
**13+** et range l’app dans le Time Allowance Social Media.

| Question (libellé Apple, ou équivalent) | Réponse | Pourquoi |
| --- | --- | --- |
| Parental Controls | **No** | Aucun contrôle parental dans l’app. |
| Age Assurance / Declared Age Range API | **No** | On ne demande pas la date de naissance. La politique dit « moins de quinze ans = accord parental » : c’est une consigne, pas une vérif. |
| Unrestricted Web Access | **No** | Pas de `WKWebView` ouvert. Le champ YouTube accepte une URL de vidéo, pas un navigateur. |
| User-Generated Content | **Yes** | Un étudiant peut partager un cours avec ses **amis**. Pas de catalogue public : `CourseVisibility.choosable` = `friends` \| `private`. « Découvrir » a été retiré. |
| Messaging and Chat | **No** | Aucun fil, aucun message. On s’ajoute en ami, c’est tout. |
| Social Media capabilities | **No** | Apple : « redistribuer, amplifier ou interagir avec du UGC via un fil ou un mode de découverte ». Il n’y a plus de rayon Découvrir, plus de dépôt `public` proposé. Un cours d’ami n’est pas un fil. |
| Advertising | **No** | Pas de pub, pas de SDK pub, pas d’IDFA. |
| In-App Controls that restrict content | **No** | Pas de filtre d’âge, pas de mode restreint. |
| Gambling / Contests / Loot boxes | **No** | |

Si Apple formule UGC / Messaging / Social Media en trois booléens
séparés (API `userGeneratedContent`, `messagingAndChat`, `socialMedia`) :

```
userGeneratedContent     = true
messagingAndChat         = false
socialMedia              = false
socialMediaAgeRestricted = (laisser vide — on n’a pas déclaré social media)
ageAssurance             = false
```

### 4.2 Content descriptors (fréquence)

Pour chaque ligne : **None**. Micabo n’embarque aucun de ces contenus.
Un étudiant *peut* importer un polycopié de médecine ou un roman : ce
n’est pas un contenu de l’app, c’est le sien, privé par défaut.

| Descripteur | Fréquence |
| --- | --- |
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | None |
| Alcohol, Tobacco, or Drug Use | None |
| Mature or Suggestive Themes | None |
| Horror or Fear Themes | None |
| Medical or Treatment Information | None |
| Gambling Simulated | None |
| Gambling Real Money | None |
| Contests | None |

**IA / assistant.** Apple demande de tenir compte d’un chatbot dans la
fréquence des contenus sensibles. `explain-selection` explique un
passage **du cours déjà importé**. Ce n’est pas un assistant général, il
n’invente pas un sujet médical ou violent tout seul. Rester sur None.

### 4.3 Age categories and override

| Champ | Valeur |
| --- | --- |
| Made for Kids | **Not Applicable** — irréversible, et les règles Kids interdisent presque tout ce que fait un compte (amis, génération, abonnement). |
| Override to Higher Age Rating | **Not Applicable** |
| Age Suitability URL | *(vide)* — ou `https://www.micabo.app/confidentialite` (section Mineurs) si le champ est proposé |

Les conditions disent qu’un moins de quinze ans doit avoir l’accord
d’un titulaire. Ce n’est **pas** un âge minimum contractuel de 15 ans
qui forcerait un override 16+. Ne pas surclasser.

Note Corée / Brésil / Australie : laisser Apple dériver. Pas de numéro
GRAC à demander.

---

## 5. App Privacy — nutrition label

App Privacy. C’est une attestation. Elle doit coller à
`https://www.micabo.app/confidentialite` et à ce que font l’app **et**
les SDK (Supabase, RevenueCat, StoreKit, Sign in with Apple, Sign in
with Google). Pas d’analytics, pas de crash reporter, pas d’IDFA.

**Do you or your third-party partners collect data from this app?**
**Yes.**

Ensuite, pour chaque type : le déclarer seulement s’il quitte
l’appareil vers nous ou un prestataire. Ce qui reste local (images
d’occlusion, audio d’une carte, réponses d’accueil avant le compte)
n’entre **pas** dans le label.

### 5.1 Contact Info

| Type | Collecté | Lié à l’identité | Tracking | Purposes |
| --- | --- | --- | --- | --- |
| Name | Oui — nom d’utilisateur | Oui | Non | App Functionality |
| Email Address | Oui — Apple / Google / lien magique | Oui | Non | App Functionality |
| Phone Number | **Non** | | | |
| Physical Address | **Non** | | | |
| Other User Contact Info | **Non** | | | |

### 5.2 Health & Fitness

Aucun. Pas de HealthKit, pas de « wellness ».

### 5.3 Financial Info

| Type | Collecté | Lié | Tracking | Purposes |
| --- | --- | --- | --- | --- |
| Payment Info | **Non** — Apple encaisse, on ne voit pas la carte | | | |
| Credit Info | **Non** | | | |
| Other Financial Info | **Non** | | | |
| Purchases | **Oui** — état Pro (produit, magasin, échéance), via StoreKit + RevenueCat | Oui | Non | App Functionality |

RevenueCat voit l’identifiant d’abonnement, pas le numéro de carte.
C’est `Purchases`, pas `Payment Info`.

### 5.4 Location

Aucun. Pas de GPS, pas de ville dérivée. Le **pays de scolarisation**
est une préférence tapée, pas une localisation : il va dans
*Other User Content* / *Other Data Types* (ci-dessous), pas ici.

### 5.5 Sensitive Info

**Non.** On ne demande ni origine, ni religion, ni orientation. Le
palier d’études et les matières ne sont pas des données sensibles au
sens d’Apple.

### 5.6 Contacts

**Non.** On ne lit pas le carnet d’adresses. Un ami s’ajoute par nom
d’utilisateur.

### 5.7 User Content

| Type | Collecté | Lié | Tracking | Purposes |
| --- | --- | --- | --- | --- |
| Photos or Videos | **Oui** — pages scannées, photos de cours, schéma d’occlusion (le schéma, s’il est envoyé pour génération) | Oui | Non | App Functionality |
| Audio Data | **Non** côté serveur — l’audio d’une carte ne quitte pas l’iPhone | | | |
| Gameplay Content | **Non** | | | |
| Customer Support | **Oui** — si l’étudiant écrit via « Faire un retour » (mailto). Déclarer : le courriel arrive chez nous. | Oui | Non | App Functionality, Other (support) |
| Other User Content | **Oui** — texte extrait, fiche, cartes, examens (nom, date, note visée), historique de révision, matières, établissement | Oui | Non | App Functionality |

Les photos passent par l’OCR **sur l’appareil**. On déclare quand même
Photos : une page floue peut partir au modèle de vision, et une
couverture peut être une photo.

### 5.8 Browsing History

**Non.**

### 5.9 Search History

**Non.** La recherche dans « Cours » est locale, elle ne part pas.

### 5.10 Identifiers

| Type | Collecté | Lié | Tracking | Purposes |
| --- | --- | --- | --- | --- |
| User ID | **Oui** — `auth.users.id` Supabase, réutilisé comme `app_user_id` RevenueCat | Oui | Non | App Functionality |
| Device ID | **Non** | | | |

Pas d’IDFA, pas d’IDFV envoyé, pas d’ATT.

### 5.11 Purchases

Déjà en 5.3. Si l’écran sépare « Purchases » : **Purchase History**,
lié, pas de tracking, App Functionality.

### 5.12 Usage Data

| Type | Collecté | Lié | Tracking | Purposes |
| --- | --- | --- | --- | --- |
| Product Interaction | **Oui**, au minimum le compteur `ai_usage` (fiche / cartes / explication, par jour) | Oui | Non | App Functionality (plafond) |
| Advertising Data | **Non** | | | |
| Other Usage Data | **Non** | | | |

Ne pas déclarer d’analytics « pour améliorer le produit » : on n’en a
pas. Le compteur ne contient pas le contenu du cours.

### 5.13 Diagnostics

**Non.** Pas de Crashlytics, pas de Sentry, pas de MetricKit renvoyé
chez nous.

### 5.14 Other Data

Si Apple propose un fourre-tout : pays, palier, établissement,
nom d’utilisateur d’annuaire. Tous liés, App Functionality, pas de
tracking.

### 5.15 Tracking

**No.** L’app n’utilise pas de données pour suivre quelqu’un dans des
apps ou sites de tiers. Ne pas activer App Tracking Transparency : il
n’y a rien à demander.

### 5.16 Privacy Policy URL (répétable ici)

`https://www.micabo.app/confidentialite`

---

## 6. Accessibilité (nutrition label)

App Accessibility. Ne cocher **que** ce qui a été essayé avec la
fonction, sur un appareil, pour une tâche courante (importer, relire
une fiche, noter une carte). Une case cochée sans essai est un
mensonge sur la fiche.

État au 1er septembre 2026, d’après le code, **sans essai VoiceOver
de bout en bout** :

| Fonction | Publier ? | Pourquoi |
| --- | --- | --- |
| VoiceOver | **Ne pas cocher** | Des `accessibilityLabel` existent (session, onglets, paywall). Ce n’est pas un parcours testé. |
| Voice Control | **Ne pas cocher** | Non testé. |
| Larger Text | **Ne pas cocher** | Hanken Grotesk en tailles fixes. Pas de Dynamic Type. |
| Dark Interface | **Ne pas cocher** | `.preferredColorScheme(.light)` partout. |
| Differentiate Without Color Only | **Ne pas cocher** | Non audité. |
| Sufficient Contrast | **Ne pas cocher** tant que ce n’est pas mesuré | Encre `#191714` sur ivoire `#F6F4ED` : probablement oui, mais on ne l’a pas mesuré. |
| Reduced Motion | **Ne pas cocher** | Le web réduit. L’iPhone n’a pas de branche `accessibilityReduceMotion` généralisée. |
| Captions | **Ne pas cocher** | Pas de vidéo dans l’app (hors YouTube importé comme texte). |

Mieux vaut une fiche vide qu’une case indéfendable. On remplira après
un vrai passage VoiceOver.

---

## 7. Version iOS — textes français

iOS App → version **1.0.0** (pas 0.1.0).

| Champ | Valeur |
| --- | --- |
| Version | `1.0.0` |
| Copyright | `2026 Adrien Martinot` |
| Support URL | `https://www.micabo.app/support` |
| Marketing URL | `https://www.micabo.app` |

### 7.1 Promotional Text — 170 caractères

Modifiable **sans** nouvelle relecture. Pour le lancement :

```
Dépose un polycopié, une photo ou une vidéo. Micabo en écrit la fiche et les cartes, puis les fait revenir juste avant que tu oublies.
```

**134 / 170.**

Variantes, à coller plus tard sans resoumettre :

```
3 jours Pro offerts. Ensuite 5,83 € / mois, prélevés 69,99 € une fois par an. Résiliable depuis ton compte Apple.
```

```
Le mode examen pose le jour J et resserre les cartes à l’approche. La répétition espacée, avec une date au bout.
```

Ne jamais y mettre un chiffre d’utilisateurs. On n’en a pas un
défendable.

### 7.2 Description — 4 000 caractères

Coller tel quel. Les trois premières lignes restent visibles sans
« Plus ». C’est le héros du site, volontairement.

```
Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la fiche, en tire les cartes, et les fait revenir juste avant que tu oublies.

Une fiche à relire. Des cartes qui reviennent le jour où tu commences à oublier. Un plan qui se resserre quand tu poses la date d’un examen.

IMPORT
PDF, scan, photos de cahier, Word, texte collé, ou une vidéo YouTube (sous-titres). La lecture se fait sur l’iPhone. Le modèle n’écrit qu’à partir de ce qui a été lu.

FICHE
Pas un mur de puces : définitions, schémas, tableaux, points d’attention. Tu règles la longueur. Tu peux faire expliquer un passage.

CARTES
Recto verso, textes à trou, QCM, zones masquées sur un schéma, prononciation. Tu commandes combien de chaque. Puis tu révises : quatre boutons, une session.

MODE EXAMEN
Tu donnes le jour J. Micabo place les révisions, les resserre à l’approche, et empêche une carte de repartir après l’épreuve.

TES COURS
Privés par défaut. Un cours partagé ne l’est qu’avec tes amis — pas dans un catalogue. Le même compte ouvre l’iPhone et micabo.app. Supprimer le compte les efface partout.

GRATUIT ET PRO
Gratuit : un cours, 70 % de sa fiche, cinq cartes par session. Pro : cours et cartes sans limite, fiche entière, entraînement libre. 69,99 € par an (3 jours offerts) ou 7,99 € par semaine, sans essai. Résiliable dans les réglages Apple.

Micabo n’est pas un professeur. Une fiche peut se tromper ou sauter un passage. Tu restes responsable de ce que tu apprends.
```

Pas de « ✨ », pas de « propulsé par l’IA » en accroche, pas d’Anki
(concurrent), pas de promesse de note, pas de « 500 000 étudiants ».

### 7.3 Keywords — 100 caractères

Virgules **sans espace**. Ne pas répéter `Micabo`, ni les mots du
sous-titre (`fiches`, `flashcards`, `cours`).

```
révision,cartes,examen,lycée,prépa,mémorisation,pdf,qcm,étude,notes,partiels,concours,licence,pass
```

**98 / 100.**

Interdits volontaires : `anki` (concurrent), `ia` / `chatgpt` (Apple
y est sourcilleux, et ça n’est pas le produit).

### 7.4 What’s New — première version

Apple l’accepte vide au premier envoi. Si le champ refuse le vide :

```
La première version. Importe un cours, relis sa fiche, révise ses cartes, pose la date d’un examen.
```

---

## 8. Localisation English (U.S.)

Add Language → English (U.S.). Les URL restent les mêmes (le site est
en français ; une page support anglaise n’existe pas — le relecteur
US s’en sort, la page est courte).

### Subtitle

```
Sheets and cards from notes
```

**27 / 30.**

### Promotional Text

```
Drop a handout, a photo, or a lecture video. Micabo writes the sheet and the cards, then brings them back just before you forget.
```

### Description

```
Drop a handout, a photo of your notes, or a lecture video. Micabo writes the sheet, builds the cards, and brings them back just before you forget.

A sheet you reread. Cards that return the day you start forgetting. A plan that tightens when you set an exam date.

IMPORT
PDF, scan, notebook photos, Word, pasted text, or a YouTube video (captions). Reading happens on the iPhone. The model only writes from what was actually read.

SHEET
Not a bullet dump: definitions, figures, tables, watch-outs. You set the length. You can ask for an explanation of a passage.

CARDS
Q&A, cloze, multiple choice, image occlusion, pronunciation. You pick how many of each. Then you review: four buttons, one session.

EXAM MODE
You give the date. Micabo places the reviews, tightens them as the day nears, and will not schedule a card past the exam.

YOUR COURSES
Private by default. A shared course goes to your friends only — not a public catalog. The same account opens the iPhone app and micabo.app. Deleting the account deletes the courses everywhere.

FREE AND PRO
Free: one course, 70% of its sheet, five cards per session. Pro: unlimited courses and cards, the full sheet, free practice. €69.99 a year (3-day trial) or €7.99 a week, no trial. Cancel in your Apple account settings.

Micabo is not a teacher. A sheet can be wrong or skip a passage. You remain responsible for what you learn.
```

### Keywords

Éviter les mots du sous-titre (`sheets`, `cards`, `notes`) :

```
study,revision,exam,flashcards,pdf,quiz,memorize,college,spaced,homework,lecture,midterm
```

### What’s New

```
The first release. Import a course, read its sheet, review its cards, set an exam date.
```

---

## 9. Captures et aperçus

Jusqu’à 10 par taille. L’ordre est l’ordre de la galerie : la première
est la miniature.

### Tailles à envoyer

| Device | Pixels (portrait) | Obligatoire |
| --- | --- | --- |
| iPhone 6,9″ (16 Pro Max / 15 Pro Max) | 1320 × 2868 ou 1290 × 2796 | **Oui** |
| iPad 13″ | 2064 × 2752 | **Oui** — `TARGETED_DEVICE_FAMILY = 1,2` |
| 6,5″ / 5,5″ | | Non, Apple étire depuis le 6,9″ |

PNG, RVB, **sans transparence**, pas de pastille « Gratuit ! », pas de
prix, pas de concurrent, pas de fonction absente du build.

Pas de vidéo pour v1 (App Preview). Si on en fait une plus tard :
15–30 s, l’app en train de servir, pas un motion design.

### Plan des 7 captures

Même ordre sur iPhone et iPad. Texte d’overlay **court**, Hanken
Grotesk, encre, pas de dégradé violet. Fond ivoire. Une phrase par
image, en haut ou en bas, jamais sur le contenu utile.

| # | Écran à photographier | Overlay FR | Overlay EN |
| --- | --- | --- | --- |
| 1 | **Réviser** — cartes du jour, barre, un examen à J−n | `Aujourd’hui, ce qu’il reste à retenir.` | `Today: what still needs to stick.` |
| 2 | **Fiche** d’un vrai cours (pas la démo interne) — définitions visibles | `Ton cours, devenu une page qu’on relit.` | `Your course, as a page you reread.` |
| 3 | **Session** — carte retournée, les quatre boutons | `Quatre boutons. La carte revient au bon moment.` | `Four buttons. The card comes back on time.` |
| 4 | **Calendrier d’examen** — jour J cerclé, points de révision | `Tu poses le jour J. Le plan se resserre.` | `Set the date. The plan tightens.` |
| 5 | **Import** — les sources (PDF, scan, YouTube, Word, texte) | `PDF, photos, YouTube, Word. Sur l’iPhone.` | `PDF, photos, YouTube, Word. On the iPhone.` |
| 6 | **Cartes** — un QCM ou un texte à trou, pas seulement du recto verso | `QCM, trous, schémas. Tu commandes le format.` | `Quiz, cloze, diagrams. You pick the format.` |
| 7 | **Profil** — série et courbe des quinze jours | `La série, et les quinze derniers jours.` | `Your streak, and the last fifteen days.` |

Ne **pas** photographier : le paywall (le prix vit dans
l’abonnement, pas sur une capture), l’écran de connexion, un cours
d’un inconnu, un état d’erreur, l’interrupteur Pro de DEBUG.

Cours à montrer : un chapitre réel (photosynthèse, fonctions affines,
ou le cours du compte de démo). Pas un Lorem ipsum.

---

## 10. Abonnements

Monetization → Subscriptions. Le détail opérationnel (clés, RevenueCat,
offres) est dans `docs/revenuecat.md`. Ici : **ce qu’on écrit dans les
champs Apple**.

### Groupe

| Champ | Valeur |
| --- | --- |
| Reference Name | `Micabo Pro` |
| Group Display Name (fr-FR) | `Micabo Pro` |
| Group Display Name (en-US) | `Micabo Pro` |
| App Name Display | Your app name |

Un seul groupe. Les trois produits s’excluent : passer de
l’hebdomadaire à l’annuel ne double pas la facture.

### Produit annuel — celui qu’on recommande

| Champ | Valeur |
| --- | --- |
| Reference Name | `Micabo Pro annuel` |
| Product ID | `com.micabo.app.pro.yearly` |
| Duration | 1 Year |
| Price (France) | **69,99 €** — laisser Apple remplir les autres pays, puis relire |
| Display Name (fr-FR) | `Annuel` |
| Description (fr-FR) | `Cours et cartes illimités, toute l’année.` |
| Display Name (en-US) | `Yearly` |
| Description (en-US) | `Unlimited courses and cards, all year.` |
| Introductory Offer | **Free**, 3 days, tous les territoires, *New subscribers* |
| Win-back / Offer Codes | aucun pour v1 |

### Produit hebdomadaire

| Champ | Valeur |
| --- | --- |
| Reference Name | `Micabo Pro hebdomadaire` |
| Product ID | `com.micabo.app.pro.weekly` |
| Duration | 1 Week |
| Price (France) | **7,99 €** |
| Display Name (fr-FR) | `Hebdomadaire` |
| Description (fr-FR) | `Cours et cartes illimités, sans engagement.` |
| Display Name (en-US) | `Weekly` |
| Description (en-US) | `Unlimited courses and cards, cancel anytime.` |
| Introductory Offer | **Aucun** |

### Produit annuel discount — hors paywall ordinaire

| Champ | Valeur |
| --- | --- |
| Reference Name | `Micabo Pro annuel discount` |
| Product ID | `com.micabo.app.pro.yearly.discount` |
| Duration | 1 Year |
| Price (France) | **39,99 €** |
| Display Name (fr-FR) | `Annuel` |
| Description (fr-FR) | `Cours et cartes illimités, toute l’année.` |
| Display Name (en-US) | `Yearly` |
| Description (en-US) | `Unlimited courses and cards, all year.` |
| Introductory Offer | **Aucun** |
| RevenueCat | offering `discount` seulement, pas `default` |

### Review Information des abonnements

Apple refuse un abonnement sans capture du paywall.

| Champ | Valeur |
| --- | --- |
| Screenshot | Le **second** paywall (`PaywallPlansView`) : les deux offres, le tableau Gratuit / PRO, le prix. Ou le premier (`PaywallOfferView`) plus « Voir toutes les offres ». |
| Review Notes | Voir le bloc ci-dessous. |

```
Micabo Pro unlocks unlimited course imports, the full generated sheet, unlimited review cards, and free practice.

Two storefront plans:
- com.micabo.app.pro.yearly — €69.99 / year, 3-day free trial (new subscribers)
- com.micabo.app.pro.weekly — €7.99 / week, no trial

A third product, com.micabo.app.pro.yearly.discount (€39.99 / year, no trial), is not on the regular paywall. It is only presented after the first imported course (gift offer). Same entitlement (pro).

The paywall is native SwiftUI (not StoreKit's SubscriptionStoreView). Restore Purchases is at the bottom, next to the Terms and Privacy links:
- https://www.micabo.app/conditions
- https://www.micabo.app/confidentialite

Free tier without Pro: 1 imported course, 70% of that sheet, 5 cards per session. Generating still runs so the reviewer can see the lock, not an empty page.

To see the paywall without waiting: import a second course, or open a session and go past the fifth card, or tap a locked sheet tail (“Débloquer la fiche”).
```

---

## 11. App Review Information

Même page que la version, en bas.

| Champ | Valeur |
| --- | --- |
| First Name | `Adrien` |
| Last Name | `Martinot` |
| Phone | *(ton mobile, format international +33…)* — Apple appelle |
| Email | `team@micabo.app` |
| Sign-In Required | **Yes** — le compte n’est pas obligatoire pour ouvrir l’app (`Skip` existe), mais **toute** génération, synchro, ami et achat demandent une session. Cocher Yes évite un relecteur bloqué sur le paywall ou l’import. |
| User Name | `review@micabo.app` |
| Password | *(tu le poses, tu le notes ici côté toi — pas dans le dépôt)* |
| Attachment | Optionnel : un PDF de cours court (2–3 pages, SVT ou maths) si tu veux qu’ils importent sans chercher un fichier. |

### Compte de démo — à créer avant d’envoyer

1. Créer `review@micabo.app` (lien magique ou mot de passe, le plus
   simple à donner à Apple). **Pas de 2FA.**
2. Finir le parcours : France, un palier lycée ou licence, deux
   matières, une date d’examen dans 21 jours, une école ou Passer.
3. Importer **un** cours réel, générer la fiche **et** des cartes
   (mélange recto verso + QCM + trou).
4. Poser l’examen sur ce cours.
5. Lui écrire une ligne `entitlements` Pro (ou un grant RevenueCat
   `promotional`) pour que le relecteur voie la fiche entière **et**
   puisse quand même ouvrir le paywall depuis Réglages / un second
   import. Alternative honnête : le laisser en gratuit, et le dire
   dans les notes — le cadenas à 70 % *est* le produit.
6. Ajouter un second compte ami (`ami-review@micabo.app`) et partager
   un cours « Mes amis », pour que le relecteur voie que ce n’est pas
   un fil public.
7. Ne pas verrouiller, ne pas supprimer, ne pas y mettre de contenu
   douteux.

### Notes de relecture — coller en anglais

Le relecteur est souvent aux États-Unis. Une note vague = refus 2.1.

```
WHAT MICABO IS
An iOS study app. The student imports a course (PDF, photos/scan, Word, pasted text, or a YouTube URL with captions). On-device OCR / PDFKit extracts text. A model then writes a structured sheet and, on demand, flashcards. Reviews use SM-2 spaced repetition. An exam date compresses the schedule toward that day.

ACCOUNT
Sign-in required for import, generation, sync, friends, and purchase.
Demo: review@micabo.app / [PASSWORD]
Sign in with Apple and Google are also implemented (Supabase). Please use the demo account; do not create a new Apple ID just to test login unless you want to.

HOW TO SEE THE CORE LOOP (≈ 4 minutes)
1. Launch. If onboarding appears on a fresh install, you can Skip sign-in — but generation will ask for an account. Prefer the demo account above.
2. Tab « Réviser » (center) is the home screen: due cards + exams.
3. Tab « Cours » → open the already-imported course → read the sheet. Pull a sentence → « Expliquer » if you want the explain-selection path.
4. On the sheet, « Cartes » / generate if the demo deck is empty. Start « Réviser N cartes ». Rate with the four buttons (Again / Hard / Good / Easy). Multiple-choice: tapping a choice flips the card; the student still rates.
5. Tab « Réviser » → exams → the dated exam on the demo account.

IMPORT (optional)
Cours → + → PDF, scan/photos, YouTube, Word, or text.
Camera and Photos permission strings are only for scanning / picking pages. Nothing is uploaded until the student confirms the import.
YouTube: paste a real captioned lecture under 1 h 30. Videos without captions, or longer than 90 minutes, are refused on purpose.

FRIENDS / SHARING
There is no public catalog and no Discover feed. A course is private by default. The only share option offered at import is « Mes amis » (friends) or « Privé ».
Friends: Profile → Amis. You can add by username or from schoolmates; you can remove a friend (SocialService.remove).
To report a shared course that should not be there: email team@micabo.app (also linked from https://www.micabo.app/support). A dedicated in-app Report button is the next submission if you require it under 1.2.

SUBSCRIPTIONS
StoreKit + RevenueCat. Group « Micabo Pro ».
Free: 1 course, 70% of the sheet (composed, then blurred), 5 cards per session.
Paywall entries: second import, locked sheet tail, 6th review card, free-practice lock, end of onboarding.
Yearly 69.99 EUR / 3-day trial; weekly 7.99 EUR / no trial.
Please do not complete a real purchase if you only need to inspect the paywall — closing it (X, always visible immediately) returns to the app. Restore is at the bottom of the paywall.

LEGAL
Privacy: https://www.micabo.app/confidentialite
Terms:    https://www.micabo.app/conditions
Support:  https://www.micabo.app/support
Account deletion: Settings → « Supprimer mon compte » (Guideline 5.1.1(v)).

PLEASE IGNORE
DEBUG-only « Micabo Pro » toggle and « Rejouer le cadeau » do not ship in Release.
On-device occlusion images and card audio never leave the phone.

THIRD-PARTY CONTENT
User-provided only. We do not ship a licensed catalog. YouTube import reads metadata + captions of a URL the student pastes; they must have the right to use that material (terms § « Vos cours »).
```

---

## 12. Questions de soumission (Submit for Review)

### Export Compliance

| Question | Réponse |
| --- | --- |
| Does your app use encryption? | **Yes** — HTTPS vers Supabase, RevenueCat, Apple, fal. |
| Exempt under US export regulations (HTTPS / standard crypto only) ? | **Yes** |

`ITSAppUsesNonExemptEncryption = false` est maintenant dans
`Micabo/Info.plist`, pour ne plus voir la question à chaque upload.

Pas de crypto maison, pas de VPN, pas de chat chiffré de bout en bout.

### Advertising Identifier

| Question | Réponse |
| --- | --- |
| Does this app use the Advertising Identifier (IDFA)? | **No** |

### Content Rights (à la soumission)

Même réponse qu’en App Information : **Yes**, contenus fournis par
l’utilisateur (et YouTube à sa demande). On n’a pas de contrat de
studio à joindre. La note de relecture suffit.

---

## 13. Digital Services Act (UE)

App Information → Digital Services Act.

| Champ | Valeur |
| --- | --- |
| Are you a trader? | **Yes** — on vend un abonnement à des consommateurs UE |
| Trader name | `Adrien Martinot` |
| Address | *(domicile ou siège — à poser)* |
| Phone | *(même que App Review, ou une ligne dédiée)* |
| Email | `team@micabo.app` |
| EU / EEA business registration | *(SIRET si tu en as un, sinon le champ prévu pour un particulier)* |
| Additional markings URL | *(vide)* |

Ça s’affiche sur la fiche européenne. Ne pas y mettre une adresse
qu’on ne veut pas voir.

---

## 14. Sortie de version

| Champ | Valeur v1 |
| --- | --- |
| Release | **Manually release this version** — pour coller le badge App Store sur le site le jour J, pas avant |
| Phased release | Indisponible sur une première version |
| Reset Overview Rating | n/a (première) |

Après l’approbation : Pending Developer Release → Release. Puis
seulement coller le lien dans `IosAlso` / le pied de page (aujourd’hui
volontairement sans badge : un badge mort se voit).

---

## 15. Sign in with Apple, notifications, permissions

Déjà dans le binaire. Rien à « activer » dans la fiche, mais le
relecteur les voit.

| Permission / capacité | Info.plist | Texte | Quand |
| --- | --- | --- | --- |
| Camera | `NSCameraUsageDescription` | « Micabo utilise l'appareil photo pour scanner vos pages de cours. » | Scan de pages |
| Photo library | `NSPhotoLibraryUsageDescription` | « Micabo accède à vos photos pour importer un cours ou un schéma. » | Import / occlusion |
| Microphone | *absent* | — | L’audio d’une carte est un fichier, pas un enregistrement |
| Tracking | *absent* | — | |
| Notifications | *absent* | — | Aucune demande système aujourd’hui |
| Sign in with Apple | entitlement `applesignin` | — | Obligatoire : Google est aussi proposé |

Ne pas ajouter une notification « pour plus tard » dans la fiche.

---

## 16. Ce que la fiche ne dit pas, et pourquoi

| Tentation | Pourquoi non |
| --- | --- |
| « 500 000 étudiants » | Chiffre jamais défendu. Interdit sur le site, interdit ici. |
| « Garantit ta note » / « le meilleur de ta classe » | Le paywall d’accueil le dit encore à l’écran 8 web. La fiche Store, elle, ne le reprend pas : c’est une allégation scolaire. |
| « Anki » dans les mots-clés | Concurrent. La page `/micabo-ou-anki` peut le dire ; Apple, non. |
| Badge « IA » en premier | Le produit est la fiche et la carte, pas le modèle. |
| Prix barré inventé | L’économie de l’annuel se **calcule** (83 % vs l’hebdomadaire aujourd’hui). On ne l’écrit pas en dur dans la description. |
| Mode sombre, widgets, notifs | Absents du build. |

---

## 17. Contrôle des longueurs

À relancer si on retouche un texte :

```bash
node -e '
const fr = {
  name: "Micabo",
  subtitle: "Fiches et flashcards de cours",
  promo: "Dépose un polycopié, une photo ou une vidéo. Micabo en écrit la fiche et les cartes, puis les fait revenir juste avant que tu oublies.",
  keywords: "révision,cartes,examen,lycée,prépa,mémorisation,pdf,qcm,étude,notes,partiels,concours,licence,pass",
};
const en = {
  subtitle: "Sheets and cards from notes",
  keywords: "study,revision,exam,flashcards,pdf,quiz,memorize,college,spaced,homework,lecture,midterm",
};
const lim = { name: 30, subtitle: 30, promo: 170, keywords: 100 };
for (const [k, v] of Object.entries(fr)) {
  const max = lim[k] ?? 170;
  console.log("FR", k, [...v].length + " / " + max, [...v].length <= max ? "ok" : "TROP LONG");
}
for (const [k, v] of Object.entries(en)) {
  const max = lim[k] ?? 170;
  console.log("EN", k, [...v].length + " / " + max, [...v].length <= max ? "ok" : "TROP LONG");
}
'
```

---

## 18. Ordre de saisie, le jour où tu t’y mets

1. Paid Apps + banque / impôts.
2. Créer l’app (§1) si elle n’existe pas.
3. App Information + DSA + Age Rating + Privacy + custom EULA.
4. Les trois abonnements + capture du paywall + notes (§10).
5. Créer le compte `review@micabo.app` et le cours de démo.
6. Passer la version à 1.0.0, archiver, uploader.
7. Version : textes FR + EN, URLs, 7 captures iPhone + 7 iPad.
8. App Review Information + notes (§11).
9. Submit : encryption exempt, pas d’IDFA, content rights Yes.
10. Release manuelle après approbation. Coller l’URL Store sur le site.

Les abonnements et la fiche partent **dans la même** soumission.
Un produit `Ready to Submit` sans build reste invisible.
