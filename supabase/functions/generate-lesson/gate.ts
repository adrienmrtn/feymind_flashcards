/**
 * **La porte du gratuit**, côté serveur : `begin_lesson` et `lesson_theme_call`, en base
 * (migration `lesson_generations`). Voir `docs/refonte-parcours.md` § 9.4.
 *
 * Un appel sans compte (la clé publiable, tolérée le temps de la transition, voir `caller.ts`)
 * n'a personne à qui attribuer une leçon : il passe, et c'est l'app qui tient la porte. Une
 * base qui ne répond pas, ou qui n'a pas encore la migration, laisse passer aussi : une panne
 * de comptage ne doit pas devenir une panne de produit, et le plafond du jour
 * (`consume_ai_quota`) reste le fusible du coût.
 */
import type { Caller } from "../_shared/caller.ts";

export type GateVerdict = "ok" | "free_limit" | "import_pro" | "forbidden" | "pro_required" | "daily_limit";

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
        : "Cette leçon n'est pas à toi.",
    );
    this.code = code;
    this.status = code === "forbidden" ? 403 : code === "daily_limit" ? 429 : 402;
  }
}

async function rpc(name: string, payload: Record<string, unknown>): Promise<unknown | undefined> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return undefined;
  try {
    const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    if (!response.ok) {
      console.warn(JSON.stringify({ gate: name, status: response.status }));
      return undefined;
    }
    return await response.json();
  } catch (_error) {
    console.warn(JSON.stringify({ gate: name, status: "network" }));
    return undefined;
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isLessonId(value: unknown): value is string {
  return typeof value === "string" && UUID.test(value);
}

/**
 * Ouvre (ou rouvre) une leçon. Refuse en `LessonGateError` quand la base dit non ; laisse
 * passer quand elle ne dit rien.
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
  const verdict = await rpc("begin_lesson", {
    p_user: caller.userId,
    p_lesson: options.lessonId,
    p_kind: options.kind,
    p_source: options.source,
    p_themes: options.themes,
    p_onboarding: options.onboarding === true,
  });
  if (verdict === "free_limit" || verdict === "import_pro" || verdict === "forbidden") {
    throw new LessonGateError(verdict);
  }
}

/**
 * **Rend une leçon réservée dont le plan n'a pas pu s'écrire.** `begin_lesson` réserve la
 * leçon avant le plan ; sans ce retour, une panne du modèle au premier essai comptait comme
 * la leçon offerte, et l'essai suivant (un autre identifiant) tombait sur `free_limit`. La
 * base ne rend qu'une leçon dont le plan n'est jamais arrivé (`themes = 0`, aucun thème
 * demandé) : un plan déjà livré, dont la réponse s'est perdue, reste compté. Sans la
 * migration `lesson_release`, l'appel échoue en silence, comme le reste de la porte.
 */
export async function releaseLesson(caller: Caller, lessonId: string): Promise<void> {
  if (!caller.userId) return;
  await rpc("release_lesson", { p_user: caller.userId, p_lesson: lessonId });
}

/** Compte un appel de thème ; refuse une leçon inconnue ou des « Réessayer » sans fin. */
export async function admitThemeCall(caller: Caller, lessonId: string): Promise<void> {
  if (!caller.userId) return;
  const allowed = await rpc("lesson_theme_call", { p_user: caller.userId, p_lesson: lessonId });
  if (allowed === false) {
    throw new LessonGateError("forbidden");
  }
}

/**
 * **Un supplément** : un lot de nouvelles questions (`practice`) ou un examen blanc (`exam`).
 * Sans abonnement, un seul de chaque, pour goûter ; avec, un plafond par jour. Un appel sans
 * compte n'a pas d'essai à consommer : il est refusé. Une base muette laisse passer, comme
 * pour la leçon.
 */
export async function beginExtra(
  caller: Caller,
  options: { kind: "practice" | "exam"; lessonId?: string },
): Promise<void> {
  if (!caller.userId) throw new LessonGateError("pro_required");
  const verdict = await rpc("begin_extra", {
    p_user: caller.userId,
    p_kind: options.kind,
    p_lesson: isLessonId(options.lessonId) ? options.lessonId : null,
  });
  if (verdict === "pro_required" || verdict === "daily_limit" || verdict === "forbidden") {
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
  await rpc("refund_extra", {
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
