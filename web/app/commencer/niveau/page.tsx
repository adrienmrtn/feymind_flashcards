"use client";

import { resolveStage, stagesFor, type CountryCode } from "@micabo/core";

import { ChoiceGroup, ChoiceRow, ContinueButton, Scaffold, useAdvance } from "@/components/onboarding/Scaffold";
import { trackOnboardingAnswer } from "@/lib/analytics/funnel";
import { useI18n } from "@/lib/i18n/client";
import { stageOfTrack, trackById, tracksFor, type SchoolTrack } from "@/lib/onboarding/school-system";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * Le niveau, **dans les mots du pays choisi** - et, pour les quatre pays décrits en détail, la
 * filière exacte.
 *
 * C'est la règle de l'iPhone (`OnboardingStep.isSkipped`) : la France, la Turquie, l'Allemagne
 * et l'Espagne voient leurs filières (« Lycée technologique », « Fen Lisesi », « Realschule »),
 * puis l'année ; les autres pays voient leurs paliers larges, et l'année ne se demande pas. Un
 * collégien français n'est plus écrit comme un lycéen : la filière dit sa marche.
 *
 * Si l'étudiant revient en arrière pour changer de pays, **la réponse est retrouvée plutôt que
 * redemandée** quand un équivalent existe. Un appui avance.
 */
export default function LevelStep() {
  const { answers, set, ready } = useOnboarding();
  const { t } = useI18n();
  const advance = useAdvance();
  const country: CountryCode = answers.country ?? "fr";
  const tracks = tracksFor(country);

  if (tracks.length > 0) {
    return <TrackChoice country={country} tracks={tracks} />;
  }

  const stages = stagesFor(country);
  // La réponse déjà donnée, ramenée dans ce pays-ci.
  const resolved = resolveStage(country, {
    id: answers.stageId ?? null,
    tier: answers.tier ?? null,
    level: answers.studyLevel ?? null,
  });
  const selectedId = resolved?.id ?? null;

  return (
    <Scaffold title={t("onboarding.niveauTitle")} footer={<ContinueButton enabled={Boolean(selectedId) && ready} />} center>
      <ChoiceGroup label={t("onboarding.niveauTitle")} className="space-y-2">
        {stages.map((stage) => (
          <ChoiceRow
            key={stage.id}
            emoji={stage.emoji}
            title={stage.title}
            selected={selectedId === stage.id}
            onSelect={() => {
              set({ stageId: stage.id, studyLevel: stage.level, tier: stage.tier, trackId: undefined, yearId: undefined });
              trackOnboardingAnswer("stage", stage.id);
              advance({ context: { trackId: undefined }, auto: true });
            }}
          />
        ))}
      </ChoiceGroup>
    </Scaffold>
  );
}

function TrackChoice({ country, tracks }: { country: CountryCode; tracks: SchoolTrack[] }) {
  const { answers, set, ready } = useOnboarding();
  const { t } = useI18n();
  const advance = useAdvance();
  const selected = trackById(answers.trackId, country);

  function choose(track: SchoolTrack) {
    const stage = stageOfTrack(country, track);
    set({
      trackId: track.id,
      // L'année ne survit qu'à la même filière : « Terminale » n'existe pas en prépa.
      yearId: track.id === answers.trackId ? answers.yearId : undefined,
      stageId: stage?.id,
      studyLevel: track.level,
      tier: track.tier,
    });
    trackOnboardingAnswer("track", track.id);
    advance({ context: { country, trackId: track.id }, auto: true });
  }

  return (
    <Scaffold title={t("onboarding.trackTitle")} footer={<ContinueButton enabled={Boolean(selected) && ready} />} center>
      <ChoiceGroup label={t("onboarding.trackTitle")} className="space-y-2">
        {tracks.map((track) => (
          <ChoiceRow
            key={track.id}
            emoji={track.emoji}
            title={track.title}
            selected={selected?.id === track.id}
            onSelect={() => choose(track)}
          />
        ))}
      </ChoiceGroup>
    </Scaffold>
  );
}
