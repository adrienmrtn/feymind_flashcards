import { assertEquals } from "jsr:@std/assert@1";

import { SHEET_HIGHLIGHTS, type SheetBlock, stripInlineMarkup } from "../_shared/sheet.ts";
import {
  applyAnchors,
  batched,
  cleanBlockMarks,
  countMarks,
  emptyApplyReport,
  type MarkAnchor,
  MARK_SYSTEM_PROMPT,
  type MarkCandidate,
  markPrompt,
  markTargets,
  type MarkWish,
  planMarkPass,
  readAnchors,
  textsToMark,
} from "./marks.ts";

const PARAGRAPH = (text: string): SheetBlock => ({ type: "paragraph", text });

const BOLD = (text: number, quote: string): MarkAnchor => ({
  text,
  kind: "bold",
  colour: null,
  quote,
});

const HIGHLIGHT = (text: number, colour: string, quote: string): MarkAnchor => ({
  text,
  kind: "highlight",
  colour,
  quote,
});

const WISH = (wish: Partial<MarkWish> = {}): MarkWish => ({
  bold: false,
  highlight: false,
  italic: false,
  ...wish,
});

/** Un paragraphe de fiche : assez long pour porter des marques, et nu. */
const NU =
  "La phase photochimique se déroule dans les thylakoïdes et produit l'ATP ainsi que le NADPH. " +
  "Le rendement de conversion réel atteint 2 pour cent sur une feuille bien exposée, très loin " +
  "du maximum théorique de 11 pour cent, et cet écart tient aux pertes par photorespiration.";

Deno.test("countMarks ne prend pas le gras pour de l'italique", () => {
  const marks = countMarks([
    PARAGRAPH("La **phase photochimique** produit l'ATP, et le rendement reste *apparent*."),
  ]);
  assertEquals(marks.bold, 1);
  assertEquals(marks.italic, 1);
  assertEquals(marks.highlight, 0);
});

Deno.test("countMarks compte les surlignages et les formules", () => {
  const marks = countMarks([
    PARAGRAPH("==menthe|Le rendement vaut $1$ à $2$ %== sur une feuille bien exposée."),
    { type: "list", ordered: false, items: ["==jaune|Un point marqué==", "Un point nu"] },
  ]);
  assertEquals(marks.highlight, 2);
  assertEquals(marks.math, 2);
});

Deno.test("la seconde passe se déclenche sur la densité, pas sur le zéro", () => {
  // Un paragraphe court et bien marqué : rien à redemander.
  const marked = [
    PARAGRAPH("La **Rubisco** fixe le carbone, ==jaune|et c'est l'étape limitante== du cycle."),
    PARAGRAPH("Le terme *stroma* désigne le compartiment, pas la membrane du thylakoïde."),
  ];
  assertEquals(planMarkPass(marked), null);

  // Le cas qui échappait au contrôle d'avant : un pavé de six cents caractères portant un
  // seul terme en gras. Zéro nulle part, et pourtant une page sans relief.
  const pavé = PARAGRAPH(
    "Les **forces** de l'entreprise tiennent à ses fondateurs, à sa technologie brevetée et à une licence exclusive. " +
      "Le plan de financement détaille chaque poste de dépense sur trois ans. ".repeat(7),
  );
  assertEquals(planMarkPass([pavé])?.candidates.length, 1);
  assertEquals(planMarkPass([]), null);
});

Deno.test("la passe ne reçoit que les textes qui ont la place d'une marque", () => {
  // Mesuré sur une fiche courante : quarante-deux textes partaient, dont six titres et seize
  // points de liste, tous trop courts pour porter quoi que ce soit. On payait leur place dans
  // la consigne, et le modèle y cherchait des marques qui n'avaient nulle part où se poser.
  const blocks: SheetBlock[] = [
    { type: "heading", level: 1, text: "Le cycle de Calvin" },
    PARAGRAPH(NU),
    { type: "list", ordered: false, items: ["La fixation", "La réduction"] },
    PARAGRAPH(NU.replace("photochimique", "sombre")),
  ];

  // textsToMark rend cinq textes ; seuls les deux paragraphes ont la place.
  assertEquals(textsToMark(blocks).length, 5);
  assertEquals(planMarkPass(blocks)?.candidates.map((c) => c.index), [1, 4]);
});

