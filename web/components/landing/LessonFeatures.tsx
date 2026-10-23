"use client";

import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";

/**
 * **Ce qu'il y a dans une leçon** : les Notes, le Quiz, les Flashcards, l'examen blanc.
 *
 * Quatre cartes, chacune avec sa petite scène qui joue en boucle — les lignes qui s'écrivent
 * et le mot-clé qui s'allume, une réponse qui devient juste, une carte qui se retourne, une
 * copie qui se note. Tout est en `transform` et `opacity`, et chaque scène est suspendue tant
 * qu'elle n'est pas arrivée à l'écran (`lp-mock`, `data-shown`).
 */
export function LessonFeatures() {
  const { t } = useI18n();
  const features = [
    { key: "notes", tone: "blue", title: t("landing.featureNotesTitle"), body: t("landing.featureNotesBody"), mock: <NotesMock /> },
    { key: "quiz", tone: "mint", title: t("landing.featureQuizTitle"), body: t("landing.featureQuizBody"), mock: <QuizMock /> },
    { key: "cards", tone: "yellow", title: t("landing.featureCardsTitle"), body: t("landing.featureCardsBody"), mock: <CardsMock /> },
    { key: "exam", tone: "lilac", title: t("landing.featureExamTitle"), body: t("landing.featureExamBody"), mock: <ExamMock /> },
  ];

  return (
    <ul className="mt-12 grid gap-5 sm:mt-14 md:grid-cols-2">
      {features.map((feature, index) => (
        <Reveal as="li" key={feature.key} delay={index % 2} className="h-full">
          <div className="lp-card flex h-full flex-col rounded-[28px] bg-surface p-5 lp-surface-shadow sm:p-6">
            <div
              aria-hidden
              className="lp-mock flex h-[236px] items-center justify-center overflow-hidden rounded-[20px] px-4 sm:px-5"
              style={{ background: `var(--color-tone-${feature.tone}-pale)` }}
            >
              {feature.mock}
            </div>
            <h3 className="mt-6 text-[21px] font-extrabold leading-[1.15] tracking-tight-title text-ink">{feature.title}</h3>
            <p className="mt-2.5 max-w-[46ch] text-[15.5px] leading-relaxed text-ink-secondary">{feature.body}</p>
          </div>
        </Reveal>
      ))}
    </ul>
  );
}

function NotesMock() {
  const { t } = useI18n();
  return (
    <div className="w-full max-w-[300px] rounded-[18px] bg-surface p-4 shadow-paper">
      <p className="text-[14px] font-extrabold text-ink">{t("landing.mockNotesTitle")}</p>
      <div className="mt-3 space-y-2">
        {[100, 92, 78].map((width, index) => (
          <span key={width} className="lp-note-line block h-2 rounded-pill bg-stroke-strong" style={{ width: `${width}%`, ["--i" as string]: index }} />
        ))}
      </div>
      <p className="mt-3 flex flex-wrap items-center gap-1.5 text-[12.5px] font-semibold text-ink-secondary">
        <span className="relative inline-flex px-1.5 py-0.5 font-extrabold text-keyword">
          <span className="lp-keyword-mark absolute inset-0 rounded-[6px] bg-tone-lilac-pale" />
          <span className="relative">{t("landing.mockNotesKeyword")}</span>
        </span>
        <span className="lp-note-line block h-2 w-[40%] rounded-pill bg-stroke-strong" style={{ ["--i" as string]: 3 }} />
      </p>
    </div>
  );
}

function QuizMock() {
  const { t } = useI18n();
  const wrong = [t("landing.mockQuizWrong1"), t("landing.mockQuizWrong2")];
  return (
    <div className="w-full max-w-[300px]">
      <p className="text-center text-[14px] font-extrabold leading-snug text-ink">{t("landing.mockQuizQuestion")}</p>
      <div className="mt-3 space-y-2">
        <div className="lp-choice-pick relative overflow-hidden rounded-[14px] bg-surface px-3.5 py-2.5 shadow-paper">
          <span className="lp-choice-right absolute inset-0 rounded-[14px] bg-correct-soft shadow-[inset_0_0_0_2px_var(--color-correct)]" />
          <span className="relative flex items-center justify-between gap-2 text-[13px] font-bold text-ink">
            {t("landing.mockQuizRight")}
            <span className="lp-choice-right flex size-5 items-center justify-center rounded-full bg-correct text-white">
              <svg viewBox="0 0 16 16" className="size-3" fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="m3.5 8.4 2.9 2.9 6.1-6.6" />
              </svg>
            </span>
          </span>
        </div>
        {wrong.map((choice) => (
          <div key={choice} className="lp-choice-dim rounded-[14px] bg-surface px-3.5 py-2.5 text-[13px] font-bold text-ink shadow-paper">
            {choice}
          </div>
        ))}
      </div>
    </div>
  );
}

