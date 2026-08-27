"use client";

import { useState, useTransition } from "react";
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

import { Float } from "@/components/app/Float";
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
}: {
  courseId: string;
  existing: number;
  floating?: boolean;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [failure, setFailure] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [quota, setQuota] = useState<QuestionQuota>(DEFAULT_QUOTA);

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
      const result = await generateCards(courseId, quota);
      if (result.status === "error") setFailure(result.message ?? "Ça n'a pas marché.");
      else {
        setOpen(false);
        router.refresh();
      }
    });
  }

  if (pending) {
    const pendingUi = (
      <div
        className={
          floating
            ? "fixed right-4 bottom-32 z-30 w-[min(100%-2rem,22rem)] paper flex items-center gap-4 rounded-group bg-surface p-5 shadow-floating lg:right-8 lg:bottom-8"
            : "paper flex items-center gap-4 rounded-group bg-surface p-5"
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
            className="pressable shiny fixed right-4 bottom-32 z-30 flex h-14 items-center gap-2.5 rounded-button bg-ink px-5 text-[15px] font-semibold text-on-ink shadow-floating lg:right-8 lg:bottom-8"
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
          <button
            type="button"
            onClick={() => setOpen(true)}
            className="pressable hover-tile paper flex w-full items-start gap-4 rounded-group bg-surface p-5 text-left"
          >
            <span
              aria-hidden
              className="flex h-12 w-12 shrink-0 items-center justify-center rounded-tile bg-accent-soft text-[24px]"
            >
              ✨
            </span>
            <span className="min-w-0">
              <span className="block text-[16.5px] font-bold text-ink">Générer les cartes</span>
              <span className="mt-1 block text-[13.5px] leading-relaxed text-ink-secondary">
                Choisis tes formats - questions, trous, QCM - et Micabo écrit les cartes à
                partir de la fiche.
              </span>
            </span>
          </button>
        ) : (
          <button
            type="button"
            onClick={() => setOpen(true)}
            className="pressable hover-tile paper flex w-full items-center gap-3.5 rounded-group bg-surface px-5 py-4 text-left"
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
          ? "fixed right-4 bottom-32 z-30 w-[min(100%-2rem,22rem)] paper rise rounded-group bg-surface p-5 shadow-floating lg:right-8 lg:bottom-8"
          : "paper rise rounded-group bg-surface p-5"
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

            <div className="flex shrink-0 items-center gap-1 rounded-pill bg-surface-muted p-1">
              <Step
                label={`Moins de ${format.title}`}
                sign="minus"
                enabled={quota[format.kind] > PER_FORMAT_RANGE.min}
                onPress={() => step(format.kind, -1)}
              />
              <span className="numeral min-w-7 text-center text-[15px] font-semibold text-ink">
                {quota[format.kind]}
              </span>
              <Step
                label={`Plus de ${format.title}`}
                sign="plus"
                /* Le plafond éteint le bouton plutôt que de rogner après validation : un chiffre
                   corrigé dans le dos fait sauter le compteur sous le doigt. */
                enabled={!capped && quota[format.kind] < PER_FORMAT_RANGE.max}
                onPress={() => step(format.kind, 1)}
              />
            </div>
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
        className={`pressable mt-4 h-13 w-full rounded-button py-3.5 text-[15px] font-semibold transition-colors duration-hover ${
          total === 0 ? "cursor-not-allowed bg-surface-sunken text-ink-tertiary" : "bg-ink text-on-ink"
        }`}
      >
        {existing === 0 ? "Générer ces cartes" : "Ajouter au paquet"}
      </button>

      {failure ? <Failure message={failure} /> : null}
    </div>
  );

  return floating ? <Float>{panel}</Float> : panel;
}

function Step({
  label,
  sign,
  enabled,
  onPress,
}: {
  label: string;
  sign: "plus" | "minus";
  enabled: boolean;
  onPress: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      disabled={!enabled}
      onClick={onPress}
      className={`flex h-7 w-7 items-center justify-center rounded-full transition-colors duration-hover ${
        enabled ? "bg-surface text-ink paper" : "text-ink-tertiary/40"
      }`}
    >
      <svg aria-hidden viewBox="0 0 20 20" className="h-3.5 w-3.5">
        <path
          d={sign === "plus" ? "M10 4.5v11M4.5 10h11" : "M4.5 10h11"}
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
        />
      </svg>
    </button>
  );
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
