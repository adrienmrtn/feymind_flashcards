# Ce qu'il faut garder pour que la donnée devienne un avantage

**Rien de ce document n'est implémenté.** C'est une proposition, et elle est volontairement
séparée du code : décider ce qu'on garde d'un utilisateur est une décision de produit et de
conformité avant d'être une décision technique, et une fois qu'on a commencé à ne *pas* garder
quelque chose, on ne peut pas revenir en arrière — les données passées n'existent plus.

Ce qui est déjà en place (migration `20260825090000_auth_and_sync.sql`) suffit à la synchro et
pose déjà la moitié du terrain : `courses.raw_text` garde le document d'origine, `courses.sheet`
garde la fiche, et `review_logs` garde chaque révision. Ce document dit ce qui manque, dans
l'ordre où je le ferais.

---

## Le principe, en une phrase

**Ce qui a de la valeur n'est pas la fiche, c'est le couple (document, fiche) et le jugement
porté dessus.** Une fiche seule est un texte de plus. Un document brut avec la fiche qu'on en a
tirée, le prompt exact qui l'a produite, le modèle qui l'a écrite, et le fait que l'étudiant
l'a réécrite ou pas, est une ligne d'entraînement. La première n'est qu'un coût de stockage, la
seconde est un actif.

Trois questions valent la peine d'être posées à ces données, et elles dictent tout le reste :

1. **Est-ce que la version N+1 du prompt fait mieux que la version N ?** Il faut pouvoir
   rejouer un ancien document dans un nouveau prompt et comparer.
2. **Qu'est-ce qu'une bonne fiche ?** Il faut un signal, et il existe déjà : une carte issue
   d'un passage bien fiché est mieux réussie en révision qu'une carte issue d'un passage
   confus.
3. **Où le modèle se trompe-t-il ?** Il faut savoir ce que l'étudiant a corrigé à la main.

---

## 1. Ce qui manque, et que j'ajouterais d'abord

### 1.1 Une table `generations` : une ligne par appel au modèle

C'est la pièce qui manque le plus. Aujourd'hui la fiche écrase la précédente et l'appel qui l'a
produite ne laisse aucune trace : on ne peut ni comparer, ni reproduire, ni mesurer.

```
generations
  id                uuid
  user_id           uuid
  course_id         uuid
  kind              text     -- 'sheet' | 'cards' | 'explain'
  model             text     -- « google/gemini-flash-1.5 »
  prompt_version    text     -- une étiquette de version du prompt, pas son texte
  prompt_hash       text     -- SHA-256 du prompt système effectif
  -- les paramètres qui ont décidé du résultat
  study_level, country_code, subject_detected, sheet_length, quota jsonb
  source_kind       text     -- 'photo' | 'pdf' | 'youtube' | 'text' | 'docx'
  input_chars       int
  -- ce qui est sorti
  output            jsonb    -- la fiche ou les cartes, telles que rendues
  output_blocks     int
  highlights_added  int      -- combien le code a dû en poser lui-même
  -- ce que ça a coûté
  latency_ms        int
  tokens_in, tokens_out int
  retried           bool
  failure_code      text
  created_at        timestamptz
```

Trois champs de cette liste sont ceux auxquels on ne pense pas et qui servent le plus :

- **`prompt_version` + `prompt_hash`.** Sans eux, on compare des fiches écrites par des prompts
  différents en croyant comparer des modèles. Le hash est là pour attraper le cas où le prompt
  a changé sans que la version soit incrémentée, ce qui arrivera.
- **`highlights_added`.** C'est déjà une mesure de qualité du prompt, gratuite : `ensureHighlights`
  compte combien de surlignages le code a dû poser parce que le modèle ne l'avait pas fait. Ce
  nombre doit descendre à chaque version du prompt. S'il remonte, la version est mauvaise.
- **`retried`.** Le taux de deuxième tentative est le meilleur indicateur de fragilité d'un
  prompt, et il est déjà calculé dans `generate-course` sans être enregistré.

### 1.2 Une table `course_revisions` : l'historique des fiches

Une fiche refaite écrase l'ancienne. C'est bien pour l'app, c'est une perte sèche pour la
suite : « refaire la fiche » est le signal le plus fort qu'on ait — l'étudiant a lu le résultat
et l'a jugé insuffisant.

```
course_revisions
  id             uuid
  course_id      uuid
  generation_id  uuid       -- vers l'appel qui l'a produite
  sheet          jsonb
  reason         text       -- 'import' | 'redo' | 'length_change' | 'manual_edit'
  superseded_at  timestamptz
  created_at     timestamptz
```

Le champ `reason` fait tout le travail. `redo` sans changement de longueur ni de modèle veut
dire « la fiche était mauvaise » ; `length_change` veut dire « elle n'était pas au bon format »,
ce qui n'est pas le même défaut. Deux `redo` de suite sur le même cours désignent un document
que le pipeline ne sait pas traiter, et ce sont ces documents-là qu'il faut aller regarder.

### 1.3 Les corrections à la main sur les cartes

`FlashcardEditorSheet` permet de corriger une carte, et cette correction est de l'or : c'est un
humain qui écrit la bonne réponse à la place du modèle, sur un contenu dont on a le contexte
exact.

