# Refonte « parcours »

L'app passe d'un outil qui fabrique des fiches et des cartes à **un chemin façon Duolingo par
leçon** : une intro, des cercles Notes, des Quiz, des Flashcards, une conclusion. Trois onglets,
une police, une mascotte qui vit, et un gratuit qui tient en une phrase.

Source : le PDF « Idées Micabo non promptées » (octobre 2026), et les décisions prises le
15 octobre 2026 à partir du code. Ce document est la référence de la refonte : ce qui n'y est pas
ne se construit pas, et ce qui change de cap s'écrit ici d'abord.

---

## 0. Les décisions, en une table

| Sujet | Décision |
| --- | --- |
| Plateformes | **iOS d'abord.** Le web continue de marcher sur les mêmes tables : tout ce qui s'ajoute est additif, rien de ce qu'il lit ne change de forme. Sa refonte viendra après |
| Anciens cours | **Convertis à l'ouverture.** Un chapitre = un cercle Notes affiché tel quel ; un appel IA ajoute intro, conclusion, icônes, questions de fin et QCM ; les cartes existantes deviennent les flashcards |
| Gratuit, anciens cours | Ouverts en entier. Mais qui a déjà un cours a **consommé** sa requête gratuite |
| Requête gratuite | **Une**, à vie : un sujet tapé dans la barre **ou** un texte collé (icône Texte). PDF, Photo, Audio, YouTube : Pro |
| Couleurs | **Ivoire + encre + bleu.** Fond `#F6F4ED`, accent `#2563EB`. Le violet ne sert qu'aux mots-clés des notes |
| Mascotte | **Un seul personnage : Mika.** La mascotte du zip s'appelle Mika : Home, chat, chargements, fin de leçon. Le blob dégradé disparaît |
| Quiz | **3 QCM de réserve par thème**, générés une fois. Un quiz de 2 thèmes tire 5 QCM sur 6 ; le quiz de 10 et l'examen blanc tirent dans la réserve du cours, ratés d'abord |
| Ce qui disparaît | **Tout ce que le PDF ne nomme pas** (§ 11). Les modèles qui se synchronisent restent, pour le web |
| Thème | « Changer le thème » est tenu : clair / sombre / comme le téléphone (`MicaboAppearance`, palette `adaptive`). L'accueil et le premier cours restent en clair |
| Série (flamme) | Hors du PDF, donc hors de l'interface. Le classement de la semaine reste |
| Lexique | **Leçon** à l'écran (onglet Leçons, Nouvelle leçon, Leçon terminée). Cercle, Palier, Notes, Quiz, Flashcards |
| Langues | Les 5 langues (fr, en, de, es, tr) traduites dans la foulée ; le turc pèse la moitié des comptes |
| Audio | Fichier **et** enregistrement, transcrits **sur l'appareil**, 90 min au plus |
| Onboarding | Inchangé pour l'instant. Le cours qu'il crée devient un parcours (conversion), et c'est la requête gratuite |
| Notifications | Aucune dans cette version |
| Livraison | Une branche, une CI macOS qui compile, teste et rend des écrans en PNG à chaque push (§ 14) |

---

## 1. Lexique

Un seul mot par concept, partout dans l'interface et dans les cinq langues.

| Mot | Ce que c'est |
| --- | --- |
| **Leçon** | Ce que l'élève crée et retrouve dans l'onglet Leçons. Dans le code : `Course` |
| **Parcours** | L'écran d'une leçon : le chemin. Le mot ne s'affiche pas, l'écran se suffit |
| **Cercle** | Une étape du chemin : Intro, Notes, Quiz, Flashcards, Conclusion. « CERCLE 4 » |
| **Thème** | Une sous-partie de la leçon, qui porte un cercle Notes. Le mot ne s'affiche pas : on lit le titre du thème. Dans le code : `Chapter` |
| **Palier** | Un groupe de 2 ou 3 thèmes et son quiz. « PALIER 2 · LES CAUSES » |
| **Notes** | Le contenu d'un thème |
| **Quiz** | Des QCM |
| **Flashcards** | Les cartes à retourner, en répétition espacée, par leçon |

---

## 2. Structure

Trois onglets, et c'est tout. On ne balaye pas de l'un à l'autre.

