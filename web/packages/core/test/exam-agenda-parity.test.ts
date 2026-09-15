import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { MOCK_OFFSETS, MOCK_SLOT_SLACK } from "../src/srs/mock";
import {
  PARCOURS_CHOICE_COUNT,
  PARCOURS_FIRST_OFFSET,
  PARCOURS_MAX,
  PARCOURS_MINUTES,
  PARCOURS_ORAL_COUNT,
  PARCOURS_QUESTION_COUNT,
  PARCOURS_TIGHT_WINDOW,
} from "../src/srs/parcours";

/**
 * **Deux calendriers qui ne posent pas les mêmes jours sont deux produits.**
 *
 * La planification des blancs n'avait jamais quitté ce paquet : l'app affichait un bouton
 * « passer un blanc » et n'avait pas à savoir quel jour il tombait. Un mini-calendrier, lui,
 * doit dessiner des jours hors ligne, donc la cadence est recopiée en Swift.
 *
 * Une recopie diverge, et celle-ci divergerait en silence : l'étudiant ouvrirait le site après
 * son téléphone et verrait sa semaine bouger sans avoir rien fait. Ce test relit donc le Swift
 * et compare les nombres, comme `sheet-parity` le fait pour le balisage.
 *
 * Il ne peut pas exécuter l'algorithme Swift. Il vérifie ce qui se vérifie de l'extérieur : les
 * constantes, et la forme de la boucle qui les emploie.
 */

const here = dirname(fileURLToPath(import.meta.url));
const swift = readFileSync(
  resolve(here, "../../../..", "Micabo/SRS/ExamAgenda.swift"),
  "utf8",
);

/** La valeur d'un `static let` du fichier Swift. */
function constant(name: string): string {
  const match = swift.match(new RegExp(`static let ${name}\\s*(?::[^=]+)?=\\s*([^\\n]+)`));
  expect(match, `\`${name}\` introuvable dans ExamAgenda.swift`).not.toBeNull();
  return match![1]!.trim();
}

function number(name: string): number {
  return Number(constant(name));
}

describe("l'agenda, des deux côtés", () => {
  it("pose les blancs aux mêmes jours", () => {
    expect(constant("mockOffsets")).toBe(`[${MOCK_OFFSETS.join(", ")}]`);
    expect(number("mockSlack")).toBe(MOCK_SLOT_SLACK);
  });

  it("donne aux parcours la même cadence", () => {
    expect(number("parcoursFirstOffset")).toBe(PARCOURS_FIRST_OFFSET);
    expect(number("parcoursTightWindow")).toBe(PARCOURS_TIGHT_WINDOW);
    expect(number("parcoursMax")).toBe(PARCOURS_MAX);

    // Les deux régimes, et non une moyenne. S'ils divergeaient, un même examen porterait des
    // rendez-vous à des jours différents selon l'écran ouvert.
    expect(number("parcoursTightStep")).toBe(2);
    expect(number("parcoursLooseStep")).toBe(3);
  });

  it("garde le même format de test", () => {
    expect(number("parcoursChoiceCount")).toBe(PARCOURS_CHOICE_COUNT);
    expect(number("parcoursOralCount")).toBe(PARCOURS_ORAL_COUNT);
    expect(number("parcoursQuestionCount")).toBe(PARCOURS_QUESTION_COUNT);
    expect(number("parcoursMinutes")).toBe(PARCOURS_MINUTES);
  });

  it("emploie la cadence de la même façon", () => {
    // Les constantes peuvent coïncider et la boucle différer. Celle-ci est courte : on vérifie
    // qu'elle change de pas au même endroit, et qu'elle s'arrête sur les deux mêmes bornes.
    expect(swift).toContain("offset < parcoursTightWindow ? parcoursTightStep : parcoursLooseStep");
    expect(swift).toContain("offset <= daysRemaining && offsets.count < Swift.max(0, limit)");
    expect(swift).toContain("guard daysRemaining >= parcoursFirstOffset else { return [] }");
  });

  it("accorde au parcours la tolérance étroite, et au blanc la large", () => {
    // Une tolérance de trois jours sur des rendez-vous posés tous les deux ferait qu'un seul
    // test coché en effacerait trois.
    expect(number("parcoursSlack")).toBe(1);
    expect(number("parcoursSlack")).toBeLessThan(number("mockSlack"));
  });

  it("écarte le parcours du blanc dans le même sens", () => {
    // Vers l'arrière des deux côtés : vers l'avant, le test finirait la veille de l'épreuve.
    expect(swift).toContain("value: -1, to: date");
    expect(swift).toContain("planned[index].kind == .parcours");
  });
});
