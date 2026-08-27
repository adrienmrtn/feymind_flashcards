-- Classement des cartes passées cette semaine, entre amis.
--
-- `review_logs` n'est lisible que par son auteur. Sans ce RPC, l'accueil
-- ne pourrait pas comparer les passages. On ne sort que le cercle
-- (moi + amitiés acceptées), et le volume de la semaine, rien d'autre.

create or replace function public.week_review_ranking()
returns table (
  user_id uuid,
  username text,
  passes bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select auth.uid() as id
  ),
  circle as (
    select me.id as user_id
    from me
    where me.id is not null
    union
    select case
      when f.requester_id = me.id then f.addressee_id
      else f.requester_id
    end
    from public.friendships f
    cross join me
    where f.status = 'accepted'
      and (f.requester_id = me.id or f.addressee_id = me.id)
  ),
  week_start as (
    select date_trunc(
      'week',
      timezone('Europe/Paris', now())
    ) at time zone 'Europe/Paris' as start_at
  )
  select
    c.user_id,
    d.username,
    count(l.id)::bigint as passes
  from circle c
  join public.directory d on d.id = c.user_id
  left join public.review_logs l
    on l.user_id = c.user_id
    and l.reviewed_at >= (select start_at from week_start)
  group by c.user_id, d.username
  order by passes desc, d.username asc nulls last
$$;

revoke all on function public.week_review_ranking() from public, anon;
grant execute on function public.week_review_ranking() to authenticated;
