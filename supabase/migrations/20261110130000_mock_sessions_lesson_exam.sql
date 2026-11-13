-- **Les examens blancs des leçons ne s'enregistraient pas.** Le site écrit leurs copies dans
-- `mock_sessions` avec `kind = 'lesson_exam'` (web/lib/lesson/exam.ts), mais la contrainte
-- posée par `exam_agenda` ne connaissait que `mock` et `parcours` : chaque examen blanc d'une
-- leçon tombait sur « new row for relation "mock_sessions" violates check constraint
-- "mock_sessions_kind_known" », y compris pour des abonnés.

alter table public.mock_sessions
  drop constraint if exists mock_sessions_kind_known;

alter table public.mock_sessions
  add constraint mock_sessions_kind_known
  check (kind in ('mock', 'parcours', 'lesson_exam'));
