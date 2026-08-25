import Link from "next/link";

import { DEFAULT_DAILY_MINUTES, buildQueue, dailyLimits } from "@micabo/core";

import { Session } from "@/components/app/Session";
import { listAllCards, listCourses } from "@/lib/data/courses";

/**
 * La session.
 *
 * La file est construite **côté serveur**, par le même `buildQueue` que l'iPhone : l'apprentissage
 * en retard d'abord, puis les révisions, puis les cartes neuves sous le plafond du rythme
 * quotidien. Le navigateur reçoit une file déjà ordonnée et ne décide de rien — sinon deux clients
 * serviraient deux ordres différents pour le même jeu.
 */
export default async function ReviewPage() {
  const [cards, courses] = await Promise.all([listAllCards(), listCourses()]);

  const queue = buildQueue(
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

  const byId = new Map(cards.map((card) => [card.id, card]));
  const titles = new Map(courses.map((course) => [course.id, course.title]));

  const ordered = queue
    .map((item) => byId.get(item.id))
    .filter((card): card is NonNullable<typeof card> => Boolean(card))
    .map((card) => ({
      id: card.id,
      front: card.front,
      back: card.back,
      hint: card.hint,
      kind: card.kind,
      choices: card.choices ?? [],
      answerIndex: card.correct_choice_index,
      courseTitle: card.course_id ? (titles.get(card.course_id) ?? null) : null,
      snapshot: {
        state: card.state,
        intervalDays: card.interval_days,
        easeFactor: card.ease_factor,
        repetitions: card.repetitions,
        lapses: card.lapses,
        stepIndex: card.step_index,
      },
    }));

  if (ordered.length === 0) {
    return (
      <div className="mx-auto max-w-[520px] py-16 text-center">
        <p className="text-[26px] font-bold text-ink">Tout est à jour.</p>
        <p className="mt-3 text-[15px] leading-relaxed text-ink-secondary">
          {cards.length === 0
            ? "Tu n'as pas encore de cartes. Elles se demandent depuis la fiche d'un cours, quand tu l'as lue."
            : "Rien ne revient aujourd'hui. C'est le principe : une carte qu'on revoit trop tôt est une carte pour rien."}
        </p>
        <Link
          href={cards.length === 0 ? "/app/importer" : "/app"}
          className="pressable mt-8 inline-flex rounded-button bg-ink px-6 py-3.5 text-[15px] font-semibold text-on-ink"
        >
          {cards.length === 0 ? "Importer un cours" : "Retour aux cours"}
        </Link>
      </div>
    );
  }

  return <Session cards={ordered} />;
}
