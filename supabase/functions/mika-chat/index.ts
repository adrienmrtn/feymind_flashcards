import { authorize, withCors } from "../_shared/caller.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  callModel,
  deepStripEmDashes,
  errorResponse,
  extractJSON,
  FalError,
  jsonResponse,
} from "../_shared/fal.ts";
import {
  buildMikaPrompt,
  MIKA_FREE_CEILING,
  MIKA_PRO_CEILING,
  MIKA_SYSTEM_PROMPT,
  mikaMaxTokens,
  parseMikaReply,
  readAttachments,
  readMode,
  readTurns,
} from "../_shared/mika.ts";

/**
 * **Mika répond à un message.**
 *
 * L'app envoie les derniers tours de la conversation, le document joint s'il y en a un,
 * la langue et le niveau ; la fonction rend une réponse d'un bloc, et une carte de
 * révision quand il y a quelque chose à retenir. Elle ne garde rien d'un appel à l'autre.
 *
 * Le quota est le seul endroit où Mika diffère des autres fonctions : un abonné y a un
 * plafond bas et réel (`MIKA_PRO_CEILING`), pas le fusible de deux mille. Chaque appui
 * coûte un appel, et c'est ce plafond qui borne la facture.
 */
interface RequestBody {
  messages?: unknown;
  attachment?: unknown;
  /** Lot 11 : plusieurs documents (les photos lues sur l'appareil), réunis en un seul. */
  attachments?: unknown;
  language?: string;
  level?: string;
  /** Lot 12 : le geste de la caméra (`translate`, `vocabulary`…), ignoré s'il est inconnu. */
  mode?: unknown;
}

Deno.serve((request: Request) =>
  withCors(request, async () => {
    try {
      // Qui appelle, et lui reste-t-il du quota. En première ligne : tout ce qui suit coûte
      // de l'argent.
      await authorize(request, "mika-chat", {
        ceiling: MIKA_FREE_CEILING,
        proCeiling: MIKA_PRO_CEILING,
      });

      const body = (await request.json()) as RequestBody;
      const turns = readTurns(body.messages);
      if (turns.length === 0 || turns[turns.length - 1].role !== "user") {
        throw new FalError("Il n'y a pas de question à laquelle répondre.", 400);
      }

      const mode = readMode(body.mode);
      const output = await callModel({
        prompt: buildMikaPrompt({
          turns,
          attachment: readAttachments(body.attachment, body.attachments),
          language: body.language,
          level: body.level,
          mode,
        }),
        systemPrompt: MIKA_SYSTEM_PROMPT,
        temperature: 0.5,
        maxTokens: mikaMaxTokens(mode),
      });

      const reply = parseMikaReply(deepStripEmDashes(extractJSON<Record<string, unknown>>(output)));
      if (!reply) {
        throw new FalError("Mika n'a pas produit de réponse exploitable.", 502);
      }

      return jsonResponse({ answer: reply });
    } catch (error) {
      return errorResponse(error);
    }
  })
);
