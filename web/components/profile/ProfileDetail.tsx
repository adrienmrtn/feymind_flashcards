"use client";

import { useState, useTransition, type ReactNode } from "react";
import { Download, LogOut } from "lucide-react";

import {
  COUNTRIES,
  SUBJECT_FAMILIES,
  displayUsername,
  normalizeUsername,
  stagesFor,
  subjectEmoji,
  type CountryCode,
} from "@micabo/core";

import { SchoolField } from "@/components/app/SchoolField";
import { LessonPrimaryButton, LessonSecondaryButton } from "@/components/lesson/LessonButtons";
import { Sheet } from "@/components/lesson/Sheet";
import { deleteAccount, exportAccountData, signOut, updateSettings } from "@/lib/actions/profile";
import { setUsername } from "@/lib/actions/social";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";
import { displayFamily, displaySubject } from "@/lib/i18n/subject-display";
import { forgetLocalAccount } from "@/lib/onboarding/persist";

export interface ProfileDetailProps {
  name: string;
  username: string;
  countryCode: CountryCode;
  /**
   * L'identifiant du palier (`fr.lycee`), ou `null`. Le menu le choisit ; l'action n'en écrit
   * que le registre dans `profiles.study_level`, et garde le palier sur ce navigateur.
   */
  studyLevel: string | null;
  school: string;
  schoolId: string | null;
  subjects: string[];
}

const FIELD = "w-full rounded-[14px] bg-surface px-3.5 py-3 text-[16px] font-semibold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)] outline-none placeholder:text-ink-tertiary focus-visible:shadow-[inset_0_0_0_2px_var(--color-accent)]";

/**
 * **Toutes les infos, et le compte** : prénom, nom d'utilisateur, pays, niveau, établissement,
 * matières ; puis l'adresse, se déconnecter, exporter ses données, supprimer le compte. Pas
 * de bouton « Enregistrer » : chaque champ s'écrit quand on le quitte, et un mot en tête dit
 * si c'est passé. Jumeau de `SettingsView` côté Swift, réduit à ce qui reste (§ 11).
 */
