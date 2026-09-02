-- Resserrer les droits déjà posés par `feedback_inbox` : l'identité d'écriture
-- vient de la session, et l'API ne peut plus toucher que `read_at`.

create or replace function public.feedback_fill_author()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  label text;
begin
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

revoke all on function public.feedback_fill_author() from public, anon, authenticated;

revoke all on table public.feedback from public, anon;
revoke delete, truncate, references, trigger on table public.feedback from authenticated;
revoke update on table public.feedback from authenticated;
grant select, insert on table public.feedback to authenticated;
grant update (read_at) on table public.feedback to authenticated;
