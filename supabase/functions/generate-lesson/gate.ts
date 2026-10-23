/**
 * **La porte du gratuit**, côté serveur : `begin_lesson` et `lesson_theme_call`, en base
 * (migrations `lesson_generations`, `lesson_gate_hardening`). Voir `docs/refonte-parcours.md`
 * § 9.4.
 *
 * Un appel sans compte (la clé publiable, tolérée le temps de la transition, voir `caller.ts`)
 * n'a personne à qui attribuer une leçon : il passe la porte, mais il paye sur le budget commun
 * des appels sans compte (`consumeQuota`), et les étapes lourdes lui sont fermées
 * (`requireAccount`).
 *
 * **Une base qui ne répond pas ferme la porte** (503), comme le décompte (`consumeQuota`).
 * Elle laissait passer : une panne, ou un délai provoqué, suffisait à ouvrir la leçon offerte
 * autant de fois qu'on voulait. Sans secret de service — en local —, la porte laisse passer,
 * pour qu'un essai reste possible. Seuls les retours (`releaseLesson`, `refundExtra`), qui
 * s'exécutent dans un `catch` et rendent ce qui a été pris, restent silencieux : leur échec
 * coûte une leçon à l'élève, pas un appel gratuit à quelqu'un d'autre.
 */
import { type Caller, CallerError } from "../_shared/caller.ts";
import { syncProFromRevenueCat } from "../_shared/revenuecat.ts";

export type GateVerdict =
  | "ok"
  | "free_limit"
  | "import_pro"
  | "forbidden"
  | "pro_required"
  | "daily_limit"
  | "course_unknown";

/** Un refus de la porte : l'app le lit par son `code`, et ouvre le paywall. */
export class LessonGateError extends Error {
  readonly status: number;
  readonly code: GateVerdict;

  constructor(code: Exclude<GateVerdict, "ok">) {
    super(
      code === "import_pro"
        ? "Importer un support, c'est avec Micabo Pro."
        : code === "free_limit"
        ? "Ta leçon offerte est déjà créée. Passe à Micabo Pro pour en créer d'autres."
        : code === "pro_required"
        ? "Tu as utilisé ton essai gratuit. Passe à Micabo Pro pour continuer."
        : code === "daily_limit"
        ? "Tu as beaucoup travaillé aujourd'hui. Reviens demain pour la suite."
        : code === "course_unknown"
        ? "Ce cours n'est pas encore synchronisé. Réessaie dans un instant."
        : "Cette leçon n'est pas à toi.",
    );
    this.code = code;
    // `course_unknown` n'ouvre pas le paywall : c'est une attente, l'app réessaie après la
    // synchro. 409 plutôt que 402, que les clients lisent comme un refus commercial.
    this.status = code === "forbidden"
      ? 403
      : code === "daily_limit"
      ? 429
      : code === "course_unknown"
      ? 409
      : 402;
  }
}

/** La porte ne sait pas répondre : on ferme, avec un statut qu'un client sait réessayer. */
function unavailable(name: string, status: number | string): CallerError {
  console.warn(JSON.stringify({ gate: name, status }));
  return new CallerError("La vérification de ton accès est temporairement indisponible. Réessaie.", 503);
}

/**
 * Un appel RPC de la porte. `undefined` sans secret de service (en local) ; sinon la réponse,
 * ou une `CallerError` 503 quand la base ne répond pas.
 */
