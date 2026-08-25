import Link from "next/link";
import { notFound } from "next/navigation";

import { courseAccent, entitlement, resolveEmoji } from "@micabo/core";

import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { getCourse, listCards } from "@/lib/data/courses";

/**
 * **La fiche : l'écran du cours.**
 *
 * Le seul endroit du produit où l'on lit vraiment — les autres écrans sont des listes. Elle a donc
 * droit à sa colonne de lecture et à rien d'autre : le texte posé à même le papier, les objets dans
 * des blocs, et l'en-tête qui porte la couleur du cours dans sa tuile plutôt que dans un bandeau.
 *
 * Et **elle s'imprime**. C'est la seconde signature du site, et ce n'est pas un gadget : une fiche
 * *est* une page, elle se relit sur papier la veille au soir, et la feuille de style d'impression
 * retire tout ce qui sert à naviguer.
 */
export default async function CourseSheetPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const course = await getCourse(id);
  if (!course) notFound();

  const cards = await listCards(id);
  const tint = course.accent_hex ?? courseAccent(course.id);

  // Le droit est lu par la fonction du noyau, jamais par un `if` écrit ici. Elle rend « ouvert »
  // pour tout le monde tant que l'encaissement n'existe pas — voir `entitlement.ARMED`.
  const right = entitlement.resolve();
  const { readable, locked } = entitlement.splitSheet(course.blocks, right);

  return (
    <article>
      <header className="flex items-start gap-4" data-print="keep">
        <span
          aria-hidden
          className="flex h-14 w-14 shrink-0 items-center justify-center rounded-tile text-[26px]"
          style={{ backgroundColor: `${tint}1f` }}
        >
          {resolveEmoji(course.emoji, course.subject, course.title)}
        </span>

        <div className="min-w-0 flex-1">
          <p className="eyebrow text-ink-tertiary">
            {[course.subject, readingTime(course.context_text)].filter(Boolean).join(" · ")}
          </p>
          <h1 className="mt-1.5 text-[30px] font-bold leading-tight text-ink">{course.title}</h1>
        </div>
      </header>

      {course.summary ? (
        <p className="mt-6 max-w-reading text-[15.75px] leading-relaxed text-ink-secondary">
          {course.summary}
        </p>
      ) : null}

      {/* L'action du cours, et **la première tant qu'il n'y a pas de cartes** : c'est la règle de
          l'app, et elle vaut ici. Les cartes ne sont pas produites au passage de l'import ; elles
          se demandent depuis la fiche, quand on l'a lue. */}
      <div className="mt-7 flex flex-wrap gap-2.5" data-print="hide">
        {cards.length === 0 ? (
          <Link
            href={`/app/c/${course.id}/cartes` as never}
            className="pressable rounded-button bg-ink px-5 py-3 text-[15px] font-semibold text-on-ink"
          >
            Créer des cartes
          </Link>
        ) : (
          <Link
            href={`/app/c/${course.id}/cartes` as never}
            className="pressable rounded-button bg-surface px-5 py-3 text-[15px] font-semibold text-ink paper"
          >
            {cards.length} carte{cards.length > 1 ? "s" : ""}
          </Link>
        )}
      </div>

      <div className="mt-10 max-w-reading">
        <SheetBlocks blocks={readable} tint={tint} />

        {locked.length > 0 ? <LockedTail count={locked.length} /> : null}
      </div>

      {course.blocks.length === 0 ? (
        <p className="mt-8 rounded-group bg-caution-soft px-5 py-4 text-[14px] text-ink-reading">
          Ce cours n&apos;a pas de fiche lisible. Il a peut-être été importé avant qu&apos;elle
          puisse être écrite — le texte d&apos;origine est conservé, donc elle peut être refaite.
        </p>
      ) : null}
    </article>
  );
}

/**
 * La fin d'une fiche, pour qui n'est pas abonné.
 *
 * Les blocs restants ne sont **pas** rendus ici, à la différence de l'app : sur le web, un texte
 * flouté reste dans le document, donc il se lit dans le code source et se copie. Le flou de l'app
 * est acceptable parce qu'un IPA ne se lit pas avec le clic droit ; ici, il faudrait envoyer au
 * navigateur ce qu'on prétend cacher. On annonce donc ce qui reste, sans l'envoyer.
 */
function LockedTail({ count }: { count: number }) {
  const percent = entitlement.lockedSheetPercent();

  return (
    <div className="mt-8 rounded-group bg-surface-muted p-7 text-center" data-print="hide">
      <span
        aria-hidden
        className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-ink text-on-ink"
      >
        <svg viewBox="0 0 20 20" className="h-5 w-5" fill="currentColor">
          <path d="M10 1.5a3.5 3.5 0 0 0-3.5 3.5v2H6a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2v-6a2 2 0 0 0-2-2h-.5V5A3.5 3.5 0 0 0 10 1.5zm-2 3.5a2 2 0 1 1 4 0v2H8V5z" />
        </svg>
      </span>
      <p className="mt-3.5 text-[16.5px] font-bold text-ink">La suite de la fiche est dans Pro</p>
      <p className="mx-auto mt-1.5 max-w-[38ch] text-[13px] leading-relaxed text-ink-secondary">
        Il te reste {percent} % de ce cours à lire — {count} bloc{count > 1 ? "s" : ""} — et tous
        les suivants à importer.
      </p>
    </div>
  );
}

/** Durée de lecture annoncée, sur une base de 200 mots par minute, comme dans l'app. */
function readingTime(text: string): string {
  const words = text.split(/\s+/).filter(Boolean).length;
  return `${Math.max(1, Math.round(words / 200))} min de lecture`;
}
