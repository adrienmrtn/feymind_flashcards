import Link from "next/link";

import { DeckPanel } from "@/components/app/DeckPanel";
import { SecondCourseCard } from "@/components/app/SecondCourseCard";
import { canImportNow } from "@/lib/data/entitlement";
import { getTranslator } from "@/lib/i18n/server";

/** Un versement Anki peut être long : les cartes partent par paquets. */
export const maxDuration = 120;

/**
 * **Un paquet, sans cours.**
 *
 * L'import demande un document et rend une fiche. Ici il n'y a pas de document : un
 * paquet vide qu'on remplit à la main, ou un fichier Anki qu'on recopie. Rien ne passe
 * par le modèle.
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
          href={"/app/paquets" as never}
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
          {t("nav.decks")}
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
