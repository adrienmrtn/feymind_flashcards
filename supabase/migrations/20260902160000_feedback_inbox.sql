-- Les retours des étudiants.
--
-- Avant, « Faire un retour » ouvrait le courriel de l'étudiant. Le message
-- s'écrit ici, et seul `team@micabo.app` le lit dans l'app (`/app/retours`).
-- L'étudiant n'a plus de client mail à ouvrir.

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  kind text not null check (kind in ('bug', 'idea')),
  message text not null,
  source text not null default 'web' check (source in ('web', 'ios')),
  -- Instantané au moment de l'envoi : le cloisonnement du profil interdit de
  -- relire le nom des autres, et l'inbox a tout de même besoin d'un qui.
  author_label text not null default '',
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists feedback_created_idx on public.feedback (created_at desc);
create index if not exists feedback_unread_idx
  on public.feedback (created_at desc)
  where read_at is null;

-- MARK: - Auteur

create or replace function public.feedback_fill_author()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  label text;
begin
  -- L'identité vient de la session, pas du client. Un `user_id` omis ou
  -- inventé ne passe pas : la colonne NOT NULL est vérifiée après ce BEFORE.
  new.user_id := (select auth.uid());

  select coalesce(
    nullif(btrim(p.display_name), ''),
    nullif(p.username, ''),
    'Compte'
  )
  into label
  from public.profiles p
  where p.id = new.user_id;

  new.author_label := coalesce(label, 'Compte');
  return new;
end;
$$;

drop trigger if exists feedback_fill_author on public.feedback;
create trigger feedback_fill_author
  before insert on public.feedback
  for each row
  execute function public.feedback_fill_author();

revoke all on function public.feedback_fill_author() from public, anon, authenticated;

-- MARK: - Plafond

-- Combien de retours aujourd'hui (UTC). `security definer` : l'étudiant n'a
-- pas de politique de lecture sur les lignes des autres, et un `count` en
-- politique d'insert lirait 0 sans ça.
create or replace function public.feedback_today_count()
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.feedback
  where user_id = (select auth.uid())
    and created_at >= (timezone('utc', now()))::date;
$$;

revoke all on function public.feedback_today_count() from public, anon;
grant execute on function public.feedback_today_count() to authenticated;

-- MARK: - Cloisonnement
--
-- Écrire le sien. Lire le sien (export RGPD) **ou** tout lire si l'e-mail
-- de session est `team@micabo.app` — c'est l'adresse Auth, pas une métadonnée
-- que l'étudiant peut éditer. Marquer lu : la boîte seulement.

alter table public.feedback enable row level security;

drop policy if exists "Retours : écrire le sien" on public.feedback;
create policy "Retours : écrire le sien"
  on public.feedback for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and kind in ('bug', 'idea')
    and source in ('web', 'ios')
    and char_length(btrim(message)) between 1 and 4000
    and public.feedback_today_count() < 5
  );

drop policy if exists "Retours : lire" on public.feedback;
create policy "Retours : lire"
  on public.feedback for select to authenticated
  using (
    (select auth.uid()) = user_id
    or lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'team@micabo.app'
  );

drop policy if exists "Retours : marquer lu" on public.feedback;
create policy "Retours : marquer lu"
  on public.feedback for update to authenticated
  using (
    lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'team@micabo.app'
  )
  with check (
    lower(coalesce((select auth.jwt() ->> 'email'), '')) = 'team@micabo.app'
  );

revoke all on table public.feedback from public, anon;
revoke delete, truncate, references, trigger on table public.feedback from authenticated;
grant select, insert on table public.feedback to authenticated;
-- Marquer lu : uniquement `read_at`. Le reste de la ligne reste figé.
grant update (read_at) on table public.feedback to authenticated;

comment on table public.feedback is
  'Bugs et idées envoyés depuis l''app. Lecture de toutes les lignes réservée à team@micabo.app.';
