"use client";

import { useEffect, useMemo, useState } from "react";
import type { Route } from "next";
import { useRouter } from "next/navigation";

import { countryFor, resolveStage } from "@micabo/core";

import { AccentText } from "@/components/onboarding/AccentText";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";
import { displaySubject } from "@/lib/i18n/subject-display";
import { BELOW_SCORE, gradeChoices, gradeLabel } from "@/lib/onboarding/grades";
import { persistStoredAnswers } from "@/lib/onboarding/persist";
import { cleanWorries, type Worry } from "@/lib/onboarding/questions";
import { trackById, yearById } from "@/lib/onboarding/school-system";
import { useOnboarding } from "@/lib/onboarding/store";
import { createClient } from "@/lib/supabase/client";

/**
 * **« Voici ce qui va changer pour toi »** : les réponses relues, juste avant le compte.
 *
 * Cet écran était un chargement de sept secondes et demie : un anneau qui tournait, quatre
 * phases qui se cochaient, et un bouton gris tant que la minuterie n'avait pas fini. Rien ne se
 * calculait - les réponses étaient déjà là. C'était la plus longue attente du parcours, et elle
 * tombait juste avant qu'on demande un compte.
 *
 * Il fait maintenant ce que fait `ProfileSummaryStepView` sur l'iPhone : il **montre** ce que
 * les réponses changent, tout de suite. L'écart entre les deux moyennes en grand, puis quatre
 * promesses au plus, dans l'ordre de l'iPhone : ce qui bloque d'abord (c'est ce qu'on a dit en
 * premier), les leçons dans ses matières, l'examen, le rythme. Le bouton est actif dès l'arrivée.
 *
 * S'il a déjà une session (un parcours rejoué), le bouton ouvre l'offre : le compte est fait.
 */
