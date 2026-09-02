"use client";

import { useState, useTransition } from "react";

import {
  BLOCK_BOUNDS,
  DAILY_MINUTES_STEPS,
  SUBJECT_FAMILIES,
  clampBlocks,
  dailyMinutesLabel,
  defaultBlocks,
  lengthContaining,
  newCardsPerDay,
  readingHint,
  sheetLengthTitle,
  subjectEmoji,
  type SheetLength,
} from "@micabo/core";

import { SchoolField } from "@/components/app/SchoolField";
import { useI18n } from "@/lib/i18n/client";
import { displayFamily, displaySubject } from "@/lib/i18n/subject-display";
import { UsernameField } from "@/components/app/UsernameField";
import { updateSettings } from "@/lib/actions/profile";

/**
 * Les réglages du compte, **écrits en base à chaque changement**.
 *
 * Pas de bouton « Enregistrer » : un réglage à un cran se règle en le poussant, et un formulaire
 * qu'on oublie de valider est un réglage perdu. L'écriture est optimiste à l'écran et confirmée
 * derrière - c'est la table `profiles` qui tranche, et c'est elle que l'iPhone relit.
 */
export function ProfileSettings({
  heading = "Réglages",
  initialName,
  initialUsername,
  initialMinutes,
  initialLength,
  initialSubjects,
  initialSchool,
  initialSchoolId,
}: {
  heading?: string;
  initialName: string;
  initialUsername: string;
  initialMinutes: number;
  initialLength: SheetLength;
  initialSubjects: string[];
  initialSchool: string;
  initialSchoolId: string | null;
}) {
  const { locale } = useI18n();
  const [name, setName] = useState(initialName);
  const [minutes, setMinutes] = useState(initialMinutes);
  const [blocks, setBlocks] = useState(() => defaultBlocks(initialLength));
  const [subjects, setSubjects] = useState(initialSubjects);
  const [saved, setSaved] = useState<"repos" | "ok" | "erreur">("repos");
  const [, startTransition] = useTransition();

  const length = lengthContaining(blocks);

  function save(patch: Parameters<typeof updateSettings>[0]) {
    startTransition(async () => {
      const result = await updateSettings(patch);
      setSaved(result.status === "ok" ? "ok" : "erreur");
    });
  }

  return (
    <div className="saas-card p-7">
      <div className="flex items-baseline justify-between gap-4">
        <p className="text-[13px] text-ink-tertiary">{heading}</p>
        <p
          className={`text-[12.5px] ${saved === "erreur" ? "text-negative" : "text-accent"}`}
          role="status"
          aria-live="polite"
        >
          {saved === "ok" ? "Enregistré" : saved === "erreur" ? "Non enregistré" : ""}
        </p>
      </div>

      <label htmlFor="profile-name" className="mt-5 block text-[13px] text-ink-tertiary">
        Ton nom
      </label>
      <input
        id="profile-name"
        value={name}
        onChange={(event) => setName(event.target.value)}
        onBlur={() => save({ displayName: name })}
        placeholder="Comment on t'appelle"
        className="mt-2 h-12 w-full rounded-button bg-surface-muted px-4 text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
      />

      <UsernameField initial={initialUsername} />

      <p className="mt-7 text-[13px] text-ink-tertiary">Matières</p>
      <div className="mt-2.5 max-h-[220px] space-y-4 overflow-y-auto pr-1">
        {SUBJECT_FAMILIES.map((family) => (
          <div key={family.name}>
            <p className="mb-1.5 text-[11px] font-medium uppercase tracking-caps text-ink-tertiary">
              {displayFamily(family.name, locale)}
            </p>
            <div className="flex flex-wrap gap-1.5">
              {family.subjects.map((subject) => {
                const selected = subjects.includes(subject);
                return (
                  <button
                    key={subject}
                    type="button"
                    aria-pressed={selected}
                    onClick={() => {
                      const next = selected
                        ? subjects.filter((item) => item !== subject)
                        : [...subjects, subject];
                      setSubjects(next);
                      save({ subjects: next });
                    }}
                    className={`pressable hover-tile flex items-center gap-1 rounded-pill px-2.5 py-1.5 text-[13px] ${
                      selected
                        ? "bg-accent-soft font-medium text-accent"
                        : "bg-surface-muted text-ink"
                    }`}
                  >
                    <span aria-hidden className="emoji text-[13px]">
                      {subjectEmoji(subject)}
                    </span>
                    {displaySubject(subject, locale)}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      <p className="mt-7 text-[13px] text-ink-tertiary">École</p>
      <div className="mt-2">
        <SchoolField
          initialName={initialSchool}
          initialId={initialSchoolId}
          onChange={(next) =>
            save({
              institutionName: next.name || null,
              institutionId: next.id,
            })
          }
        />
      </div>

      <div className="mt-7">
        <div className="flex items-baseline justify-between gap-3">
          <label htmlFor="profile-minutes" className="text-[13px] text-ink-tertiary">
            Rythme quotidien
          </label>
          <p className="text-[13px] font-medium text-ink">
            {dailyMinutesLabel(minutes)}{" "}
            <span className="text-ink-tertiary">· {newCardsPerDay(minutes)} cartes neuves</span>
          </p>
        </div>
        <input
          id="profile-minutes"
          type="range"
          min={0}
          max={DAILY_MINUTES_STEPS.length - 1}
          value={Math.max(0, DAILY_MINUTES_STEPS.indexOf(minutes))}
          onChange={(event) => {
            const next = DAILY_MINUTES_STEPS[Number(event.target.value)] ?? minutes;
            setMinutes(next);
          }}
          onPointerUp={() => save({ dailyMinutes: minutes })}
          onKeyUp={() => save({ dailyMinutes: minutes })}
          className="mt-4 w-full accent-[var(--color-accent)]"
        />
      </div>

      <div className="mt-7">
        <div className="flex items-baseline justify-between gap-3">
          <label htmlFor="profile-blocks" className="text-[13px] text-ink-tertiary">
            Longueur des fiches
          </label>
          <p className="text-[13px] font-medium text-ink">
            {sheetLengthTitle(length)}{" "}
            <span className="text-ink-tertiary">· {readingHint(blocks)}</span>
          </p>
        </div>
        <input
          id="profile-blocks"
          type="range"
          min={BLOCK_BOUNDS.min}
          max={BLOCK_BOUNDS.max}
          value={blocks}
          onChange={(event) => setBlocks(clampBlocks(Number(event.target.value)))}
          onPointerUp={() => save({ sheetBlocks: blocks })}
          onKeyUp={() => save({ sheetBlocks: blocks })}
          className="mt-4 w-full accent-[var(--color-accent)]"
        />
      </div>
    </div>
  );
}