export function ProfileDetail({ email, onClose, ...initial }: ProfileDetailProps & { email: string; onClose: () => void }) {
  const { t, locale } = useI18n();
  const [name, setName] = useState(initial.name);
  const [username, setUsernameDraft] = useState(initial.username);
  const [usernameNote, setUsernameNote] = useState<string | null>(null);
  const [country, setCountry] = useState<CountryCode>(initial.countryCode);
  const [level, setLevel] = useState<string | null>(initial.studyLevel);
  const [subjects, setSubjects] = useState(initial.subjects);
  const [subjectsOpen, setSubjectsOpen] = useState(false);
  const [saved, setSaved] = useState<"idle" | "ok" | "error">("idle");
  const [deleting, setDeleting] = useState(false);
  const [typed, setTyped] = useState("");
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const stages = stagesFor(country);
  const regionNames = (() => {
    try {
      return new Intl.DisplayNames([localeBcp47(locale)], { type: "region" });
    } catch {
      return null;
    }
  })();
  const countryName = (iso: string, fallback: string) => {
    try {
      return regionNames?.of(iso.toUpperCase()) ?? fallback;
    } catch {
      return fallback;
    }
  };

  function save(patch: Parameters<typeof updateSettings>[0]) {
    startTransition(async () => {
      const result = await updateSettings(patch);
      setSaved(result.status === "ok" ? "ok" : "error");
    });
  }

  function saveUsername() {
    if (username.trim() === initial.username && !usernameNote) return;
    startTransition(async () => {
      const result = await setUsername(username);
      if (result.status === "ok") {
        setSaved("ok");
        setUsernameNote(null);
        if (result.username) setUsernameDraft(result.username);
      } else {
        setSaved("error");
        setUsernameNote(result.message ?? t("app.settings.saved.error"));
      }
    });
  }

  function exportData() {
    startTransition(async () => {
      const result = await exportAccountData();
      if (result.status !== "ok" || !result.payload) {
        setFailure(result.message ?? t("app.common.errorGeneric"));
        return;
      }
      const blob = new Blob([JSON.stringify(result.payload, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `micabo-donnees-${new Date().toISOString().slice(0, 10)}.json`;
      link.click();
      URL.revokeObjectURL(url);
    });
  }

  const confirmWord = t("app.settings.delete.confirmWord");
  const canDelete = typed.trim().toLowerCase() === confirmWord.toLowerCase();

  function remove() {
    if (!canDelete || pending) return;
    forgetLocalAccount();
    startTransition(async () => {
      const result = await deleteAccount();
      if (result.status !== "ok") {
        setFailure(result.message ?? t("app.settings.delete.error"));
        return;
      }
      window.location.href = "/";
    });
  }

  return (
    <Sheet title={t("app.profileTab.info")} onClose={onClose} wide>
      <p role="status" aria-live="polite" className={`-mt-2 min-h-[18px] text-[13px] font-bold ${saved === "error" ? "text-wrong-ink" : "text-accent"}`}>
        {saved === "ok" ? t("app.profileTab.saved") : saved === "error" ? t("app.profileTab.notSaved") : ""}
      </p>

      <Field label={t("app.profileTab.name")} htmlFor="profile-name">
        <input id="profile-name" value={name} onChange={(event) => setName(event.target.value)} onBlur={() => name.trim() !== initial.name.trim() && save({ displayName: name })} placeholder={t("app.profileTab.namePlaceholder")} maxLength={60} className={FIELD} />
      </Field>

      <Field label={t("app.profileTab.username")} htmlFor="profile-username" hint={usernameNote ?? (normalizeUsername(username) ? displayUsername(normalizeUsername(username)) : t("app.settings.usernameHelp"))} hintTone={usernameNote ? "error" : "normal"}>
        <div className={`${FIELD} flex items-center gap-1`}>
          <span className="text-[16px] font-extrabold text-ink-tertiary">@</span>
          <input id="profile-username" value={username} onChange={(event) => setUsernameDraft(event.target.value)} onBlur={saveUsername} className="min-w-0 flex-1 bg-transparent outline-none" maxLength={30} />
        </div>
      </Field>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field label={t("app.profileTab.country")} htmlFor="profile-country">
          <select
            id="profile-country"
            value={country}
            onChange={(event) => {
              const next = event.target.value as CountryCode;
              setCountry(next);
              setLevel(null);
              save({ countryCode: next, studyLevel: null });
            }}
            className={FIELD}
          >
            {COUNTRIES.map((entry) => (
              <option key={entry.code} value={entry.code}>
                {entry.flag} {countryName(entry.iso, entry.name)}
              </option>
            ))}
          </select>
        </Field>
        <Field label={t("app.profileTab.level")} htmlFor="profile-level">
          <select
            id="profile-level"
            value={level ?? ""}
            onChange={(event) => {
              const next = event.target.value || null;
              setLevel(next);
              save({ studyLevel: next });
            }}
            className={FIELD}
          >
            <option value="">{t("app.profileTab.levelNone")}</option>
            {stages.map((stage) => (
              <option key={stage.id} value={stage.id}>
                {stage.emoji} {stage.title}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <Field label={t("app.profileTab.school")}>
        <SchoolField initialName={initial.school} initialId={initial.schoolId} countryCode={country} onChange={(next) => save({ institutionName: next.name || null, institutionId: next.id })} />
      </Field>

      <Field label={t("app.profileTab.subjects")} hint={subjects.length > 0 ? subjects.map((subject) => displaySubject(subject, locale)).join(" · ") : t("app.profileTab.subjectsNone")}>
        <button type="button" onClick={() => setSubjectsOpen((open) => !open)} aria-expanded={subjectsOpen} className="pressable w-fit rounded-pill bg-surface-muted px-3.5 py-2 text-[14px] font-extrabold text-ink">
          {subjectsOpen ? t("app.settings.done") : t("app.settings.change")}
        </button>
        {subjectsOpen ? (
          <div className="notes-reveal flex flex-col gap-3.5 rounded-[18px] bg-surface-muted p-3.5">
            {SUBJECT_FAMILIES.map((family) => (
              <div key={family.name}>
                <p className="mb-1.5 text-[11px] font-extrabold uppercase tracking-caps text-ink-tertiary">{displayFamily(family.name, locale)}</p>
                <div className="flex flex-wrap gap-1.5">
                  {family.subjects.map((subject) => {
                    const on = subjects.includes(subject);
                    return (
                      <button
                        key={subject}
                        type="button"
                        aria-pressed={on}
                        onClick={() => {
                          const next = on ? subjects.filter((item) => item !== subject) : [...subjects, subject];
                          setSubjects(next);
                          save({ subjects: next });
                        }}
                        className={`pressable flex items-center gap-1 rounded-pill px-2.5 py-1.5 text-[13px] font-bold ${on ? "bg-accent text-on-ink" : "bg-surface text-ink"}`}
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
      </Field>

      <section className="mt-2 flex flex-col gap-3 border-t border-hairline pt-5">
        <h3 className="text-[12px] font-extrabold uppercase tracking-caps text-ink-secondary">{t("app.profileTab.account")}</h3>
        <p className="text-[14.5px] font-medium text-ink-secondary">{email ? t("app.profileTab.signedInAs", { email }) : t("app.profile.offline")}</p>
        <div className="flex flex-wrap gap-2.5">
          <button type="button" onClick={() => startTransition(() => signOut())} disabled={pending} className="pressable flex items-center gap-2 rounded-pill bg-surface px-4 py-2.5 text-[14.5px] font-extrabold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)] disabled:opacity-50">
            <LogOut aria-hidden="true" className="size-4" strokeWidth={2.6} />
            {t("app.profileTab.signOut")}
          </button>
          <button type="button" onClick={exportData} disabled={pending} className="pressable flex items-center gap-2 rounded-pill bg-surface px-4 py-2.5 text-[14.5px] font-extrabold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)] disabled:opacity-50">
            <Download aria-hidden="true" className="size-4" strokeWidth={2.6} />
            {t("app.profileTab.exportData")}
          </button>
        </div>
        {failure ? (
          <p role="alert" className="text-[14px] font-bold text-wrong-ink">
            {failure}
          </p>
        ) : null}
      </section>

      <section className="flex flex-col gap-3 border-t border-hairline pt-5">
        <h3 className="text-[15px] font-extrabold text-wrong-ink">{t("app.settings.delete.title")}</h3>
        <p className="text-[14px] font-medium text-ink-secondary">{t("app.settings.delete.body")}</p>
        {deleting ? (
          <div className="flex flex-col gap-3 rounded-[18px] bg-wrong-soft p-4">
            <label htmlFor="delete-account-confirm" className="text-[13.5px] font-bold text-wrong-ink">
              {t("app.settings.delete.confirmLabel")}
            </label>
            <input id="delete-account-confirm" value={typed} onChange={(event) => setTyped(event.target.value)} autoComplete="off" className={FIELD} />
            <LessonPrimaryButton onClick={remove} disabled={!canDelete || pending} style={{ background: canDelete ? "var(--color-wrong)" : undefined }}>
              {pending ? t("app.settings.delete.pending") : t("app.settings.delete.confirm")}
            </LessonPrimaryButton>
            <LessonSecondaryButton onClick={() => setDeleting(false)}>{t("app.common.cancel")}</LessonSecondaryButton>
          </div>
        ) : (
          <button type="button" onClick={() => setDeleting(true)} className="pressable w-fit rounded-pill bg-wrong-soft px-4 py-2.5 text-[14.5px] font-extrabold text-wrong-ink">
            {t("app.settings.delete.open")}
          </button>
        )}
      </section>
    </Sheet>
  );
}

function Field({ label, htmlFor, hint, hintTone = "normal", children }: { label: string; htmlFor?: string; hint?: ReactNode; hintTone?: "normal" | "error"; children: ReactNode }) {
  const Label = htmlFor ? "label" : "p";
  return (
    <div className="flex flex-col gap-2">
      <Label htmlFor={htmlFor} className="text-[14px] font-extrabold text-ink-secondary">
        {label}
      </Label>
      {children}
      {hint ? <p className={`text-[13px] font-medium ${hintTone === "error" ? "text-wrong-ink" : "text-ink-tertiary"}`}>{hint}</p> : null}
    </div>
  );
}
