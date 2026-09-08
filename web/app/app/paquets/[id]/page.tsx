import { notFound } from "next/navigation";
import type { Route } from "next";

import { CardWorkshop } from "@/components/app/CardWorkshop";
import { getCourse, listCards, listExams } from "@/lib/data/courses";
import { getTranslator } from "@/lib/i18n/server";

/**
 * La vue paquets dédiée : le même atelier, le retour vers la liste des paquets.
 */
export default async function DeckWorkshopPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ generer?: string }>;
}) {
  const { id } = await params;
  const { generer } = await searchParams;
  const [{ t }, course, cards, exams] = await Promise.all([
    getTranslator(),
    getCourse(id),
    listCards(id),
    listExams(),
  ]);
  if (!course) notFound();

  return (
    <CardWorkshop
      t={t}
      course={course}
      cards={cards}
      exams={exams}
      generer={generer}
      backHref={"/app/paquets" as Route}
      backLabel={t("nav.decks")}
      heading={course.title}
    />
  );
}
