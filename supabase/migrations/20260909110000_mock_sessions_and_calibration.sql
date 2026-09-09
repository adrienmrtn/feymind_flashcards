-- L'examen blanc, et la mesure de ce que l'étudiant fait vraiment.
--
-- Deux manques que le mode examen laissait entiers.
--
-- **Le plan ne savait produire qu'un seul type de travail** : « révise N cartes ».
-- Un examen blanc est autre chose - un temps imparti, un tirage sur tout le
-- programme, un score - et c'est la seule chose qui mesure le rappel en
-- conditions d'épreuve plutôt que carte par carte.
--
-- **Le plan tournait sur une constante de débit**, la même pour tout le monde.
-- Quelqu'un qui fait deux cartes et demie à la minute recevait un planning qui
-- ment de soixante pour cent, et aucune question d'accueil ne l'aurait corrigé :
-- personne ne connaît son propre chiffre. On le mesure.

-- MARK: - Les examens blancs

-- Une session est une unité close : elle s'ouvre, elle se remplit, elle se ferme.
-- Les réponses tiennent donc dans la ligne plutôt que dans une table fille -
-- personne ne requête « toutes les réponses de tous les blancs », on lit une
-- session entière ou rien.
--
-- `exam_id` **désigne** l'épreuve sans la posséder, comme `exams.course_ids`
-- désigne les cours : supprimer une épreuve ne doit pas effacer la preuve qu'on
-- s'est entraîné.
create table if not exists public.mock_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,
  exam_id uuid,

  /* Le jour où le plan l'avait posé. Nul quand l'étudiant la lance lui-même. */
  planned_for date,
  /* Temps imparti, en minutes. C'est la contrainte, pas une estimation. */
  minutes int not null default 20,
  question_count int not null default 0,
  correct_count int not null default 0,

  /* [{ card: uuid, correct: bool }] - le détail, pour dire ce qui a manqué. */
  answers jsonb not null default '[]',

  started_at timestamptz not null default now(),
  finished_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.mock_sessions
  drop constraint if exists mock_sessions_counts_sane;

alter table public.mock_sessions
  add constraint mock_sessions_counts_sane
  check (
    question_count >= 0
    and correct_count >= 0
    and correct_count <= question_count
    and minutes between 1 and 300
  );

create index if not exists mock_sessions_user_exam_idx
  on public.mock_sessions (user_id, exam_id, started_at desc);

create index if not exists mock_sessions_user_done_idx
  on public.mock_sessions (user_id, finished_at desc)
  where finished_at is not null;

alter table public.mock_sessions enable row level security;

drop policy if exists "own mock sessions" on public.mock_sessions;
create policy "own mock sessions"
  on public.mock_sessions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

comment on table public.mock_sessions is
  'Un examen blanc passé : temps imparti, tirage, score. Alimente la préparation projetée.';

-- MARK: - Le débit réellement mesuré

-- `review_logs` ne porte pas de durée, et lui en ajouter une ne mesurerait que
-- l'avenir. L'écart entre deux passages consécutifs la donne déjà : quelques
-- secondes dans une session, des heures entre deux sessions.
--
-- Deux bornes, et elles comptent. Au-delà de `gap_break_seconds` on a changé de
-- session, donc l'écart ne se compte pas. En deçà, on plafonne à
-- `max_card_seconds` : une carte qu'on a laissée à l'écran en allant manger ne
-- doit pas faire croire que l'étudiant met quatre minutes par carte.
create or replace function public.review_throughput(since_days int default 60)
returns table (
  cards bigint,
  seconds numeric,
  cards_per_minute numeric,
  sessions bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  with bornes as (
    select 300::numeric as gap_break_seconds, 120::numeric as max_card_seconds
  ),
  passages as (
    select
      l.reviewed_at,
      extract(epoch from (
        l.reviewed_at - lag(l.reviewed_at) over (order by l.reviewed_at)
      )) as ecart
    from public.review_logs l
    where l.user_id = auth.uid()
      and l.reviewed_at >= now() - make_interval(days => greatest(since_days, 1))
  ),
  compte as (
    select
      count(*) filter (
        where p.ecart is not null and p.ecart <= b.gap_break_seconds
      ) as cards,
      coalesce(sum(
        least(greatest(p.ecart, 1), b.max_card_seconds)
      ) filter (
        where p.ecart is not null and p.ecart <= b.gap_break_seconds
      ), 0) as seconds,
      count(*) filter (
        where p.ecart is null or p.ecart > b.gap_break_seconds
      ) as sessions
    from passages p
    cross join bornes b
  )
  select
    c.cards,
    c.seconds,
    case when c.seconds > 0 then round((c.cards * 60.0) / c.seconds, 2) else null end,
    c.sessions
  from compte c;
$$;

comment on function public.review_throughput(int) is
  'Cartes par minute, déduites des écarts entre passages. Nul tant qu''on ne sait pas.';

-- L'observance se mesure contre `review_daily_counts`, posée par la migration
-- précédente : elle rend déjà un point par jour. Le plan n'est pas stocké - il se
-- recalcule à chaque rendu - donc on ne compare pas au plan d'hier mais à la
-- capacité déclarée, qui est la seule chose stable, et c'est de toute façon la
-- bonne question : « as-tu utilisé le temps que tu disais avoir ».
