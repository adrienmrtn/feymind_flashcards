"use client";

import { SUBJECT_FAMILIES, isoFromFlagEmoji, subjectEmoji } from "@micabo/core";

import { Flag } from "@/components/onboarding/Flag";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";
import { displayFamily, displaySubject } from "@/lib/i18n/subject-display";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * Les matières, en pastilles qui s'enroulent par familles.
 *
 * L'emoji vient de la **même table que les cours importés** : une seconde liste tenue en parallèle
 * finirait par donner à une matière un emoji que ses cours n'ont pas. Et aucune matière ne partage
 * l'emoji d'une autre - un test du noyau le verrouille, parce que sur une cinquantaine de pastilles
 * un emoji répété fait relire les libellés un par un, ce qui est le travail qu'il devait éviter.
 *
 * Plusieurs réponses, et au moins une : on ne construit rien avec zéro matière, et personne n'en
 * étudie une seule.
 */
export default function SubjectsStep() {
  const { answers, set, ready } = useOnboarding();
  const { t, locale } = useI18n();
  const chosen = answers.subjects ?? [];

  function toggle(subject: string) {
    const next = chosen.includes(subject)
      ? chosen.filter((item) => item !== subject)
      : [...chosen, subject];
    set({ subjects: next });
  }

  return (
    <Scaffold
      eyebrow={t("onboarding.eyebrowPath")}
      title={t("onboarding.matieresTitle")}
      footer={
        <ContinueButton
          label={
            chosen.length === 1
              ? t("onboarding.continueOne")
              : chosen.length > 1
                ? t("onboarding.continueMany", { n: chosen.length })
                : undefined
          }
          enabled={chosen.length > 0 && ready}
          href="/commencer/ecole"
        />
      }
    >
      <div className="space-y-6 pr-1">
        {SUBJECT_FAMILIES.map((family) => (
          <div key={family.name}>
            <p className="eyebrow mb-2.5 text-ink-tertiary">{displayFamily(family.name, locale)}</p>
            <div className="flex flex-wrap gap-2">
              {family.subjects.map((subject) => {
                const selected = chosen.includes(subject);
                return (
                  <button
                    key={subject}
                    type="button"
                    onClick={() => toggle(subject)}
                    aria-pressed={selected}
                    className={`pressable flex items-center gap-1.5 rounded-pill px-3.5 py-2 text-[14px] transition-colors duration-hover ${
                      selected
                        ? "bg-accent-soft font-medium text-accent"
                        : "bg-surface-muted text-ink shadow-[inset_0_0_0_1px_var(--color-stroke-strong)]"
                    }`}
                  >
                    <SubjectMark subject={subject} />
                    {displaySubject(subject, locale)}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>
    </Scaffold>
  );
}

/**
 * Un drapeau **dessiné** pour une langue vivante. L'emoji seul s'y lisait « ES » sur
 * les machines sans glyphes régionaux - c'est exactement ce qui manquait sur cet écran.
 */
function SubjectMark({ subject }: { subject: string }) {
  const emoji = subjectEmoji(subject);
  const iso = isoFromFlagEmoji(emoji);
  if (iso) {
    return <Flag iso={iso} emoji={emoji} label={subject} className="h-[15px] w-[20px]" />;
  }
  return (
    <span aria-hidden className="emoji">
      {emoji}
    </span>
  );
}
