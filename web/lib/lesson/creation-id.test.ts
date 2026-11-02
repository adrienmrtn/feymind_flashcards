import { describe, expect, it } from "vitest";

import type { LessonCreation } from "@micabo/core";

import {
  CREATION_ID_PREFIX,
  CREATION_ID_TTL_MS,
  creationKey,
  forgetCreation,
  lessonIdForCreation,
  type CreationStorage,
} from "./creation-id";

function memoryStorage(): CreationStorage & { size: () => number } {
  const items = new Map<string, string>();
  return {
    getItem: (key) => items.get(key) ?? null,
    setItem: (key, value) => void items.set(key, value),
    removeItem: (key) => void items.delete(key),
    size: () => items.size,
  };
}

const topic: LessonCreation = { topic: "La photosynthèse", text: "", images: [], source: "topic" };
const other: LessonCreation = { topic: "La Révolution française", text: "", images: [], source: "topic" };

const A = "6f9619ff-8b86-d011-b42d-00c04fc964ff";
const B = "0b2f3c4d-1111-4222-8333-944455556666";

describe("lessonIdForCreation", () => {
  it("rend le même identifiant au même brouillon, d'un chargement à l'autre", () => {
    const storage = memoryStorage();
    const first = lessonIdForCreation(topic, storage, { now: 0, make: () => A });
    const again = lessonIdForCreation({ ...topic }, storage, { now: 60_000, make: () => B });
    expect(first).toBe(A);
    expect(again).toBe(A);
  });

  it("tire un identifiant neuf pour un autre brouillon", () => {
    const storage = memoryStorage();
    lessonIdForCreation(topic, storage, { now: 0, make: () => A });
    expect(lessonIdForCreation(other, storage, { now: 0, make: () => B })).toBe(B);
  });

  it("oublie l'identifiant une fois la leçon créée", () => {
    const storage = memoryStorage();
    lessonIdForCreation(topic, storage, { now: 0, make: () => A });
    forgetCreation(topic, storage);
    expect(storage.size()).toBe(0);
    expect(lessonIdForCreation(topic, storage, { now: 0, make: () => B })).toBe(B);
  });

  it("ne reprend pas un identifiant de plus d'une journée", () => {
    const storage = memoryStorage();
    lessonIdForCreation(topic, storage, { now: 0, make: () => A });
    expect(lessonIdForCreation(topic, storage, { now: CREATION_ID_TTL_MS + 1, make: () => B })).toBe(B);
  });

  it("ignore une entrée illisible, et vit sans stockage", () => {
    const storage = memoryStorage();
    storage.setItem(creationKey(topic), "{pas du json");
    expect(lessonIdForCreation(topic, storage, { now: 0, make: () => A })).toBe(A);
    expect(lessonIdForCreation(topic, null, { now: 0, make: () => B })).toBe(B);
  });

  it("survit à un stockage qui refuse d'écrire", () => {
    const refusing: CreationStorage = {
      getItem: () => null,
      setItem: () => {
        throw new Error("QuotaExceededError");
      },
      removeItem: () => undefined,
    };
    expect(lessonIdForCreation(topic, refusing, { now: 0, make: () => A })).toBe(A);
  });
});

describe("creationKey", () => {
  it("ne porte pas le texte, et distingue les supports", () => {
    const text: LessonCreation = { text: "x".repeat(50_000), images: [], source: "text" };
    const key = creationKey(text);
    expect(key.startsWith(CREATION_ID_PREFIX)).toBe(true);
    expect(key.length).toBeLessThan(CREATION_ID_PREFIX.length + 20);
    expect(creationKey({ ...text, source: "pdf" })).not.toBe(key);
    expect(creationKey({ ...text, images: ["data:image/png;base64,AAAA"] })).not.toBe(key);
  });
});
