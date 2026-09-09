-- Le mode examen devient le cœur du produit.
--
-- Trois choses manquaient pour qu'un plan soit autre chose qu'une moyenne :
-- le temps réellement disponible chaque jour, ce que l'épreuve demande
-- (son type, les formats à travailler), et de quoi savoir sur quelles
-- cartes l'étudiant se trompe. Rien ici n'est un réglage de confort :
-- chacune de ces colonnes entre dans le calcul du plan.

-- MARK: - Disponibilités

-- Sept entiers, lundi en premier, en minutes. Nul signifie « le rythme
-- quotidien s'applique tous les jours », c'est-à-dire le comportement
-- d'avant : personne n'a à remplir ce réglage pour que l'app marche.
alter table public.profiles
  add column if not exists weekly_minutes smallint[];

alter table public.profiles
  drop constraint if exists profiles_weekly_minutes_shape;

alter table public.profiles
  add constraint profiles_weekly_minutes_shape
  check (
    weekly_minutes is null
    or (
      array_length(weekly_minutes, 1) = 7
      and 0 <= all (weekly_minutes)
      and 600 >= all (weekly_minutes)
    )
  );

comment on column public.profiles.weekly_minutes is
  'Minutes disponibles par jour, lundi en premier. Nul = le rythme quotidien partout.';

-- Une exception écrase la ligne hebdomadaire pour une date. Zéro minute
-- est un jour off : c'est le cas le plus fréquent, et c'est pour lui que
-- la table existe.
create table if not exists public.availability_exceptions (
  user_id uuid not null references auth.users on delete cascade,
  day date not null,
  minutes smallint not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.availability_exceptions
  drop constraint if exists availability_exceptions_minutes_range;

alter table public.availability_exceptions
  add constraint availability_exceptions_minutes_range
  check (minutes between 0 and 600);

create index if not exists availability_exceptions_user_day_idx
  on public.availability_exceptions (user_id, day);

alter table public.availability_exceptions enable row level security;

drop policy if exists "own availability exceptions" on public.availability_exceptions;
create policy "own availability exceptions"
  on public.availability_exceptions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- MARK: - Ce que l'épreuve demande

-- Le type ne change pas l'algorithme, il change les formats proposés par
-- défaut et le libellé. Un oral ne se prépare pas avec des QCM.
alter table public.exams
  add column if not exists kind text not null default 'exam';

alter table public.exams
  drop constraint if exists exams_kind_known;

alter table public.exams
  add constraint exams_kind_known
  check (kind in ('exam', 'midterm', 'final', 'quiz', 'oral', 'mock'));

comment on column public.exams.kind is
  'Type d''épreuve. Décide des formats proposés, pas de la replanification.';

-- Les formats d'entraînement cochés. Vide signifie « tout ce que le cours
-- contient », donc l'absence de choix ne prive de rien.
alter table public.exams
  add column if not exists formats text[] not null default '{}';

comment on column public.exams.formats is
  'Formats retenus pour cette épreuve : basic, choice, cloze. Vide = tous.';

-- Les chapitres au programme, par identifiant de bloc de fiche. Vide
-- signifie « tout le cours ».
alter table public.exams
  add column if not exists chapter_ids text[] not null default '{}';

comment on column public.exams.chapter_ids is
  'Blocs de fiche au programme. Vide = le cours entier.';

-- MARK: - Sur quoi l'étudiant se trompe

-- `review_logs` est en ajout seul et ne se lit que par son auteur. Sans
-- cette fonction, savoir qu'une carte est ratée une fois sur trois
-- demanderait de rapatrier tout l'historique dans le navigateur.
--
-- Sécurité par l'appelant : la politique de `review_logs` s'applique
-- telle quelle, donc la fonction ne peut rien montrer de plus que ce que
-- l'étudiant voit déjà.
create or replace function public.card_difficulty(since_days int default 120)
returns table (
  card_id uuid,
  reviews bigint,
  again_count bigint,
  hard_count bigint,
  last_rating int,
  last_reviewed_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    l.card_id,
    count(*) as reviews,
    count(*) filter (where l.rating = 1) as again_count,
    count(*) filter (where l.rating = 2) as hard_count,
    (array_agg(l.rating order by l.reviewed_at desc))[1] as last_rating,
    max(l.reviewed_at) as last_reviewed_at
  from public.review_logs l
  where l.user_id = auth.uid()
    and l.card_id is not null
    and l.reviewed_at >= now() - make_interval(days => greatest(since_days, 1))
  group by l.card_id
  having count(*) >= 2;
$$;

comment on function public.card_difficulty(int) is
  'Par carte : passages, ratés, difficiles. Sert à faire remonter ce qui résiste.';

-- MARK: - Le volume révisé par jour, pour les statistiques

-- Le tableau de bord montre une courbe sur plusieurs mois. La compter
-- côté client demanderait de rapatrier chaque ligne de révision ; ici
-- Postgres rend un point par jour.
create or replace function public.review_daily_counts(since_days int default 120)
returns table (
  day date,
  passes bigint,
  again_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    (l.reviewed_at at time zone 'UTC')::date as day,
    count(*) as passes,
    count(*) filter (where l.rating = 1) as again_count
  from public.review_logs l
  where l.user_id = auth.uid()
    and l.reviewed_at >= now() - make_interval(days => greatest(since_days, 1))
  group by 1
  order by 1;
$$;

comment on function public.review_daily_counts(int) is
  'Un point par jour : passages et ratés. Alimente les statistiques.';
