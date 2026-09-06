import Link from "next/link";

import { DeckPanel } from "@/components/app/DeckPanel";
import { SecondCourseCard } from "@/components/app/SecondCourseCard";
import { canImportNow } from "@/lib/data/entitlement";
import { getTranslator } from "@/lib/i18n/server";

/** Coller du texte fait écrire les premières cartes : c'est le modèle qui répond, pas la base. */
export const maxDuration = 120;

/**
 * **Un paquet, sans cours.**
 *
 * L'import demande un document et rend une fiche. Ici il n'y a pas de document : il y a du
 * vocabulaire, des dates, des formules - des choses déjà comprises qu'il faut retenir. Un
 * paquet Anki entre par le même écran, parce que c'est le même objet : des cartes que
 * personne n'a besoin d'écrire.
 *
 * Le paquet occupe une place de cours, donc il passe la même porte : sans ça, le gratuit
 * s'ouvrirait en grand par un chemin qui ne s'appelle pas « importer ».
 */
export default async function NewDeckPage() {
  const [{ t }, canImport] = await Promise.all([getTranslator(), canImportNow()]);

  return (
    <>
      <header>
        <Link
          href={"/app/importer" as never}
          className="inline-flex items-center gap-1.5 text-[13.5px] text-ink-tertiary"
        >
          <svg
            aria-hidden
            viewBox="0 0 20 20"
            className="h-3.5 w-3.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M12 4l-6 6 6 6" />
          </svg>
          {t("nav.import")}
        </Link>

        <div className="mt-3">
          <h1 className="text-lg font-semibold tracking-tight text-foreground">
            {t("app.deck.title")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">{t("app.deck.lead")}</p>
        </div>
      </header>

      <div className="mt-7">{canImport ? <DeckPanel /> : <SecondCourseCard />}</div>
    </>
  );
}
