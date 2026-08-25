/**
 * Recopié à l'identique depuis `supabase/functions/_shared/fal.ts`.
 *
 * Il vit ici parce que `fal.ts` lit `Deno.env` : l'importer depuis Node ferait entrer tout le
 * client fal.ai et son environnement dans le paquet du site, pour deux expressions
 * régulières. La règle qu'elles portent, en revanche, appartient bien au module de fiche —
 * un tiret cadratin est la première marque d'un texte laissé tel que le modèle l'a rendu.
 */
export function stripEmDashes(value: string): string {
  return value
    .replace(/\s+[—–―]\s+/g, ", ")
    .replace(/[—–―]/g, "-");
}
