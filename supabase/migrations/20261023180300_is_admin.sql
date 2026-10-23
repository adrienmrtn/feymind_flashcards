-- **L'équipe se reconnaît à son compte, pas à son jeton.**
--
-- La boîte des retours (`feedback_inbox`) et le journal des événements (`app_events`)
-- s'ouvraient en entier à qui présentait un jeton dont la revendication `email` valait
-- `team@micabo.app`. C'est l'adresse que GoTrue a écrite dans le jeton, pas une métadonnée
-- que l'étudiant édite — mais c'est l'adresse **déclarée**, confirmée ou non : selon les
-- réglages d'Auth, une inscription par mot de passe à cette adresse, jamais confirmée, ou un
-- changement d'adresse en attente, suffisait à porter la revendication. `is_lifetime_pro`
-- (`lifetime_pro_gate`) avait déjà fait le bon choix : relire `auth.users`, et n'accepter
-- qu'une adresse confirmée.
--
-- `security definer`, parce qu'`authenticated` ne lit pas `auth.users` ; elle ne répond que
-- sur l'appelant (`auth.uid()`), donc l'exposer en RPC ne révèle rien qu'il ne sache déjà.
-- Elle reste exécutable par `authenticated` : une politique s'évalue avec les droits de
-- celui qui interroge.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users u
    where u.id = (select auth.uid())
      and u.email_confirmed_at is not null
      and lower(trim(u.email)) = 'team@micabo.app'
  );
$$;

revoke execute on function public.is_admin() from anon, public;
grant execute on function public.is_admin() to authenticated;

-- MARK: - Les retours

drop policy if exists "Retours : lire" on public.feedback;
create policy "Retours : lire"
  on public.feedback for select to authenticated
  using (
    (select auth.uid()) = user_id
    or (select public.is_admin())
  );

drop policy if exists "Retours : marquer lu" on public.feedback;
create policy "Retours : marquer lu"
  on public.feedback for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- MARK: - Les événements

drop policy if exists "Événements : lire" on public.app_events;
create policy "Événements : lire"
  on public.app_events for select to authenticated
  using ((select public.is_admin()));
