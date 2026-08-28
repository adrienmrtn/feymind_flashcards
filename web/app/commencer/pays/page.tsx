"use client";

import { Suspense, useEffect, useMemo, useState } from "react";

import { COUNTRIES, countryFor, guessCountry, type CountryCode } from "@micabo/core";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { Flag } from "@/components/onboarding/Flag";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * Le pays de scolarisation.
 *
 * Il passe devant « qu'est-ce qui te décrit le mieux ? » parce qu'il **commande ses réponses**, et
 * il décide aussi de la langue dans laquelle Micabo écrit. La ligne qui annonçait le système retenu
 * a disparu : elle répétait en petit ce que l'écran suivant allait montrer en grand.
 *
 * L'ordre est celui du noyau, donc celui de l'app : les marchés visés d'abord, les pays
 * francophones historiques ensuite. Le pays détecté est **mis en évidence à sa place** plutôt que
 * remonté en tête - le remonter cassait un ordre qui veut dire quelque chose.
 *
 * « Autre pays » ouvre un champ où l'on **écrit** son pays. Un menu déroulant de deux cents entrées
 * se parcourt moins vite qu'un mot tapé, et c'est déjà le choix de l'app.
 */
export default function CountryStep() {
  return (
    <Suspense fallback={null}>
      <CountryStepBody />
    </Suspense>
  );
}

function CountryStepBody() {
  const { answers, set, ready } = useOnboarding();
  const [guessed, setGuessed] = useState<CountryCode | null>(null);

  useEffect(() => {
    setGuessed(guessCountry(navigator.languages ?? [navigator.language]));
  }, []);

  const selected = answers.country ?? null;
  const [typed, setTyped] = useState(answers.customCountry ?? "");

  const listed = useMemo(() => COUNTRIES.filter((item) => item.code !== "other"), []);
  const elsewhere = countryFor("other");

  const answered = selected === "other" ? typed.trim().length >= 2 : Boolean(selected);

  return (
    <Scaffold
      eyebrow="Ton parcours"
      title="Tu étudies dans quel pays ?"
      footer={<ContinueButton enabled={answered && ready} href="/commencer/niveau" />}
    >
      <div className="space-y-2 pr-1">
        {listed.map((item) => (
          <Row
            key={item.code}
            iso={item.iso}
            emoji={item.flag}
            name={item.name}
            detail={item.code === guessed ? "Détecté" : undefined}
            selected={selected === item.code}
            onSelect={() =>
              // Changer de pays invalide le palier : c'est l'écran suivant qui le retrouvera, et le
              // garder ferait répondre « Prépa » à quelqu'un qui étudie en Turquie.
              set({ country: item.code, stageId: undefined, customCountry: undefined })
            }
          />
        ))}

        <Row
          iso=""
          emoji={elsewhere.flag}
          name={selected === "other" && typed.trim() ? typed.trim() : elsewhere.name}
          selected={selected === "other"}
          onSelect={() => set({ country: "other", stageId: undefined })}
        />

        {selected === "other" ? (
          <div className="rise pl-1 pt-1">
            <label htmlFor="pays-libre" className="sr-only">
              Le nom de ton pays
            </label>
            <input
              id="pays-libre"
              type="text"
              autoFocus
              autoComplete="country-name"
              value={typed}
              onChange={(event) => {
                setTyped(event.target.value);
                set({ customCountry: event.target.value.trim() || undefined });
              }}
              placeholder="Écris ton pays"
              className="paper h-13 w-full rounded-button bg-surface px-4 py-3.5 text-[16px] text-ink outline-none placeholder:text-ink-tertiary"
            />
          </div>
        ) : null}
      </div>
    </Scaffold>
  );
}

/**
 * Une réponse de cet écran-ci, et pas le `ChoiceRow` commun : celui-là porte un emoji à même la
 * ligne, or un drapeau n'est pas un emoji ici - c'est une image, et elle a son propre gabarit.
 */
function Row({
  iso,
  emoji,
  name,
  detail,
  selected,
  onSelect,
}: {
  iso: string;
  emoji: string;
  name: string;
  detail?: string;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      className={`pressable flex w-full items-center gap-4 rounded-button px-4 py-3.5 text-left transition-colors duration-hover ${
        selected ? "bg-accent-soft" : "bg-surface paper"
      }`}
    >
      <Flag iso={iso} emoji={emoji} label="" className="h-[22px] w-[30px]" />

      <span className="min-w-0 flex-1">
        <span className={`block truncate text-[16px] font-medium ${selected ? "text-accent" : "text-ink"}`}>
          {name}
        </span>
        {detail ? (
          <span className="mt-0.5 block text-[12.5px] text-ink-tertiary">{detail}</span>
        ) : null}
      </span>

      <span
        aria-hidden
        className={`flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 transition-colors duration-hover ${
          selected ? "border-accent bg-accent" : "border-stroke-strong"
        }`}
      >
        {selected ? (
          <svg viewBox="0 0 20 20" className="h-full w-full text-on-ink">
            <path
              d="M5 10.5l3.2 3.2L15 7"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.4"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        ) : null}
      </span>
    </button>
  );
}
