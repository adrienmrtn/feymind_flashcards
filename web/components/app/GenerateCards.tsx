"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import {
  CARD_KINDS,
  DEFAULT_QUOTA,
  PER_FORMAT_RANGE,
  TOTAL_RANGE,
  isAtCap,
  quotaTotal,
  type CardKind,
  type QuestionQuota,
} from "@micabo/core";

import { CountStepper } from "@/components/app/CountStepper";
import { Float } from "@/components/app/Float";
import { GenerateCardsCta } from "@/components/app/GenerateCardsCta";
import { generateCards } from "@/lib/actions/course";

/**
 * Demander des cartes, **et combien de chaque format**.
 *
 * C'est le panneau de l'app, porté : un compteur par format, le total lu dessous. Ce qui vivait ici
 * était un bouton seul, et le quota était écrit en dur dans l'action - on demandait des cartes et
 * on recevait ce que le code avait décidé. **Un nombre par format est une commande, pas une
 * autorisation** : celui qui veut cinq QCM et cinq textes à trou pour son contrôle de la semaine
 * peut le demander.
 *
 * Les bornes viennent du noyau partagé, donc ce sont celles de l'iPhone au chiffre près : c'est la
 * même fonction Edge qui reçoit le quota.
 */
export function GenerateCards({
  courseId,
  existing,
  floating = false,
  autoStart = false,
}: {
  courseId: string;
  existing: number;
  floating?: boolean;
  autoStart?: boolean;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [failure, setFailure] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [quota, setQuota] = useState<QuestionQuota>(DEFAULT_QUOTA);
  const opened = useRef(false);

  const total = quotaTotal(quota);
  const capped = isAtCap(quota);

  function step(kind: CardKind, delta: number) {
    setQuota((current) => {
      const next = Math.min(
        PER_FORMAT_RANGE.max,
        Math.max(PER_FORMAT_RANGE.min, current[kind] + delta),
      );
      return { ...current, [kind]: next };
    });
  }

  function ask() {
    setFailure(null);
    startTransition(async () => {
      const result = await Promise.race([
        generateCards(courseId, quota),
        new Promise<{ status: "error"; message: string }>((resolve) => {
          setTimeout(
            () =>
              resolve({
                status: "error",
                message: "L'écriture a pris trop longtemps. Réessaie.",
              }),
            90_000,
          );
        }),
      ]);
      if (result.status === "error") setFailure(result.message ?? "Ça n'a pas marché.");
      else {
        setOpen(false);
        router.replace(`/app/c/${courseId}/cartes` as never);
        router.refresh();
      }
    });
  }

  useEffect(() => {
    if (!autoStart || opened.current) return;
    opened.current = true;
    setOpen(true);
  }, [autoStart]);

  if (pending) {
    const pendingUi = (
      <div
        className={
          floating
            ? "fixed right-4 bottom-6 z-30 w-[min(100%-2rem,22rem)] flex items-center gap-4 rounded-2xl border border-border bg-card p-5 shadow-xs lg:right-8"
            : "flex items-center gap-4 rounded-2xl border border-border bg-card p-5"
        }
        data-print="hide"
      >
        <ThinkingOrb state="composing" size={64} />
        <div>
          <p className="text-[15.5px] font-semibold text-ink">Micabo écrit les cartes…</p>
          <p className="numeral mt-0.5 text-[13px] text-ink-tertiary">
            {total} carte{total > 1 ? "s" : ""} demandée{total > 1 ? "s" : ""}
          </p>
        </div>
      </div>
    );
    return floating ? <Float>{pendingUi}</Float> : pendingUi;
  }

  if (!open) {
    if (floating) {
      return (
        <Float>
          <button
            type="button"
            onClick={() => setOpen(true)}
            data-print="hide"
            className="fixed right-4 bottom-6 z-30 inline-flex h-9 items-center gap-2 rounded-lg border border-primary bg-primary px-3 text-sm font-medium text-primary-foreground shadow-xs lg:right-8"
          >
            <span aria-hidden>✨</span>
            Générer les cartes
          </button>
        </Float>
      );
    }

    return (
      <div>
        {existing === 0 ? (
          <GenerateCardsCta onClick={() => setOpen(true)} />
        ) : (
          <button
            type="button"
            onClick={() => setOpen(true)}
            className="flex w-full items-center gap-3.5 rounded-2xl border border-border bg-card px-5 py-4 text-left"
          >
            <span aria-hidden className="emoji text-[22px]">
              ➕
            </span>
            <span>
              <span className="block text-[15.5px] font-semibold text-ink">Ajouter au paquet</span>
              <span className="mt-0.5 block text-[13px] text-ink-tertiary">
                D&apos;autres questions, dans les formats que tu veux.
              </span>
            </span>
          </button>
        )}

        {failure ? <Failure message={failure} /> : null}
      </div>
    );
  }

  const panel = (
    <div
      className={
        floating
          ? "fixed right-4 bottom-6 z-30 w-[min(100%-2rem,22rem)] rounded-2xl border border-border bg-card p-5 shadow-xs lg:right-8"
          : "rounded-2xl border border-border bg-card p-5"
      }
      data-print="hide"
    >
      <div className="flex items-baseline justify-between gap-4">
        <p className="eyebrow text-ink-tertiary">Combien de cartes, par format</p>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="text-[13px] text-ink-tertiary underline-draw"
        >
          Annuler
        </button>
      </div>

      <div className="mt-4 divide-y divide-hairline">
        {CARD_KINDS.map((format) => (
          <div key={format.kind} className="flex items-center gap-4 py-3.5">
            <span aria-hidden className="emoji text-[22px]">
              {format.emoji}
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-[15px] font-medium text-ink">{format.title}</p>
              <p className="mt-0.5 text-[12.5px] text-ink-tertiary">{format.detail}</p>
            </div>

            <CountStepper
              size="sm"
              value={quota[format.kind]}
              min={PER_FORMAT_RANGE.min}
              max={capped ? quota[format.kind] : PER_FORMAT_RANGE.max}
              onChange={(next) => step(format.kind, next - quota[format.kind])}
              minusLabel={`Moins de ${format.title}`}
              plusLabel={`Plus de ${format.title}`}
            />
          </div>
        ))}
      </div>

      <p className="numeral mt-4 text-[13px] text-ink-tertiary">
        {total} carte{total > 1 ? "s" : ""} au total
        {capped ? ` · le maximum est ${TOTAL_RANGE.max}` : ""}
      </p>

      <button
        type="button"
        onClick={ask}
        disabled={total === 0}
        className={`mt-4 inline-flex h-9 w-full items-center justify-center rounded-lg border text-sm font-medium ${
          total === 0
            ? "cursor-not-allowed border-transparent bg-surface-sunken text-ink-tertiary"
            : "border-primary bg-primary text-primary-foreground"
        }`}
      >
        {existing === 0 ? "Générer ces cartes" : "Ajouter au paquet"}
      </button>

      {failure ? <Failure message={failure} /> : null}
    </div>
  );

  return floating ? <Float>{panel}</Float> : panel;
}

function Failure({ message }: { message: string }) {
  return (
    <p
      className="mt-4 rounded-button bg-negative-soft px-4 py-3 text-[13.5px] text-negative"
      role="alert"
    >
      {message}
    </p>
  );
}
