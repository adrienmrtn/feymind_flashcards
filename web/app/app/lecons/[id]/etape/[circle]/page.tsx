import Link from "next/link";
import { notFound } from "next/navigation";

import { lessonCircles } from "@micabo/core";

import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { getLesson, listThemes } from "@/lib/data/lessons";
import { getTranslator } from "@/lib/i18n/server";
import { lessonPath } from "@/lib/lesson/routes";

/**
 * **Une étape du chemin.** Le lot 4 de `docs/refonte-web.md` écrit ici l'Intro, les Notes, le
 * Checkpoint et le Quiz final ; en attendant, l'étape se nomme et ramène au chemin.
 */
export default async function StepPage({ params }: { params: Promise<{ id: string; circle: string }> }) {
  const { id, circle } = await params;
  const [{ t }, lesson] = await Promise.all([getTranslator(), getLesson(id)]);
  if (!lesson?.path) notFound();
  const themes = await listThemes(lesson.id);
  const circles = lessonCircles(
    lesson.path,
    themes.map((theme) => ({ title: theme.title, icon: theme.icon })),
    { intro: t("lesson.circle.intro"), checkpoint: t("lesson.circle.checkpoint"), final: t("lesson.circle.final") },
  );
  const step = circles.find((entry) => entry.id === decodeURIComponent(circle));
  if (!step) notFound();

  return (
    <div className="mx-auto flex max-w-[520px] flex-col items-center gap-4 pt-10 text-center">
      <MicaboIcon id={step.icon} size={64} />
      <p className="text-[12px] font-extrabold uppercase tracking-caps text-ink-tertiary">{t("lesson.path.step", { n: step.number })}</p>
      <h1 className="text-[26px] font-extrabold text-ink">{step.title}</h1>
      <Link href={lessonPath(lesson.id)} className="underline-draw mt-4 text-[15px] font-semibold text-ink-secondary">
        {t("common.back")}
      </Link>
    </div>
  );
}
