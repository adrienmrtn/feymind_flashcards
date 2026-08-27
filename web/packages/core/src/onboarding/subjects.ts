/**
 * Les matières proposées à l'inscription, par familles.
 *
 * Portées depuis `Micabo/Features/Onboarding/SubjectCatalog.swift`.
 *
 * La seule règle qui compte ici, et elle est verrouillée par un test : **aucune matière ne porte
 * l'emoji d'une autre.** Sept familles côte à côte, c'est une cinquantaine de pastilles sur un
 * écran ; deux pastilles identiques obligent à lire les libellés un par un, ce qui est exactement
 * le travail que l'emoji devait éviter.
 *
 * L'emoji n'est pas écrit ici : il vient de la **même table** que les cours importés. Une
 * deuxième liste tenue en parallèle finirait par ne plus dire la même chose que la première, et
 * l'écran des matières donnerait à une matière un emoji que ses cours n'ont pas.
 */

import { deriveEmoji } from "../emoji";

export interface SubjectFamily {
  name: string;
  subjects: readonly string[];
}

export const SUBJECT_FAMILIES: readonly SubjectFamily[] = [
  {
    name: "Sciences",
    subjects: [
      "Mathématiques",
      "Physique",
      "Chimie",
      "SVT",
      "Statistiques",
      "Astronomie",
      "Géologie",
    ],
  },
  {
    name: "Santé",
    subjects: ["Médecine", "Pharmacie", "Soins infirmiers", "Kinésithérapie", "Anatomie", "Nutrition"],
  },
  {
    name: "Sciences humaines",
    subjects: [
      "Histoire",
      "Géographie",
      "Philosophie",
      "Sociologie",
      "Psychologie",
      "Sciences politiques",
    ],
  },
  {
    name: "Langues",
    subjects: [
      "Anglais",
      "Espagnol",
      "Allemand",
      "Italien",
      "Portugais",
      "Japonais",
      "Chinois",
      "Arabe",
      "Russe",
      "Latin & grec",
      "Français",
    ],
  },
  {
    name: "Droit & économie",
    subjects: ["Droit", "Économie", "Comptabilité", "Finance", "Management", "Marketing"],
  },
  {
    name: "Technique",
    subjects: [
      "Informatique",
      "Algorithmique",
      "Réseaux",
      "Électronique",
      "Mécanique",
      "Génie civil",
      "Architecture",
    ],
  },
  {
    name: "Et aussi",
    subjects: [
      "Arts",
      "Musique",
      "Cinéma",
      "Théâtre",
      "Danse",
      "Photographie",
      "Journalisme",
      "Pédagogie",
      "Sport & STAPS",
      "Code de la route",
      "Culture générale",
    ],
  },
];

export const ALL_SUBJECTS: readonly string[] = SUBJECT_FAMILIES.flatMap(
  (family) => family.subjects,
);

/** L'emoji d'une matière du catalogue, déduit comme celui d'un cours qui porterait ce nom-là. */
export function subjectEmoji(subject: string): string {
  return deriveEmoji(subject, subject);
}
