"use client";

import { useTransition } from "react";

import { markFeedbackRead } from "@/lib/actions/feedback";
import type { InboxRow } from "@/lib/feedback";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";
import type { UiLocale } from "@/lib/i18n/locales";

export function InboxList({ rows }: { rows: InboxRow[] }) {
  const { t } = useI18n();
  if (rows.length === 0) {
    return (
      <p className="text-[14.5px] text-ink-secondary">{t("app.inbox.emptyFilter")}</p>
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
  const { t, locale } = useI18n();
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
        <p className="text-[12px] text-ink-tertiary">{when(row.createdAt, locale)}</p>
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-2">
        <span
          className={`rounded-pill px-2 py-0.5 text-[11px] font-bold uppercase tracking-caps ${
            row.kind === "bug"
              ? "bg-caution-soft text-caution"
              : "bg-info-soft text-info"
          }`}
        >
          {row.kind === "bug" ? t("app.inbox.kind.bug") : t("app.inbox.kind.idea")}
        </span>
        <span className="text-[11.5px] text-ink-tertiary">
          {row.source === "ios" ? t("app.inbox.source.iphone") : t("app.inbox.source.web")}
        </span>
        {unread ? (
          <span className="text-[11.5px] font-medium text-accent">{t("app.inbox.unreadBadge")}</span>
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
          {pending ? "…" : t("app.inbox.markRead")}
        </button>
      ) : null}
    </li>
  );
}

function when(iso: string, locale: UiLocale): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleString(localeBcp47(locale), {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}
