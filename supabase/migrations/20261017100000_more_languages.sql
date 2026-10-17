-- Les langues des nouveaux marchés : l'Europe entière, le Moyen-Orient, le Brésil et
-- l'Amérique latine.
--
-- Une langue de cours n'est plus toujours deux lettres : le portugais du Brésil (`pt-BR`)
-- et l'espagnol d'Amérique latine (`es-419`) s'écrivent avec leur région, parce qu'on n'y
-- écrit pas les mêmes fiches qu'à Lisbonne ou à Madrid.

alter table public.courses
  drop constraint if exists courses_language_check;

alter table public.courses
  add constraint courses_language_check
  check (language is null or language ~ '^[a-z]{2}(-[A-Za-z0-9]{2,3})?$');

alter table public.profiles
  drop constraint if exists profiles_sheet_language_check;

alter table public.profiles
  add constraint profiles_sheet_language_check
  check (
    sheet_language is null
    or sheet_language in (
      'fr', 'en', 'de', 'it', 'es', 'es-419', 'pt', 'pt-BR', 'cs', 'sk', 'nl', 'el', 'hu', 'pl',
      'ro', 'sv', 'da', 'fi', 'et', 'hr', 'sl', 'sr', 'bg', 'ru', 'tr', 'ar'
    )
  );
