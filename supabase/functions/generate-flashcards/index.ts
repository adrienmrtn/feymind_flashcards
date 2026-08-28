import { authorize, withCors } from "../_shared/caller.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  callModel,
  CORS_HEADERS,
  deepStripEmDashes,
  errorResponse,
  extractJSON,
  FalError,
  jsonResponse,
} from "../_shared/fal.ts";
import { detectDiscipline, disciplineBrief } from "../_shared/discipline.ts";
import { languageBrief } from "../_shared/language.ts";

interface RequestBody {
  title?: string;
  context?: string;
  count?: number;
  existing?: string[];
  /** Formats autorisés : « basic », « cloze », « choice ». Hérité, remplacé par `quota`. */
  kinds?: string[];
  /** Nombre exact de cartes par format : { basic, cloze, choice }. */
  quota?: Record<string, number>;
  /** Matière du cours, quand elle est connue : elle change ce qu'une carte doit demander. */
  subject?: string;
  /** Langue des cartes, la même que celle de la fiche : « fr » ou « en ». */
  language?: string;
  model?: string;
}

interface GeneratedCard {
  front?: string;
  back?: string;
  hint?: string;
  kind?: string;
  choices?: string[];
  answerIndex?: number;
}

const SYSTEM_PROMPT =
  `Tu conçois des flashcards de révision en français pour l'application Micabo, dans l'esprit d'Anki.

CONCISION, AVANT TOUT LE RESTE
Une carte se lit en trois secondes et se répond de mémoire. Une carte bavarde ne se révise pas : elle se relit, ce qui n'est pas la même chose et n'apprend rien.
- Recto : UNE phrase, 15 mots au maximum. Une seule question, pas deux collées par « et ».
- Verso : UNE phrase, 20 mots au maximum. Deux phrases seulement si la seconde est indispensable, et jamais trois.
- Tu réponds directement. Pas de reprise de la question dans la réponse, pas de « il s'agit de », pas de « c'est le processus par lequel ».
- Une énumération s'écrit en termes séparés par des virgules, sans phrase d'introduction.
- Pas de contexte, pas de rappel, pas de mise en garde : la carte ne dit que ce qu'il faut retenir.

RÈGLES
- Une carte teste UNE seule idée. Deux idées font deux cartes.
- Le recto est une vraie question ou une amorce à compléter, jamais un simple mot-clé.
- Couvre l'ensemble du cours, pas seulement le début. Varie définitions, mécanismes, comparaisons, applications.
- Pas de question dont la réponse est « oui » ou « non ».
- INTERDIT : les tirets cadratins et demi-cadratins. Pas de markdown, pas de numérotation.
- INTERDIT : les commandes LaTeX nues. Une flèche s'écrit →, pas \\rightarrow. Une lettre grecque s'écrit α, pas \\alpha. Une vraie formule, et seulement une vraie formule, va entre $...$.

INDICE
- Le champ "hint" est facultatif : ne le mets que s'il aide vraiment à retrouver la réponse.
- Un indice porte sur le FOND : la catégorie, le mécanisme en jeu, la partie du cours d'où ça vient, un exemple voisin.
- Un indice tient en cinq mots.
- INTERDIT : tout indice qui décrit la forme de la réponse (lettre initiale, nombre de mots, de lettres ou de syllabes). Ça n'apprend rien.

FORMATS DE CARTES
Chaque carte porte un champ "kind" :
- "basic" : question au recto, réponse au verso. C'est le format par défaut.
- "cloze" : texte à trou. Le recto est UNE phrase du cours, 20 mots au maximum, dont le terme clé est remplacé par le caractère …, le verso est uniquement ce terme manquant, sans phrase autour. Un seul trou par carte, et la phrase doit rester compréhensible.
- "choice" : QCM. Le recto est la question, "choices" contient 3 ou 4 propositions de 8 mots maximum, toutes plausibles et de longueur comparable, "answerIndex" est l'index de la bonne (0 pour la première), et le verso reprend la bonne réponse en UNE phrase qui dit pourquoi elle est bonne.

LE NOMBRE DE CARTES PAR FORMAT EST UNE COMMANDE
La consigne donne un nombre exact pour chaque format. Tu produis ce nombre, ni plus ni moins, pour chacun. Un format à 0 n'apparaît pas du tout. Si le cours se prête mal à un format, tu écris quand même le nombre demandé en choisissant les passages les moins mauvais : c'est l'étudiant qui sait comment il révise.

FORMAT DE SORTIE
Réponds uniquement par un tableau JSON compact, une seule ligne, sans texte autour :
[{"kind":"basic","front":"...","back":"...","hint":"..."},{"kind":"cloze","front":"La phrase avec un … à la place du terme.","back":"le terme"},{"kind":"choice","front":"...","choices":["...","...","..."],"answerIndex":1,"back":"..."}]`;