Deno.test("une fiche qui n'a nulle part où poser une marque ne déclenche aucun appel", () => {
  // Des marques manquent - le déclenchement le dit - mais rien n'est assez long pour en
  // porter. Le seul appel dont on soit certain qu'il ne servirait à rien.
  const blocks: SheetBlock[] = [
    { type: "heading", level: 1, text: "Premier titre de partie" },
    { type: "heading", level: 1, text: "Deuxième titre de partie" },
    { type: "list", ordered: false, items: ["Un point court", "Un autre point"] },
  ];
  assertEquals(planMarkPass(blocks), null);
});

Deno.test("le plan ne retient que les sortes de marques qui manquent", () => {
  // Assez de gras et de surlignage pour leur densité, pas un seul italique : c'est le cas le
  // plus fréquent, et il faisait jusqu'ici rejuger tout le gras de la fiche.
  const riche = PARAGRAPH(
    "La **Rubisco** catalyse la fixation du carbone dans le stroma du chloroplaste. ".repeat(5) +
      "==jaune|Le rendement de conversion reste faible sur une feuille exposée.== ".repeat(2) +
      "Le reste du texte tient sans marque et sert surtout à porter du volume utile. ".repeat(10),
  );

  assertEquals(planMarkPass([riche])?.wish, WISH({ italic: true }));
});

Deno.test("les cibles suivent la longueur des textes", () => {
  const court = markTargets(["Une phrase de cinquante caractères environ, pas plus."]);
  assertEquals(court.bold, 1);
  // Jamais zéro : même un texte minuscule mérite un repère.
  assertEquals(court.highlight, 1);

  const long = markTargets([("Un texte de mille caractères. ").repeat(60)]);
  assertEquals(long.bold > court.bold, true);
  assertEquals(long.highlight > court.highlight, true);
});

Deno.test("le message de la passe chiffre ce qu'il attend de CE lot", () => {
  const texts = [("Un paragraphe de fiche, assez long pour compter. ").repeat(12)];
  const prompt = markPrompt(texts, WISH({ bold: true, highlight: true, italic: true }));
  const target = markTargets(texts);
  assertEquals([target.bold, target.highlight, target.italic], [2, 1, 1]);

  // Les comptes viennent de la longueur du lot, et l'accord suit le compte : « 1 surligneurs »
  // se lit comme une consigne bâclée, et une consigne bâclée s'applique bâclée.
  assertEquals(prompt.includes('2 marques "gras", 1 surligneur et 1 marque "italique"'), true);
});

Deno.test("le message numérote les textes : c'est ce numéro que la réponse renvoie", () => {
  const both = WISH({ bold: true });
  const prompt = markPrompt(["Le premier texte.", "Le second texte."], both);
  assertEquals(prompt.includes("[0] Le premier texte."), true);
  assertEquals(prompt.includes("[1] Le second texte."), true);
  // L'accord suit le nombre : « 1 textes » se lit comme une consigne bâclée.
  assertEquals(markPrompt(["Seul."], both).includes("1 texte de la fiche, numéroté,"), true);
});

