import { assert, assertEquals } from "jsr:@std/assert@1";
import { depthOf } from "../_shared/learner.ts";
import { openingOf, PLAN_SYSTEM_PROMPT, PLAN_TOKENS, THEME_SYSTEM_PROMPT, THEME_TOKENS, themeBrief } from "./prompt.ts";

const base = {
  lessonTitle: "La fin de l'ouverture commerciale ?",
  themes: ["Décrypter le sujet", "I. Une fin apparente", "II. Des fondations solides", "III. Une transformation", "Méthode pour la copie", "Concepts-clés"],
  questions: 6,
  flashcards: 6,
  kinds: ["choice"],
} as const;

function brief(options: Partial<Parameters<typeof themeBrief>[0]> & { themeIndex: number }): string {
  return themeBrief({ ...base, themes: [...base.themes], kinds: [...base.kinds], themeTitle: base.themes[options.themeIndex]!, ...options });
}

Deno.test("le plan demande la nature du support et un rôle par thème", () => {
  assert(PLAN_SYSTEM_PROMPT.includes(`{"material":"…"`));
  assert(PLAN_SYSTEM_PROMPT.includes(`"role":"core"`));
  assert(PLAN_SYSTEM_PROMPT.includes("RECONNAIS LE SUPPORT"));
  assert(PLAN_SYSTEM_PROMPT.includes("2 à 6 notions"));
  assert(PLAN_SYSTEM_PROMPT.includes("« I. Une fin apparente »"));
});

Deno.test("les plafonds de sortie : le plan grandit, le thème reste à 8 192", () => {
  assertEquals(PLAN_TOKENS, 4_096);
  assertEquals(THEME_TOKENS, 8_192);
});

Deno.test("un emoji n'est permis qu'en fin de sous-titre", () => {
  assert(THEME_SYSTEM_PROMPT.includes("un seul à la fin d'un sous-titre"));
  assert(THEME_SYSTEM_PROMPT.includes("c'est le seul endroit des notes où un emoji est permis"));
  assert(!THEME_SYSTEM_PROMPT.includes("aucun emoji, aucun tiret"), "l'interdiction absolue d'avant a disparu");
});

Deno.test("quatre supports donnent quatre formes de thème", () => {
  const depth = depthOf("preUniversity");
  const forms = [
    brief({ themeIndex: 1, depth, material: "chapter", role: "core" }),
    brief({ themeIndex: 1, depth, material: "lecture", role: "core" }),
    brief({ themeIndex: 1, depth, material: "essay", role: "core" }),
    brief({ themeIndex: 1, depth, material: "exam", role: "exercise" }),
  ].map((text) => text.split("FORME DE CE THÈME")[1]!.split("VOLUME")[0]!);
  assertEquals(new Set(forms).size, 4);
  assert(forms[0]!.includes("CHAPITRE DE COURS"));
  assert(forms[1]!.includes("TRANSCRIPTION"));
  assert(forms[2]!.includes("DISSERTATION"));
  assert(forms[3]!.includes("SUJET D'EXAMEN") && forms[3]!.includes("UN EXERCICE DU SUJET"));
});

Deno.test("le niveau règle le style : une fiche avancée, des notes guidées au collège", () => {
  const advanced = brief({ themeIndex: 1, depth: depthOf("undergraduate"), material: "chapter" });
  const young = brief({ themeIndex: 1, depth: depthOf("lowerSecondary"), material: "chapter" });
  assert(advanced.includes("FICHE CONDENSÉE"));
  assert(advanced.includes("des listes de 8 puces au plus, de 28 mots"));
  assert(young.includes("STYLE DES NOTES : GUIDÉES"));
  assert(young.includes("des listes de 5 puces au plus, de 16 mots"));
  // Sans support connu, un chapitre ; sans marche, des notes expliquées.
  assert(themeBrief({ ...base, themes: [...base.themes], kinds: ["choice"], themeTitle: "T", themeIndex: 0 }).includes("STRUCTURÉES ET EXPLIQUÉES"));
});

Deno.test("l'ouverture du thème est subordonnée au support : le rôle, puis le registre, puis le rang", () => {
  assertEquals(openingOf(4, "method", "fiche"), null);
  assertEquals(openingOf(0, "decrypt", "explained"), null);
  assertEquals(openingOf(5, "keyterms", "guided"), null);
  assert(openingOf(0, "core", "fiche")!.includes("phrase de cadrage"));
  assert(openingOf(0, "core", "explained")!.includes("l'accroche"));
  assert(!openingOf(0, "core", "fiche")!.includes("accroche"), "une fiche n'ouvre pas sur une accroche");
  assert(openingOf(1, "core", "fiche") !== openingOf(2, "core", "fiche"), "deux thèmes voisins n'ouvrent pas pareil");
  const method = brief({ themeIndex: 4, depth: depthOf("competitive"), material: "essay", role: "method" });
  assert(method.includes("LA MÉTHODE DE L'ÉPREUVE"));
  assert(!method.includes("Les autres thèmes sont écrits à part : pour que"), "le rôle décide de la forme, pas le rang");
});

Deno.test("la méthode en encadré pour un cours lu en vue d'une épreuve", () => {
  const prepared = brief({ themeIndex: 1, depth: depthOf("upperSecondary"), material: "chapter", examOriented: true });
  const relaxed = brief({ themeIndex: 1, depth: depthOf("upperSecondary"), material: "chapter", examOriented: false });
  assert(prepared.includes("L'élève prépare une épreuve"));
  assert(!relaxed.includes("L'élève prépare une épreuve"));
});

Deno.test("le prompt du thème interdit les encadrés par réflexe et les redites", () => {
  assert(THEME_SYSTEM_PROMPT.includes("Zéro à trois encadrés"));
  assert(THEME_SYSTEM_PROMPT.includes("qui ne répètent ni le \"oneLiner\""));
  assert(THEME_SYSTEM_PROMPT.includes("n'appartient qu'à UN thème"));
});
