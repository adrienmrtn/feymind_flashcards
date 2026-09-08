import { describe, expect, it } from "vitest";

import { buildWriterPage, WRITER_ROOT_ID } from "./writer-page";

describe("la page d'écriture hors Next", () => {
  it("embarque le POST et le pourcentage, sans casser sur </script>", () => {
    const html = buildWriterPage(
      {
        text: "chapitre </script><script>alert(1)</script>",
        hintTitle: "Cours",
      },
      { writing: "Micabo is writing the sheet…", waitHint: "Cours" },
      "https://www.micabo.app",
    );
    expect(html).toContain(`id="${WRITER_ROOT_ID}"`);
    expect(html).toContain("XMLHttpRequest");
    expect(html).toContain("/api/import-course");
    expect(html).toContain("location.replace");
    expect(html).toContain("https://www.micabo.app");
    expect(html).not.toContain("</script><script>alert");
    expect(html).toContain("\\u003cscript>alert");
  });
});
