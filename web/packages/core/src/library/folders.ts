/**
 * **L'arborescence de la bibliothèque.**
 *
 * Les dossiers arrivent à plat - une ligne, un parent - et c'est bien ainsi : une table
 * plate se lit en une requête, là où une arborescence stockée coûterait un aller-retour par
 * niveau. Le rangement, lui, se refait ici, en mémoire, et **des deux côtés** : c'est la même
 * fonction qui compose l'écran du site et celui de l'iPhone, donc les deux montrent le même
 * classeur.
 *
 * Trois règles portent tout le reste :
 *
 * - **Un cours est dans un dossier, ou à la racine.** Jamais dans deux, jamais nulle part.
 * - **Un dossier orphelin remonte à la racine** plutôt que de disparaître. Un parent effacé
 *   pendant qu'un autre appareil déplaçait son enfant est un cas réel, et un dossier
 *   invisible avec quinze cours dedans est le pire résultat possible.
 * - **Un cycle est ignoré à la lecture.** La base le refuse déjà, mais l'écran ne doit pas
 *   pouvoir boucler à l'infini sur une donnée abîmée : ce qui boucle est traité en orphelin.
 */

export interface FolderNode {
  id: string;
  parentId: string | null;
  name: string;
  emoji: string | null;
  position: number;
}

export interface FolderTree<Course> {
  folder: FolderNode;
  /** Les sous-dossiers, rangés. */
  children: FolderTree<Course>[];
  /** Les cours posés directement dedans. */
  courses: Course[];
  /** Ce que le dossier contient en tout, sous-dossiers compris. C'est le compte à afficher. */
  total: number;
}

export interface Library<Course> {
  tree: FolderTree<Course>[];
  /** Les cours qui ne sont rangés nulle part. */
  loose: Course[];
}

/** La profondeur au-delà de laquelle un classeur n'est plus un classeur. */
export const FOLDER_MAX_DEPTH = 5;

export function buildLibrary<Course extends { folder_id?: string | null }>(
  folders: readonly FolderNode[],
  courses: readonly Course[],
): Library<Course> {
  const known = new Map(folders.map((folder) => [folder.id, folder]));

  // Un parent inconnu, effacé ou bouclé rend le dossier à la racine.
  const parentOf = (folder: FolderNode): string | null => {
    if (!folder.parentId || !known.has(folder.parentId)) return null;
    return hasCycle(folder, known) ? null : folder.parentId;
  };

  const byParent = new Map<string | null, FolderNode[]>();
  for (const folder of folders) {
    const parent = parentOf(folder);
    const bucket = byParent.get(parent);
    if (bucket) bucket.push(folder);
    else byParent.set(parent, [folder]);
  }

  const coursesByFolder = new Map<string | null, Course[]>();
  for (const course of courses) {
    const folder = course.folder_id && known.has(course.folder_id) ? course.folder_id : null;
    const bucket = coursesByFolder.get(folder);
    if (bucket) bucket.push(course);
    else coursesByFolder.set(folder, [course]);
  }

  function branch(parent: string | null, depth: number): FolderTree<Course>[] {
    if (depth > FOLDER_MAX_DEPTH) return [];
    const here = byParent.get(parent) ?? [];
    return [...here].sort(compareFolders).map((folder) => {
      const children = branch(folder.id, depth + 1);
      const own = coursesByFolder.get(folder.id) ?? [];
      return {
        folder,
        children,
        courses: own,
        total: own.length + children.reduce((sum, child) => sum + child.total, 0),
      };
    });
  }

  return { tree: branch(null, 1), loose: coursesByFolder.get(null) ?? [] };
}

/** Le rang voulu d'abord, le nom ensuite : deux dossiers au même rang ne dansent pas. */
function compareFolders(a: FolderNode, b: FolderNode): number {
  if (a.position !== b.position) return a.position - b.position;
  return a.name.localeCompare(b.name);
}

function hasCycle(folder: FolderNode, known: Map<string, FolderNode>): boolean {
  const seen = new Set<string>([folder.id]);
  let cursor = folder.parentId;
  while (cursor) {
    if (seen.has(cursor)) return true;
    seen.add(cursor);
    cursor = known.get(cursor)?.parentId ?? null;
  }
  return false;
}

/**
 * Le chemin d'un dossier jusqu'à la racine, racine d'abord.
 *
 * C'est le fil d'Ariane, et c'est aussi ce qui dit à un déplacement s'il est légal : on ne
 * déplace pas un dossier dans quelque chose qui est déjà en dessous de lui.
 */
export function folderPath(
  folders: readonly FolderNode[],
  id: string | null,
): FolderNode[] {
  if (!id) return [];
  const known = new Map(folders.map((folder) => [folder.id, folder]));
  const path: FolderNode[] = [];
  const seen = new Set<string>();
  let cursor: string | null = id;

  while (cursor && known.has(cursor) && !seen.has(cursor)) {
    seen.add(cursor);
    const step: FolderNode = known.get(cursor)!;
    path.unshift(step);
    cursor = step.parentId;
  }

  return path;
}

/**
 * Vrai quand `folder` peut aller dans `target`.
 *
 * Un dossier ne se range ni dans lui-même, ni dans un de ses descendants - il disparaîtrait
 * des deux côtés - ni au-delà de la profondeur admise, parce qu'un classeur à huit niveaux
 * ne se parcourt plus, il se subit.
 */
export function canMoveFolder(
  folders: readonly FolderNode[],
  folder: string,
  target: string | null,
): boolean {
  if (folder === target) return false;
  if (target === null) return true;

  const path = folderPath(folders, target);
  if (path.some((step) => step.id === folder)) return false;

  return path.length + depthUnder(folders, folder) <= FOLDER_MAX_DEPTH;
}

/** Le nombre de niveaux qu'un dossier emporte avec lui, lui compris. */
function depthUnder(folders: readonly FolderNode[], id: string): number {
  const children = folders.filter((folder) => folder.parentId === id);
  if (children.length === 0) return 1;
  return 1 + Math.max(...children.map((child) => depthUnder(folders, child.id)));
}
