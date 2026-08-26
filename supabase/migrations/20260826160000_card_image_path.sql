-- Le schéma d'une carte à occlusion. Les zones (mask_*) existent déjà ;
-- l'image, elle, restait sur le téléphone. Le web la pose ici, en data URL
-- JPEG, partagée par les cartes d'un même groupe.

alter table public.flashcards
  add column if not exists image_path text;

comment on column public.flashcards.image_path is
  'Schéma d''une carte à occlusion (data URL ou chemin Storage).';
