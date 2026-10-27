import "server-only";

import { actionT } from "@/lib/i18n/action";
import { readUiLocale } from "@/lib/i18n/server";

/**
 * **Le refus du serveur, avec son code.**
 *
 * `functions.invoke` rend « Edge Function returned a non-2xx status code », qui ne dit rien à
 * personne. Le corps porte le message utile et, pour la porte du gratuit, un `code`
 * (`free_limit`, `import_pro`, `pro_required`, `daily_limit`, `forbidden`) que l'écran
 * traduit en paywall ou en phrase (`lesson.error.*`).
 */
export interface FunctionRefusal {
  message: string;
  code?: string;
}

const CODE_KEYS: Record<string, string> = {
  free_limit: "lesson.error.freeLimit",
  import_pro: "lesson.error.importPro",
  forbidden: "lesson.error.forbidden",
  pro_required: "lesson.error.proRequired",
  daily_limit: "lesson.error.dailyLimit",
};

export async function readableFunctionError(error: unknown): Promise<FunctionRefusal> {
  const context = (error as { context?: Response }).context;
  if (context && typeof context.json === "function") {
    try {
      const body = (await context.json()) as { error?: string; code?: string };
      const key = body?.code ? CODE_KEYS[body.code] : undefined;
      if (key) return { message: await actionT(key), code: body.code };
      // Le serveur écrit ses messages en français : ils ne s'affichent tels quels que sur un site
      // en français. Ailleurs, la phrase générique de la langue de l'interface les remplace,
      // comme sur l'iPhone.
      if (body?.error) {
        const message = (await readUiLocale()) === "fr" ? body.error : await actionT("lesson.error.generic");
        return { message, ...(body.code ? { code: body.code } : {}) };
      }
    } catch {
      // Un corps illisible : on retombe sur le message du transport, qui vaut mieux que rien.
    }
  }
  return { message: error instanceof Error ? error.message : await actionT("lesson.error.generic") };
}