Deno.test("le message ne nomme que les sortes qui manquent", () => {
  const texts = [NU];

  const italique = markPrompt(texts, WISH({ italic: true }));
  assertEquals(italique.includes('"gras"'), false);
  assertEquals(italique.includes("surligneur"), false);
  assertEquals(italique.includes('marque "italique"'), true);
  assertEquals(italique.includes("Ce sont les seules sortes qui manquent"), true);

  // La chasse à l'italique est longue et ne sert qu'à l'italique : ailleurs elle prend de la
  // place et de l'attention pour une marque dont on ne veut pas.
  assertEquals(italique.includes("cherche mieux"), true);
  assertEquals(markPrompt(texts, WISH({ bold: true })).includes("cherche mieux"), false);

  // Quand les trois manquent, il n'y a rien à restreindre.
  const toutes = markPrompt(texts, WISH({ bold: true, highlight: true, italic: true }));
  assertEquals(toutes.includes("Ce sont les seules sortes"), false);
});

const CANDIDATES = (texts: readonly string[], from = 0): MarkCandidate[] =>
  texts.map((text, index) => ({ index: from + index, text }));

Deno.test("les lots tiennent le plafond de textes, et gardent leur rang", () => {
  const textes = Array.from({ length: 45 }, (_, index) => `texte ${index}`);
  const lots = batched(CANDIDATES(textes));

  // Deux appels là où l'ancien découpage en lots de six en demandait huit.
  assertEquals(lots.length, 2);
  assertEquals(lots[0]!.texts.length, 24);
  assertEquals(lots[0]!.indices[0], 0);
  assertEquals(lots[1]!.indices[0], 24);
  assertEquals(lots.flatMap((lot) => lot.texts), textes);
});

Deno.test("le lot garde le rang réel de chaque texte, pas un décalage", () => {
  // La sélection saute les textes trop courts : les rangs d'un lot ne se suivent plus, et un
  // décalage recollerait les marques sur les mauvais blocs.
  const lots = batched(
    [{ index: 1, text: "un" }, { index: 4, text: "deux" }, { index: 9, text: "trois" }],
    { texts: 2, chars: 10_000 },
  );
  assertEquals(lots.length, 2);
  assertEquals(lots[0]!.indices, [1, 4]);
  assertEquals(lots[1]!.indices, [9]);
});

Deno.test("les lots tiennent aussi le plafond de caractères", () => {
  const gros = Array.from({ length: 6 }, () => "x".repeat(5_000));
  const lots = batched(CANDIDATES(gros));
  assertEquals(lots.length, 3);
  assertEquals(lots[0]!.texts.length, 2);
  assertEquals(lots[2]!.indices[0], 4);

  // Un texte plus gros que le plafond à lui seul part quand même : le retenir le perdrait.
  const énorme = batched(CANDIDATES(["x".repeat(20_000), "court"]));
  assertEquals(énorme.length, 2);
  assertEquals(énorme[0]!.texts.length, 1);
  assertEquals(énorme[1]!.indices, [1]);
});

Deno.test("la consigne demande des marques, pas des textes", () => {
  assertEquals(MARK_SYSTEM_PROMPT.includes("SE RETROUVE DANS SON TEXTE, UNE SEULE FOIS"), true);
  assertEquals(MARK_SYSTEM_PROMPT.includes("UNE LISTE VIDE EST UNE ERREUR"), true);
  assertEquals(MARK_SYSTEM_PROMPT.includes("EXEMPLE"), true);
});

Deno.test("la consigne ne nomme que des surligneurs qui existent", () => {
  // Ce contrôle vivait sur le prompt d'écriture ; c'est cette consigne-ci qui porte
  // désormais le code couleur, et elle seule. Un nom de teinte inconnu du rendu laisserait
  // « framboise|texte » se lire dans la phrase, sur les deux clients à la fois - et
  // `readAnchors` le refuserait, donc la marque serait cherchée puis jetée en silence.
  const named = [...MARK_SYSTEM_PROMPT.matchAll(/^- ([a-zéèêà]+) : /gmu)].map((m) => m[1]!);
  assertEquals(named.length, SHEET_HIGHLIGHTS.length);
  for (const colour of named) {
    assertEquals(SHEET_HIGHLIGHTS.includes(colour as typeof SHEET_HIGHLIGHTS[number]), true);
  }

  // Et réciproquement : les cinq feutres ont chacun leur ligne et leur nom entre guillemets
  // dans la description de "m", sinon l'un d'eux ne serait jamais posé.
  for (const colour of SHEET_HIGHLIGHTS) {
    assertEquals(named.includes(colour), true);
    assertEquals(MARK_SYSTEM_PROMPT.includes(`"${colour}"`), true);
  }
});

