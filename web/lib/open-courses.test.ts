import { describe, expect, it } from "vitest";

import { parseOpenCourses, pinCourse, unpinCourse } from "./open-courses";

const alpha = { id: "a", title: "Photosynthèse", emoji: "🌿" };
const beta = { id: "b", title: "La Révolution", emoji: "🇫🇷" };
const gamma = { id: "c", title: "Le cycle de l'eau", emoji: "💧" };

describe("les cours ouverts", () => {
  it("reprend l'ancien onglet unique", () => {
    expect(parseOpenCourses(null, JSON.stringify(alpha))).toEqual([alpha]);
  });

  it("préfère la liste quand elle existe", () => {
    expect(parseOpenCourses(JSON.stringify([beta, alpha]), JSON.stringify(alpha))).toEqual([
      beta,
      alpha,
    ]);
  });

  it("ajoute sans fermer les autres, et remonte celui qu'on rouvre", () => {
    expect(pinCourse([alpha], beta)).toEqual([beta, alpha]);
    expect(pinCourse([alpha, beta], alpha)).toEqual([alpha, beta]);
  });

  it("ferme un cours sans toucher aux autres", () => {
    expect(unpinCourse([alpha, beta, gamma], beta.id)).toEqual([alpha, gamma]);
  });
});
