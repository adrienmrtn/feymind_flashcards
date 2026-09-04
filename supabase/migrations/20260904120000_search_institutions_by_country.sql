-- Filter institution search by the student's country.
-- Applied remotely via Supabase MCP; kept here for reproducibility.

drop function if exists public.search_institutions(text, int);

create or replace function public.search_institutions(
  query text,
  result_limit int default 12,
  country text default null
)
returns table (
  id text,
  name text,
  country_code text,
  kind text,
  score real
)
language sql
stable
security invoker
set search_path = public
as $$
  with q as (
    select
      lower(trim(query)) as needle,
      case
        when country is null or length(trim(country)) = 0 then null
        when upper(trim(country)) in ('UK') then 'GB'
        else upper(trim(country))
      end as iso
  )
  select
    i.id,
    i.name,
    i.country_code,
    i.kind,
    greatest(
      similarity(lower(i.name), q.needle),
      case when lower(i.name) like q.needle || '%' then 0.9 else 0 end,
      case when lower(i.name) like '%' || q.needle || '%' then 0.6 else 0 end,
      coalesce((
        select max(
          greatest(
            similarity(lower(a), q.needle),
            case when lower(a) like q.needle || '%' then 0.85 else 0 end,
            case when lower(a) like '%' || q.needle || '%' then 0.5 else 0 end
          )
        )
        from unnest(i.aliases) a
      ), 0)
    )::real as score
  from public.institutions i, q
  where length(q.needle) >= 2
    and (q.iso is null or i.country_code = q.iso)
    and (
      lower(i.name) like '%' || q.needle || '%'
      or i.name % q.needle
      or exists (
        select 1 from unnest(i.aliases) a
        where lower(a) like '%' || q.needle || '%' or a % q.needle
      )
    )
  order by
    score desc,
    case i.kind
      when 'grande_ecole' then 0
      when 'university' then 1
      when 'lycee' then 2
      else 3
    end,
    char_length(i.name) asc
  limit greatest(1, least(coalesce(result_limit, 12), 30));
$$;

grant execute on function public.search_institutions(text, int, text) to anon, authenticated;
