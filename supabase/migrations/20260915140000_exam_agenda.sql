-- Le test de parcours, et les rendez-vous que l'étudiant déplace.
--
-- Deux besoins, et un seul d'entre eux demande une table.

-- MARK: - Ce qu'une session mesure

-- Une session de mesure pouvait être un examen blanc, et rien d'autre. Le test de parcours
-- passe par la même machinerie - `generate-mock` sait déjà produire cinq QCM et cinq questions
-- orales, il suffit de le lui demander - et se range donc dans la même table. Ce qui manquait
-- est de pouvoir les distinguer à la lecture : l'agenda doit savoir quel rendez-vous une
-- session honore, et la préparation ne leur accorde pas le même poids.
--
-- `default 'mock'` parce que tout ce qui existe est un blanc. Aucune ligne à réécrire.
alter table public.mock_sessions
  add column if not exists kind text not null default 'mock';

alter table public.mock_sessions
  drop constraint if exists mock_sessions_kind_known;

alter table public.mock_sessions
  add constraint mock_sessions_kind_known
  check (kind in ('mock', 'parcours'));

-- L'agenda demande la dernière session d'une sorte pour une épreuve. Sans cet index, c'est un
-- parcours de toutes les sessions de l'utilisateur à chaque ouverture d'une page d'examen.
create index if not exists mock_sessions_user_kind_idx
  on public.mock_sessions (user_id, exam_id, kind, finished_at desc)
  where finished_at is not null;

comment on column public.mock_sessions.kind is
  'Ce que la session mesure : un examen blanc (vingt questions, temps imparti) ou un test de parcours (cinq QCM et cinq questions orales, cinq minutes).';

-- MARK: - Les rendez-vous déplacés, et eux seuls

-- **Aucun rendez-vous n'est écrit à la création d'un examen.** Les blancs se déduisent de
-- leurs décalages, les parcours de leur cadence, et les deux se recalculent depuis la date de
-- l'épreuve à chaque lecture. Déplacer un examen d'une semaine déplace tout son agenda sans
-- qu'une ligne bouge ici, et changer la cadence n'oblige pas à réécrire l'historique de tout
-- le monde.
--
-- Ce qui se persiste est l'exception : la date que l'étudiant a choisie lui-même.
--
-- ## Pourquoi la clé porte un rang et pas une date
--
-- Une surcharge doit désigner un rendez-vous, et sa date ne peut pas le faire puisque c'est
-- précisément ce qu'on change. C'est donc son **rang dans sa série** qui l'identifie : le blanc
-- numéro 0 est celui de J-7, le parcours numéro 3 est le quatrième en partant de l'épreuve. Ce
-- rang se compte depuis l'épreuve et non depuis aujourd'hui, donc il ne bouge pas quand les
-- jours passent - c'est ce qui permet à un déplacement de survivre à la nuit.
--
-- La clé primaire est donc (utilisateur, épreuve, sorte, rang) : déplacer deux fois le même
-- rendez-vous écrase, ce qui est exactement ce qu'on veut.
create table if not exists public.exam_plan_overrides (
  user_id uuid not null references auth.users on delete cascade,
  exam_id uuid not null,
  kind text not null,
  slot int not null,
  scheduled_for date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, exam_id, kind, slot),
  constraint exam_plan_overrides_kind_known check (kind in ('mock', 'parcours')),
  -- Huit parcours et deux blancs au plus, et de la marge pour changer d'avis là-dessus sans
  -- migration. Un rang hors de ces bornes ne désigne aucun rendez-vous.
  constraint exam_plan_overrides_slot_sane check (slot between 0 and 31)
);

create index if not exists exam_plan_overrides_exam_idx
  on public.exam_plan_overrides (user_id, exam_id);

alter table public.exam_plan_overrides enable row level security;

drop policy if exists "own exam plan overrides" on public.exam_plan_overrides;
create policy "own exam plan overrides"
  on public.exam_plan_overrides
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

comment on table public.exam_plan_overrides is
  'Les rendez-vous de mesure que l''étudiant a déplacés lui-même. Le reste de l''agenda est dérivé de la date de l''épreuve et ne s''écrit nulle part.';

comment on column public.exam_plan_overrides.slot is
  'Le rang du rendez-vous dans sa série, compté depuis l''épreuve. C''est son identité : une date ne peut pas la porter, c''est ce qui change.';
