import { DEFAULT_SHEET_LENGTH, isSheetLength } from "@micabo/core";

import { ImportPanel } from "@/components/app/ImportPanel";

/**
 * L'écriture d'une fiche appelle le modèle : sans ça, Vercel coupe trop tôt.
 *
 * Le plafond est celui du plan, et non un chiffre choisi : une vidéo sans sous-titres part
 * chez Gemini, qui la regarde. Deux minutes ne suffisaient pas, et une action coupée en
 * plein appel rendait « This page couldn't load » sur une lecture qui aboutissait.
 */
export const maxDuration = 300;
import { SecondCourseCard } from "@/components/app/SecondCourseCard";
import { canImportNow } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";
import { getTranslator } from "@/lib/i18n/server";

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
  const [{ t }, profile, canImport] = await Promise.all([
    getTranslator(),
    readProfile(),
    canImportNow(),
  ]);

  const initialLength = isSheetLength(profile?.sheet_length)
    ? profile.sheet_length
    : DEFAULT_SHEET_LENGTH;

  return (
    <>
      <header>
        <h1 className="page-title">
          {t("nav.import")}
        </h1>
        <p className="page-lead">
          {canImport ? t("app.import.lead.canImport") : t("app.import.lead.firstFree")}
        </p>
      </header>

      {canImport ? (
        <div data-tour="importer-panneau">
          <ImportPanel initialLength={initialLength} />
        </div>
      ) : (
        <SecondCourseCard />
      )}
    </>
  );
}
