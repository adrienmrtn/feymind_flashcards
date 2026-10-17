import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  EXCERPT,
  excerptBudget,
  excerptForTheme,
  GAP,
  splitPassages,
  termsOf,
  WHOLE_SOURCE,
} from "./excerpt.ts";

/** Un cours de biologie en huit chapitres, chacun avec son vocabulaire. */
const CHAPTERS = [
  {
    title: "La photosynthèse",
    words: ["photosynthèse", "chlorophylle", "lumière", "chloroplaste"],
  },
  {
    title: "La respiration cellulaire",
    words: ["respiration", "mitochondrie", "glucose", "oxygène"],
  },
  { title: "La division cellulaire", words: ["mitose", "chromosomes", "centromère", "fuseau"] },
  { title: "L'ADN et les gènes", words: ["ADN", "gènes", "nucléotides", "hélice"] },
  {
    title: "La synthèse des protéines",
    words: ["protéines", "ribosome", "acides aminés", "traduction"],
  },
  { title: "Le système immunitaire", words: ["anticorps", "lymphocytes", "antigène", "vaccin"] },
  { title: "Le système nerveux", words: ["neurones", "synapse", "influx", "axone"] },
  {
    title: "L'évolution des espèces",
    words: ["évolution", "sélection naturelle", "Darwin", "espèces"],
  },
];

const FILLER =
  "Le cours insiste sur ce point, et le professeur le reprend en classe avec un schéma.";

function chapter(index: number): string {
  const { title, words } = CHAPTERS[index]!;
  const paragraphs = [0, 1, 2, 3].map((p) =>
    Array.from({ length: 5 }, (_, s) => {
      const word = words[(p + s) % words.length]!;
      return `Dans ce passage ${index + 1}.${p + 1}, ${word} joue un rôle précis. ${FILLER}`;
    }).join(" ")
  );
  return [`Chapitre ${index + 1} : ${title}`, ...paragraphs].join("\n\n");
}

const COURSE = CHAPTERS.map((_, index) => chapter(index)).join("\n\n");
const THEMES = CHAPTERS.map((entry) => entry.title);

Deno.test("le cours d'essai est assez long pour être découpé", () => {
  assert(COURSE.length > WHOLE_SOURCE);
});

Deno.test("un support court part entier", () => {
  const short = chapter(0);
  assert(short.length <= WHOLE_SOURCE);
  assertEquals(excerptForTheme(short, THEMES, 3), short.trim());
});

Deno.test("le budget fait trois parts, borné des deux côtés", () => {
  assertEquals(excerptBudget(60_000, 12), 15_000);
  assertEquals(excerptBudget(20_000, 8), EXCERPT.min);
  assertEquals(excerptBudget(60_000, 4), EXCERPT.max);
});

Deno.test("chaque thème lit son chapitre, et pas plus que son budget", () => {
  const budget = excerptBudget(COURSE.length, THEMES.length);
  THEMES.forEach((title, index) => {
    const excerpt = excerptForTheme(COURSE, THEMES, index);
    assert(excerpt.length < COURSE.length, `thème ${index} : rien n'a été retiré`);
    // Les séparateurs ajoutés ne comptent pas dans le budget, le texte du document si.
    assert(excerpt.replaceAll(GAP, "").length <= budget + 200, `thème ${index} : budget dépassé`);
    assert(
      excerpt.includes(`Chapitre ${index + 1} : ${title}`),
      `thème ${index} : son titre manque`,
    );
    for (const word of CHAPTERS[index]!.words) {
      assert(excerpt.includes(word), `thème ${index} : « ${word} » manque`);
    }
  });
});

Deno.test("mis ensemble, les extraits couvrent tout le cours", () => {
  const read = THEMES.map((_, index) => excerptForTheme(COURSE, THEMES, index)).join("\n");
  for (const passage of splitPassages(COURSE)) {
    assert(read.includes(passage.text), `jamais lu : ${passage.text.slice(0, 60)}`);
  }
});

Deno.test("les passages gardés restent dans l'ordre du document", () => {
  const excerpt = excerptForTheme(COURSE, THEMES, 4);
  const starts = excerpt
    .split(`\n\n${GAP}\n\n`)
    .map((block) => COURSE.indexOf(block));
  assert(starts.every((start) => start >= 0), "un extrait n'est pas un morceau du document");
  assertEquals([...starts].sort((a, b) => a - b), starts);
});

Deno.test("une notion posée au début est retrouvée par un thème de la fin", () => {
  const themes = [...THEMES];
  themes[7] = "La chlorophylle dans l'évolution";
  const excerpt = excerptForTheme(COURSE, themes, 7);
  assert(excerpt.includes("chlorophylle"));
  assert(excerpt.includes("Darwin"));
  assert(excerpt.includes(GAP), "le passage du début devrait être séparé du reste");
});

Deno.test("sans mot reconnu, la place décide : le premier thème lit le début, le dernier la fin", () => {
  const themes = ["Partie 1", "Partie 2", "Partie 3", "Partie 4", "Partie 5", "Partie 6"];
  const first = excerptForTheme(COURSE, themes, 0);
  const last = excerptForTheme(COURSE, themes, themes.length - 1);
  assert(first.startsWith("Chapitre 1 : La photosynthèse"));
  assert(!first.includes("Chapitre 8"));
  assert(last.includes("Chapitre 8 : L'évolution des espèces"));
  assert(!last.includes("Chapitre 1 :"));
});

Deno.test("un document en une seule ligne est découpé à ses phrases, et la place reste juste", () => {
  const flat = COURSE.replace(/\n+/g, " ");
  const passages = splitPassages(flat);
  assert(passages.length > 20);
  assert(passages.every((passage) => passage.text.length <= 1_600));
  assert(passages[0]!.position < 0.05);
  assert(passages[passages.length - 1]!.position > 0.95);

  const themes = ["Partie 1", "Partie 2", "Partie 3", "Partie 4", "Partie 5", "Partie 6"];
  assert(excerptForTheme(flat, themes, 0).startsWith("Chapitre 1 : La photosynthèse"));
  assert(excerptForTheme(flat, themes, 5).includes("Darwin"));
});

Deno.test("un titre seul s'accroche au paragraphe qu'il annonce", () => {
  const passages = splitPassages(COURSE);
  const heading = passages.find((passage) => passage.text.startsWith("Chapitre 2 :"));
  assert(heading);
  assert(heading.text.includes("respiration"), "le titre est resté seul");
});

Deno.test("les mots du titre : sans accents, sans mots-outils, ramenés à leur racine", () => {
  assertEquals(termsOf("Les Révolutions de 1848"), ["revol", "1848"]);
  assertEquals(termsOf("La crise"), termsOf("les crises"));
  assertEquals(termsOf("Partie 2 : introduction"), []);
});

Deno.test("les points du plan désignent les passages mieux que le titre", () => {
  const themes = THEMES.map((_, index) => `Partie ${index + 1}`);
  const points = themes.map(() => [] as string[]);
  points[0] = ["Darwin et la sélection naturelle"];
  const excerpt = excerptForTheme(COURSE, themes, 0, points);
  assert(excerpt.startsWith("Chapitre 1 : La photosynthèse"), "la place garde le début");
  assert(excerpt.includes("Darwin"), "le point a ramené le chapitre de la fin");
});
