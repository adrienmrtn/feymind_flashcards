"use client";

import { useState, useTransition } from "react";

import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Field, FieldDescription, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { joinWaitlist, type WaitlistResult, type WaitlistSource } from "@/lib/actions/waitlist";

/**
 * Le seul appel à l'action du site, et il marche.
 *
 * `thinking-orbs` fait ici exactement ce pour quoi elle est faite : une attente **courte**, en
 * 20 px, à même la ligne. Elle est monochrome, donc elle ne se bat pas avec le vert de Micabo,
 * et son `state="connecting"` dit la bonne chose - on parle au serveur.
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
      <Alert variant="success" role="status">
        <AlertDescription
          className={`font-medium text-accent ${size === "large" ? "text-[15px]" : "text-[14px]"}`}
        >
          {result.message}
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <form onSubmit={submit} noValidate>
      <Field>
        <FieldLabel htmlFor={`waitlist-${source}`} className="sr-only">
          Ton adresse électronique
        </FieldLabel>
        <div className="flex items-center gap-2">
          <Input
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
            className="h-12 rounded-button text-[16px] sm:text-[16px] [&_[data-slot=input]]:h-12 [&_[data-slot=input]]:text-[16px]"
          />
          <Button
            type="submit"
            size="lg"
            loading={pending}
            className={size === "large" ? "h-12 shrink-0 px-5" : "h-12 shrink-0"}
          >
            Être prévenu
          </Button>
        </div>
        <FieldDescription>
          {result?.message ?? "Une adresse, rien d'autre. Pas de lettre d'information."}
        </FieldDescription>
      </Field>
    </form>
  );
}
