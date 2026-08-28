-- La note visée, au point près. L'intensité (passages) s'en déduit :
-- 10–13 léger, 14–17 standard, au-delà intensif.
alter table public.exams
  add column if not exists target_score smallint not null default 15;

update public.exams
set target_score = case intensity
  when 'light' then 12
  when 'intense' then 19
  else 15
end
where target_score = 15;

alter table public.exams
  drop constraint if exists exams_target_score_range;

alter table public.exams
  add constraint exams_target_score_range
  check (target_score between 10 and 20);

comment on column public.exams.target_score is
  'Note visée, sur une droite 10–20. Le libellé suit le bulletin du pays.';
