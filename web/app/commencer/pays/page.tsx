"use client";

import { useEffect, useMemo, useState } from "react";

import { COUNTRIES, countryFor, guessCountry, type CountryCode } from "@micabo/core";

import { ChoiceGroup, ChoiceRow, ContinueButton, Scaffold, useAdvance } from "@/components/onboarding/Scaffold";
import { Flag } from "@/components/onboarding/Flag";
import { trackOnboardingAnswer } from "@/lib/analytics/funnel";
import { useI18n } from "@/lib/i18n/client";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * Le pays de scolarisation.
 *
 * Il passe en premier parce qu'il **commande les réponses suivantes** - les paliers, les
 * filières, le barème des moyennes - et qu'il décide de la langue dans laquelle Micabo écrit.
 *
 * **Un appui suffit** : toucher un pays avance tout seul, après le temps de voir la coche.
 * « Autre pays » ouvre un champ où l'on écrit son pays, et c'est Entrée ou le bouton qui
 * avance. Un menu déroulant de deux cents entrées se parcourt moins vite qu'un mot tapé.
 *
 * L'ordre est celui du noyau, donc celui de l'app : les marchés visés d'abord, les pays
 * francophones historiques ensuite. Le pays détecté est **mis en évidence à sa place** plutôt
 * que remonté en tête - le remonter cassait un ordre qui veut dire quelque chose.
 */
export default function CountryStep() {
  const { answers, set, ready } = useOnboarding();
  const { t, locale } = useI18n();
  const advance = useAdvance();
  const [guessed, setGuessed] = useState<CountryCode | null>(null);

  function countryName(code: CountryCode, fallback: string) {
    const key = `country.${code}`;
    const translated = t(key);
    return translated === key ? fallback : translated;
  }

  useEffect(() => {
    setGuessed(guessCountry(navigator.languages ?? [navigator.language], locale));
  }, [locale]);

  const selected = answers.country ?? null;
  const [typed, setTyped] = useState(answers.customCountry ?? "");
  useEffect(() => {
    if (ready) setTyped(answers.customCountry ?? "");
    // Une fois, quand les réponses gardées arrivent.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready]);

  const listed = useMemo(() => COUNTRIES.filter((item) => item.code !== "other"), []);
  const elsewhere = countryFor("other");
  const answered = selected === "other" ? typed.trim().length >= 2 : Boolean(selected);

  function choose(code: CountryCode) {
    // Changer de pays invalide le palier, la filière et l'année : garder « Prépa » à
    // quelqu'un qui étudie en Turquie serait une réponse fausse écrite à sa place.
    const changed = code !== selected;
    set({
      country: code,
      ...(changed ? { stageId: undefined, trackId: undefined, yearId: undefined } : {}),
      ...(code !== "other" ? { customCountry: undefined } : {}),
    });
    trackOnboardingAnswer("country", code);
    if (code !== "other") advance({ context: { country: code, trackId: changed ? undefined : answers.trackId }, auto: true });
  }

  return (
    <Scaffold title={t("onboarding.paysTitle")} footer={<ContinueButton enabled={answered && ready} />} width="wide">
      {/* Vingt-cinq pays : deux colonnes dès que la carte le permet, et la liste se lit d'un
          coup d'œil. Sur un téléphone, une colonne qui défile dans la carte. */}
      <ChoiceGroup label={t("onboarding.paysTitle")} className="grid grid-cols-1 gap-2 sm:grid-cols-2">
        {listed.map((item) => (
          <ChoiceRow
            key={item.code}
            icon={<Flag iso={item.iso} emoji={item.flag} label="" className="h-[20px] w-[28px] shrink-0" />}
            title={countryName(item.code, item.name)}
            detail={item.code === guessed ? t("common.detected") : undefined}
            selected={selected === item.code}
            onSelect={() => choose(item.code)}
          />
        ))}

        <ChoiceRow
          icon={<Flag iso="" emoji={elsewhere.flag} label="" className="h-[20px] w-[28px] shrink-0" />}
          title={selected === "other" && typed.trim() ? typed.trim() : countryName("other", elsewhere.name)}
          selected={selected === "other"}
          onSelect={() => choose("other")}
        />

        {selected === "other" ? (
          <div className="rise pt-1 sm:col-span-2">
            <label htmlFor="pays-libre" className="mb-1.5 block text-[13px] font-bold text-ink">
              {t("onboarding.customCountry")}
            </label>
            <input
              id="pays-libre"
              type="text"
              autoFocus
              autoComplete="country-name"
              enterKeyHint="next"
              value={typed}
              onChange={(event) => {
                setTyped(event.target.value);
                set({ customCountry: event.target.value.trim() || undefined });
              }}
              placeholder={t("onboarding.customPlaceholder")}
              className="h-12 w-full rounded-[14px] border-[1.5px] border-stroke bg-surface px-4 text-[16px] text-ink outline-none transition-colors duration-hover placeholder:text-ink-tertiary focus:border-accent"
            />
          </div>
        ) : null}
      </ChoiceGroup>
    </Scaffold>
  );
}
