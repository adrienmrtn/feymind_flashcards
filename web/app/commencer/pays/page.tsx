"use client";

import { useEffect, useMemo, useState } from "react";

import { COUNTRIES, countryFor, guessCountry, type CountryCode } from "@micabo/core";

import { ChoiceRow, ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * Le pays de scolarisation.
 *
 * Elle passe devant « qu'est-ce qui te décrit le mieux ? » parce qu'elle **commande ses réponses**,
 * et elle décide aussi de la langue dans laquelle Micabo écrit. Les deux conséquences se lisent
 * sous les pastilles : c'est ce qui justifie la question au moment où on la pose.
 *
 * Le pays détecté est posé **en premier et déjà en évidence**. C'est une suggestion, jamais une
 * réponse : la locale du navigateur dit la langue, pas le pays où l'on étudie.
 */
export default function CountryStep() {
  const { answers, set, ready } = useOnboarding();
  const [guessed, setGuessed] = useState<CountryCode | null>(null);

  useEffect(() => {
    setGuessed(guessCountry(navigator.languages ?? [navigator.language]));
  }, []);

  const selected = answers.country ?? null;

  // Le pays détecté remonte en tête. Les autres gardent leur ordre, qui est celui de l'usage
  // réel de Micabo — la France d'abord, « Ailleurs » en dernier.
  const ordered = useMemo(() => {
    if (!guessed) return COUNTRIES;
    const first = COUNTRIES.find((country) => country.code === guessed);
    if (!first) return COUNTRIES;
    return [first, ...COUNTRIES.filter((country) => country.code !== guessed)];
  }, [guessed]);

  const country = selected ? countryFor(selected) : null;

  return (
    <Scaffold
      eyebrow="Ton parcours"
      title="Tu étudies dans quel pays ?"
      subtitle="Pour te proposer le bon système scolaire."
      footer={
        <ContinueButton
          enabled={Boolean(selected) && ready}
          href="/commencer/niveau"
        />
      }
    >
      <div className="space-y-2">
        {ordered.map((item, index) => (
          <ChoiceRow
            key={item.code}
            emoji={item.flag}
            title={item.name}
            detail={index === 0 && item.code === guessed ? "Détecté" : undefined}
            selected={selected === item.code}
            onSelect={() =>
              // Changer de pays invalide le palier : c'est l'écran suivant qui le retrouvera, et
              // le garder ferait répondre « Prépa » à quelqu'un qui étudie aux États-Unis.
              set({ country: item.code, stageId: undefined })
            }
          />
        ))}
      </div>

      {country ? (
        <p className="mt-5 text-center text-[13px] text-ink-tertiary">
          Système retenu : {country.systemHint} · Micabo écrira en{" "}
          {country.language === "fr" ? "français" : "anglais"}.
        </p>
      ) : null}
    </Scaffold>
  );
}
