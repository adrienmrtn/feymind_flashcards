/**
 * Déployer depuis ces sources : `supabase functions deploy generate-course`.
 * L'API MCP tronque un envoi trop gros. Un bundle coupé démarre le worker
 * sans `Deno.serve`, et chaque appel pend jusqu'au 504 — l'écran reste alors
 * sur « Micabo écrit la fiche… ».
 */
import { consumeQuota, readCaller, withCors } from "../_shared/caller.ts";
import { CircuitOpenError } from "../_shared/circuit.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  callModel,
  deepStripEmDashes,
  errorResponse,
  FalError,
  jsonResponse,
} from "../_shared/fal.ts";
import { parseModelJSON } from "../_shared/json.ts";
import {
  normalizeSheet,
  sheetToPlainText,
  stripInlineMarkup,
  type SheetBlock,
} from "../_shared/sheet.ts";
import {
  batched,
  cleanBlockMarks,
  countMarks,
  emptyMergeReport,
  emptyShapeReport,
  markPrompt,
  MARK_SYSTEM_PROMPT,
  mergeMarked,
  needsMarkPass,
  readMarkedTexts,
  textsToMark,
} from "./marks.ts";
import { detectDiscipline, disciplineBrief } from "../_shared/discipline.ts";
import { languageBrief } from "../_shared/language.ts";
import { sanitizeInstructions, sanitizeMeta, wrapUntrusted } from "../_shared/prompt-boundary.ts";
import {
  audienceBrief,
  COURSE_SYSTEM_PROMPT,
  instructionsBrief,
  lengthBrief,
  MAX_INSTRUCTIONS,
  PROMPT_VERSION,
  readingBrief,
  retryBrief,
  VISION_SYSTEM_PROMPT,
} from "./prompt.ts";

const OUTPUT_TOKEN_LIMIT = 8_192;

async function writeSheet(
  prompt: string,
  model: string | undefined,
  temperature: number,
): Promise<Record<string, unknown> | null> {
  try {
    const output = await callModel({
      prompt,
      systemPrompt: COURSE_SYSTEM_PROMPT,
      model,
      temperature,
      maxTokens: OUTPUT_TOKEN_LIMIT,
    });
    return deepStripEmDashes(parseModelJSON<Record<string, unknown>>(output));
  } catch (error) {
    // Une panne Fal (404 modèle, circuit ouvert, timeout) n'est pas une fiche
    // illisible : retenter tout de suite paie un second appel pour le même refus.
    if (error instanceof FalError || error instanceof CircuitOpenError) throw error;
    return null;
  }
}

/**
 * Repose les marques quand la fiche en porte trop peu pour sa longueur.
 *
 * Voir `marks.ts` : le déclenchement est sur la **densité**, la seconde passe ne peut que
 * marquer, elle travaille par lots de dix textes, et tout texte qui a bougé ou qui perd une
 * marque est écarté à la fusion. Un échec ici n'est pas une panne de fiche : on rend la fiche
 * telle qu'elle était écrite.
 *
 * Les lots partent **ensemble**. En file, quarante-cinq textes feraient cinq allers-retours à
 * la suite, soit une vingtaine de secondes ajoutées à un import qui en prend déjà trente.
 */
async function repaintMarks(
  blocks: SheetBlock[],
): Promise<{ blocks: SheetBlock[]; report: Record<string, number> }> {
  const report = { ...emptyMergeReport(), batches: 0, failed: 0, ragged: 0, ran: 0 };
  if (!needsMarkPass(blocks)) return { blocks, report };

  report.ran = 1;
  const lots = batched(textsToMark(blocks));
  report.batches = lots.length;

  const marked = await Promise.all(lots.map(async (lot) => {
    try {
      const output = await callModel({
        prompt: markPrompt(lot),
        systemPrompt: MARK_SYSTEM_PROMPT,
        // Froid : on ne demande pas d'imagination, on demande des marques au bon endroit.
        temperature: 0.1,
        maxTokens: OUTPUT_TOKEN_LIMIT,
      });
      const parsed = deepStripEmDashes(parseModelJSON<unknown>(output));
      // Un lot dont la réponse n'a ni la bonne taille ni une forme lisible est un lot
      // perdu : ses textes repartent tels quels plutôt que de décaler tous les suivants.
      const texts = readMarkedTexts(parsed, lot.length);
      if (!texts) {
        report.ragged += 1;
        return lot;
      }
      return texts;
    } catch (_error) {
      report.failed += 1;
      return lot;
    }
  }));

  return { blocks: normalizeSheet(mergeMarked(blocks, marked.flat(), report)), report };
}

