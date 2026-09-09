-- D'où l'étudiant part sur cette épreuve.
--
-- La seule chose que le plan a besoin de savoir et qu'il ne peut pas mesurer.
-- Le journal de révision dit ce qui a été travaillé **dans l'app** ; il ne sait
-- rien d'un cours suivi en amphi toute l'année, ni d'un chapitre découvert la
-- veille. Deux étudiants avec les mêmes cartes neuves peuvent être à des
-- distances très différentes de leur épreuve.
--
-- Trois réponses, parce qu'au-delà personne ne sait se situer honnêtement, et
-- parce que chacune change le plan d'un cran de passages :
--
--   cold  - « je découvre »      : un passage de plus par carte
--   seen  - « j'ai déjà vu »     : le plan normal
--   solid - « je révise »        : un passage de moins
--
-- C'est une **question**, pas une mesure, donc elle est facultative : sans
-- réponse, `seen` s'applique et le plan est celui d'avant.
alter table public.exams
  add column if not exists starting_point text not null default 'seen';

alter table public.exams
  drop constraint if exists exams_starting_point_known;

alter table public.exams
  add constraint exams_starting_point_known
  check (starting_point in ('cold', 'seen', 'solid'));

comment on column public.exams.starting_point is
  'D''où part l''étudiant : cold, seen, solid. Décale l''intensité d''un cran.';
