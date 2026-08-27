-- Suppression du compte, **par l'étudiant lui-même**.
--
-- Tout ce qui lui appartient référence `auth.users` avec `on delete cascade` : profil,
-- cours, cartes, historique, examens, amitiés, droit Pro. Effacer la ligne Auth
-- emporte le reste. L'adresse e-mail redevient libre : une inscription suivante
-- crée un nouvel `id`, le déclencheur `handle_new_user` pose un profil vide, et
-- c'est comme si le compte venait d'être créé.
--
-- La fonction est `security definer` parce que `authenticated` n'a pas le droit
-- d'écrire dans `auth.users`. Elle ne vise **que** `auth.uid()` : on ne peut pas
-- s'en servir pour effacer un autre compte. `anon` n'a pas le droit de l'appeler.

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid;
begin
  uid := auth.uid();
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
