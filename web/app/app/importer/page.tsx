import { ImportPanel } from "@/components/app/ImportPanel";

/**
 * L'import, **au clavier et au glisser-déposer.**
 *
 * C'est là que le web se sépare le plus de l'iPhone. L'app a un scanner de documents, une caméra
 * et un sélecteur de photos, parce qu'un polycopié papier est devant soi et que le téléphone est
 * dans la main. Le web a un fichier déjà sur le disque, un presse-papier plein, et un lien de
 * vidéo dans un onglet — et il a un vrai clavier.
 *
 * Trois entrées, donc, et pas de scanner : un `<input capture>` sur un portable ouvre une webcam,
 * ce qui donne une photo de polycopié inexploitable. Mieux vaut ne pas proposer que proposer mal.
 */
export default function ImportPage() {
  return (
    <>
      <header>
        <p className="eyebrow text-ink-tertiary">Nouveau cours</p>
        <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">
          Qu&apos;est-ce qu&apos;on fiche ?
        </h1>
        <p className="mt-3 max-w-reading text-[15px] leading-relaxed text-ink-secondary">
          Micabo lit le document, en écrit la fiche, et te la montre. Les cartes viennent après, si
          tu les veux.
        </p>
      </header>

      <ImportPanel />
    </>
  );
}
