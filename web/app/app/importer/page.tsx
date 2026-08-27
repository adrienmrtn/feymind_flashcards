import { DEFAULT_SHEET_LENGTH, isSheetLength } from "@micabo/core";

import { ImportPanel } from "@/components/app/ImportPanel";
import { createClient } from "@/lib/supabase/server";

/**
 * L'import : **une zone de dépôt**, et deux échappatoires.
 *
 * C'est là que le web se sépare le plus de l'iPhone. L'app a un scanner, une caméra et un sélecteur
 * de photos, parce qu'un polycopié papier est devant soi et que le téléphone est dans la main. Le
 * web a un fichier déjà sur le disque : le geste juste est de le lâcher dans la page.
 *
 * Pas de scanner ici : un `<input capture>` sur un portable ouvre une webcam, ce qui donne une
 * photo de polycopié inexploitable. Mieux vaut ne pas proposer que proposer mal.
 *
 * La longueur de fiche part de **ce que le profil a retenu** - la colonne que l'iPhone écrit aussi.
 */
export default async function ImportPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = user
    ? await supabase.from("profiles").select("sheet_length").eq("id", user.id).maybeSingle()
    : { data: null };

  const initialLength = isSheetLength(profile?.sheet_length)
    ? profile.sheet_length
    : DEFAULT_SHEET_LENGTH;

  return (
    <>
      <header>
        <p className="eyebrow text-ink-tertiary">Nouveau cours</p>
        <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">
          Qu&apos;est-ce qu&apos;on fiche ?
        </h1>
      </header>

      <ImportPanel initialLength={initialLength} />
    </>
  );
}
