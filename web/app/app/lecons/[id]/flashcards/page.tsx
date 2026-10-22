import { notFound } from "next/navigation";

import { CardsHub, type HubCard } from "@/components/lesson/CardsHub";
import { listCards } from "@/lib/data/courses";
import { loadLessonContext } from "@/lib/lesson/load";

/**
 * **Les flashcards de la leçon** : l'entrée Flashcards de la barre. `?reviser=1` lance la
 * révision tout de suite (« Revoir mes flashcards », à la fin d'une leçon).
 */
export default async function LessonFlashcardsPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ reviser?: string }>;
}) {
  const [{ id }, query] = await Promise.all([params, searchParams]);
  const context = await loadLessonContext(id);
  if (!context) notFound();
  const cards = (await listCards(context.lesson.id)).filter((card) => !card.is_suspended);
  const hubCards: HubCard[] = cards.map((card) => ({
    id: card.id,
    front: card.front,
    back: card.back,
    kind: card.kind,
    choices: card.choices ?? [],
    correctChoiceIndex: card.correct_choice_index,
    isSuspended: card.is_suspended,
    state: card.state,
    dueDate: card.due_date,
    intervalDays: card.interval_days,
    position: card.position,
    snapshot: {
      state: card.state,
      intervalDays: card.interval_days,
      easeFactor: card.ease_factor,
      repetitions: card.repetitions,
      lapses: card.lapses,
      stepIndex: card.step_index,
      dueDate: card.due_date,
    },
  }));
  return <CardsHub lessonId={context.lesson.id} tone={context.tone} cards={hubCards} autoStart={query.reviser === "1"} />;
}
