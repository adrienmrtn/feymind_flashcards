"use client";

import { useState, useTransition } from "react";

import { Button } from "@/components/ui/button";
import { sendFeedback } from "@/lib/actions/feedback";
import type { FeedbackKind } from "@/lib/feedback";

/**
 * Un bug ou une idée, écrits en base. Plus de boîte mail à ouvrir.
 */
export function FeedbackCard() {
  const [kind, setKind] = useState<FeedbackKind>("bug");
  const [message, setMessage] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [ok, setOk] = useState(false);
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

  return (
    <section className="saas-card p-7">
      <p className="text-[13px] text-ink-tertiary">Faire un retour</p>
      <p className="mt-1 text-[13.5px] leading-relaxed text-ink-secondary">
        Un bug, une idée. Ça s&apos;écrit ici, sans ouvrir ta boîte mail.
      </p>

      <div className="mt-5 grid grid-cols-2 gap-2">
        <KindButton
          label="Un bug"
          selected={kind === "bug"}
          onSelect={() => setKind("bug")}
        />
        <KindButton
          label="Une idée"
          selected={kind === "idea"}
          onSelect={() => setKind("idea")}
        />
      </div>

      <label htmlFor="feedback-message" className="mt-5 block text-[13px] text-ink-tertiary">
        Ton message
      </label>
      <textarea
        id="feedback-message"
        value={message}
        onChange={(event) => setMessage(event.target.value)}
        rows={5}
        maxLength={4000}
        placeholder={kind === "bug" ? "Ce qui s'est passé, et où." : "Ce que tu aimerais pouvoir faire."}
        className="mt-2 w-full resize-y rounded-button bg-surface-muted px-4 py-3 text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
      />

      <Button
        type="button"
        size="lg"
        disabled={!ready}
        onClick={send}
        className="mt-4 w-full"
      >
        {pending ? "Envoi…" : "Envoyer"}
      </Button>

      {status ? (
        <p
          className={`mt-3 text-[13px] ${ok ? "text-ink-secondary" : "text-negative"}`}
          role={ok ? "status" : "alert"}
        >
          {status}
        </p>
      ) : null}
    </section>
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
      className={`pressable min-h-11 rounded-button px-3 text-[14.5px] font-medium ${
        selected
          ? "bg-accent-soft text-accent"
          : "bg-surface-muted text-ink shadow-[inset_0_0_0_1px_var(--color-stroke-strong)]"
      }`}
    >
      {label}
    </button>
  );
}