interface OutputCard {
  kind: string;
  front: string;
  back: string;
  hint?: string;
  choices?: string[];
  answerIndex?: number;
}

/** Graphie unique du trou, la même que côté application (`ClozeGap`). */
const GAP = "…";

function normalizeGap(text: string): string {
  let result = text;
  for (const candidate of ["[...]", "(...)", "[…]", "(…)", "_____", "____", "___", "__", "..."]) {
    result = result.split(candidate).join(GAP);
  }
  while (result.includes(GAP + GAP)) {
    result = result.split(GAP + GAP).join(GAP);
  }
  return result;
}

/**
 * Ramène une carte au format qu'elle tient vraiment : un QCM sans propositions
 * exploitables, ou un texte à trou sans trou, repasse en recto verso. Une carte
 * bancale n'est pas jetée pour autant : sa question et sa réponse restent bonnes.
 */
function normalizeCard(card: GeneratedCard, allowed: Set<string>): OutputCard {
  const back = card.back!.trim();
  const hint = card.hint?.trim() || undefined;
  const kind = typeof card.kind === "string" ? card.kind.trim().toLowerCase() : "basic";
  const front = kind === "cloze" ? normalizeGap(card.front!.trim()) : card.front!.trim();

  if (kind === "cloze" && allowed.has("cloze") && front.includes(GAP)) {
    return { kind, front, back, hint };
  }

  if (kind === "choice" && allowed.has("choice")) {
    const choices = [
      ...new Set(
        (Array.isArray(card.choices) ? card.choices : [])
          .filter((choice): choice is string => typeof choice === "string")
          .map((choice) => choice.trim())
          .filter((choice) => choice.length > 0),
      ),
    ];

    const declared = typeof card.answerIndex === "number" ? card.answerIndex : -1;
    const answerIndex = choices[declared] !== undefined
      ? declared
      : choices.findIndex((choice) => choice.toLowerCase() === back.toLowerCase());

    if (choices.length >= 2 && answerIndex >= 0) {
      return { kind, front, back, hint, choices, answerIndex };
    }
  }

  return { kind: "basic", front, back, hint };
}

const FORMATS = ["basic", "cloze", "choice"] as const;
type Format = typeof FORMATS[number];

const PER_FORMAT_MAXIMUM = 24;
const TOTAL_MINIMUM = 3;
const TOTAL_MAXIMUM = 48;

const FORMAT_LABELS: Record<Format, string> = {
  basic: "recto verso",
  cloze: "textes à trou",
  choice: "QCM",
};

/**
 * Combien de cartes de chaque format écrire.
 *
 * L'application envoie un quota depuis qu'on y choisit un nombre exact par format. Les
 * anciennes versions n'envoient qu'un total et une liste de formats autorisés : on répartit
 * alors le total entre eux, ce qui donne exactement ce que faisait cette fonction avant.
 */
function resolveQuota(body: RequestBody): Record<Format, number> {
  const requested = body.quota;
  if (requested && FORMATS.some((format) => typeof requested[format] === "number")) {
    const quota = {
      basic: clamp(requested.basic),
      cloze: clamp(requested.cloze),
      choice: clamp(requested.choice),
    };
    return balance(quota);
  }

  const total = Math.min(Math.max(body.count ?? 24, TOTAL_MINIMUM), TOTAL_MAXIMUM);
  const allowed = FORMATS.filter((format) =>
    format === "basic" || (body.kinds ?? FORMATS).includes(format)
  );
  const share = Math.max(1, Math.floor(total / allowed.length));

  const quota = { basic: 0, cloze: 0, choice: 0 };
  for (const format of allowed) quota[format] = share;
  quota.basic = clamp(total - (quota.cloze + quota.choice));
  return balance(quota);
}

function clamp(value: unknown): number {
  const parsed = typeof value === "number" && Number.isFinite(value) ? Math.round(value) : 0;
  return Math.min(PER_FORMAT_MAXIMUM, Math.max(0, parsed));
}

