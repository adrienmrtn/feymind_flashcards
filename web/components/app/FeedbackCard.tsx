"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { feedbackMailto, type FeedbackKind } from "@/lib/feedback";
import { LEGAL_CONTACT } from "@/lib/legal";

/**
 * Un bug ou une idée, envoyés à `team@micabo.app`.
 *
 * On n'héberge pas de boîte : le bouton ouvre le courriel déjà adressé.
 * Sans client mail, le lien `mailto:` reste cliquable ailleurs.
 */
export function FeedbackCard() {
  const [kind, setKind] = useState<FeedbackKind>("bug");
  const [message, setMessage] = useState("");

  const ready = message.trim().length > 0;

  function send() {
    if (!ready) return;
    window.location.href = feedbackMailto(kind, message);
  }

  return (
    <section className="saas-card p-7">
      <p className="text-[13px] text-ink-tertiary">Faire un retour</p>
      <p className="mt-1 text-[13.5px] leading-relaxed text-ink-secondary">
        Un bug, une idée. Ça arrive chez {LEGAL_CONTACT}.
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
        Envoyer
      </Button>
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
