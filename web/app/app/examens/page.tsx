import Link from "next/link";

import { dayDifference, startOfDay } from "@micabo/core";

import { listAllCards, listCourses, listExams } from "@/lib/data/courses";

/**
 * Les examens, **sur leur propre onglet.**
 *
 * Ils vivaient au bas du profil, entre le rythme quotidien et la langue des fiches : c'est le
 * mauvais endroit pour la seule chose du produit qui porte une date. Le mode examen est la
 * fonctionnalité que personne d'autre n'a, et une fonctionnalité rangée dans les réglages est une
 * fonctionnalité qu'on ne trouve pas.
 *
 * Le compte à rebours est calculé sur aujourd'hui, à minuit : compter en heures ferait passer un
 * examen de demain matin à « dans 0 jour ».
 */
export default async function ExamsPage() {
  const [exams, courses, cards] = await Promise.all([listExams(), listCourses(), listAllCards()]);

  const today = startOfDay(new Date());
  const titles = new Map(courses.map((course) => [course.id, course.title]));

  const dated = exams
    .map((exam) => ({
      ...exam,
      days: dayDifference(today, startOfDay(new Date(`${exam.exam_date}T12:00:00`))),
    }))
    .sort((left, right) => left.days - right.days);

  const upcoming = dated.filter((exam) => exam.days >= 0);
  const past = dated.filter((exam) => exam.days < 0);

  return (
    <>
      <header>
        <p className="eyebrow text-ink-tertiary">Mode examen</p>
        <h1 className="mt-2 text-[32px] font-bold leading-tight text-ink">Examens</h1>
      </header>

      {upcoming.length === 0 ? (
        <div className="mt-9 rounded-group bg-canvas-sage p-8 text-center">
          <p className="text-[17px] font-semibold text-ink">Aucun examen à venir.</p>
          <p className="mx-auto mt-2.5 max-w-[44ch] text-[14.5px] leading-relaxed text-ink-reading">
            La répétition espacée ignore le jour J : une carte revue hier avec un intervalle de
            vingt jours retomberait trois semaines après l&apos;épreuve. Une date la remet dans le
            bon ordre.
          </p>
          <Link
            href="/app/importer"
            className="pressable mt-7 inline-flex rounded-button bg-ink px-6 py-3.5 text-[15px] font-semibold text-on-ink"
          >
            Importer un cours
          </Link>
        </div>
      ) : (
        <div className="mt-9 space-y-3">
          {upcoming.map((exam, index) => (
            <article
              key={exam.id}
              className={`rounded-group p-6 ${index === 0 ? "bg-ink text-on-ink" : "paper bg-surface"}`}
            >
              <div className="flex items-start justify-between gap-5">
                <div className="min-w-0">
                  <p
                    className={`text-[17px] font-semibold ${
                      index === 0 ? "text-on-ink" : "text-ink"
                    }`}
                  >
                    {exam.name}
                  </p>
                  <p
                    className={`mt-1 text-[13.5px] ${
                      index === 0 ? "text-on-ink-muted" : "text-ink-tertiary"
                    }`}
                  >
                    {frenchDate(exam.exam_date)}
                  </p>
                </div>

                <div className="shrink-0 text-right">
                  <p
                    className={`numeral text-[34px] font-bold leading-none ${
                      index === 0 ? "text-on-ink" : "text-ink"
                    }`}
                  >
                    {exam.days}
                  </p>
                  <p
                    className={`text-[12px] ${
                      index === 0 ? "text-on-ink-muted" : "text-ink-tertiary"
                    }`}
                  >
                    jour{exam.days > 1 ? "s" : ""}
                  </p>
                </div>
              </div>

              {exam.course_ids?.length ? (
                <p
                  className={`mt-4 text-[13px] ${
                    index === 0 ? "text-on-ink-muted" : "text-ink-secondary"
                  }`}
                >
                  {exam.course_ids
                    .map((id) => titles.get(id))
                    .filter(Boolean)
                    .join(", ")}
                </p>
              ) : (
                <p
                  className={`mt-4 text-[13px] ${
                    index === 0 ? "text-on-ink-muted" : "text-ink-tertiary"
                  }`}
                >
                  Aucun cours rattaché — le plan se posera au premier import.
                </p>
              )}
            </article>
          ))}
        </div>
      )}

      {/* Le plan ne se pose pas sur rien : c'est pour ça qu'`is_planned` reste faux tant qu'il n'y
          a pas de cartes, et le dire vaut mieux que de laisser croire. */}
      {upcoming.length > 0 && cards.length === 0 ? (
        <p className="mt-4 rounded-group bg-caution-soft px-5 py-4 text-[13.5px] leading-relaxed text-ink-reading">
          Il n&apos;y a pas encore de cartes à replanifier. Un plan posé sur rien n&apos;est pas un
          plan : il se posera au premier paquet.
        </p>
      ) : null}

      {past.length > 0 ? (
        <section className="mt-12">
          <p className="eyebrow mb-3 text-ink-tertiary">Passés</p>
          <ul className="paper divide-y divide-hairline overflow-hidden rounded-group bg-surface">
            {past.map((exam) => (
              <li key={exam.id} className="flex items-baseline justify-between gap-4 px-5 py-3.5">
                <span className="text-[14.5px] text-ink-secondary">{exam.name}</span>
                <span className="shrink-0 text-[13px] text-ink-tertiary">
                  {frenchDate(exam.exam_date)}
                </span>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </>
  );
}

function frenchDate(value: string): string {
  return new Date(`${value}T12:00:00`).toLocaleDateString("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}
