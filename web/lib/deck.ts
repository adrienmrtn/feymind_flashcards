/**
 * Le pas de versement d'un paquet.
 *
 * L'action serveur le borne, l'écran découpe dessus et compte l'avancement : le même nombre
 * des deux côtés, donc un seul endroit où il est écrit. Deux cents cartes tiennent dans un
 * corps d'action sans approcher la limite, et laissent la barre avancer assez souvent pour
 * qu'un import de mille cartes ne ressemble pas à une page figée.
 *
 * Il vit ici et pas dans `lib/actions/decks.ts` : un module `"use server"` ne peut exporter
 * que des fonctions.
 */
export const DECK_CHUNK = 200;
