import { notFound } from "next/navigation";

import { resolveEmoji } from "@micabo/core";

import { OpenCourse } from "@/components/app/OpenCourse";
import { getCourse } from "@/lib/data/courses";

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
  const course = await getCourse(id);
  if (!course) notFound();

  return (
    <>
      <OpenCourse
        id={course.id}
        title={course.title || "Sans titre"}
        emoji={resolveEmoji(course.emoji, course.subject, course.title)}
      />
      {children}
    </>
  );
}