Deno.test("cleanBlockMarks passe sur tous les textes d'une fiche", () => {
  const blocks: SheetBlock[] = [
    PARAGRAPH("Une entreprise fondée en 2017, issue de==rose| trente-cinq ans de recherche=="),
    { type: "list", ordered: false, items: ["Un **point** net", "Un point **abîmé"] },
  ];
  const cleaned = cleanBlockMarks(blocks);
  assertEquals(
    cleaned[0],
    PARAGRAPH("Une entreprise fondée en 2017, issue de trente-cinq ans de recherche"),
  );
  assertEquals(cleaned[1], {
    type: "list",
    ordered: false,
    items: ["Un **point** net", "Un point abîmé"],
  });
});

Deno.test("textsToMark rend les textes dans l'ordre où la pose les attend", () => {
  const blocks: SheetBlock[] = [
    { type: "heading", level: 1, text: "Titre" },
    PARAGRAPH("Un paragraphe."),
    { type: "list", ordered: false, items: ["Un", "Deux"] },
    { type: "formula", latex: "E = mc^2", caption: "La légende" },
  ];
  assertEquals(textsToMark(blocks), ["Titre", "Un paragraphe.", "Un", "Deux", "La légende"]);
});

// MARK: - La lecture de la réponse

Deno.test("readAnchors accepte les formes voisines d'une même réponse", () => {
  const report = emptyApplyReport();

  assertEquals(readAnchors([{ t: 0, m: "gras", q: "un terme" }], 1, report), [
    { text: 0, kind: "bold", colour: null, quote: "un terme" },
  ]);

  // Un tableau enveloppé, des clés françaises, un numéro rendu en chaîne : mesuré, un lot
  // sur deux revenait ainsi du temps où la passe rendait des textes.
  assertEquals(
    readAnchors({ marques: [{ t: "1", marque: "menthe", passage: "un passage" }] }, 2, report),
    [{ text: 1, kind: "highlight", colour: "menthe", quote: "un passage" }],
  );

  // Une réponse qui n'est pas une liste est un lot perdu, et se distingue d'une liste vide.
  assertEquals(readAnchors("pas du JSON", 1, report), null);
  assertEquals(readAnchors([], 1, report), []);
});

Deno.test("readAnchors refuse une teinte inventée et un numéro hors du lot", () => {
  const report = emptyApplyReport();

  // Une couleur hors des cinq laisserait « framboise| » se lire dans la phrase.
  assertEquals(readAnchors([{ t: 0, m: "framboise", q: "un passage" }], 1, report), []);
  assertEquals(report.malformed, 1);

  assertEquals(readAnchors([{ t: 9, m: "gras", q: "un terme" }], 2, report), []);
  assertEquals(report.stray, 1);
});

// MARK: - La pose

Deno.test("applyAnchors pose les marques que le modèle a désignées", () => {
  const blocks = [PARAGRAPH("La Rubisco fixe le carbone. C'est l'étape limitante du cycle.")];
  const report = emptyApplyReport();

  const marked = applyAnchors(blocks, [
    BOLD(0, "Rubisco"),
    HIGHLIGHT(0, "jaune", "C'est l'étape limitante du cycle"),
  ], report);

  assertEquals(
    marked[0],
    PARAGRAPH("La **Rubisco** fixe le carbone. ==jaune|C'est l'étape limitante du cycle==."),
  );
  assertEquals(report.placed, 2);
});

