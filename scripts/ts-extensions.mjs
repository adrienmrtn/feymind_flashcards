import { registerHooks } from "node:module";

/**
 * Rendre les imports sans extension résolvables par Node.
 *
 * Les catalogues du site s'importent entre eux à la mode des bundlers - `./app-fr` et non
 * `./app-fr.ts` - parce que c'est Next qui les compile. Node, lui, exige l'extension : le
 * générateur de catalogues Swift ne pouvait donc plus tourner depuis que les catalogues ont
 * été découpés, et les clés partagées ne descendaient plus jusqu'à l'iPhone.
 *
 * Le crochet ne fait qu'une chose : quand une résolution relative échoue, il réessaie en
 * ajoutant `.ts`. Rien d'autre n'est touché, et surtout pas la façon dont le site compile.
 */
registerHooks({
  resolve(specifier, context, nextResolve) {
    try {
      return nextResolve(specifier, context);
    } catch (error) {
      if (specifier.startsWith(".") && !specifier.endsWith(".ts")) {
        return nextResolve(`${specifier}.ts`, context);
      }
      throw error;
    }
  },
});
