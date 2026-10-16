-- La refonte « parcours » : chaque cours devient une leçon, un chemin de cercles.
--
-- Voir `docs/refonte-parcours.md` § 8. Le plan de la leçon (intro, paliers, conclusion,
-- icône) et la progression de l'élève vivent sur le cours ; les notes, l'icône et les
-- questions de chaque thème vivent sur son chapitre — un chapitre est un thème, et un cercle
-- Notes.
--
-- **Cette migration est strictement additive.** Le site continue de lire `courses.sheet`,
-- `chapters.sheet` et `flashcards` exactement comme avant : aucune colonne n'est retirée,
-- aucune contrainte n'est durcie. L'app, de son côté, vérifie que ces colonnes existent
-- avant de les envoyer (`CloudSchema`) : un téléphone à jour face à une base qui n'a pas
-- encore cette migration continue de synchroniser l'ancien format, sans erreur.

alter table public.courses
  -- Le plan (`LessonPath`) : `{"version", "icon", "intro": {"lines", "minutes"},
  -- "takeaways", "groups": [{"name", "themes"}], "shortened", "singleQuiz", "status"}`.
  add column if not exists path jsonb,
  -- La progression (`LessonProgress`) : cercles cochés, scores des quiz, questions
  -- ratées, temps passé par activité, date de fin.
  add column if not exists progress jsonb,
  -- Un des cinq tons de Micabo : yellow, mint, blue, pink, lilac.
  add column if not exists tone text,
  -- L'icône 3D de la leçon, par son nom dans la base (« globe », « fiole »…).
  add column if not exists icon text,
  -- La dernière ouverture : « Reprendre » sur l'accueil.
  add column if not exists last_opened_at timestamptz;

alter table public.chapters
  -- L'icône 3D du thème.
  add column if not exists icon text,
  -- Les notes au format de la refonte (`ThemeNotes`) : `{"oneLiner", "blocks", "takeaways"}`.
  -- Nulles sur un ancien chapitre, qui garde `sheet`.
  add column if not exists notes jsonb,
  -- La question de fin et les QCM de réserve (`ThemeQuiz`) : `{"questions": [...]}`.
  add column if not exists quiz jsonb,
  -- La génération du thème : pending, ready, failed.
  add column if not exists status text;
