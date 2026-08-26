"use client";

import { SUBJECT_FAMILIES, subjectEmoji } from "@micabo/core";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * Les matières, en pastilles qui s'enroulent par familles.
 *
 * L'emoji vient de la **même table que les cours importés** : une seconde liste tenue en parallèle
 * finirait par donner à une matière un emoji que ses cours n'ont pas. Et aucune matière ne partage
 * l'emoji d'une autre — un test du noyau le verrouille, parce que sur une cinquantaine de pastilles
 * un emoji répété fait relire les libellés un par un, ce qui est le travail qu'il devait éviter.
 *
 * Plusieurs réponses, et au moins une : on ne construit rien avec zéro matière, et personne n'en
 * étudie une seule.
 */
export default function SubjectsStep() {
  const { answers, set, ready } = useOnboarding();
  const chosen = answers.subjects ?? [];

  function toggle(subject: string) {
    const next = chosen.includes(subject)
      ? chosen.filter((item) => item !== subject)
      : [...chosen, subject];
    set({ subjects: next });
  }

  return (
    <Scaffold
      eyebrow="Ton parcours"
      title="Qu'est-ce que tu étudies ?"
      footer={
        <ContinueButton
          label={chosen.length > 0 ? `Continuer avec ${chosen.length} matière${chosen.length > 1 ? "s" : ""}` : "Continuer"}
          enabled={chosen.length > 0 && ready}
          href="/commencer/examen"
        />
      }
    >
      <div className="max-h-[54svh] space-y-7 overflow-y-auto pr-1 sm:max-h-[58svh]">
        {SUBJECT_FAMILIES.map((family) => (
          <div key={family.name}>
            <p className="eyebrow mb-2.5 text-ink-tertiary">{family.name}</p>
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
                        : "bg-surface text-ink paper"
                    }`}
                  >
                    <span aria-hidden className="emoji">
                      {subjectEmoji(subject)}
                    </span>
                    {subject}
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