export default function SummaryStep() {
  const { answers, ready } = useOnboarding();
  const { t, locale } = useI18n();
  const router = useRouter();
  const [signedIn, setSignedIn] = useState(false);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    // La session se lit dans le navigateur, sans aller-retour : l'écran ne l'attend pas.
    void createClient()
      .auth.getSession()
      .then(({ data }) => setSignedIn(Boolean(data.session)));
  }, []);

  const country = answers.country;
  const track = trackById(answers.trackId, country);
  const year = yearById(answers.yearId, track);
  const stage = country ? resolveStage(country, { id: answers.stageId ?? null, tier: answers.tier ?? null, level: answers.studyLevel ?? null }) : null;

  const profileLine = useMemo(() => {
    const bits: string[] = [];
    if (country && country !== "other") bits.push(`${countryFor(country).flag} ${t(`country.${country}`)}`);
    else if (answers.customCountry) bits.push(`🌍 ${answers.customCountry}`);
    if (track) bits.push(year ? `${track.title} · ${year.title}` : track.title);
    else if (stage) bits.push(stage.title);
    return bits.join(" · ");
  }, [answers.customCountry, country, stage, t, track, year]);

  const grade = (score: number) =>
    score <= BELOW_SCORE
      ? t("onboarding.averageBelow", { grade: gradeChoices(country)[0]?.label ?? "" })
      : (gradeLabel(score, country) ?? "");

  const worries = cleanWorries(answers.worries);
  const lead: Worry | undefined = worries[0];
  const subjects = (answers.subjects ?? []).map((subject) => displaySubject(subject, locale));
  const shown = subjects.slice(0, 2).join(", ");
  const list = subjects.length > 2 ? t("onboarding.summaryMore", { list: shown, n: subjects.length - 2 }) : shown;

  const benefits: { emoji: string; title: string; body: string }[] = [];
  if (lead) benefits.push({ emoji: BENEFIT_EMOJI[lead], title: t(`onboarding.benefit.${lead}.title`), body: t(`onboarding.benefit.${lead}.body`) });
  benefits.push({
    emoji: "📚",
    title: t("onboarding.coursesTitle"),
    body: subjects.length > 0 ? t("onboarding.coursesBody", { subjects: list }) : t("onboarding.coursesBodyAny"),
  });
  if (lead === "examStress") {
    benefits.push({ emoji: BENEFIT_EMOJI.forgetting, title: t("onboarding.benefit.forgetting.title"), body: t("onboarding.benefit.forgetting.body") });
  } else {
    benefits.push({ emoji: "📝", title: t("onboarding.examsTitle"), body: t("onboarding.examsBody") });
  }
  if (answers.dailyMinutes) {
    benefits.push({ emoji: "⏰", title: t("onboarding.rhythmTitle", { n: answers.dailyMinutes }), body: t("onboarding.rhythmBodyAny") });
  }

  async function continueOn() {
    if (leaving) return;
    setLeaving(true);
    if (signedIn) {
      await persistStoredAnswers();
      router.push("/commencer/offre" as Route);
      return;
    }
    router.push("/commencer/compte" as Route);
  }

  return (
    <Scaffold
      title={<AccentText text={t("onboarding.summaryTitle")} />}
      lead={profileLine || undefined}
      footer={
        <ContinueButton
          label={signedIn ? t("onboarding.openMicabo") : t("onboarding.createAccount")}
          enabled={ready && !leaving}
          onPress={() => void continueOn()}
        />
      }
      width="wide"
    >
      {answers.currentScore !== undefined && answers.targetScore !== undefined ? (
        <div className="flex items-stretch gap-2 rounded-[20px] border-[1.5px] border-stroke bg-surface p-2">
          <div className="flex flex-1 flex-col items-center justify-center rounded-[14px] px-2 py-2 text-center">
            <span className="text-[12.5px] font-bold text-ink-secondary">{t("onboarding.goalNow")}</span>
            <span className="numeral mt-1 text-[24px] font-extrabold leading-none text-ink-secondary sm:text-[26px]">
              {grade(answers.currentScore)}
            </span>
          </div>
          <span aria-hidden className="flex h-10 w-10 shrink-0 items-center justify-center self-center rounded-full bg-accent-soft text-accent">
            <svg viewBox="0 0 20 20" className="h-[18px] w-[18px] rtl:-scale-x-100" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M4 10h11M11 5l5 5-5 5" />
            </svg>
          </span>
          <div className="flex flex-1 flex-col items-center justify-center rounded-[14px] bg-accent-soft/60 px-2 py-2 text-center">
            <span className="text-[12.5px] font-bold text-accent">{t("onboarding.goalTarget")}</span>
            <span className="numeral home-gradient-text mt-1 text-[28px] font-extrabold leading-none sm:text-[30px]">{grade(answers.targetScore)}</span>
          </div>
        </div>
      ) : null}

      <ul className="mt-2.5 space-y-2">
        {benefits.slice(0, 4).map((benefit, index) => (
          <li
            key={benefit.title}
            className="rise flex items-center gap-3 rounded-[16px] border-[1.5px] border-stroke bg-surface px-3 py-2.5"
            style={{ animationDelay: `${60 + index * 50}ms` }}
          >
            <span aria-hidden className="emoji flex h-10 w-10 shrink-0 items-center justify-center rounded-[12px] bg-accent-soft text-[20px]">
              {benefit.emoji}
            </span>
            <span className="min-w-0">
              <span className="block text-[14.5px] font-extrabold leading-snug text-ink">{benefit.title}</span>
              <span className="block text-[13px] leading-snug text-ink-secondary">{benefit.body}</span>
            </span>
          </li>
        ))}
      </ul>
    </Scaffold>
  );
}

const BENEFIT_EMOJI: Record<Worry, string> = {
  examStress: "🏆",
  hardLessons: "💡",
  homework: "⏳",
  forgetting: "🧠",
  noStart: "🚩",
  motivation: "🔥",
};
