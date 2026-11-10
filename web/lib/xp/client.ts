"use client";

import { useEffect, useState } from "react";

import type { XpReason } from "@micabo/core";

import { applyAward, readXpState, xpSnapshot, type XpSnapshot, type XpState } from "@/lib/xp/state";

/**
 * **L'XP dans le navigateur** (`docs/refonte-knowunity.md` § 2) : un état par compte dans
 * `localStorage`, que chaque geste récompensé fait monter (`awardXp`) et que les écrans lisent
 * (`useXp`). Le navigateur peut refuser d'écrire (navigation privée, stockage plein) : l'XP vit
 * alors le temps de la page, et rien ne casse.
 *
 * `awardXp` ne demande aucun contexte React : un quiz, une carte ou Mika l'appellent comme
 * `requestPaywall`. `XpHost`, monté une fois dans l'app, écoute l'événement pour le « +10 XP »,
 * la feuille de fête et la synchro.
 */
export const XP_EVENT = "micabo:xp";

export interface XpGain {
  reason: XpReason;
  amount: number;
  reachedGoal: boolean;
}

const PREFIX = "micabo.xp.";
let owner = "guest";
let memory: XpState | null = null;

/** Le compte dont on tient l'XP : posé par `XpHost`, pour que deux comptes ne se mélangent pas. */
export function setXpOwner(userId: string | null): void {
  const next = userId || "guest";
  if (next !== owner) memory = null;
  owner = next;
}

function key(): string {
  return `${PREFIX}${owner}`;
}

export function loadXpState(now = new Date()): XpState {
  try {
    const raw = window.localStorage.getItem(key());
    if (raw !== null) return readXpState(JSON.parse(raw), now);
  } catch {
    // Illisible ou refusé : l'état de la page, s'il y en a un.
  }
  return memory ? readXpState(memory, now) : readXpState(null, now);
}

export function saveXpState(state: XpState): void {
  memory = state;
  try {
    window.localStorage.setItem(key(), JSON.stringify(state));
  } catch {
    // Le navigateur refuse : l'XP reste en mémoire le temps de la page.
  }
}

/** Un geste récompensé. Sans effet hors navigateur, et au-delà du plafond du jour. */
export function awardXp(reason: XpReason): void {
  if (typeof window === "undefined") return;
  const now = new Date();
  const award = applyAward(loadXpState(now), reason, now);
  if (award.gained <= 0) return;
  saveXpState(award.state);
  window.dispatchEvent(new CustomEvent<XpGain>(XP_EVENT, { detail: { reason, amount: award.gained, reachedGoal: award.reachedGoal } }));
}

const ZERO: XpSnapshot = { today: 0, week: 0, total: 0, league: "bronze" };

/**
 * Ce que les pastilles montrent : l'XP du jour, de la semaine, le total et la ligue. Zéro au
 * premier rendu (le serveur ne connaît pas le navigateur), puis la valeur gardée, puis chaque gain.
 */
export function useXp(): XpSnapshot {
  const [snapshot, setSnapshot] = useState<XpSnapshot>(ZERO);
  useEffect(() => {
    const refresh = () => {
      const now = new Date();
      setSnapshot(xpSnapshot(loadXpState(now), now));
    };
    refresh();
    window.addEventListener(XP_EVENT, refresh);
    window.addEventListener("storage", refresh);
    window.addEventListener("focus", refresh);
    return () => {
      window.removeEventListener(XP_EVENT, refresh);
      window.removeEventListener("storage", refresh);
      window.removeEventListener("focus", refresh);
    };
  }, []);
  return snapshot;
}