/** Ramène le total dans ses bornes, en rognant d'abord le format le plus nombreux. */
function balance(quota: Record<Format, number>): Record<Format, number> {
  const result = { ...quota };
  let total = result.basic + result.cloze + result.choice;

  while (total > TOTAL_MAXIMUM) {
    const largest = FORMATS.reduce((best, format) => result[format] > result[best] ? format : best);
    result[largest] -= 1;
    total -= 1;
  }

  if (total < TOTAL_MINIMUM) {
    result.basic += TOTAL_MINIMUM - total;
  }

  return result;
}

/**
 * Retient les cartes format par format, dans la limite commandée.
 *
 * Le modèle rend souvent le bon total mais la mauvaise répartition : douze cartes dont deux
 * QCM quand on en demandait cinq. Le tri se fait donc ici, et le surplus d'un format ne vient
 * pas manger la place d'un autre.
 *
 * Il reste un second tour, et il est volontaire : quand un format est resté en deçà de sa
 * commande, on complète le total avec les cartes écartées au premier tour. Un QCM dont les
 * propositions étaient inexploitables est retombé en recto verso, et cette carte-là est
 * juste. Renvoyer huit cartes au lieu de douze parce que le modèle a mal compté serait payer
 * son erreur deux fois.
 */
function selectByQuota(cards: OutputCard[], quota: Record<Format, number>): OutputCard[] {
  const total = quota.basic + quota.cloze + quota.choice;
  const remaining = { ...quota };
  const kept: OutputCard[] = [];
  const leftovers: OutputCard[] = [];

  for (const card of cards) {
    const format = (FORMATS as readonly string[]).includes(card.kind)
      ? card.kind as Format
      : "basic";
    if (remaining[format] > 0) {
      remaining[format] -= 1;
      kept.push(card);
    } else {
      leftovers.push(card);
    }
  }

  return kept.concat(leftovers.slice(0, Math.max(0, total - kept.length)));
}

Deno.serve((request: Request) =>
  withCors(request, async () => {
    try {
      // Qui appelle, et lui reste-t-il du quota. En première ligne : tout ce qui suit coûte de
      // l'argent.
      await authorize(request, "generate-flashcards");

      const body = (await request.json()) as RequestBody;
      const context = (body.context ?? "").trim().slice(0, 40_000);

      if (context.length < 40) {
        throw new FalError("Le cours est trop court pour générer des flashcards.", 400);
      }

      const quota = resolveQuota(body);
      const count = quota.basic + quota.cloze + quota.choice;
      const allowedKinds = new Set<string>(FORMATS.filter((format) => quota[format] > 0));

      const existing = (body.existing ?? []).slice(0, 60);

      const breakdown = FORMATS
        .map((format) => `${quota[format]} ${FORMAT_LABELS[format]}`)
        .join(", ");

      // La matière change ce qu'une carte doit demander : une date en histoire, une condition
      // d'application en droit, un mot dans sa langue en langue vivante.
      const subjectBrief = disciplineBrief(detectDiscipline(context, body.title, body.subject));

      const sections = [
        languageBrief(body.language),
        `Cours : ${body.title ?? "Sans titre"}`,
        subjectBrief,
        `Génère exactement ${count} flashcards, réparties ainsi : ${breakdown}. Ces nombres ne se négocient pas.`,
        allowedKinds.size > 1
          ? `Écris-les dans l'ordre : d'abord les "basic", puis les "cloze", puis les "choice".`
          : `Un seul format est demandé. N'écris rien d'autre.`,
        existing.length > 0
          ? `Ces questions existent déjà, ne les répète pas et ne les reformule pas :\n${
            existing.map((item) => `- ${item}`).join("\n")
          }`
          : "",
        `CONTENU DU COURS :\n${context}`,
      ].filter(Boolean);

      const output = await callModel({
        prompt: sections.join("\n\n"),
        systemPrompt: SYSTEM_PROMPT,
        model: body.model,
        temperature: 0.5,
        maxTokens: 8_192,
      });

      const parsed = extractJSON<GeneratedCard[] | { cards?: GeneratedCard[] }>(output);
      const rawCards = Array.isArray(parsed) ? parsed : parsed.cards ?? [];

      const normalized = deepStripEmDashes(rawCards)
        .filter((card) => typeof card?.front === "string" && typeof card?.back === "string")
        .map((card) => normalizeCard(card, allowedKinds))
        .filter((card) => card.front.length > 0 && card.back.length > 0);

      const cards = selectByQuota(normalized, quota);

      if (cards.length === 0) {
        throw new FalError("Le modèle n'a produit aucune carte exploitable.", 502);
      }

      return jsonResponse({ cards });
    } catch (error) {
      return errorResponse(error);
    }
  })
);
