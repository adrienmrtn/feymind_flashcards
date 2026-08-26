import Link from "next/link";

import {
  DEFAULT_DAILY_MINUTES,
  courseAccent,
  dailyLimits,
  resolveEmoji,
  studyCounts,
} from "@micabo/core";

import { listAllCards, listCourses } from "@/lib/data/courses";

/**
 * **Cours : l'écran d'ouverture du web.**
 *
 * L'iPhone ouvre sur Réviser, et c'est juste là-bas — on sort son téléphone dans une file
 * d'attente, et le bouton de session doit être sous le pouce. On s'assied devant un écran pour
 * travailler, et ce qu'on veut alors est l'étagère : ce qu'on a importé, ce qu'on a produit.
 *
 * Le compte de cartes dues est quand même là, en haut, mais comme **une ligne et pas comme une
 * page** : c'est un rappel, pas la destination.
 */
export default async function CoursesPage() {
  const [courses, cards] = await Promise.all([listCourses(), listAllCards()]);

  const counts = studyCounts(
    cards.map((card) => ({
      id: card.id,
      state: card.state,
      dueDate: new Date(card.due_date),
      position: card.position,
      createdAt: new Date(card.created_at),
      isSuspended: card.is_suspended,
    })),
    { limits: dailyLimits(DEFAULT_DAILY_MINUTES) },
  );

  const mine = courses.filter((course) => !course.is_from_library);

  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="eyebrow text-ink-tertiary">Ton étagère</p>
          <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">Cours</h1>
        </div>

        {counts.total > 0 ? (
          <Link
            href="/app/reviser"
            className="pressable flex items-center gap-2.5 rounded-button bg-ink px-5 py-3 text-[15px] font-semibold text-on-ink"
          >
            Réviser <span className="numeral">{counts.total}</span> carte
            {counts.total > 1 ? "s" : ""}
          </Link>
        ) : null}
      </header>

      {counts.total === 0 && cards.length > 0 ? (
        <p className="mt-6 text-[14px] text-ink-tertiary">
          Tout est à jour. Rien ne revient aujourd&apos;hui.
        </p>
      ) : null}

      {mine.length === 0 ? (
        <EmptyShelf />
      ) : (
        <div className="mt-9 overflow-hidden rounded-group bg-surface paper">
          {mine.map((course, index) => (
            <Link
              key={course.id}
              href={`/app/c/${course.id}` as never}
              className={`flex items-center gap-4 px-5 py-4 transition-colors duration-hover hover:bg-surface-muted/60 ${
                index > 0 ? "border-t border-hairline" : ""
              }`}
            >
              <span
                aria-hidden
                className="flex h-11 w-11 shrink-0 items-center justify-center rounded-tile text-[20px]"
                style={{ backgroundColor: `${course.accent_hex ?? courseAccent(course.id)}1f` }}
              >
                {resolveEmoji(course.emoji, course.subject, course.title)}
              </span>

              <span className="min-w-0 flex-1">
                <span className="block truncate text-[16px] font-semibold text-ink">
                  {course.title || "Sans titre"}
                </span>
                <span className="mt-0.5 block truncate text-[13px] text-ink-tertiary">
                  {[course.subject, sourceLabel(course.source)].filter(Boolean).join(" · ")}
                </span>
              </span>

              <svg
                aria-hidden
                viewBox="0 0 20 20"
                className="h-4 w-4 shrink-0 text-ink-tertiary"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M8 4l6 6-6 6" />
              </svg>
            </Link>
          ))}
        </div>
      )}
    </>
  );
}

/**
 * L'étagère vide.
 *
 * C'est l'écran que voit un étudiant qui vient de finir le parcours, donc le premier écran réel du
 * produit — et l'état qu'on oublie toujours de dessiner. Il porte son propre appel à importer :
 * une page vide avec une navigation à gauche laisse chercher où commencer.
 */
function EmptyShelf() {
  return (
    <div className="mt-10 rounded-group bg-canvas-sage p-8 text-center">
      <p className="text-[17px] font-semibold text-ink">Ton étagère est vide.</p>
      <p className="mx-auto mt-2.5 max-w-[42ch] text-[14.5px] leading-relaxed text-ink-reading">
        Dépose un polycopié, colle tes notes ou donne un lien de vidéo de cours. Micabo en écrit la
        fiche, et tu décides ensuite s&apos;il en faut des cartes.
      </p>
      <Link
        href="/app/importer"
        className="pressable mt-7 inline-flex items-center gap-2 rounded-button bg-ink px-6 py-3.5 text-[15px] font-semibold text-on-ink"
      >
        Importer un cours
      </Link>
    </div>
  );
}

function sourceLabel(source: string): string {
  switch (source) {
    case "pdf":
      return "PDF";
    case "photo":
      return "Photos";
    case "youtube":
      return "Vidéo";
    case "docx":
      return "Word";
    case "deck":
      return "Paquet";
    default:
      return "Texte";
  }
}
