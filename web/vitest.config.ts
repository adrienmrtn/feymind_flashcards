import path from "node:path";

import { defineConfig } from "vitest/config";

export default defineConfig({
  // Le même `@/` que dans `tsconfig.json`. Sans lui, un test ne peut pas ouvrir un module
  // qui vit sous `app/` — et `app/robots.ts` en est un qu'on tient à vérifier.
  resolve: {
    alias: { "@": path.resolve(import.meta.dirname, ".") },
  },
  test: {
    include: ["lib/**/*.test.ts"],
    environment: "node",
  },
});