interface RequestBody {
  text?: string;
  images?: string[];
  hintTitle?: string;
  sourceName?: string;
  /** Stade d'étude choisi à l'inscription : « lycee », « prepa », « sante »… */
  level?: string;
  /** Pays de scolarisation, en deux lettres : « fr », « be », « ca »… */
  country?: string;
  /** Langue de la fiche : code ISO, ou « source » pour rester dans celle du document. */
  language?: string;
  /** Longueur de fiche demandée : « brief », « standard » ou « deep ». */
  length?: string;
  /** Volume exact demandé par le curseur, en blocs. */
  blocks?: number;
  /** Matière, quand l'application la connaît déjà. Sinon elle est devinée. */
  subject?: string;
  /** Comment le texte a été obtenu : « photo », « pdf », « youtube », « text », « docx ». */
  source?: string;
  /** Prompt libre de l'étudiant, pris en compte à l'écriture de la fiche. */
  instructions?: string;
}

const MAX_TEXT_LENGTH = 60_000;
const MAX_IMAGES = 6;
const MAX_IMAGE_CHARS = 4_000_000;

function acceptedImages(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  let total = 0;
  for (const item of raw) {
    if (typeof item !== "string") continue;
    const url = item.trim();
    if (!url.startsWith("https://") && !url.startsWith("data:image/")) continue;
    total += url.length;
    if (total > MAX_IMAGE_CHARS) break;
    out.push(url);
    if (out.length >= MAX_IMAGES) break;
  }
  return out;
}
/** Au delà, on reste à la borne basse du format demandé : la fiche resterait illisible. */
const LONG_DOCUMENT_LENGTH = 12_000;

