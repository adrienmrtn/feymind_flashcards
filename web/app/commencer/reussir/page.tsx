"use client";

import { ExamPrepStory } from "@/components/onboarding/ExamPrepStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * Le jour J, et les cartes qui s'y rendent.
 */
export default function ExamPrepStep() {
  return (
    <Scaffold
      title="On te prépare à réussir tes examens."
      footer={<ContinueButton enabled href="/commencer/retention" />}
      center
    >
      <ExamPrepStory />
    </Scaffold>
  );
}
