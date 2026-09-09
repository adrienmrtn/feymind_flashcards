import { notFound } from "next/navigation";

import { isMockDebrief, paperScore, type MockAnswer, type MockGrade, type MockQuestion } from "@micabo/core";

import { MockPaper } from "@/components/app/plan/MockPaper";
import { MockReport } from "@/components/app/plan/MockReport";
import { listExams } from "@/lib/data/courses";
import { readMockSession } from "@/lib/data/mocks";
import { getTranslator } from "@/lib/i18n/server";

/**
 * Une copie d'examen blanc : la passation, puis le débriefing.
 *
 * Les deux vivent sur la même adresse, et c'est voulu. Une copie remise n'est pas une page
 * qu'on quitte : c'est le moment où elle devient lisible. Rediriger vers l'épreuve, comme
 * avant, faisait disparaître le travail de l'étudiant à la seconde où il valait quelque chose.
 */
export default async function MockPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  const [session, { t }] = await Promise.all([readMockSession(id), getTranslator()]);
  if (!session) notFound();

  const questions = (session.questions ?? []) as MockQuestion[];
  if (questions.length === 0) notFound();

  const exams = await listExams();
  const exam = exams.find((row) => row.id === session.exam_id);
  const examName = exam?.name ?? t("app.mock.panelTitle");

  if (!session.finished_at) {
    return (
      <MockPaper
        sessionId={session.id}
        examName={examName}
        minutes={session.minutes}
        questions={questions}
        withAudio={session.with_audio}
      />
    );
  }

  const grades = (session.grades ?? []) as MockGrade[];
  return (
    <MockReport
      examId={session.exam_id}
      score={paperScore(grades)}
      questions={questions}
      answers={(session.answers ?? []) as MockAnswer[]}
      grades={grades}
      debrief={isMockDebrief(session.debrief) ? session.debrief : null}
    />
  );
}