Deux colonnes sur `flashcards` suffisent, et elles sont bien plus simples qu'une table à part :

```
flashcards
  + generated_front  text     -- ce que le modèle avait écrit
  + generated_back   text
  + edited_at        timestamptz
```

Une carte dont `front <> generated_front` est une paire (mauvais, bon) prête à l'emploi. Une
carte supprimée est un signal négatif — d'où l'importance du `deleted_at` déjà en place, à
condition de ne jamais purger ces lignes.

### 1.4 Le texte de la source, tel qu'il a été lu

`raw_text` est déjà là, et c'est le plus important. J'ajouterais deux choses autour :

- **Les images source dans le stockage objet**, avec leur chemin dans `courses.source_assets`.
  Aujourd'hui les photos et les couvertures restent sur l'appareil et sont perdues à la
  réinstallation. Or **le couple (photo, texte OCR, fiche) est exactement ce qui permettrait de
  corriger le problème « absraction »** : sans la photo, on ne peut jamais savoir si l'erreur
  vient de la lecture ou du modèle.
- **`ocr_confidence`**, que Vision rend déjà et qu'on jette. Un mot lu avec une confiance de
  0,3 est précisément celui qu'il ne faut pas définir. C'est un garde-fou déterministe qu'on
  peut construire *sans modèle*, et il vaut mieux que n'importe quelle consigne de prompt.

---

## 2. Ce que je ne garderais pas

Une liste de ce qu'on ne garde pas vaut celle de ce qu'on garde, et elle est plus courte à
défendre devant un utilisateur.

- **Le texte du prompt complet à chaque appel.** Un hash et une version suffisent, le texte vit
  dans le dépôt sous git. Garder le prompt entier multiplie la taille de la table par cent pour
  une information qu'on a déjà.
- **Les brouillons de frappe.** Ce que quelqu'un tape puis efface dans un champ ne nous
  appartient pas.
- **Les données de révision à la milliseconde.** `review_logs` a la bonne granularité. Un
  journal d'événements d'interface (chaque appui, chaque défilement) coûte cher, se périme vite,
  et ne répond à aucune des trois questions du début.
- **Les enregistrements audio et les schémas, hors du stockage objet.** Une colonne `bytea`
  transforme une base Postgres en disque dur : les sauvegardes deviennent énormes, les requêtes
  ralentissent, et le coût par utilisateur explose. Le stockage objet coûte trente fois moins.

---

## 3. Les décisions à prendre avant d'écrire une ligne

Ce sont des questions de produit, et elles doivent être tranchées d'abord.

1. **Le consentement.** Utiliser les cours de quelqu'un pour améliorer un modèle demande une
   base légale, et « c'était dans les conditions d'utilisation » n'en est pas une solide en
   Europe pour un public en partie mineur. Le chemin propre : un réglage explicite,
   `profiles.contributes_to_improvement`, décoché par défaut, avec une phrase qui dit ce que ça
   couvre. Un opt-out n'est pas suffisant si le public est scolaire.
2. **La minorité.** Micabo cible le lycée : une partie des utilisateurs a moins de 15 ans, ce
   qui change le régime applicable. À trancher avant de collecter, pas après.
3. **La séparation.** Les données d'entraînement n'ont pas à vivre dans la base de production.
   Un schéma `analytics` distinct, alimenté par des triggers ou un flux, avec ses propres droits
   et sa propre durée de conservation, évite qu'une requête d'analyse touche les lignes que
   l'app sert.
4. **La dépersonnalisation.** Un couple (document, fiche) n'a pas besoin de savoir de qui il
   vient. Remplacer `user_id` par un pseudonyme stable côté `analytics` permet de garder les
   corrélations (« les fiches de cet utilisateur sont souvent refaites ») sans garder
   l'identité.
5. **La durée.** Un cours brut gardé indéfiniment est une dette. Deux ans est une durée
   défendable pour du contenu d'entraînement, avec une purge automatique.

---

## 4. Dans quel ordre

Si je devais le faire, dans cet ordre, et chaque étape a une valeur seule :

1. **`generations`**, et rien d'autre. C'est la table qui permet de mesurer, donc celle qui
   permet de savoir si les suivantes servent. Elle s'écrit depuis les Edge Functions, qui ont
   déjà toutes les informations en main — c'est une insertion de plus dans un code qui existe.
2. **`highlights_added` et `retried`**, deux entiers de cette table. À partir de là, chaque
   changement de prompt devient mesurable au lieu d'être une opinion.
3. **`course_revisions`**, avec `reason`. C'est le moment où « refaire la fiche » cesse d'être
   une perte.
4. **Les images source dans le stockage objet.** C'est ce qui débloque le diagnostic des erreurs
   de lecture, le sujet sur lequel l'app est aujourd'hui aveugle.
5. **`generated_front` / `generated_back`** sur les cartes. C'est le jeu de paires (mauvais,
   bon), et c'est celui qui a le plus de valeur par octet — mais il n'a de sens qu'une fois
   qu'on a du volume.

Le point de bascule est l'étape 2, pas l'étape 5 : le jour où on peut dire « cette version du
prompt pose 40 % de surlignages en moins que la précédente », le volant commence à tourner.
Tout ce qui vient avant est du stockage.