Deno.serve((request: Request) =>
  withCors(request, async () => {
    try {
      // Qui appelle. Le décompte attend d'avoir un document utilisable : un 400
      // ne doit pas brûler une unité, c'est ce qui s'est passé sur generate-flashcards
      // le 8 septembre (quatre refus, quatre lignes dans ai_usage).
      const caller = readCaller(request);

      const body = (await request.json()) as RequestBody;
      const text = (body.text ?? "").trim().slice(0, MAX_TEXT_LENGTH);
      const images = acceptedImages(body.images);

      if (text.length < 40 && images.length === 0) {
        throw new FalError("Le document ne contient pas assez de contenu à analyser.", 400);
      }

      await consumeQuota(caller, "generate-course");

      // Passe visuelle : le modèle décrit les schémas que l'extraction texte ne voit pas, et
      // relève leurs valeurs, sans quoi la fiche ne pourrait pas porter de graphe.
      let visualNotes = "";
      if (images.length > 0) {
        try {
          visualNotes = await callModel({
            prompt:
              "Voici les pages d'un document de cours. Décris précisément les éléments visuels utiles à la compréhension.",
            systemPrompt: VISION_SYSTEM_PROMPT,
            imageUrls: images,
            temperature: 0.2,
            maxTokens: 1600,
          });
        } catch (_error) {
          // Un échec de la passe visuelle ne doit pas bloquer l'écriture de la fiche.
          visualNotes = "";
        }
      }

      // La langue passe en tête, avant même le titre : en queue de message, derrière un
      // document de soixante mille caractères, le modèle la perd et retombe sur le français
      // du prompt système.
      const hintTitle = sanitizeMeta(body.hintTitle, 200);
      const sourceName = sanitizeMeta(body.sourceName, 200);

      const sections: string[] = [languageBrief(body.language)];
      if (hintTitle) sections.push(`Titre souhaité par l'étudiant : ${hintTitle}`);
      if (sourceName) sections.push(`Nom du fichier source : ${sourceName}`);
      // Le destinataire, la matière et le volume passent avant le document : ce sont les
      // consignes qui décident de la façon de lire tout ce qui suit.
      sections.push(audienceBrief(body.level, body.country));

      const discipline = detectDiscipline(text, hintTitle, body.subject);
      const subjectBrief = disciplineBrief(discipline);
      if (subjectBrief) sections.push(subjectBrief);

      sections.push(lengthBrief(body.length, text.length > LONG_DOCUMENT_LENGTH, body.blocks));

      const reading = readingBrief(body.source, text.length);
      if (reading) sections.push(reading);

      const extra = instructionsBrief(sanitizeInstructions(body.instructions, MAX_INSTRUCTIONS));
      if (extra) sections.push(extra);

      if (text.length > 0) sections.push(wrapUntrusted("TEXTE EXTRAIT DU DOCUMENT", text));
      if (visualNotes) {
        sections.push(wrapUntrusted("DESCRIPTION DES VISUELS DU DOCUMENT", visualNotes));
      }
      sections.push("JSON compact, une seule ligne, sans indentation.");
      sections.push("Écris maintenant le JSON de la fiche.");

      const prompt = sections.join("\n\n");
      let parsed = await writeSheet(prompt, undefined, 0.3);

      // Une fiche coupée ou illisible : on redemande plus court plutôt que d'abandonner.
      if (!parsed || normalizeSheet(parsed.sheet ?? parsed.blocks).length < 3) {
        parsed = await writeSheet(
          `${prompt}\n\n${retryBrief(body.length)}`,
          undefined,
          0.15,
        );
      }

      if (!parsed) {
        throw new FalError(
          "L'écriture de la fiche a échoué. Réessaie, le document n'a rien perdu.",
          502,
        );
      }

      // Les figures ont quitté la fiche. Le modèle voit toujours les pages - c'est ce qui lui
      // permet de lire un scan - mais rien de ce qu'il en tire n'est recadré ni collé dans le
      // document : une image de schéma extraite d'un PDF y était décorative et souvent
      // illisible, et elle n'est de toute façon plus modifiable par celui qui relit.
      const written = normalizeSheet(parsed.sheet ?? parsed.blocks);

      // Les marques d'abord, la mise à plat ensuite : `context_text` se calcule sur la fiche
      // telle qu'elle sera lue, même si les marques n'y survivent pas.
      // La forme des marques est vérifiée **avant** de compter : une fiche dont les deux
      // surlignages sont posés au milieu d'un mot n'est pas une fiche marquée, et le
      // déclenchement de la repasse doit le savoir.
      const shape = emptyShapeReport();
      const cleaned = cleanBlockMarks(written, shape);
      const repaint = await repaintMarks(cleaned);
      const blocks = cleanBlockMarks(repaint.blocks, shape);

      if (blocks.length < 3) {
        throw new FalError("Le modèle n'a pas produit de fiche exploitable.", 502);
      }

      // La version à plat est calculée ici, pas demandée au modèle : deux rédactions du même
      // contenu finiraient par se contredire, et celle-ci est déterministe.
      const contextText = sheetToPlainText(blocks);
      if (contextText.length < 40) {
        throw new FalError("Le modèle n'a pas produit de contenu exploitable.", 502);
      }

      const course = {
        title: typeof parsed.title === "string" ? parsed.title : "",
        subject: typeof parsed.subject === "string" ? parsed.subject : undefined,
        emoji: typeof parsed.emoji === "string" ? parsed.emoji : undefined,
        summary: typeof parsed.summary === "string" ? stripInlineMarkup(parsed.summary) : "",
        sheet: { blocks },
        contextText,
      };

      return jsonResponse({
        course,
        usedVision: images.length > 0 && visualNotes.length > 0,
        /**
         * **Le marquage se compte à chaque étape, et le compte sort avec la fiche.**
         *
         * Trois jours à corriger un marquage absent sans savoir *où* il disparaissait : le
         * modèle n'en posait-il pas, la repasse les effaçait-elle, la vérification de forme
         * les retirait-elle ? Chacune de ces trois hypothèses demandait un déploiement pour
         * être écartée. Quatre compteurs dans la réponse les départagent en un appel, et ils
         * ne coûtent rien à personne : aucun client ne les lit, ils ne touchent pas la fiche.
         */
        meta: {
          promptVersion: PROMPT_VERSION,
          marks: {
            written: countMarks(written),
            cleaned: countMarks(cleaned),
            repainted: countMarks(repaint.blocks),
            final: countMarks(blocks),
          },
          repaint: repaint.report,
          shape,
        },
      });
    } catch (error) {
      return errorResponse(error);
    }
  })
);
