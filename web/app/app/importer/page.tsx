import { DEFAULT_SHEET_LENGTH, isSheetLength } from "@micabo/core";

import { ImportPanel } from "@/components/app/ImportPanel";
import { SecondCourseCard } from "@/components/app/SecondCourseCard";
import { canImportNow } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";

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
  const [profile, canImport] = await Promise.all([readProfile(), canImportNow()]);

  const initialLength = isSheetLength(profile?.sheet_length)
    ? profile.sheet_length
    : DEFAULT_SHEET_LENGTH;

  return (
    <>
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">Importer</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {canImport ? "Relis d'abord, puis écris la fiche." : "Le premier cours est offert."}
        </p>
      </header>

      {canImport ? <ImportPanel initialLength={initialLength} /> : <SecondCourseCard />}
    </>
  );
}
