-- L'examen blanc devient une copie.
--
-- Le blanc d'avant tirait N cartes et demandait à l'étudiant de se noter lui-même,
-- une carte à la fois, la réponse retournée juste après. Trois défauts, et ils
-- allaient ensemble : on se croit juste sur ce qu'on n'aurait pas su écrire, une
-- carte à la fois n'apprend pas à gérer son temps, et une réponse montrée tout de
-- suite transforme l'épreuve en révision.
--
-- La copie est écrite par le modèle sur le programme de l'épreuve : QCM, vrai ou
-- faux, mot caché, et - quand l'étudiant a un micro - des questions Feynman
-- répondues à l'oral. Les fermées se corrigent à la comparaison, les orales par le
-- modèle. D'où trois colonnes.

alter table public.mock_sessions
  /* La copie telle qu'elle a été posée. C'est elle qui doit survivre au
     rechargement : sans elle, revenir sur l'onglet redistribuerait des questions,
     et l'étudiant passerait un autre examen que celui qu'il avait commencé. */
  add column if not exists questions jsonb not null default '[]',

  /* Ce que la correction a rendu : la note par question, et le mot du modèle sur
     les réponses orales. Séparé de `answers`, qui reste ce que l'étudiant a posé. */
  add column if not exists grades jsonb not null default '[]',

  /* Le débriefing : une phrase, ce qui tient, ce qui ne tient pas, quoi faire. */
  add column if not exists debrief jsonb,

  /* Vrai quand la copie contenait des questions orales. Deux copies de familles
     différentes ne se comparent pas tout à fait, et le débriefing le dit. */
  add column if not exists with_audio boolean not null default false;

comment on column public.mock_sessions.questions is
  'La copie posée à l''ouverture : [{ kind, id, prompt, ... }]. Immuable pendant la passation.';
comment on column public.mock_sessions.grades is
  'La correction : [{ id, score 0-100, comment }].';
comment on column public.mock_sessions.debrief is
  'Le débriefing du modèle : { headline, strengths[], gaps[], advice }.';
