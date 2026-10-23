import { redirect } from "next/navigation";

import { lessonPath } from "@/lib/lesson/routes";

/**
 * **L'ancienne adresse d'un cours** mène à sa leçon.
 *
 * `/app/c/<id>` était la fiche ; depuis la refonte « parcours », un cours est une leçon et
 * s'ouvre sur son chemin. L'adresse reste pour les liens déjà envoyés et les onglets déjà
 * épinglés : elle redirige, elle ne meurt pas.
 */
export default async function CourseRedirect({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  redirect(lessonPath(id));
}
