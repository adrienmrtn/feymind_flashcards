import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    // Les dates de `exam.ts` sont des journées locales, comme `MicaboCalendar` côté iOS. Un
    // test qui tournerait dans un autre fuseau que celui de la machine donnerait un décalage
    // d'un jour sur les examens ; on fixe donc le fuseau.
    environment: "node",
  },
});