Deno.test("un surligneur qui s'ouvre au milieu d'une phrase est refusé", () => {
  // C'est le défaut qu'on voit le plus sur une fiche rendue : la bande démarre après une
  // virgule, donc en plein milieu d'une ligne, et se lit comme une sélection qui a dérapé.
  // Un trait de feutre couvre une proposition, ou il ne couvre rien.
  const report = emptyApplyReport();
  const blocks = [
    PARAGRAPH("La Rubisco fixe le carbone, et c'est l'étape limitante du cycle de Calvin."),
  ];

  assertEquals(
    applyAnchors(blocks, [HIGHLIGHT(0, "jaune", "c'est l'étape limitante du cycle")], report),
    blocks,
  );
  assertEquals(report.shape, 1);
});

Deno.test("un seul surligneur par texte", () => {
  // Deux bandes de couleurs différentes collées dans le même paragraphe, c'est du confetti :
  // le code couleur ne dit plus rien, et la page n'a plus de passage mis en avant.
  const report = emptyApplyReport();
  const blocks = [
    PARAGRAPH(
      "La Rubisco fixe le carbone dans le stroma. Le rendement plafonne à deux pour cent. " +
        "Cette limite tient à la photorespiration de l'enzyme.",
    ),
  ];

  const marked = applyAnchors(blocks, [
    HIGHLIGHT(0, "jaune", "La Rubisco fixe le carbone dans le stroma"),
    HIGHLIGHT(0, "menthe", "Le rendement plafonne à deux pour cent"),
  ], report);

  assertEquals((marked[0] as { text: string }).text.match(/==/g)?.length, 2);
  assertEquals(report.placed, 1);
  assertEquals(report.crossing, 1);
});

Deno.test("deux textes qui se suivent ne portent pas chacun une bande", () => {
  // Sur deux points de liste consécutifs, les deux bandes se suivent à une interligne d'écart
  // et se lisent comme une seule, plus épaisse. La seconde attend le point suivant.
  const report = emptyApplyReport();
  const blocks: SheetBlock[] = [
    {
      type: "list",
      ordered: false,
      items: [
        "L'hélicase ouvre la double hélice au niveau de l'origine",
        "La primase pose une amorce d'ARN complémentaire du brin",
        "La polymérase allonge le brin dans le sens cinq vers trois",
      ],
    },
  ];

  const marked = applyAnchors(blocks, [
    HIGHLIGHT(0, "jaune", "L'hélicase ouvre la double hélice au niveau de l'origine"),
    HIGHLIGHT(1, "bleu", "La primase pose une amorce d'ARN complémentaire du brin"),
    HIGHLIGHT(2, "bleu", "La polymérase allonge le brin dans le sens cinq vers trois"),
  ], report);

  const items = (marked[0] as { items: string[] }).items;
  assertEquals(items[0]?.includes("=="), true);
  assertEquals(items[1]?.includes("=="), false);
  assertEquals(items[2]?.includes("=="), true);
  assertEquals(report.placed, 2);
});

Deno.test("le texte nu ne bouge jamais, quoi que le modèle ait renvoyé", () => {
  // C'est la propriété que tout le protocole existe pour garantir : le modèle ne rend plus de
  // texte, donc il ne peut plus en changer un mot au passage. L'ancienne passe devait le
  // vérifier caractère par caractère à l'arrivée ; ici c'est vrai par construction.
  const original = "La Rubisco fixe le carbone. C'est l'étape limitante du cycle de Calvin.";
  const marked = applyAnchors([PARAGRAPH(original)], [
    BOLD(0, "Rubisco"),
    BOLD(0, "carbone"),
    HIGHLIGHT(0, "bleu", "C'est l'étape limitante du cycle de Calvin"),
    // Celles-ci seront refusées, et ne doivent rien laisser derrière elles.
    BOLD(0, "chlorophylle"),
    BOLD(0, "cycl"),
  ]);

  assertEquals(stripInlineMarkup((marked[0] as { text: string }).text), original);
});

