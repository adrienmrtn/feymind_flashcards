"use client";

import {
  GENERATION_LANGUAGES,
  SOURCE_LANGUAGE,
  generationLanguageLabel,
  type GenerationLanguage,
} from "@micabo/core";

/**
 * La langue de **cette** fiche.
 *
 * Par défaut on reste dans celle du document. Forcer une autre langue est
 * un choix, pas un défaut caché derrière le pays du profil.
 */
export function LanguageChoices({
  value,
  onChange,
  disabled = false,
}: {
  value: GenerationLanguage;
  onChange: (next: GenerationLanguage) => void;
  disabled?: boolean;
}) {
  return (
    <div>
      <label htmlFor="generation-language" className="sr-only">
        Langue de la fiche
      </label>
      <select
        id="generation-language"
        value={value}
        disabled={disabled}
        onChange={(event) => onChange(event.target.value as GenerationLanguage)}
        className="h-12 w-full rounded-button bg-surface-muted px-4 text-[15px] font-medium text-ink outline-none disabled:opacity-60"
      >
        {GENERATION_LANGUAGES.map((code) => (
          <option key={code} value={code}>
            {generationLanguageLabel(code)}
          </option>
        ))}
      </select>
      <p className="mt-2 text-[12.5px] leading-relaxed text-ink-tertiary">
        {value === SOURCE_LANGUAGE
          ? "Micabo écrit dans la langue du cours."
          : "La fiche sera traduite dans cette langue."}
      </p>
    </div>
  );
}
