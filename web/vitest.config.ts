import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["lib/import/**/*.test.ts"],
    environment: "node",
  },
});
