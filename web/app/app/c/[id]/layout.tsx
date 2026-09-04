import { notFound } from "next/navigation";

import { resolveEmoji } from "@micabo/core";

import { OpenCourse } from "@/components/app/OpenCourse";
import { getCourseMeta } from "@/lib/data/courses";
import { getTranslator } from "@/lib/i18n/server";

/**
 * Ce qui épingle un cours dans la barre.
 *
 * Il est posé sur le **segment** et non sur chaque page : la fiche, ses cartes et sa session sont
 * trois écrans du même cours, et répéter l'épinglage dans chacune finirait par en oublier une.
 */
export default async function CourseLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const [{ t }, course] = await Promise.all([getTranslator(), getCourseMeta(id)]);
  if (!course) notFound();

  return (
    <>
      <OpenCourse
        id={course.id}
        title={course.title || t("app.course.untitled")}
        emoji={resolveEmoji(course.emoji, course.subject, course.title)}
      />
      {children}
    </>
  );
}