Deno.test("un passage introuvable ou ambigu ne pose rien, et se compte", () => {
  const report = emptyApplyReport();

  const absent = applyAnchors([PARAGRAPH("La Rubisco fixe le carbone.")], [
    BOLD(0, "chlorophylle"),
  ], report);
  assertEquals(absent, [PARAGRAPH("La Rubisco fixe le carbone.")]);
  assertEquals(report.absent, 1);

  // Deux occurrences : on ne sait pas laquelle le modèle visait, et marquer la première
  // serait marquer au hasard une fois sur deux.
  const ambigu = applyAnchors(
    [PARAGRAPH("Le cycle commence, puis le cycle se referme sur lui-même.")],
    [BOLD(0, "cycle")],
    report,
  );
  assertEquals(ambigu, [PARAGRAPH("Le cycle commence, puis le cycle se referme sur lui-même.")]);
  assertEquals(report.ambiguous, 1);
  assertEquals(report.placed, 0);
});

Deno.test("une marque posée au milieu d'un mot est refusée avant d'être écrite", () => {
  const report = emptyApplyReport();
  const blocks = [PARAGRAPH("La photosynthèse convertit l'énergie lumineuse en sucre.")];

  assertEquals(applyAnchors(blocks, [BOLD(0, "synthèse")], report), blocks);
  assertEquals(report.shape, 1);
});

Deno.test("une marque ne coupe pas une formule", () => {
  const report = emptyApplyReport();
  const blocks = [PARAGRAPH("La vitesse $v = d/t$ augmente avec la distance parcourue.")];

  assertEquals(applyAnchors(blocks, [BOLD(0, "$v = d/t$")], report), blocks);
  assertEquals(report.shape, 1);
});

Deno.test("une marque à cheval sur une marque existante est refusée", () => {
  // Le rendu ne sait pas lire des marqueurs entrelacés : `==menthe|Le **rendement== atteint**`
  // n'est ni un surlignage ni un gras.
  const report = emptyApplyReport();
  const blocks = [PARAGRAPH("Le rendement réel atteint **92 pour cent** en régime nominal.")];

  const marked = applyAnchors(blocks, [
    HIGHLIGHT(0, "menthe", "Le rendement réel atteint **92 pour"),
  ], report);

  assertEquals(marked, blocks);
  assertEquals(report.crossing, 1);
});

Deno.test("un gras se pose à l'intérieur d'un surligneur, dans le bon ordre", () => {
  const blocks = [
    PARAGRAPH("Le rendement de conversion atteint 92 pour cent en régime nominal."),
  ];

  const marked = applyAnchors(blocks, [
    HIGHLIGHT(0, "menthe", "Le rendement de conversion atteint 92 pour cent"),
    BOLD(0, "rendement de conversion"),
  ]);

  assertEquals(
    marked[0],
    PARAGRAPH(
      "==menthe|Le **rendement de conversion** atteint 92 pour cent== en régime nominal.",
    ),
  );
});

Deno.test("applyAnchors marque les points d'une liste un à un", () => {
  const blocks: SheetBlock[] = [
    { type: "heading", level: 1, text: "Le cycle de Calvin" },
    { type: "list", ordered: true, items: ["La fixation du carbone", "La réduction du glycérate"] },
  ];

  const marked = applyAnchors(blocks, [BOLD(1, "fixation"), BOLD(2, "réduction")]);

  assertEquals(marked[0], { type: "heading", level: 1, text: "Le cycle de Calvin" });
  assertEquals(marked[1], {
    type: "list",
    ordered: true,
    items: ["La **fixation** du carbone", "La **réduction** du glycérate"],
  });
});

Deno.test("applyAnchors rend la fiche telle quelle quand il n'y a rien à poser", () => {
  const blocks = [PARAGRAPH("Un paragraphe sans marque à poser.")];
  assertEquals(applyAnchors(blocks, []), blocks);
});