| Onglet | Rôle |
| --- | --- |
| **Home** | Créer une leçon (sujet tapé ou supports), voir ses stats, reprendre la dernière leçon |
| **Leçons** | Toutes les leçons, rangées dans des dossiers |
| **Profil** | La carte profil, Passer en Pro, amis et classement, réglages, support |

La barre d'onglets est une pilule de verre flottante (Liquid Glass sur iOS 26, matériau
`.ultraThinMaterial` avant). Elle s'efface sur les écrans poussés, comme aujourd'hui.

---

## 3. Home

Dans l'ordre, de haut en bas :

1. **Mika**, qui demande « Qu'est-ce que tu veux apprendre aujourd'hui ? ».
2. **La barre « comme une IA »** : on tape un sujet, on envoie, ça crée une leçon.
3. **Cinq icônes d'import** sous la barre : PDF · Photo · Audio · YouTube · Texte. On peut
   **combiner jusqu'à 5 supports** pour une seule leçon : les supports déposés s'affichent en
   pastilles au-dessus de la barre, qu'on envoie ensemble.
4. **Les stats** : X h de révision · X leçons apprises · X flashcards apprises.
   - Heures = temps **mesuré** passé dans Notes, Quiz et Flashcards (cumul de toutes les leçons).
   - Leçon apprise = parcours arrivé à « Leçon terminée ».
   - Flashcard apprise = carte dont le prochain rappel est à plus de 7 jours.
5. **« Reprendre »** : la dernière leçon ouverte, son anneau de progression, « Cercle 4 ·
   {titre} ». Un appui ouvre le parcours centré sur le cercle en cours.

Détails des imports :

- **PDF** accepte aussi les fichiers Word (`.docx`) : même geste, même icône.
- **Photo** propose l'appareil photo (scan de document) ou la photothèque.
- **Audio** : un fichier (mémo vocal, `.m4a`, `.mp3`, `.wav`) ou un enregistrement en direct.
  Transcription sur l'appareil (`SpeechTranscriber` sur iOS 26, `SFSpeechRecognizer` en mode
  local avant), 90 minutes au plus.
- **YouTube** : un lien, le pipeline actuel (sous-titres, repli Gemini).
- **Texte** : un texte collé.

---

## 4. Créer une leçon

1. L'élève tape un sujet ou dépose ses supports, et envoie.
2. **Gratuit déjà consommé, ou import en gratuit** → paywall, ici et pas plus loin.
3. Deux questions, une par écran : **« As-tu un examen ? »** (oui / non), puis si oui
   **« Quelle date ? »**. La date s'affiche ensuite sur la leçon (« J-12 »).
4. **Écran de génération** : Mika réfléchit, quatre étapes (« Je lis tes supports · J'écris
   tes notes · Je découpe les thèmes · Je prépare tes questions »). **Les étapes sont reliées
   au vrai travail**, pas à un minuteur.
5. **Atterrissage sur le parcours** dès que le plan est connu (≈ 10 s), cercle 1 ouvert.

La matière, le titre, la langue et l'icône sont déduits ; plus aucune question sur la matière,
le nom ou l'objectif. La langue des notes est celle de l'app.

---

## 5. Le parcours

> **Chaque parcours est un univers.** Un titre précis, un chemin qui se lit : une intro, des
> paliers, une conclusion. Gros cercles, chemin visible, le cercle en cours mis en avant.

### 5.1 Comment le chemin se construit

L'IA rend des **thèmes** : 4 au minimum, 12 au maximum. Le chemin est ensuite **toujours
construit de la même façon**, par une fonction pure (`PathLayout`) :

1. **Intro**
2. Un cercle **Notes** par thème
3. Un cercle **Quiz** après chaque groupe de 2 thèmes (de 3 si la leçon en a plus de 8). Le
   quiz porte sur les thèmes du groupe. Si le compte ne tombe pas juste : avec des groupes de 2,
   le dernier groupe prend 3 thèmes ; avec des groupes de 3, un reste de 1 coupe les 4 derniers
   en 2 + 2, un reste de 2 fait un dernier groupe de 2. Un quiz ne couvre jamais plus de 3 thèmes
4. Un cercle **Flashcards** avant la fin
5. **Conclusion**

