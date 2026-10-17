import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  allowedRole,
  guessMaterial,
  guessRole,
  isExamOriented,
  MATERIAL_PLAN_RULES,
  MATERIALS,
  materialHeader,
  materialThemeBrief,
  planMaterialBrief,
  readMaterial,
  readMaterialHeader,
  readRole,
} from "./material.ts";

Deno.test("la nature du support se lit comme le modèle l'écrit", () => {
  for (const material of MATERIALS) assertEquals(readMaterial(material), material);
  assertEquals(readMaterial("Dissertation"), "essay");
  assertEquals(readMaterial("copie"), "essay");
  assertEquals(readMaterial("corrigé"), "essay");
  assertEquals(readMaterial("past paper"), "exam");
  assertEquals(readMaterial("YouTube"), "lecture");
  assertEquals(readMaterial("transcript"), "lecture");
  assertEquals(readMaterial("diapositives"), "slides");
  assertEquals(readMaterial("cours"), "chapter");
  assertEquals(readMaterial("poème"), null);
  assertEquals(readMaterial(42), null);
});

Deno.test("le rôle d'un thème : inconnu, il est ordinaire", () => {
  assertEquals(readRole("method"), "method");
  assertEquals(readRole("Méthode"), "method");
  assertEquals(readRole("key terms"), "keyterms");
  assertEquals(readRole("glossaire"), "keyterms");
  assertEquals(readRole("problématique"), "decrypt");
  assertEquals(readRole("exercice"), "exercise");
  assertEquals(readRole("partie"), "core");
  assertEquals(readRole("n'importe quoi"), "core");
  assertEquals(readRole(undefined), "core");
});

Deno.test("la nature du support se devine prudemment sur le texte", () => {
  assertEquals(guessMaterial("Bonjour à tous, aujourd'hui on va parler de…", "youtube"), "lecture");
  assertEquals(guessMaterial("…", "audio"), "lecture");
  assertEquals(guessMaterial("", "text"), "topic");
  assertEquals(guessMaterial("peu importe", "topic"), "topic");
  const exam = "Baccalauréat 2024. Durée de l'épreuve : 4 h. L'usage de la calculatrice est autorisé.\nExercice 1 (5 points)\n1. Calculer…\nExercice 2 (6 points)";
  assertEquals(guessMaterial(exam, "pdf"), "exam");
  const essay = "Introduction. Accroche… Problématique : assiste-t-on à la fin de l'ouverture commerciale ?\nAnnonce du plan.\nI. Les signes d'une fin apparente\nTransition.\nII. Des fondations qui perdurent\nIII. Une transformation\nConclusion. Ouverture.";
  assertEquals(guessMaterial(essay, "photo"), "essay");
  const chapter = "Chapitre 3 : La photosynthèse\n1. La phase claire\nLes chloroplastes captent la lumière…\n2. La phase sombre\nLe cycle de Calvin…";
  assertEquals(guessMaterial(chapter, "pdf"), "chapter");
  // Un cours qui parle une fois d'« exercice » n'est pas un sujet d'examen.
  assertEquals(guessMaterial("Le cours. Voir l'exercice 3 du manuel pour s'entraîner.", "pdf"), "chapter");
});

Deno.test("le rôle se devine sur le titre quand le plan ne l'a pas transmis", () => {
  assertEquals(guessRole("Méthode et repères pour la copie", "essay"), "method");
  assertEquals(guessRole("Concepts-clés à maîtriser", "chapter"), "keyterms");
  assertEquals(guessRole("Key terms", "article"), "keyterms");
  assertEquals(guessRole("Décrypter le sujet", "essay"), "decrypt");
  assertEquals(guessRole("Décrypter le sujet", "chapter"), "core", "un cours n'a pas de sujet à décrypter");
  assertEquals(guessRole("Exercice 2 : les suites", "exam"), "exercise");
  assertEquals(guessRole("Les causes de la crise", "chapter"), "core");
});

Deno.test("la méthode de l'épreuve n'a sa place que dans une leçon tournée vers l'épreuve", () => {
  assertEquals(allowedRole("method", "chapter", false), "core");
  assertEquals(allowedRole("method", "chapter", true), "method");
  assertEquals(allowedRole("method", "essay", false), "method");
  assertEquals(allowedRole("method", "exam", false), "method");
  assertEquals(allowedRole("method", "lecture", false), "core");
  assertEquals(allowedRole("decrypt", "lecture", true), "core");
  assertEquals(allowedRole("decrypt", "topic", false), "decrypt", "un sujet de dissertation tapé se décrypte");
  assertEquals(allowedRole("exercise", "essay", true), "core");
  assertEquals(allowedRole("exercise", "exam", false), "exercise");
  assertEquals(allowedRole("keyterms", "lecture", false), "keyterms");
});

