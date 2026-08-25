"use client";

import { useState, useTransition } from "react";
import { ThinkingOrb } from "thinking-orbs";

import { joinWaitlist, type WaitlistResult, type WaitlistSource } from "@/lib/actions/waitlist";

/**
 * Le seul appel à l'action du site, et il marche.
 *
 * `thinking-orbs` fait ici exactement ce pour quoi elle est faite : une attente **courte**, en
 * 20 px, à même la ligne. Elle est monochrome, donc elle ne se bat pas avec le vert de Micabo,
 * et son `state="connecting"` dit la bonne chose — on parle au serveur.
 *
 * Le retour d'information n'est **jamais** porté par la seule animation : le message est écrit,
 * et il est annoncé aux lecteurs d'écran. Une interface où le mouvement est le seul canal de
 * retour est une interface qui ne dit rien à celui qui ne le voit pas.
 */
export function WaitlistForm({
  source,
  size = "large",
}: {
  source: WaitlistSource;
  size?: "large" | "compact";
}) {
  const [email, setEmail] = useState("");
  const [result, setResult] = useState<WaitlistResult | null>(null);
  const [pending, startTransition] = useTransition();

  const done = result?.status === "ok" || result?.status === "already";

  function submit(event: React.FormEvent) {
    event.preventDefault();
    if (pending || done) return;
    startTransition(async () => {
      setResult(await joinWaitlist(email, source));
    });
  }

  if (done) {
    return (
      <p
        className={`flex items-center gap-2.5 font-medium text-accent ${
          size === "large" ? "text-[15px]" : "text-[14px]"
        }`}
        role="status"
      >
        <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5 shrink-0">
          <path
            d="M4 10.5l4 4 8-9"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
        {result.message}
      </p>
    );
  }

  return (
    <form onSubmit={submit} noValidate>
      <div
        className={`paper flex items-center gap-2 rounded-button bg-surface p-1.5 ${
          size === "large" ? "sm:p-2" : ""
        }`}
      >
        <label htmlFor={`waitlist-${source}`} className="sr-only">
          Ton adresse électronique
        </label>
        <input
          id={`waitlist-${source}`}
          type="email"
          inputMode="email"
          autoComplete="email"
          required
          value={email}
          onChange={(event) => {
            setEmail(event.target.value);
            if (result) setResult(null);
          }}
          placeholder="ton@adresse.fr"
          /* 16 px au minimum sur mobile : en dessous, Safari zoome sur le champ au focus et ne
             dézoome jamais. */
          className={`min-w-0 flex-1 bg-transparent px-3 text-[16px] text-ink outline-none placeholder:text-ink-tertiary ${
            size === "large" ? "sm:text-[17px]" : ""
          }`}
        />
        <button
          type="submit"
          disabled={pending}
          className={`pressable flex shrink-0 items-center gap-2 rounded-[12px] bg-ink px-4 font-semibold text-on-ink disabled:opacity-70 ${
            size === "large" ? "h-11 text-[15px] sm:px-5" : "h-10 text-[14px]"
          }`}
        >
          {pending ? (
            <>
              <ThinkingOrb state="connecting" size={20} theme="dark" />
              Un instant
            </>
          ) : (
            "Être prévenu"
          )}
        </button>
      </div>

      <p
        className="mt-2.5 min-h-5 text-[13px] text-ink-tertiary"
        role={result ? "alert" : undefined}
      >
        {result?.message ?? "Une adresse, rien d'autre. Pas de lettre d'information."}
      </p>
    </form>
  );
}