| Thèmes | Groupes | Cercles | Chemin |
| --- | --- | --- | --- |
| 4 | 2 · 2 | 9 | Intro · N1 · N2 · Quiz · N3 · N4 · Quiz · Flashcards · Conclusion |
| 5 | 2 · 3 | 10 | … · N3 · N4 · N5 · Quiz · … |
| 6 | 2 · 2 · 2 | 12 | Intro · N1 · N2 · Quiz · N3 · N4 · Quiz · N5 · N6 · Quiz · Flashcards · Conclusion |
| 9 | 3 · 3 · 3 | 15 | |
| 10 | 3 · 3 · 2 · 2 | 17 | |
| 12 | 3 · 3 · 3 · 3 | 19 | Intro · N1 · N2 · N3 · Quiz · … · Flashcards · Conclusion |

**Leçon très courte** (moins de 1 500 caractères de supports) : 4 thèmes, l'IA complète avec des
exemples, et **un seul quiz** sur les 4.

**Les paliers.** Avant chaque groupe, un en-tête centré sur le chemin (« PALIER 2 · LES
CAUSES », 12 pt majuscules) : le nom du groupe, choisi par l'IA.

**Les anciens cours** : un chapitre = un thème, quel que soit leur nombre (de 1 à 30). Les
groupes et les noms de palier sont générés à la conversion.

### 5.2 Génération progressive

Les cercles apparaissent dès que les thèmes sont connus ; chaque cercle Notes se remplit quand il
est prêt (petit spinner dedans en attendant). L'Intro est disponible tout de suite : l'élève
commence à lire pendant que le reste s'écrit. Un cercle dont la génération échoue affiche
« Réessayer » ; les autres restent utilisables.

### 5.3 L'écran

**En haut** : chevron retour à gauche, bouton **Mika** (bulle) à droite — le chat, avec la leçon
jointe d'office. L'icône 3D de la leçon (96 pt, centrée), le titre (26 pt, centré, 2 lignes
max), la progression « 3 sur 12 · 25 % » et une barre fine dans la couleur de la leçon. Si
examen : une pastille « Examen le 12 nov · J-12 ». La barre du haut devient une barre native au
défilement.

**Le chemin** :

- Cercles de **72 pt en zigzag** (centre − 60 pt, centre + 60 pt), 112 pt d'écart vertical,
  reliés par un trait de 6 pt entre les centres. Le trait est dans la couleur de la leçon
  jusqu'au cercle en cours, gris clair après.
