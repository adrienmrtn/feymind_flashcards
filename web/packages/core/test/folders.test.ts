import { describe, expect, it } from "vitest";

import {
  FOLDER_MAX_DEPTH,
  buildLibrary,
  canMoveFolder,
  folderPath,
  type FolderNode,
} from "../src/library/folders";

function folder(id: string, parentId: string | null = null, position = 0): FolderNode {
  return { id, parentId, name: id, emoji: null, position };
}

interface Course {
  id: string;
  folder_id: string | null;
}

const course = (id: string, folder_id: string | null = null): Course => ({ id, folder_id });

describe("l'arborescence", () => {
  it("range les cours dans leur dossier, et le reste à la racine", () => {
    const library = buildLibrary(
      [folder("physique"), folder("thermo", "physique")],
      [course("a", "thermo"), course("b", "physique"), course("c", null)],
    );

    expect(library.loose.map((item) => item.id)).toEqual(["c"]);
    expect(library.tree).toHaveLength(1);
    expect(library.tree[0]!.courses.map((item) => item.id)).toEqual(["b"]);
    expect(library.tree[0]!.children[0]!.courses.map((item) => item.id)).toEqual(["a"]);
  });

  it("compte ce que contient un dossier, sous-dossiers compris", () => {
    const library = buildLibrary(
      [folder("physique"), folder("thermo", "physique"), folder("td", "thermo")],
      [course("a", "td"), course("b", "thermo"), course("c", "physique")],
    );

    expect(library.tree[0]!.total).toBe(3);
    expect(library.tree[0]!.children[0]!.total).toBe(2);
  });

  it("remonte à la racine un dossier dont le parent a disparu", () => {
    // Le parent effacé sur un autre appareil pendant qu'on déplaçait l'enfant : le dossier
    // doit rester visible, sinon ce qu'il contient est perdu de vue.
    const library = buildLibrary([folder("orphelin", "fantome")], [course("a", "orphelin")]);

    expect(library.tree.map((node) => node.folder.id)).toEqual(["orphelin"]);
    expect(library.tree[0]!.courses).toHaveLength(1);
  });

  it("ne boucle pas sur une arborescence abîmée", () => {
    const library = buildLibrary([folder("a", "b"), folder("b", "a")], []);

    expect(library.tree.map((node) => node.folder.id).sort()).toEqual(["a", "b"]);
  });

  it("rend un cours à la racine quand son dossier n'existe plus", () => {
    const library = buildLibrary([], [course("a", "disparu")]);

    expect(library.loose.map((item) => item.id)).toEqual(["a"]);
  });

  it("trie par rang voulu, puis par nom", () => {
    const library = buildLibrary(
      [
        { id: "z", parentId: null, name: "Zoologie", emoji: null, position: 0 },
        { id: "a", parentId: null, name: "Anatomie", emoji: null, position: 0 },
        { id: "p", parentId: null, name: "Physique", emoji: null, position: -1 },
      ],
      [],
    );

    expect(library.tree.map((node) => node.folder.id)).toEqual(["p", "a", "z"]);
  });
});

describe("le chemin", () => {
  it("part de la racine et descend jusqu'au dossier", () => {
    const folders = [folder("physique"), folder("thermo", "physique"), folder("td", "thermo")];

    expect(folderPath(folders, "td").map((step) => step.id)).toEqual([
      "physique",
      "thermo",
      "td",
    ]);
    expect(folderPath(folders, null)).toEqual([]);
  });
});

describe("le déplacement", () => {
  const folders = [folder("physique"), folder("thermo", "physique"), folder("chimie")];

  it("accepte un dossier vers un autre, et vers la racine", () => {
    expect(canMoveFolder(folders, "chimie", "physique")).toBe(true);
    expect(canMoveFolder(folders, "thermo", null)).toBe(true);
  });

  it("refuse un dossier dans lui-même ou dans son contenu", () => {
    expect(canMoveFolder(folders, "physique", "physique")).toBe(false);
    expect(canMoveFolder(folders, "physique", "thermo")).toBe(false);
  });

  it("refuse ce qui creuserait le classeur trop profond", () => {
    const deep: FolderNode[] = [];
    for (let level = 0; level < FOLDER_MAX_DEPTH; level += 1) {
      deep.push(folder(`n${level}`, level === 0 ? null : `n${level - 1}`));
    }
    deep.push(folder("seul"));

    // Le dernier niveau est déjà au plafond : rien ne peut y entrer.
    expect(canMoveFolder(deep, "seul", `n${FOLDER_MAX_DEPTH - 1}`)).toBe(false);
    expect(canMoveFolder(deep, "seul", `n${FOLDER_MAX_DEPTH - 2}`)).toBe(true);
  });
});
