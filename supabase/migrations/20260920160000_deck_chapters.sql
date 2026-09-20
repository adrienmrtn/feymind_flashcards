-- Les chapitres d'un deck.
--
-- C'est la table qui manquait, et son absence bloquait tout le reste. Jusqu'ici, les
-- « chapitres » d'une fiche étaient une lecture des blocs de type `heading` faite au
-- moment de l'afficher : la matière était là — 1 205 blocs `heading` sur 143 fiches, huit
-- titres et demi par cours en moyenne — mais elle n'avait ni identité, ni progression, ni
-- cartes rattachées.
--
-- La preuve que ça bloquait déjà est en base : `exams.chapter_ids` existe dans ce schéma
-- depuis septembre, et les trente et un examens enregistrés portent tous un tableau vide.
-- La colonne a été prévue pour une entité qui n'avait jamais été créée.
--
-- Trois choses en dépendent, et aucune ne tient sans cette table : un pourcentage de
-- connaissance par partie du cours, une révision qui ne porte que sur une partie, et un
-- ordre d'introduction des cartes neuves qui suit le plan plutôt que la date d'import.
--
-- **Cette migration est strictement additive.** Le site continue de lire `courses.sheet`
-- et `flashcards` exactement comme avant : aucune colonne n'est retirée, aucune contrainte
-- n'est durcie, et `flashcards.chapter_id` est nullable. Un client qui ignore les
-- chapitres se comporte comme aujourd'hui.

create table if not exists public.chapters (
  -- Fourni par l'app, comme pour les cours et les dossiers : c'est l'identifiant SwiftData
  -- du chapitre. C'est ce qui permet à l'iPhone de découper un deck hors ligne et de le
  -- synchroniser ensuite sans attendre qu'un identifiant serveur redescende.
  id uuid primary key,
  user_id uuid not null references auth.users on delete cascade,
  course_id uuid not null references public.courses on delete cascade,

  -- Le rang dans le plan, à partir de zéro. Il ne se modifie pas depuis l'interface :
  -- c'est lui qui commande l'ordre d'introduction des cartes neuves, et un plan qu'on
  -- réordonne est un plan dont l'ordre ne veut plus rien dire.
  position integer not null default 0,

  title text not null default '',

  -- Les blocs de ce chapitre, au même format que `courses.sheet` : `{"blocks": [...]}`.
  -- Le titre reste dans les blocs, en tête ; `title` en est la copie dénormalisée, pour
  -- les listes et les sommaires qui n'ont pas à décoder le JSON pour afficher un plan.
  sheet jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Le chapitre dont une carte est née. `null` partout ailleurs, et ça le restera : une
-- carte importée d'Anki, écrite à la main, ou produite avant la refonte n'a pas de
-- chapitre.
--
-- `on delete set null` et non `cascade` : une carte appartient au deck, pas au chapitre.
-- Un chapitre supprimé par une régénération ne doit pas emporter l'historique de
-- répétition espacée des cartes qu'il portait — elles retombent non classées, ce que
-- l'écran du deck sait montrer.
alter table public.flashcards
  add column if not exists chapter_id uuid references public.chapters on delete set null;

-- Le plan d'un deck, lu dans l'ordre. C'est la requête de l'écran du deck.
create index if not exists chapters_course_position_idx
  on public.chapters (course_id, position)
  where deleted_at is null;

-- La descente de synchronisation, qui ne demande que ce qui a bougé.
create index if not exists chapters_user_updated_idx
  on public.chapters (user_id, updated_at desc);

-- Les cartes d'un chapitre, pour son pourcentage de connaissance.
create index if not exists flashcards_chapter_idx
  on public.flashcards (chapter_id)
  where deleted_at is null and chapter_id is not null;

-- Deux chapitres d'un même deck ne partagent pas un rang. La contrainte est partielle :
-- un chapitre supprimé libère sa place, sinon une régénération échouerait sur le plan
-- qu'elle vient de remplacer.
create unique index if not exists chapters_course_position_unique
  on public.chapters (course_id, position)
  where deleted_at is null;

-- MARK: - L'horodatage

/* `updated_at` est tenu par la base et non par le client.
 *
 * La synchronisation descend « ce qui a changé depuis » : une horloge d'appareil en avance
 * de deux minutes suffirait à faire manquer des lignes à tous les autres appareils du même
 * compte, et personne ne s'en apercevrait avant d'avoir perdu un chapitre. */
create or replace function public.chapters_touch()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists chapters_touch_trigger on public.chapters;
create trigger chapters_touch_trigger
  before insert or update on public.chapters
  for each row execute function public.chapters_touch();

-- MARK: - Qui voit quoi

alter table public.chapters enable row level security;

drop policy if exists "Chapitres : les siens" on public.chapters;
create policy "Chapitres : les siens"
  on public.chapters for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
