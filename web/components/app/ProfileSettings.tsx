"use client";

import { useState, useTransition, type ReactNode } from "react";

import {
  BLOCK_BOUNDS,
  SUBJECT_FAMILIES,
  clampBlocks,
  defaultBlocks,
  lengthContaining,
  readingHint,
  sheetLengthTitle,
  subjectEmoji,
  type SheetLength,
} from "@micabo/core";

import { SchoolField } from "@/components/app/SchoolField";
import {
  ROW_FIELD,
  ROW_GHOST,
  SettingsGroup,
  SettingsRow,
} from "@/components/app/settings/Rows";
import { useI18n } from "@/lib/i18n/client";
import { displayFamily, displaySubject } from "@/lib/i18n/subject-display";
import { UsernameField } from "@/components/app/UsernameField";
import { updateSettings } from "@/lib/actions/profile";

/**
 * Ce qui décide de ce que Micabo t'écrit, **une ligne par réglage**.
 *
 * Pas de bouton « Enregistrer » : un réglage à un cran se règle en le poussant, et un
 * formulaire qu'on oublie de valider est un réglage perdu. L'écriture est optimiste à l'écran
 * et confirmée derrière - c'est la table `profiles` qui tranche, et c'est elle que l'iPhone
 * relit. Le seul retour visible est un mot dans l'en-tête du groupe : il vaut pour les six
 * lignes, là où six témoins séparés feraient clignoter la page à chaque frappe.
 *
 * Les matières sont **repliées derrière leur compte**. Le mur de quarante pastilles occupait
 * la moitié de l'écran des réglages pour une question qu'on règle une fois par an, et il était
 * enfermé dans une zone à défilement qui coupait une catégorie en deux.
 */
export function ProfileSettings({
  initialName,
  initialUsername,
  initialLength,
  initialSubjects,
  initialSchool,
  initialSchoolId,
  initialCountry,
  children,
}: {
  initialName: string;
  initialUsername: string;
  initialLength: SheetLength;
  initialSubjects: string[];
  initialSchool: string;
  initialSchoolId: string | null;
  initialCountry?: string | null;
  /** La langue des fiches : elle décide aussi de ce qu'on te sert, donc elle est ici. */
  children?: ReactNode;
}) {
  const { locale, t } = useI18n();
  const [name, setName] = useState(initialName);
  const [blocks, setBlocks] = useState(() => defaultBlocks(initialLength));
  const [subjects, setSubjects] = useState(initialSubjects);
  const [openSubjects, setOpenSubjects] = useState(false);
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
    <SettingsGroup
      icon="📓"
      title={t("settings.section.study")}
      hint={t("settings.section.studyHint")}
      action={
        <p
          className={`text-[12.5px] ${saved === "erreur" ? "text-negative" : "text-accent"}`}
          role="status"
          aria-live="polite"
        >
          {saved === "ok"
            ? t("app.settings.saved.ok")
            : saved === "erreur"
              ? t("app.settings.saved.error")
              : ""}
        </p>
      }
    >
      <SettingsRow
        label={t("app.settings.displayNameLabel")}
        htmlFor="profile-name"
        tour="reglages-toi"
        control={
          <input
            id="profile-name"
            value={name}
            onChange={(event) => setName(event.target.value)}
            onBlur={() => save({ displayName: name })}
            placeholder={t("app.settings.displayNamePlaceholder")}
            className={`${ROW_FIELD} w-[15rem] max-w-full`}
          />
        }
      />

      <UsernameField initial={initialUsername} />

      <SettingsRow
        label={t("app.settings.subjects")}
        hint={
          subjects.length > 0
            ? subjects
                .slice(0, 4)
                .map((subject) => displaySubject(subject, locale))
                .join(" · ") + (subjects.length > 4 ? ` +${subjects.length - 4}` : "")
            : t("app.settings.subjectsEmpty")
        }
        control={
          <button
            type="button"
            onClick={() => setOpenSubjects((open) => !open)}
            aria-expanded={openSubjects}
            className={ROW_GHOST}
          >
            {openSubjects ? t("app.settings.done") : t("app.settings.change")}
          </button>
        }
      >
        {openSubjects ? (
          <div className="rise space-y-4 rounded-group bg-surface-muted p-4">
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
                        className={`pressable flex items-center gap-1 rounded-pill px-2.5 py-1.5 text-[13px] ${
                          selected
                            ? "bg-accent-soft font-medium text-accent"
                            : "bg-surface text-ink"
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
        ) : null}
      </SettingsRow>

      <SettingsRow label={t("app.settings.school")} hint={t("app.settings.schoolHint")}>
        <SchoolField
          initialName={initialSchool}
          initialId={initialSchoolId}
          countryCode={initialCountry}
          onChange={(next) =>
            save({
              institutionName: next.name || null,
              institutionId: next.id,
            })
          }
        />
      </SettingsRow>

      <SettingsRow
        label={t("app.settings.sheetLength")}
        htmlFor="profile-blocks"
        control={
          <p className="text-[13.5px] font-medium text-ink">
            {sheetLengthTitle(length)}{" "}
            <span className="font-normal text-ink-tertiary">· {readingHint(blocks)}</span>
          </p>
        }
      >
        <input
          id="profile-blocks"
          type="range"
          min={BLOCK_BOUNDS.min}
          max={BLOCK_BOUNDS.max}
          value={blocks}
          onChange={(event) => setBlocks(clampBlocks(Number(event.target.value)))}
          onPointerUp={() => save({ sheetBlocks: blocks })}
          onKeyUp={() => save({ sheetBlocks: blocks })}
          className="w-full accent-[var(--color-accent)]"
        />
      </SettingsRow>

      {children}
    </SettingsGroup>
  );
}