Deno.test("l'orientation vers l'épreuve vient de l'élève", () => {
  assert(isExamOriented({ tier: "upperSecondary", exam: "Bac de français" }));
  assert(isExamOriented({ tier: "competitive" }));
  assert(isExamOriented({ tier: "preUniversity" }));
  assert(isExamOriented({ tier: "undergraduate", worries: ["examStress"] }));
  assert(!isExamOriented({ tier: "undergraduate" }));
  assert(!isExamOriented({ tier: "lowerSecondary", worries: ["forgetting"] }));
});

Deno.test("la nature du support et les rôles voyagent en tête du texte de référence", () => {
  const header = materialHeader("essay", ["decrypt", "core", "core", "core", "method", "keyterms"]);
  // Rien que l'app iOS retirerait (`TextSanitizer.removeInlineMarkup`).
  for (const mark of ["**", "==", "`", "*", "_"]) assert(!header.includes(mark), mark);
  const context = `${header}Le texte de la copie.\nSa suite.`;
  const read = readMaterialHeader(context);
  assertEquals(read.material, "essay");
  assertEquals(read.roles, ["decrypt", "core", "core", "core", "method", "keyterms"]);
  assertEquals(read.text, "Le texte de la copie.\nSa suite.");
  // Une leçon d'avant : pas d'en-tête, le texte revient tel quel.
  assertEquals(readMaterialHeader("Chapitre 1. La cellule."), { text: "Chapitre 1. La cellule." });
  // Un en-tête abîmé ne fait pas inventer de nature.
  const broken = readMaterialHeader("NATURE DU SUPPORT : poeme\n\nTexte.");
  assertEquals(broken.material, undefined);
  assertEquals(broken.text, "Texte.");
  // Les rôles inconnus redeviennent ordinaires.
  assertEquals(readMaterialHeader("NATURE DU SUPPORT : exam\nRÔLES DES THÈMES : exercise bidule\n\nX").roles, ["exercise", "core"]);
});

Deno.test("le plan reconnaît le support et bâtit sa structure sur lui", () => {
  for (const material of MATERIALS) assert(MATERIAL_PLAN_RULES.includes(`"${material}"`), material);
  for (const part of ["COUVERTURE", "n'omets pas", "ne fusionne jamais", "jamais une tranche de minutes", "« Concepts-clés »", "UN thème par partie"]) {
    assert(MATERIAL_PLAN_RULES.includes(part), part);
  }
  const video = planMaterialBrief({ guess: "lecture", fromScratch: false, register: "fiche", examOriented: false });
  assert(video.includes(`"material" vaut "lecture"`));
  assert(video.includes("fiche condensée"));
  assert(video.includes("ORIENTATION EXAMEN : non"));
  const topic = planMaterialBrief({ guess: "topic", fromScratch: true, register: "guided", examOriented: true });
  assert(topic.includes(`"material" vaut "topic"`));
  assert(topic.includes("ORIENTATION EXAMEN : oui"));
  assert(planMaterialBrief({ guess: "chapter", fromScratch: false, register: "explained", examOriented: false }).includes("Corrige-la"));
});

Deno.test("la forme d'un thème suit le support, son rôle et le registre", () => {
  const brief = (material: Parameters<typeof materialThemeBrief>[0]["material"], role: Parameters<typeof materialThemeBrief>[0]["role"], register: "fiche" | "explained" | "guided", examOriented = false) =>
    materialThemeBrief({ material, role, register, examOriented });
  // Quatre supports, quatre consignes distinctes.
  const four = [brief("chapter", "core", "fiche"), brief("lecture", "core", "fiche"), brief("essay", "core", "fiche"), brief("exam", "exercise", "fiche")];
  assertEquals(new Set(four).size, 4);
  assert(four[1]!.includes("TRANSCRIPTION"));
  assert(four[2]!.includes("**Ainsi**"));
  assert(four[3]!.includes("UN EXERCICE DU SUJET"));
  // Le registre : une fiche avancée, des notes expliquées, des notes guidées.
  assert(brief("chapter", "core", "fiche").includes("FICHE CONDENSÉE"));
  assert(brief("chapter", "core", "fiche").includes("**un terme de tête**"));
  assert(brief("chapter", "core", "explained").includes("STRUCTURÉES ET EXPLIQUÉES"));
  assert(brief("chapter", "core", "guided").includes("GUIDÉES"));
  // Les rôles.
  assert(brief("essay", "decrypt", "fiche").includes("DÉCRYPTE LE SUJET"));
  assert(brief("essay", "method", "fiche").includes("**Gestion du temps**"));
  assert(brief("chapter", "keyterms", "guided").includes(`"table" à deux colonnes`));
  // Un cours lu en vue d'une épreuve : un réflexe de méthode en encadré, pas un thème entier.
  assert(brief("chapter", "core", "explained", true).includes(`"callout" "tip"`));
  assert(!brief("chapter", "core", "explained", false).includes(`"callout" "tip"`));
  assert(!brief("essay", "core", "fiche", true).includes(`"callout" "tip"`), "la copie a déjà son thème de méthode");
});
