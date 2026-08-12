-- Institutions directory for onboarding school autocomplete.
-- Applied remotely via Supabase MCP; kept here for reproducibility.

create extension if not exists pg_trgm;

create table if not exists public.institutions (
  id text primary key,
  name text not null,
  country_code text not null default '',
  kind text not null check (kind in ('university', 'grande_ecole', 'lycee', 'other')),
  aliases text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists institutions_name_trgm on public.institutions using gin (name gin_trgm_ops);
create index if not exists institutions_country_idx on public.institutions (country_code);
create index if not exists institutions_kind_idx on public.institutions (kind);

alter table public.institutions enable row level security;

drop policy if exists "Institutions are publicly readable" on public.institutions;
create policy "Institutions are publicly readable"
  on public.institutions
  for select
  to anon, authenticated
  using (true);

create or replace function public.search_institutions(query text, result_limit int default 12)
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
    select lower(trim(query)) as needle
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
    case i.country_code when 'FR' then 0 else 1 end,
    case i.kind
      when 'grande_ecole' then 0
      when 'university' then 1
      when 'lycee' then 2
      else 3
    end,
    char_length(i.name) asc
  limit greatest(1, least(coalesce(result_limit, 12), 30));
$$;

grant execute on function public.search_institutions(text, int) to anon, authenticated;