function CardsMock() {
  const { t } = useI18n();
  const grades = [
    { key: "again", label: t("landing.mockGradeAgain"), on: false },
    { key: "good", label: t("landing.mockGradeGood"), on: true },
    { key: "easy", label: t("landing.mockGradeEasy"), on: false },
  ];
  return (
    <div className="flex w-full max-w-[280px] flex-col items-center">
      <div className="lp-flip-scene h-[112px] w-full">
        <div className="lp-flip h-full w-full">
          <div className="lp-flip-face flex flex-col items-center justify-center rounded-[18px] bg-surface p-4 text-center shadow-paper">
            <p className="text-[11px] font-extrabold uppercase tracking-caps text-ink-tertiary">{t("landing.demoStepCards")}</p>
            <p className="mt-1.5 text-[18px] font-extrabold text-ink">{t("landing.mockCardFront")}</p>
          </div>
          <div className="lp-flip-face lp-flip-back flex items-center justify-center rounded-[18px] bg-surface p-4 text-center shadow-paper">
            <p className="text-[14px] font-bold leading-snug text-ink">{t("landing.mockCardBack")}</p>
          </div>
        </div>
      </div>
      <div className="mt-3 flex gap-2">
        {grades.map((grade) => (
          <span key={grade.key} className="relative overflow-hidden rounded-pill bg-surface px-3.5 py-1.5 text-[12px] font-extrabold text-ink shadow-paper">
            {grade.on ? <span className="lp-grade-on absolute inset-0 bg-correct" /> : null}
            <span className="relative">{grade.label}</span>
            {grade.on ? <span className="lp-grade-on absolute inset-0 flex items-center justify-center text-white">{grade.label}</span> : null}
          </span>
        ))}
      </div>
    </div>
  );
}

function ExamMock() {
  const { t } = useI18n();
  const themes = [
    { label: t("landing.mockExamTheme1"), width: 0.86 },
    { label: t("landing.mockExamTheme2"), width: 0.64 },
    { label: t("landing.mockExamTheme3"), width: 0.92 },
  ];
  return (
    <div className="w-full max-w-[300px] rounded-[18px] bg-surface p-4 shadow-paper">
      <div className="flex items-center justify-between">
        <p className="text-[14px] font-extrabold text-ink">{t("landing.mockExamTitle")}</p>
        <span className="numeral flex items-center gap-1.5 rounded-pill bg-surface-muted px-2.5 py-1 text-[12px] font-extrabold text-ink-secondary">
          <svg viewBox="0 0 20 20" className="size-3.5" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="10" cy="11" r="7" />
            <path d="M8 2h4" strokeLinecap="round" />
            <path className="lp-clock-hand" d="M10 11V6.5" strokeLinecap="round" />
          </svg>
          24:00
        </span>
      </div>
      <div className="mt-3.5 space-y-2.5">
        {themes.map((theme, index) => (
          <div key={theme.label}>
            <p className="text-[11.5px] font-bold text-ink-tertiary">{theme.label}</p>
            <span className="mt-1 block h-2 overflow-hidden rounded-pill bg-track">
              <span
                className="lp-exam-bar block h-full w-full rounded-pill bg-tone-lilac-vivid"
                style={{ ["--w" as string]: theme.width, ["--i" as string]: index }}
              />
            </span>
          </div>
        ))}
      </div>
      <div className="mt-3.5 flex justify-end">
        <span className="lp-exam-score numeral rounded-pill bg-tone-lilac-pale px-3 py-1 text-[15px] font-extrabold text-tone-lilac-ink">16/20</span>
      </div>
    </div>
  );
}
