import Link from "next/link";
import { redirect } from "next/navigation";

import {
  courseAccent,
  masteryByCourse,
  resolveEmoji,
  studyCounts,
  type FolderNode,
} from "@micabo/core";

import { CoursesExplore } from "@/components/app/CoursesExplore";
import { Shelf, type ShelfCourse } from "@/components/app/library/Shelf";
import { Button } from "@/components/ui/button";
import { listCardSnapshots, listCourses, listExams, listFolders } from "@/lib/data/courses";
import { canImportNow } from "@/lib/data/entitlement";
import { examMarkForCourse } from "@/lib/data/exam-marks";
import { loadCardDifficulty } from "@/lib/data/difficulty";
import { copyCourseSource, copyReviewButton } from "@/lib/i18n/copy";
import { getTranslator } from "@/lib/i18n/server";

/**
 * L'étagère, et son classeur.
 *
 * La page assemble ce que la grille a besoin de savoir - la maîtrise, l'épreuve à venir, la
 * tuile - et le passe **déjà calculé** au composant qui glisse. Le rangement se fait au doigt,
 * donc dans le navigateur ; la maîtrise se calcule sur toutes les cartes, donc sur le serveur.
 * Mélanger les deux ferait descendre le paquet de cartes entier dans la page.
 *
 * Les cours des amis se lisent encore sur leur profil, selon la visibilité qu'ils ont choisie.
 */
export default async function CoursesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  if (params.vue === "decouvrir") redirect("/app/cours");

  const [{ t }, courses, folders, cards, exams, canImport, difficulties] = await Promise.all([
    getTranslator(),
    listCourses(),
    listFolders(),
    listCardSnapshots(),
    listExams(),
    canImportNow(),
    loadCardDifficulty(),
  ]);

  // La maîtrise remplace le compte de vues sur chaque tuile : « 42 vues » ne dit rien à celui
  // qui révise, « appris à 61 % » lui dit s'il peut passer à autre chose.
  const mastery = masteryByCourse(
    cards.map((card) => ({
      id: card.id,
      courseId: card.course_id,
      state: card.state,
      intervalDays: card.interval_days,
      isSuspended: card.is_suspended,
    })),
    difficulties,
  );

  const counts = studyCounts(
    cards.map((card) => ({
      id: card.id,
      state: card.state,
      dueDate: new Date(card.due_date),
      position: card.position,
      createdAt: new Date(card.created_at),
      isSuspended: card.is_suspended,
    })),
  );

  const tiles: ShelfCourse[] = courses.map((course) => {
    const exam = examMarkForCourse(exams, course.id);
    const own = mastery.get(course.id) ?? null;
    return {
      id: course.id,
      title: course.title,
      subtitle: [
        course.subject,
        course.is_from_library
          ? t("app.course.source.adopted")
          : copyCourseSource(t, course.source),
      ]
        .filter(Boolean)
        .join(" · "),
      emoji: resolveEmoji(course.emoji, course.subject, course.title),
      accent: course.accent_hex ?? courseAccent(course.id),
      folder_id: course.folder_id,
      mastery: own,
      masteryLabel: t("app.courses.mastery", {
        percent: own?.percent ?? 0,
        cards: own?.cardCount ?? 0,
      }),
      exam: exam ? { name: exam.name, daysRemaining: exam.daysRemaining } : null,
    };
  });

  const nodes: FolderNode[] = folders.map((folder) => ({
    id: folder.id,
    parentId: folder.parent_id,
    name: folder.name,
    emoji: folder.emoji,
    position: folder.position,
  }));

  return (
    <CoursesExplore
      revise={
        counts.total > 0 ? (
          <Button render={<Link href={"/app/reviser" as never} />}>
            {copyReviewButton(t, counts.total)}
          </Button>
        ) : null
      }
    >
      <Shelf
        folders={nodes}
        courses={tiles}
        canImport={canImport}
        emptyReviews={counts.total === 0 && cards.length > 0}
      />
    </CoursesExplore>
  );
}
