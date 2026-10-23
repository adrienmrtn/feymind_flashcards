"use client";

import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle2, Circle, Trash2, X } from "lucide-react";

import { LessonPrimaryButton } from "@/components/lesson/LessonButtons";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { deleteExam, saveExam } from "@/lib/actions/exams";
import { useI18n } from "@/lib/i18n/client";

export interface ExamLessonChoice {
  id: string;
  title: string;
  icon: string | null;
}

export interface ExamDraft {
  id?: string;
  name: string;
  examDate: string;
  courseIds: string[];
}

/** **Un examen** : son nom, son jour, ses leçons. On peut le modifier ou le supprimer. Jumeau de `ExamEditSheet`. */
export function ExamEditSheet({ draft, lessons, onClose }: { draft: ExamDraft; lessons: ExamLessonChoice[]; onClose: () => void }) {
  const { t } = useI18n();
  const router = useRouter();
  const [name, setName] = useState(draft.name);
  const [date, setDate] = useState(draft.examDate);
  const [selected, setSelected] = useState<Set<string>>(() => new Set(draft.courseIds.length > 0 ? draft.courseIds : lessons.slice(0, 1).map((lesson) => lesson.id)));
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  useEffect(() => {
    function escape(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    document.addEventListener("keydown", escape);
    return () => document.removeEventListener("keydown", escape);
  }, [onClose]);

  const canSave = name.trim().length > 0 && /^\d{4}-\d{2}-\d{2}$/.test(date) && selected.size > 0;

  function toggle(id: string) {
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function save() {
    setFailure(null);
    startTransition(async () => {
      const result = await saveExam({ id: draft.id, name: name.trim(), examDate: date, courseIds: lessons.map((lesson) => lesson.id).filter((id) => selected.has(id)) });
      if (result.status === "error") {
        setFailure(result.message ?? t("app.common.errorGeneric"));
        return;
      }
      router.refresh();
      onClose();
    });
  }

  function remove() {
    if (!draft.id) return;
    startTransition(async () => {
      const result = await deleteExam(draft.id!);
      if (result.status === "error") {
        setFailure(result.message ?? t("app.common.errorGeneric"));
        return;
      }
      router.refresh();
      onClose();
    });
  }

  const today = new Date();
  const min = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 sm:items-center sm:p-6" role="dialog" aria-modal="true" onClick={onClose}>
      <div className="score-in flex max-h-[92svh] w-full max-w-[560px] flex-col rounded-t-[28px] bg-canvas sm:rounded-[28px]" onClick={(event) => event.stopPropagation()}>
        <div className="flex items-center justify-between px-5 pt-4">
          <h2 className="text-[20px] font-extrabold text-ink">{t(draft.id ? "lesson.exam.edit" : "lesson.exam.new")}</h2>
          <button type="button" onClick={onClose} aria-label={t("app.common.cancel")} className="pressable flex size-9 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted">
            <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
          </button>
        </div>

        <div className="flex flex-1 flex-col gap-[22px] overflow-y-auto px-5 py-4">
          <label className="flex flex-col gap-2.5">
            <span className="text-[15px] font-extrabold text-ink-secondary">{t("lesson.exam.name")}</span>
            <input
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder={t("lesson.exam.namePlaceholder")}
              maxLength={120}
              className="rounded-[16px] bg-surface px-4 py-4 text-[18px] font-semibold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)] outline-none focus-visible:shadow-[inset_0_0_0_2px_var(--color-accent)]"
            />
          </label>
          <label className="flex flex-col gap-2.5">
            <span className="text-[15px] font-extrabold text-ink-secondary">{t("lesson.exam.date")}</span>
            <input
              type="date"
              value={date}
              min={min}
              onChange={(event) => setDate(event.target.value)}
              className="rounded-[16px] bg-surface px-4 py-4 text-[18px] font-extrabold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)] outline-none focus-visible:shadow-[inset_0_0_0_2px_var(--color-accent)]"
            />
          </label>
          <div className="flex flex-col gap-2.5">
            <span className="text-[15px] font-extrabold text-ink-secondary">{t("lesson.exam.lessons")}</span>
            <LessonChecklist lessons={lessons} selected={selected} onToggle={toggle} />
          </div>
          {draft.id ? (
            confirmDelete ? (
              <div className="flex flex-col gap-2 rounded-[18px] bg-wrong-soft p-4">
                <p className="text-[15px] font-bold text-wrong-ink">{t("lesson.exam.deleteConfirm")}</p>
                <button type="button" onClick={remove} disabled={pending} className="pressable rounded-[14px] bg-wrong py-3 text-[15px] font-extrabold text-on-ink">
                  {t("lesson.exam.delete")}
                </button>
              </div>
            ) : (
              <button type="button" onClick={() => setConfirmDelete(true)} className="pressable flex items-center justify-center gap-2 py-3.5 text-[16px] font-bold text-wrong-ink">
                <Trash2 aria-hidden="true" className="size-[18px]" strokeWidth={2.4} />
                {t("lesson.exam.delete")}
              </button>
            )
          ) : null}
          {failure ? <p className="text-[14px] font-bold text-wrong-ink">{failure}</p> : null}
        </div>

        <div className="px-5 pb-[max(1rem,env(safe-area-inset-bottom))] pt-2">
          <LessonPrimaryButton onClick={save} disabled={!canSave || pending} style={{ background: canSave ? "var(--color-accent)" : undefined }}>
            {t("lesson.exam.save")}
          </LessonPrimaryButton>
        </div>
      </div>
    </div>
  );
}

/** Les leçons à cocher, avec leur icône. */
export function LessonChecklist({ lessons, selected, onToggle }: { lessons: ExamLessonChoice[]; selected: ReadonlySet<string>; onToggle: (id: string) => void }) {
  const { t } = useI18n();
  if (lessons.length === 0) return <p className="text-[15px] font-medium text-ink-secondary">{t("lesson.exam.noLessons")}</p>;
  return (
    <ul className="flex flex-col gap-2.5">
      {lessons.map((lesson) => {
        const on = selected.has(lesson.id);
        return (
          <li key={lesson.id}>
            <button
              type="button"
              aria-pressed={on}
              onClick={() => onToggle(lesson.id)}
              className={`pressable flex w-full items-center gap-3 rounded-[18px] p-3 text-left ${on ? "bg-accent-soft shadow-[inset_0_0_0_2px_var(--color-accent)]" : "bg-surface shadow-[inset_0_0_0_1.5px_var(--color-stroke)]"}`}
            >
              <MicaboIcon id={lesson.icon} size={38} />
              <span className="line-clamp-2 flex-1 text-[16px] font-bold text-ink">{lesson.title}</span>
              {on ? <CheckCircle2 aria-hidden="true" className="size-6 text-accent" strokeWidth={2.4} /> : <Circle aria-hidden="true" className="size-6 text-ink-tertiary" strokeWidth={2} />}
            </button>
          </li>
        );
      })}
    </ul>
  );
}
