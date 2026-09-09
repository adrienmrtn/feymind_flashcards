"use client";

import { useMemo, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import {
  EMPTY_MASTERY,
  buildLibrary,
  canMoveFolder,
  folderPath,
  type FolderNode,
  type Mastery,
} from "@micabo/core";

import { MasteryBar } from "@/components/app/charts/MasteryBar";
import { CourseExamBadge } from "@/components/app/CourseExamBadge";
import { LockedAddCourseCard } from "@/components/app/SecondCourseCard";
import {
  createFolder,
  deleteFolder,
  moveCourse,
  moveFolder,
  renameFolder,
} from "@/lib/actions/folders";
import { useI18n } from "@/lib/i18n/client";

/**
 * **L'étagère, avec des dossiers.**
 *
 * Une liste à plat tient le premier semestre. Au troisième, il y a quarante cours de cinq
 * matières, et retrouver le chapitre 4 de thermodynamique se fait en faisant défiler jusqu'à
 * le voir passer. Le tri par matière ne remplace pas un rangement : « Physique » est une
 * étiquette, pas une organisation, et personne ne range son classeur en une pile par matière.
 *
 * La forme est celle d'un gestionnaire de fichiers, parce que c'est la seule qu'on n'a pas à
 * expliquer :
 *
 * - **On entre dans un dossier**, on ne déplie pas un arbre. Une arborescence dépliée dans une
 *   grille de tuiles donne une colonne de décalages et plus aucune grille ; entrer garde des
 *   tuiles de même taille, et le fil d'Ariane dit où l'on est.
 * - **On glisse pour ranger.** Une tuile de cours se prend et se lâche sur un dossier. Un
 *   dossier se glisse dans un autre, ce qui fait les sous-dossiers sans autre commande.
 * - **On glisse sur « sortir » pour dépiler.** C'est la tuile de remontée, en tête de grille
 *   dès qu'on est dans un dossier : elle sert à naviguer d'un clic, et à sortir un cours d'un
 *   lâcher. C'est le `..` de tous les gestionnaires de fichiers.
 *
 * Le déplacement est **optimiste** : la tuile change de place au lâcher, et le serveur suit.
 * Attendre l'aller-retour ferait un glisser-déposer qui recule sous le doigt, ce qui est la
 * seule façon de rater ce geste.
 */

export interface ShelfCourse {
  id: string;
  title: string;
  subtitle: string;
  emoji: string;
  accent: string;
  folder_id: string | null;
  mastery: Mastery | null;
  masteryLabel: string;
  exam: { name: string; daysRemaining: number } | null;
}

type Dragged =
  | { kind: "course"; id: string }
  | { kind: "folder"; id: string }
  | null;

/**
 * Ce qu'on transporte, écrit dans le presse-papiers du glissement.
 *
 * C'est la source de vérité du lâcher, et pas l'état React : un état se met à jour **après**
 * le rendu suivant, alors que `dragover` et `drop` peuvent arriver dans le même tour de
 * boucle. Un lâcher qui lit un état pas encore posé ne fait rien du tout, et le cours revient
 * à sa place sans explication.
 */
const PAYLOAD = "application/x-micabo-item";

export function Shelf({
  folders: initialFolders,
  courses: initialCourses,
  canImport,
  emptyReviews,
}: {
  folders: FolderNode[];
  courses: ShelfCourse[];
  canImport: boolean;
  emptyReviews: boolean;
}) {
  const { t } = useI18n();
  const router = useRouter();
  const [folders, setFolders] = useState(initialFolders);
  const [courses, setCourses] = useState(initialCourses);

  /**
   * **La copie locale se recale sur le serveur dès qu'il a changé d'avis.**
   *
   * Le déplacement est optimiste : la tuile bouge au lâcher, avant la réponse. Il faut donc
   * une copie modifiable - et une copie ne se remet pas à jour toute seule quand la page est
   * re-rendue. Sans ce recalage, un dossier créé n'apparaîtrait qu'au prochain chargement
   * complet, et un déplacement refusé par le serveur resterait affiché comme accepté.
   *
   * La comparaison porte sur le **contenu**, pas sur l'identité des tableaux : un rendu du
   * serveur en fabrique de nouveaux à chaque fois, et se recaler dessus écraserait le
   * déplacement en cours.
   */
  const signature = useMemo(
    () =>
      JSON.stringify([
        initialFolders.map((folder) => [folder.id, folder.parentId, folder.name, folder.emoji]),
        initialCourses.map((course) => [course.id, course.folder_id]),
      ]),
    [initialFolders, initialCourses],
  );
  const settled = useRef(signature);
  if (settled.current !== signature) {
    settled.current = signature;
    setFolders(initialFolders);
    setCourses(initialCourses);
  }
  const [openId, setOpenId] = useState<string | null>(null);
  const [dragged, setDragged] = useState<Dragged>(null);
  /** Le même, lisible tout de suite : c'est lui que le lâcher consulte. */
  const carried = useRef<Dragged>(null);
  const [over, setOver] = useState<string | null>(null);
  const [naming, setNaming] = useState(false);
  const [draft, setDraft] = useState("");
  const [failure, setFailure] = useState<string | null>(null);
  const [, startTransition] = useTransition();

  const library = useMemo(() => buildLibrary(folders, courses), [folders, courses]);
  const path = useMemo(() => folderPath(folders, openId), [folders, openId]);

  /** Ce que la grille montre : le contenu du dossier ouvert, ou la racine. */
  const here = useMemo(() => {
    if (!openId) return { folders: library.tree, courses: library.loose };
    const found = findNode(library.tree, openId);
    return found
      ? { folders: found.children, courses: found.courses }
      : { folders: [], courses: [] };
  }, [library, openId]);

  const parentOfOpen = path.length > 1 ? path[path.length - 2]!.id : null;

  function run(action: () => Promise<{ status: "ok" | "error"; message?: string }>) {
    setFailure(null);
    startTransition(async () => {
      const result = await action();
      if (result.status === "error") {
        setFailure(result.message ?? t("app.common.errorGeneric"));
        // La vérité est en base : on redemande plutôt que de deviner ce qui a été refusé.
        router.refresh();
        return;
      }
      router.refresh();
    });
  }

  function startDrag(payload: Exclude<Dragged, null>, event: React.DragEvent) {
    carried.current = payload;
    setDragged(payload);
    event.dataTransfer.setData(PAYLOAD, `${payload.kind}:${payload.id}`);
    // Sans une charge `text/plain`, Firefox refuse de commencer le glissement.
    event.dataTransfer.setData("text/plain", payload.id);
    event.dataTransfer.effectAllowed = "move";
  }

  function endDrag() {
    carried.current = null;
    setDragged(null);
    setOver(null);
  }

  /** Le lâcher. `target` est un dossier, ou `null` pour la racine du niveau visé. */
  function drop(target: string | null, event: React.DragEvent) {
    const payload = readPayload(event) ?? carried.current;
    endDrag();
    if (!payload) return;

    if (payload.kind === "course") {
      const course = courses.find((item) => item.id === payload.id);
      if (!course || course.folder_id === target) return;
      setCourses((list) =>
        list.map((item) => (item.id === payload.id ? { ...item, folder_id: target } : item)),
      );
      run(() => moveCourse(payload.id, target));
      return;
    }

    const folder = folders.find((item) => item.id === payload.id);
    if (!folder || folder.parentId === target) return;
    if (!canMoveFolder(folders, payload.id, target)) {
      setFailure(t("app.folders.cannotNest"));
      return;
    }
    setFolders((list) =>
      list.map((item) => (item.id === payload.id ? { ...item, parentId: target } : item)),
    );
    run(() => moveFolder(payload.id, target));
  }

  function submitName() {
    const name = draft.trim();
    setNaming(false);
    setDraft("");
    if (name.length === 0) return;
    run(() => createFolder(name, openId));
  }

  const dropProps = (target: string | null, key: string) => ({
    onDragOver: (event: React.DragEvent) => {
      // Pendant le survol, le navigateur ne laisse pas lire la charge - seulement ses
      // types. C'est assez pour savoir qu'il s'agit d'une de nos tuiles.
      if (!carried.current && !event.dataTransfer.types.includes(PAYLOAD)) return;
      event.preventDefault();
      event.dataTransfer.dropEffect = "move";
      setOver(key);
    },
    onDragLeave: () => setOver((current) => (current === key ? null : current)),
    onDrop: (event: React.DragEvent) => {
      event.preventDefault();
      drop(target, event);
    },
    "data-over": over === key ? "" : undefined,
  });

  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <nav aria-label={t("app.folders.breadcrumb")} className="flex min-w-0 flex-wrap items-center gap-1">
          <Crumb
            label={t("app.folders.root")}
            active={openId === null}
            onOpen={() => setOpenId(null)}
            {...dropProps(null, "crumb:root")}
          />
          {path.map((step) => (
            <span key={step.id} className="flex items-center gap-1">
              <span aria-hidden className="text-ink-tertiary">
                ›
              </span>
              <Crumb
                label={step.name}
                emoji={step.emoji}
                active={step.id === openId}
                onOpen={() => setOpenId(step.id)}
                {...dropProps(step.id, `crumb:${step.id}`)}
              />
            </span>
          ))}
        </nav>

        {naming ? (
          <input
            autoFocus
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            onBlur={submitName}
            onKeyDown={(event) => {
              if (event.key === "Enter") submitName();
              if (event.key === "Escape") {
                setNaming(false);
                setDraft("");
              }
            }}
            placeholder={t("app.folders.namePlaceholder")}
            className="h-9 w-[13rem] rounded-button bg-surface-muted px-3 text-[13.5px] text-ink outline-none"
          />
        ) : (
          <button
            type="button"
            onClick={() => setNaming(true)}
            className="pressable h-9 rounded-button bg-surface-muted px-3.5 text-[13.5px] font-medium text-ink"
          >
            {t("app.folders.new")}
          </button>
        )}
      </div>

      {failure ? (
        <p className="text-[13px] text-negative" role="alert">
          {failure}
        </p>
      ) : null}

      {emptyReviews ? (
        <p className="text-[13px] text-muted-foreground">{t("app.courses.doneTomorrow")}</p>
      ) : null}

      {here.folders.length === 0 && here.courses.length === 0 ? (
        <p className="text-[15px] text-ink-secondary">
          {openId ? t("app.folders.empty") : t("app.courses.emptyLead")}
        </p>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3" data-tour="cours-etagere">
        {openId ? (
          <button
            type="button"
            onClick={() => setOpenId(parentOfOpen)}
            {...dropProps(parentOfOpen, "up")}
            className="drop-target flex items-center gap-3 rounded-group border border-dashed border-stroke-strong px-5 py-4 text-left"
          >
            <span
              aria-hidden
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-tile bg-surface-muted text-ink-secondary"
            >
              <svg viewBox="0 0 24 24" className="h-5 w-5">
                <path
                  d="M12 19V6M6 12l6-6 6 6"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </span>
            <span className="min-w-0">
              <span className="block text-[15px] font-semibold text-ink">
                {t("app.folders.up")}
              </span>
              <span className="mt-0.5 block text-[12.5px] text-ink-tertiary">
                {t("app.folders.upHint")}
              </span>
            </span>
          </button>
        ) : null}

        {here.folders.map((node) => (
          <FolderTile
            key={node.folder.id}
            node={node.folder}
            total={node.total}
            onOpen={() => setOpenId(node.folder.id)}
            onRename={(name) => run(() => renameFolder(node.folder.id, name))}
            onDelete={() => run(() => deleteFolder(node.folder.id))}
            onDragStart={(event: React.DragEvent) =>
              startDrag({ kind: "folder", id: node.folder.id }, event)
            }
            onDragEnd={endDrag}
            {...dropProps(node.folder.id, `folder:${node.folder.id}`)}
          />
        ))}

        {here.courses.map((course) => (
          <CourseTile
            key={course.id}
            course={course}
            dragging={dragged?.kind === "course" && dragged.id === course.id}
            onDragStart={(event) => startDrag({ kind: "course", id: course.id }, event)}
            onDragEnd={endDrag}
          />
        ))}

        {canImport ? <AddCourseCard label={t("app.courses.addTitle")} hint={t("app.courses.addFormats")} /> : <LockedAddCourseCard />}
      </div>
    </>
  );
}

/** La charge d'un lâcher, quand le navigateur la rend. */
function readPayload(event: React.DragEvent): Dragged {
  const raw = event.dataTransfer.getData(PAYLOAD);
  const [kind, id] = raw.split(":");
  if ((kind === "course" || kind === "folder") && id) return { kind, id };
  return null;
}

function findNode<T>(
  tree: ReturnType<typeof buildLibrary<ShelfCourse>>["tree"],
  id: string,
): ReturnType<typeof buildLibrary<ShelfCourse>>["tree"][number] | null {
  for (const node of tree) {
    if (node.folder.id === id) return node;
    const found = findNode(node.children, id);
    if (found) return found;
  }
  return null;
}

function Crumb({
  label,
  emoji,
  active,
  onOpen,
  ...drop
}: {
  label: string;
  emoji?: string | null;
  active: boolean;
  onOpen: () => void;
} & Record<string, unknown>) {
  return (
    <button
      type="button"
      onClick={onOpen}
      {...drop}
      className={`drop-target pressable inline-flex h-8 max-w-[14rem] items-center gap-1.5 truncate rounded-button px-2.5 text-[13.5px] ${
        active ? "font-semibold text-ink" : "text-ink-tertiary hover:text-ink"
      }`}
    >
      {emoji ? (
        <span aria-hidden className="emoji">
          {emoji}
        </span>
      ) : null}
      {label}
    </button>
  );
}

function FolderTile({
  node,
  total,
  onOpen,
  onRename,
  onDelete,
  ...rest
}: {
  node: FolderNode;
  total: number;
  onOpen: () => void;
  onRename: (name: string) => void;
  onDelete: () => void;
} & Record<string, unknown>) {
  const { t } = useI18n();
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(node.name);

  return (
    <div
      draggable
      {...rest}
      className="drop-target hover-tile group relative flex flex-col gap-4 rounded-group border border-border bg-card p-5 transition-[border-color] duration-hover"
    >
      <span
        aria-hidden
        className="flex h-12 w-12 items-center justify-center rounded-tile bg-surface-muted text-[22px]"
      >
        {node.emoji ?? "📁"}
      </span>

      {editing ? (
        <input
          autoFocus
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          onBlur={() => {
            setEditing(false);
            if (draft.trim() && draft.trim() !== node.name) onRename(draft.trim());
          }}
          onKeyDown={(event) => {
            if (event.key === "Enter") event.currentTarget.blur();
            if (event.key === "Escape") {
              setDraft(node.name);
              setEditing(false);
            }
          }}
          className="h-9 w-full rounded-button bg-surface-muted px-2.5 text-[15px] font-semibold text-ink outline-none"
        />
      ) : (
        <button type="button" onClick={onOpen} className="min-w-0 text-left">
          <span className="line-clamp-2 block text-[16px] font-semibold leading-snug text-ink">
            {node.name}
          </span>
          <span className="mt-1.5 block text-[13px] text-ink-tertiary">
            {t("app.folders.count", { count: total })}
          </span>
        </button>
      )}

      <div className="mt-auto flex gap-1.5 opacity-0 transition-opacity duration-hover group-hover:opacity-100 group-focus-within:opacity-100">
        <button
          type="button"
          onClick={() => setEditing(true)}
          className="pressable rounded-button bg-surface-muted px-2.5 py-1.5 text-[12.5px] font-medium text-ink"
        >
          {t("app.folders.rename")}
        </button>
        <button
          type="button"
          onClick={onDelete}
          className="pressable rounded-button px-2.5 py-1.5 text-[12.5px] font-medium text-negative"
        >
          {t("app.folders.delete")}
        </button>
      </div>
    </div>
  );
}

function CourseTile({
  course,
  dragging,
  onDragStart,
  onDragEnd,
}: {
  course: ShelfCourse;
  dragging: boolean;
  onDragStart: (event: React.DragEvent) => void;
  onDragEnd: () => void;
}) {
  const { t } = useI18n();

  return (
    <Link
      href={`/app/c/${course.id}` as never}
      draggable
      onDragStart={onDragStart}
      onDragEnd={onDragEnd}
      className={`hover-tile relative flex cursor-grab flex-col gap-4 rounded-group border border-border bg-card p-5 transition-[border-color,opacity] duration-hover active:cursor-grabbing ${
        dragging ? "opacity-40" : ""
      }`}
    >
      {course.exam ? (
        <span className="absolute right-3 top-3">
          <CourseExamBadge name={course.exam.name} daysRemaining={course.exam.daysRemaining} />
        </span>
      ) : null}

      <span
        aria-hidden
        className="flex h-12 w-12 items-center justify-center rounded-tile text-[22px]"
        style={{ backgroundColor: `${course.accent}1f` }}
      >
        {course.emoji}
      </span>

      <span className="min-w-0">
        <span className="line-clamp-2 block text-[16px] font-semibold leading-snug text-ink">
          {course.title || t("app.course.untitled")}
        </span>
        <span className="mt-1.5 line-clamp-1 block text-[13px] text-ink-tertiary">
          {course.subtitle}
        </span>
      </span>

      <span className="mt-auto block">
        <MasteryBar mastery={course.mastery ?? EMPTY_MASTERY} size="sm" legend={false} />
        <span className="numeral mt-2 block text-[12.5px] text-ink-secondary">
          {course.masteryLabel}
        </span>
      </span>
    </Link>
  );
}

function AddCourseCard({ label, hint }: { label: string; hint: string }) {
  return (
    <Link
      href={"/app/importer" as never}
      data-tour="cours-ajouter"
      className="relative flex flex-col gap-4 rounded-group border border-dashed border-stroke-strong bg-transparent p-5 transition-[background-color,border-color] duration-hover hover:bg-surface-muted"
    >
      <span
        aria-hidden
        className="flex h-12 w-12 items-center justify-center rounded-tile bg-surface-muted text-ink-secondary"
      >
        <svg viewBox="0 0 24 24" className="h-6 w-6">
          <path
            d="M12 5v14M5 12h14"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          />
        </svg>
      </span>
      <span className="min-w-0">
        <span className="line-clamp-2 block text-[16px] font-semibold leading-snug text-ink">
          {label}
        </span>
        <span className="mt-1.5 line-clamp-2 block text-[13px] text-ink-tertiary">{hint}</span>
      </span>
    </Link>
  );
}
