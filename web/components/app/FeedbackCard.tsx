"use client";

import { useState, useTransition } from "react";

import { ROW_GHOST, SettingsRow } from "@/components/app/settings/Rows";
import { Button } from "@/components/ui/button";
import { sendFeedback } from "@/lib/actions/feedback";
import type { FeedbackKind } from "@/lib/feedback";
import { useI18n } from "@/lib/i18n/client";

/**
 * Un bug ou une idée, écrits en base. Plus de boîte mail à ouvrir.
 */
export function FeedbackCard() {
  const { t } = useI18n();
  const [kind, setKind] = useState<FeedbackKind>("bug");
  const [message, setMessage] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [ok, setOk] = useState(false);
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();

  const ready = message.trim().length > 0 && !pending;

  function send() {
    if (!ready) return;
    setStatus(null);
    startTransition(async () => {
      const result = await sendFeedback(kind, message, "web");
      setOk(result.status === "ok");
      setStatus(result.message);
      if (result.status === "ok") setMessage("");
    });
  }

  // Le formulaire était déplié en permanence dans les réglages : une zone de texte de cinq
  // lignes, ouverte, au milieu d'un écran où l'on vient changer sa langue. Il se demande.
  return (
    <SettingsRow
      label={t("app.feedback.title")}
      hint={t("app.feedback.lead")}
      control={
        open ? null : (
          <button type="button" onClick={() => setOpen(true)} className={ROW_GHOST}>
            {t("app.feedback.open")}
          </button>
        )
      }
    >
      {open ? (
        <div className="rise rounded-group bg-surface-muted p-4">
          <div className="grid max-w-[320px] grid-cols-2 gap-2">
            <KindButton
              label={t("app.feedback.kind.bug")}
              selected={kind === "bug"}
              onSelect={() => setKind("bug")}
            />
            <KindButton
              label={t("app.feedback.kind.idea")}
              selected={kind === "idea"}
              onSelect={() => setKind("idea")}
            />
          </div>

          <label htmlFor="feedback-message" className="mt-3 block text-[13px] text-ink-tertiary">
            {t("app.feedback.messageLabel")}
          </label>
          <textarea
            id="feedback-message"
            value={message}
            onChange={(event) => setMessage(event.target.value)}
            rows={4}
            maxLength={4000}
            placeholder={
              kind === "bug"
                ? t("app.feedback.placeholder.bug")
                : t("app.feedback.placeholder.idea")
            }
            className="mt-2 w-full resize-y rounded-button bg-surface px-4 py-3 text-[14.5px] text-ink outline-none placeholder:text-ink-tertiary"
          />

          <div className="mt-3 flex flex-wrap items-center gap-2">
            <Button type="button" disabled={!ready} onClick={send}>
              {pending ? t("app.feedback.pending") : t("app.feedback.send")}
            </Button>
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="pressable h-10 rounded-button px-3 text-[13.5px] text-ink-secondary"
            >
              {t("app.common.cancel")}
            </button>
          </div>

          {status ? (
            <p
              className={`mt-3 text-[13px] ${ok ? "text-ink-secondary" : "text-negative"}`}
              role={ok ? "status" : "alert"}
            >
              {status}
            </p>
          ) : null}
        </div>
      ) : null}
    </SettingsRow>
  );
}

function KindButton({
  label,
  selected,
  onSelect,
}: {
  label: string;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      className={`pressable h-10 rounded-button px-3 text-[14px] font-medium ${
        selected
          ? "bg-accent-soft text-accent"
          : "bg-surface text-ink"
      }`}
    >
      {label}
    </button>
  );
}