async function rpc(name: string, payload: Record<string, unknown>): Promise<unknown | undefined> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return undefined;
  let response: Response;
  try {
    response = await fetch(`${url}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(8_000),
    });
  } catch (_error) {
    throw unavailable(name, "network");
  }
  if (!response.ok) throw unavailable(name, response.status);
  try {
    return await response.json();
  } catch (_error) {
    throw unavailable(name, "unreadable");
  }
}

/** Un retour (`release_lesson`, `refund_extra`) : il ne lève jamais, il le dit au journal. */
async function giveBack(name: string, payload: Record<string, unknown>): Promise<void> {
  try {
    await rpc(name, payload);
  } catch (_error) {
    // `rpc` a déjà laissé sa ligne au journal.
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isLessonId(value: unknown): value is string {
  return typeof value === "string" && UUID.test(value);
}

/** Ce que la base a répondu, quand c'est un verdict qu'on connaît. */
function readVerdict(value: unknown): GateVerdict | null {
  const known: GateVerdict[] = [
    "ok",
    "free_limit",
    "import_pro",
    "forbidden",
    "pro_required",
    "daily_limit",
    "course_unknown",
  ];
  return typeof value === "string" && (known as string[]).includes(value)
    ? value as GateVerdict
    : null;
}

/**
 * Ouvre (ou rouvre) une leçon. Refuse en `LessonGateError` quand la base dit non, en
 * `CallerError` 503 quand elle ne répond pas.
 */
export async function beginLesson(
  caller: Caller,
  options: {
    lessonId: string;
    kind: "create" | "convert";
    source: string;
    themes: number;
    /** La leçon du parcours d'accueil : offerte même depuis un support importé. */
    onboarding?: boolean;
  },
): Promise<void> {
  if (!caller.userId) return;
  const userId = caller.userId;
  const ask = async () => {
    const answer = await rpc("begin_lesson", {
      p_user: userId,
      p_lesson: options.lessonId,
      p_kind: options.kind,
      p_source: options.source,
      p_themes: options.themes,
      p_onboarding: options.onboarding === true,
    });
    if (answer === undefined) return "ok" as const;
    const verdict = readVerdict(answer);
    // Une réponse qu'on ne sait pas lire n'est pas un « oui ».
    if (!verdict) throw unavailable("begin_lesson", "unknown_verdict");
    return verdict;
  };
  let verdict = await ask();
  // « Pas d'abonnement » selon la base : RevenueCat a peut-être un achat que le webhook n'a
  // pas encore recopié. S'il dit Pro, la ligne est écrite et on redemande.
  if (
    (verdict === "free_limit" || verdict === "import_pro" || verdict === "course_unknown") &&
    await syncProFromRevenueCat(userId)
  ) {
    verdict = await ask();
  }
  if (verdict !== "ok") {
    throw new LessonGateError(verdict);
  }
}

/**
 * **Rend une leçon réservée dont le plan n'a pas pu s'écrire.** `begin_lesson` réserve la
 * leçon avant le plan ; sans ce retour, une panne du modèle au premier essai comptait comme
 * la leçon offerte, et l'essai suivant (un autre identifiant) tombait sur `free_limit`. La
 * base ne rend qu'une leçon dont le plan n'est jamais arrivé (`themes = 0`, aucun thème
 * demandé) : un plan déjà livré, dont la réponse s'est perdue, reste compté. Et si ce retour
 * lui-même n'arrive pas — la fonction tuée en route —, `begin_lesson` tient la réservation
 * pour rendue au bout de dix minutes.
 */
export async function releaseLesson(caller: Caller, lessonId: string): Promise<void> {
  if (!caller.userId) return;
  await giveBack("release_lesson", { p_user: caller.userId, p_lesson: lessonId });
}

/** Compte un appel de thème ; refuse une leçon inconnue ou des « Réessayer » sans fin. */
export async function admitThemeCall(caller: Caller, lessonId: string): Promise<void> {
  if (!caller.userId) return;
  const allowed = await rpc("lesson_theme_call", { p_user: caller.userId, p_lesson: lessonId });
  if (allowed === undefined || allowed === true) return;
  if (allowed === false) throw new LessonGateError("forbidden");
  throw unavailable("lesson_theme_call", "unknown_verdict");
}

/**
 * **Un supplément** : un lot de nouvelles questions (`practice`) ou un examen blanc (`exam`).
 * Sans abonnement, un seul de chaque, pour goûter ; avec, un plafond par jour. Un appel sans
 * compte n'a pas d'essai à consommer : il est refusé. Une base muette ferme, comme pour la
 * leçon.
 */
export async function beginExtra(
  caller: Caller,
  options: { kind: "practice" | "exam"; lessonId?: string },
): Promise<void> {
  if (!caller.userId) throw new LessonGateError("pro_required");
  const userId = caller.userId;
  const ask = async () => {
    const answer = await rpc("begin_extra", {
      p_user: userId,
      p_kind: options.kind,
      p_lesson: isLessonId(options.lessonId) ? options.lessonId : null,
    });
    if (answer === undefined) return "ok" as const;
    const verdict = readVerdict(answer);
    if (!verdict) throw unavailable("begin_extra", "unknown_verdict");
    return verdict;
  };
  let verdict = await ask();
  if (verdict === "pro_required" && await syncProFromRevenueCat(userId)) {
    verdict = await ask();
  }
  if (verdict !== "ok") {
    throw new LessonGateError(verdict);
  }
}

/**
 * **Rend un supplément** dont l'écriture a échoué : une panne du modèle ne coûte pas l'essai
 * gratuit, ni une part du plafond Pro. Sans effet pour un anonyme, qui n'en a pas pris.
 */
export async function refundExtra(
  caller: Caller,
  options: { kind: "practice" | "exam"; lessonId?: string },
): Promise<void> {
  if (!caller.userId) return;
  await giveBack("refund_extra", {
    p_user: caller.userId,
    p_kind: options.kind,
    p_lesson: isLessonId(options.lessonId) ? options.lessonId : null,
  });
}

/** La source déclarée, ramenée aux valeurs que la base connaît. */
export function normalizeSource(value: unknown, fromScratch: boolean): string {
  if (fromScratch) return "topic";
  const known = ["text", "pdf", "photo", "audio", "youtube", "docx", "mixed"];
  return typeof value === "string" && known.includes(value) ? value : "text";
}