- Chaque cercle porte son **icône 3D** (44 pt) : étoile pour l'Intro, l'icône du thème pour
  Notes (choisie par l'IA dans la base), clipboard pour Quiz, cartes pour Flashcards, trophée
  pour la Conclusion.
- Le **titre du cercle** est du côté opposé : « CERCLE 4 » en 12 pt majuscules gris, puis le
  titre en 17 pt gras.
- **Trois états** :
  - **Fait** : fond dans la couleur de la leçon, petite coche blanche en badge en bas à droite,
    titre en encre.
  - **En cours** : cercle plus gros (84 pt), anneau de progression autour (où on en est dans
    le cercle), étiquette **« Continuer »** au-dessus (pill ivoire, texte vert), pulsation lente.
  - **À venir** : fond gris clair, icône à 40 %, titre gris. Un appui : petit secouement +
    « Termine d'abord {cercle} ». **On ne saute pas.**
- Entre deux groupes : l'en-tête de palier.
- À l'ouverture, le chemin est centré sur le cercle en cours.

**En bas** : la navbar interne, pill flottante, trois entrées : **Notes · Quiz · Flashcards**
(icônes 3D).

### 5.4 Les cinq cercles

| Cercle | Ce qu'on voit | Ce qui le coche |
| --- | --- | --- |
| **Intro** | « Ce que tu vas apprendre » : 3 lignes, la liste des thèmes avec leurs icônes, « Temps estimé : 25 min », bouton noir « C'est parti » | L'appui sur « C'est parti » |
| **Notes** | Les notes du thème (§ 6), une barre fine en haut qui avance au défilement, et la question de fin | Lu jusqu'en bas **et** question répondue, bonne ou mauvaise |
| **Quiz** | 5 QCM, un par écran, barre « 2 / 5 », réponse immédiate en vert ou rouge avec une phrase d'explication, puis l'écran de score « 4 / 5 » avec Mika | Les 5 répondues, sans score minimum. **Chaque question ratée devient une flashcard à revoir demain** |
| **Flashcards** | 10 cartes de la leçon (les questions ratées d'abord, puis tirage), on retourne, on note **Encore / Bien / Facile**, écran de fin « 10 / 10 » | Les 10 notées |
| **Conclusion** | « À retenir » : 5 phrases clés, le score moyen des quiz, bouton noir « Terminer » | L'appui sur « Terminer », qui ouvre « Leçon terminée » |

**Après chaque cercle** : bouton noir « Cercle suivant » → retour sur le chemin avec
l'animation : le cercle se remplit de couleur et se coche, le trait se colore jusqu'au suivant,
le suivant se dégrise et reçoit « Continuer », le chemin défile dessus (0,6 s au total, un petit
retour haptique).

**« Leçon terminée »** : plein écran, Mika célèbre, confettis légers, « Score 82 % »,
« 24 min », deux boutons : « Revoir mes flashcards » et « Retour aux leçons ». La leçon compte
comme apprise dans les stats de Home.

**Notes de flashcards** : Encore = `again`, Bien = `good`, Facile = `easy` du SM-2 actuel ;
« Difficile » disparaît de l'interface.

### 5.5 Et après

- Le chemin reste ouvert, tout est coché, n'importe quel cercle se rouvre.
- Les flashcards de la leçon vivent dans l'entrée **Flashcards** de la navbar avec « X à réviser
  aujourd'hui » (répétition espacée, **par leçon**), et une pastille sur la carte de la leçon.
- Si une date d'examen existe : **à J-7 et à J-2**, un bandeau « Examen blanc » sur le parcours,
  qui lance le quiz complet (10 questions).

### 5.6 La navbar interne

| Entrée | Contenu |
| --- | --- |
| **Notes** | Toute la leçon d'un coup, en défilement, pour relire avant un contrôle (mêmes blocs que les cercles Notes) |
| **Quiz** | 10 questions sur toute la leçon, tirées de la réserve (ratées d'abord), relançable |
| **Flashcards** | Les flashcards de **cette leçon**, « X à réviser aujourd'hui » et un bouton pour lancer la révision |

### 5.7 Cas particuliers

- **Très long** (plus de 60 000 caractères) : coupé à 60 000, message « La leçon a été
  raccourcie ».
- **Génération qui échoue sur un cercle** : « Réessayer » sur le cercle, le reste utilisable.
- **Gratuit** : la leçon gratuite a le parcours complet.

---

## 6. La mise en page des Notes

> Des notes, pas un cours magistral. Des phrases courtes, un code couleur simple, les mots-clés
> en couleur, des titres clairs.

**Typo (Nunito)** :

| Élément | Taille / graisse |
| --- | --- |
| Titre du thème | 26 pt · gras |
| Sous-titre | 20 pt · gras |
| Corps et puces | 17 pt · normal · interligne 1,35 |
| Mot-clé | 17 pt · gras · violet |
| Petit texte (durée, numéro de cercle) | 12 pt · majuscules · gris. Le seul petit texte autorisé |

**Structure d'un cercle Notes**, toujours dans cet ordre :

1. **Titre du thème** (26 pt) avec l'icône 3D du cercle à gauche.
2. **« En une phrase »** : l'idée clé dans un encadré de la couleur de la leçon.
3. **2 à 5 blocs courts** : un paragraphe (60 mots max) ou une liste (3 à 5 puces, une ligne
   chacune). Un sous-titre (20 pt) peut ouvrir un bloc.
4. **Blocs spéciaux**, seulement quand le contenu le demande : **Définition** (le terme en
   violet, replié, un appui l'ouvre) · **Dates** (frise horizontale) · **Formule** (encadré, la
   formule au centre) · **Exemple** (encadré gris clair).
5. **« À retenir »** : 3 phrases clés sur fond de la couleur de la leçon.
6. **La question de fin** : 1 QCM à 4 choix. Bonne réponse : vert + Mika qui célèbre.
   Mauvaise : rouge + explication en une phrase. Dans les deux cas, le cercle se coche.

**Code couleur, 3 règles et pas plus** :

- **La couleur de la leçon** (un des 5 tons, attribué à la création) : fond des encadrés « En une
  phrase » et « À retenir », filet des titres, barre de progression, cercles cochés.
- **Violet** : les mots-clés et les termes définis. Seul usage du violet dans les notes.
- **Vert / rouge** : bonne / mauvaise réponse, uniquement.

**Interdits** — vérifiés par le prompt **et** par un validateur côté serveur et côté app :
phrase de plus de 25 mots · paragraphe de plus de 60 mots · liste de plus de 5 puces ·
sous-titre gris sous un titre · emoji dans le texte · deux encadrés de suite.

**Les anciens chapitres** (titres, paragraphes, listes, formules) s'affichent avec la même typo
et le même code couleur : leurs surlignages deviennent des mots-clés violets. Seuls « En une
phrase » et « À retenir » leur manquent.

---

## 7. Le gratuit et le payant

| Gratuit | Pro |
| --- | --- |
| **Une** leçon créée par l'IA, à vie, depuis un sujet tapé ou un texte collé | Leçons illimitées (plafond de coût serveur) |
| Son parcours complet : notes, quiz, flashcards, examen blanc | Import PDF, Photo, Audio, YouTube |
| Ses anciens cours, ouverts en entier (mais ils consomment la requête) | |
| Mika : une question offerte, à vie | Mika : 30 messages par jour |

- **Le refus tombe sur l'envoi** : appuyer sur une icône d'import en gratuit ouvre le paywall,
  envoyer un deuxième sujet aussi. Jamais au milieu d'un parcours.
- **La porte est tenue des deux côtés.** L'app refuse avant l'appel (`FreeTier`, `ProAccess`) ;
  le serveur refuse aussi (§ 9.4) : aujourd'hui aucune fonction ne vérifie l'abonnement, et une
  requête gratuite que seul le client compte n'est pas une limite.
- Les anciennes portes disparaissent : 30 % de fiche, 1 carte par jour, entraînement libre,
  chapitres verrouillés.
- L'offre ne bouge pas (annuel, hebdo, 3 jours d'essai, offre cadeau), RevenueCat reste le juge.

---

## 8. Les données

Tout est **additif** : de nouveaux champs avec une valeur par défaut, de nouvelles colonnes
`if not exists`. Le magasin SwiftData n'a pas de plan de migration et se recrée s'il ne s'ouvre
plus : un champ sans défaut effacerait les données locales.

### 8.1 Sur l'appareil

**`Course`** (la leçon) gagne :

| Champ | Type | Rôle |
| --- | --- | --- |
| `pathData` | `Data?` (JSON `LessonPath`) | Le plan : icône, intro, conclusion, paliers, état de génération. `nil` = ancien cours pas encore converti |
| `progressData` | `Data?` (JSON `LessonProgress`) | Cercles faits, cercle en cours, scores des quiz, temps passé par activité, date de fin |
| `toneRaw` | `String` | Un des 5 tons (`yellow`, `mint`, `blue`, `pink`, `lilac`) |
| `iconID` | `String` | L'icône 3D de la leçon, dans la base |
| `lastOpenedAt` | `Date?` | Pour « Reprendre » |

**`Chapter`** (le thème) gagne :

| Champ | Type | Rôle |
| --- | --- | --- |
| `iconID` | `String` | L'icône 3D du thème |
| `notesData` | `Data?` (JSON `ThemeNotes`) | Les notes au nouveau format (§ 8.3). `nil` sur un ancien chapitre, qui garde `sheetData` |
| `quizData` | `Data?` (JSON `[QuizQuestion]`) | La question de fin et les 3 QCM de réserve |
| `statusRaw` | `String` | `pending`, `ready`, `failed` — la génération progressive |

**La date d'examen** reste un `Exam` lié à la leçon (`courseIDs`) : il se synchronise déjà et le
web le lit. Seuls son nom, sa date et sa leçon servent ; le planificateur ne s'en sert plus.

**Les flashcards** restent des `Flashcard` rattachées à la leçon et au thème. Les nouvelles sont
recto/verso ; les questions de quiz ratées deviennent des cartes `choice` dues le lendemain. Les
anciennes gardent leur format (à trous, QCM, masques), que la révision sait déjà afficher.

### 8.2 Dans Supabase

Une migration, rejouable :

```sql
alter table public.courses
  add column if not exists path jsonb,
  add column if not exists progress jsonb,
  add column if not exists tone text,
  add column if not exists icon text,
  add column if not exists last_opened_at timestamptz;
alter table public.chapters
  add column if not exists icon text,
  add column if not exists notes jsonb,
  add column if not exists quiz jsonb,
  add column if not exists status text;
```

Et la table de la porte gratuite (§ 9.4). Côté app : `CourseRecord` et `ChapterRecord` gagnent
les propriétés, **leurs `CodingKeys` et leur `encode(to:)`** — c'est exactement là que
`courses.language` s'est perdu (il n'est ni envoyé ni reçu aujourd'hui) ; il est corrigé au
passage. Toute modification de progression touche `updatedAt` pour partir au prochain envoi.

### 8.3 Les formats JSON

```jsonc
// LessonPath — courses.path
{
  "version": 1,
  "icon": "globe",                       // nom dans la base d'icônes 3D
  "intro": { "lines": ["…", "…", "…"], "minutes": 25 },
  "takeaways": ["…", "…", "…", "…", "…"], // la Conclusion
  "groups": [ { "name": "Les causes", "themes": [0, 1] }, … ],
  "shortened": false,                    // supports coupés à 60 000 caractères
  "singleQuiz": false,                   // leçon très courte : un seul quiz
  "status": "generating" | "ready" | "failed"
}

// ThemeNotes — chapters.notes
{
  "oneLiner": "…",
  "blocks": [
    { "type": "subtitle", "text": "…" },
    { "type": "paragraph", "text": "… **mot-clé** …" },
    { "type": "list", "items": ["…", "…", "…"] },
    { "type": "definition", "term": "…", "text": "…" },
    { "type": "dates", "items": [ { "date": "1947", "text": "…" }, … ] },
    { "type": "formula", "latex": "…", "caption": "…" },
    { "type": "example", "text": "…" }
  ],
  "takeaways": ["…", "…", "…"]
}

// ThemeQuiz — chapters.quiz (la première question est celle de fin, les suivantes la réserve)
{ "questions": [ { "id": "<thème>:0", "prompt": "…", "choices": ["…", "…", "…", "…"],
                   "answer": 2, "why": "…" }, … ] }

// LessonProgress — courses.progress
{
  "done": ["intro", "notes:0", "notes:1", "quiz:0"],
  "inCircle": 0.4,
  "quizScores": { "quiz:0": [4, 5] },
  "missed": ["<id de question>", …],
  "seconds": { "notes": 840, "quiz": 210, "flashcards": 300 },
  "finishedAt": "2026-10-20T18:03:00Z"
}
```

Les identifiants de cercle (`intro`, `notes:<rang>`, `quiz:<groupe>`, `flashcards`,
`conclusion`) sont stables : c'est la clé de la progression. Le cercle en cours n'est pas
stocké, c'est le premier cercle non coché (`PathLayout.current`).

Le balisage en ligne des notes ne garde que `**mot-clé**` (gras violet) et `$latex$`.

---

## 9. La génération

### 9.1 Le pipeline

Trois appels, orchestrés par l'app (`LessonBuilder`), qui écrit au fur et à mesure dans la
leçon — c'est ce qui rend la génération progressive visible :

1. **`lesson-plan`** (≈ 5 à 10 s) — reçoit les supports (texte combiné, pages en image) ou le
   sujet, le niveau, le pays, la langue. Rend : titre, matière, icône de la leçon, les thèmes
   (titre de 6 mots max + icône), les paliers (nom + thèmes), l'intro (3 lignes + durée
   estimée), la conclusion (5 phrases), et le texte de référence (`contextText`, OCR des images
   compris). → La leçon est créée, le chemin s'affiche, l'Intro est lisible.
2. **`lesson-theme`**, une fois par thème, **4 en parallèle** — reçoit le texte de référence,
   le titre du thème, les titres des autres (pour ne pas se recouvrir), le niveau. Rend les notes
   (`ThemeNotes`), la question de fin, 3 QCM de réserve et 3 flashcards. → Le cercle passe de
   `pending` à `ready`. En échec, `failed` et « Réessayer ».
3. **`lesson-convert`** — pour un ancien cours : reçoit les titres des chapitres et leur texte à
   plat. Rend l'icône de la leçon, l'icône de chaque thème, les paliers, l'intro, la conclusion,
   et pour chaque thème la question de fin et 3 QCM. Si le cours a moins de 3 cartes par
   chapitre, il rend aussi les flashcards manquantes.

Les trois vivent dans une même fonction `generate-lesson` (champ `stage`), pour partager le
contexte, le modèle et la porte.

### 9.2 Le modèle et le coût

`google/gemini-2.5-flash-lite` par fal.ai, comme aujourd'hui, repli sur `gemini-2.5-flash`. Un
parcours de 6 thèmes : un plan (≈ 15 k jetons d'entrée, 1 k de sortie) et 6 thèmes (≈ 15 k
d'entrée, 2 k de sortie chacun), soit ≈ 110 k jetons d'entrée et 13 k de sortie : **environ
deux centimes** par leçon au prix public de flash-lite.

### 9.3 Le niveau

On garde ce qui existe — le palier (`lycee`, `prepa`, `licence`, `sante`, `master`, `concours`)
et le pays — et on l'affine : l'étape précise (`EducationStage` : « 4e », « Terminale »,
« L2 »…) et l'année partent aussi, et le prompt écrit pour cet élève-là (vocabulaire, longueur
des phrases, exemples). Un collégien n'a pas les mêmes notes qu'un étudiant en santé.

### 9.4 La porte, côté serveur

Une table `lesson_generations` (une ligne par plan demandé : utilisateur, leçon, nombre de
thèmes, appels de thème consommés) :

- **`lesson-plan`** : si l'utilisateur n'est pas Pro (`entitlements.is_pro` et pas expiré), et
  qu'il a déjà une génération **ou** un cours qui n'est ni un exemple ni une reprise → refus
  `free_limit`, que l'app traduit en paywall. Sinon la ligne est créée.
- **`lesson-theme`** : n'est servi que pour une génération existante de l'utilisateur, et dans la
  limite de 2 × le nombre de thèmes (les « Réessayer » compris).
- **`lesson-convert`** : une fois par cours, sans toucher à la requête gratuite.
- L'import (PDF, photo, audio, YouTube) en gratuit est refusé par la même règle : le plan sait
  d'où vient son texte.
- Le plafond Pro reste un fusible de coût (`consume_ai_quota`, par jour).

---

## 10. Design system

- **Police : Nunito partout** (Regular, Medium, SemiBold, Bold, ExtraBold), interface et lecture.
  Outfit et Hanken Grotesk sortent du bundle.
- **Couleurs** : fond ivoire `#F6F4ED`, surfaces blanches, encre, accent bleu `#2563EB`. Les
  **5 tons** (jaune, menthe, bleu, rose, lilas) existent en deux nuances : **pâle** pour les fonds
  d'encadré, **vive** pour les cercles cochés, le trait et la barre de progression — une coche
  blanche ne se lit pas sur un pastel. Violet = mots-clés. Vert / rouge = réponses.
- **Pas d'emoji dans les textes**, nulle part : des icônes 3D (la base du zip) et, pour les
  petites commandes, des SF Symbols.
- **Mascotte Mika** animée : elle respire, cligne, réagit (contente, réfléchit, célèbre, déçue).
  Le blob disparaît.
- **Style épuré** : pas de sous-titres inutiles, texte agrandi.
- **Navbar en verre** (§ 2), boutons d'action principaux **noirs** (encre).
- **Thème** : clair, sombre, ou comme le téléphone. Chaque jeton de `MicaboPalette.adaptive` porte
  sa valeur de jour et de nuit ; le réglage ne fait que fixer l'apparence de la fenêtre.

---

## 11. Ce qui disparaît de l'interface

Tout ce que le PDF ne nomme pas. Le code part avec ; seuls restent les modèles qui se
synchronisent (le web les lit).

| Disparaît | Remplacé par |
| --- | --- |
| Onglet Réviser (révision globale, séances du jour) | Les flashcards par leçon |
| Onglet Mika (conversation globale) | Le bouton Mika dans la leçon |
| Création en 9 écrans (matière, nom, langue, objectif, note visée, confiance) | La barre de Home + 2 questions |
| Planificateur d'examen, projection, calendrier, examens blancs oraux | Date d'examen, « J-12 », examen blanc QCM à J-7 et J-2 |
| Éditeur de fiche, éditeur de cartes, masques sur image, génération de cartes à la carte | — |
| « Expliquer » sur une sélection | Mika dans la leçon |
| Import Anki, paquet de cartes sans cours | — |
| Cours d'amis à reprendre, bibliothèque | — (amis et classement restent) |
| Profil : série, « Ce que tu sais », activité sur 15 jours, « Ce qui résiste » | Les stats de Home |
| Réglages d'étude (longueur de fiche, taille de lecture, minutes par jour, nouvelles cartes par jour) | — |
| Note « Difficile » | Encore / Bien / Facile |

Reste dans la carte profil : prénom, nom d'utilisateur, pays, niveau, établissement, matières,
compte (connexion, déconnexion), **suppression du compte** (exigée par l'App Store).

---

## 12. Profil

1. **La carte profil**. Un appui ouvre toutes les infos (prénom, nom d'utilisateur, pays,
   niveau et filière, matières, langue, compte, suppression).
2. Si gratuit : **« Passer en Pro »**.
3. **Amis et classement de la semaine.**
4. **Réglages** : Changer la langue · Changer le thème · Nous noter.
5. **Support** : Contacter le support (`maximilien@vikstudios.com`) · Nos autres apps
   (vikstudios.com) · Conditions d'utilisation · Politique de confidentialité.

---

## 13. Langues

Chaque phrase nouvelle est écrite dans les 5 langues au moment où elle entre. Les phrases de la
refonte (`lesson.*`) vivent dans `LessonI18nCatalogs`, à part des catalogues générés ; les autres
dans `IosI18nCatalogs` (iOS) ou les catalogues partagés du web (puis l'export). Le test de parité
des clés tient. Les prompts écrivent dans la langue de l'app.

---

## 14. Livrer sans Xcode

La CI `.github/workflows/ios.yml` tourne à chaque push sur un runner macOS (gratuit : le dépôt est
public) :

1. **Compiler** — `build-for-testing` de l'app et des tests ;
2. **Tester** — les tests, sur le dernier simulateur iPhone ;
3. **Rendus** — `RenderGalleryTests` dessine les écrans en PNG (artefact « rendus ») ;
4. **Ce qui a cassé** — les erreurs et les tests en échec, en fin de journal et dans le résumé.

Les fonctions Supabase et la migration se déploient comme aujourd'hui (`pin.sh` ou la CLI) : le
projet de production n'est pas joignable depuis la session de développement.

---

## 15. Les lots

| # | Lot | Contenu |
| --- | --- | --- |
| 0 | **Voir** | CI, rendus PNG, cible de tests réparée, ce document |
| 1 | **Fondations** | Nunito, palette ivoire / bleu / 5 tons, jetons typo du PDF, `MicaboIcon` (icônes 3D, SF Symbols en attendant le zip), composant Mika |
| 2 | **Données** | `LessonPath`, `ThemeNotes`, `QuizQuestion`, `LessonProgress`, `PathLayout` (testé), champs SwiftData, migration Supabase, synchro (et `language` réparé) |
| 3 | **Génération** | `generate-lesson` (plan, thème, conversion), validateurs, porte serveur, `LessonBuilder` progressif |
| 4 | **Parcours** | L'écran du chemin, les 5 cercles, la navbar interne, « Leçon terminée », Mika dans la leçon, examen blanc |
| 5 | **Home** | Mika, la barre, les 5 imports (audio compris), les stats mesurées, « Reprendre », les 2 questions, l'écran de génération |
| 6 | **Leçons** | Cartes horizontales, dossiers, menu Renommer · Déplacer · Supprimer, pastille « 8 à réviser » |
| 7 | **Profil** | Carte profil et détail, Pro, amis et classement, réglages, support |
| 8 | **Nettoyage** | Les portes du gratuit, les anciens écrans supprimés (§ 11), les tests réalignés, les tests de parité du web |
| 9 | **Finitions** | Traductions relues, thème sombre, README |

## 16. Reçu, et ce qui reste à faire hors du code

- **La mascotte** (`micabo-mascotte-mico (2).zip`) est intégrée : `design/mika/` garde le SVG et
  le CSS d'origine, `scripts/generate-mika.py` les traduit en `Micabo/Resources/mika.json`, que
  `MikaMascot` rejoue nativement (huit humeurs). Les GIF du zip ne sont pas embarqués.
- **Les icônes 3D** (`micabo-icones-3d.zip`) sont dans `Assets.xcassets` (`Icon3D-*`) ; la même
  liste est donnée au modèle (`supabase/functions/_shared/icons.ts`, testée contre le Swift).
- **À déployer à la main** sur le projet de production : les migrations
  `20261016090000_lesson_paths.sql` et `20261016091000_lesson_generations.sql`, puis la fonction
  `generate-lesson`. Tant que les colonnes manquent, l'app ne les envoie pas (`CloudSchema`) ; tant
  que la fonction manque, un ancien cours s'ouvre quand même (« Ouvrir sans attendre »).
