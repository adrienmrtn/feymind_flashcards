import { getTranslator } from "./server";

/** Message d'action déjà traduit dans la langue du cookie. */
export async function actionT(
  key: string,
  vars?: Record<string, string | number>,
): Promise<string> {
  const { t } = await getTranslator();
  return t(key, vars);
}
