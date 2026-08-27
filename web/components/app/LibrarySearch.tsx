"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function LibrarySearch({ initial, subject }: { initial: string; subject: string | null }) {
  const router = useRouter();
  const [value, setValue] = useState(initial);

  function go(next: string) {
    const params = new URLSearchParams();
    params.set("vue", "decouvrir");
    if (next.trim()) params.set("q", next.trim());
    if (subject) params.set("matiere", subject);
    router.push(`/app/cours?${params.toString()}` as never);
  }

  return (
    <form
      onSubmit={(event) => {
        event.preventDefault();
        go(value);
      }}
      className="flex h-12 items-center rounded-button bg-surface-muted px-4"
    >
      <input
        value={value}
        onChange={(event) => setValue(event.target.value)}
        placeholder="Un cours, une matière…"
        className="h-full min-w-0 flex-1 bg-transparent text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
      />
    </form>
  );
}
