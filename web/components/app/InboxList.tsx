"use client";

import { useTransition } from "react";

import { markFeedbackRead } from "@/lib/actions/feedback";
import type { InboxRow } from "@/lib/feedback";

export function InboxList({ rows }: { rows: InboxRow[] }) {
  if (rows.length === 0) {
    return (
      <p className="text-[14.5px] text-ink-secondary">Aucun retour dans ce filtre.</p>
    );
  }

  return (
    <ul className="space-y-3">
      {rows.map((row) => (
        <InboxItem key={row.id} row={row} />
      ))}
    </ul>
  );
}

function InboxItem({ row }: { row: InboxRow }) {
  const [pending, startTransition] = useTransition();
  const unread = !row.readAt;

  function mark() {
    if (!unread || pending) return;
    startTransition(async () => {
      await markFeedbackRead(row.id);
    });
  }

  return (
    <li className="saas-card p-5">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <p className="text-[13px] font-semibold text-ink">{row.authorLabel}</p>
        <p className="text-[12px] text-ink-tertiary">{when(row.createdAt)}</p>
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-2">
        <span
          className={`rounded-pill px-2 py-0.5 text-[11px] font-bold uppercase tracking-caps ${
            row.kind === "bug"
              ? "bg-caution-soft text-caution"
              : "bg-info-soft text-info"
          }`}
        >
          {row.kind === "bug" ? "Bug" : "Idée"}
        </span>
        <span className="text-[11.5px] text-ink-tertiary">
          {row.source === "ios" ? "iPhone" : "Web"}
        </span>
        {unread ? (
          <span className="text-[11.5px] font-medium text-accent">Non lu</span>
        ) : null}
      </div>
      <p className="mt-3 whitespace-pre-wrap text-[15px] leading-relaxed text-ink">
        {row.message}
      </p>
      {unread ? (
        <button
          type="button"
          onClick={mark}
          disabled={pending}
          className="pressable mt-4 text-[13px] font-medium text-ink underline-draw disabled:opacity-40"
        >
          {pending ? "…" : "Marquer comme lu"}
        </button>
      ) : null}
    </li>
  );
}

function when(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleString("fr-FR", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}
