"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Ellipsis, Pencil, RotateCcw, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { deleteLesson, renameLesson, restartLesson } from "@/lib/actions/lesson";
import { useI18n } from "@/lib/i18n/client";
import { LESSONS_PATH } from "@/lib/lesson/routes";

/**
 * **Le menu « ⋯ » d'une leçon** : renommer, recommencer, supprimer.
 *
 * Trois gestes rares, derrière un bouton : les mettre à plat sur l'écran du chemin ferait
 * de « Supprimer » un voisin de « Continuer ». Recommencer et supprimer demandent une
 * confirmation, en toutes lettres : le premier efface une progression, le second une leçon.
 */
export function LessonMenu({ lessonId, title, canReset }: { lessonId: string; title: string; canReset: boolean }) {
  const { t } = useI18n();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [mode, setMode] = useState<"menu" | "rename" | "reset" | "delete">("menu");
  const [draft, setDraft] = useState(title);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function away(event: MouseEvent) {
      if (root.current && !root.current.contains(event.target as Node)) close();
    }
    function escape(event: KeyboardEvent) {
      if (event.key === "Escape") close();
    }
    document.addEventListener("mousedown", away);
    document.addEventListener("keydown", escape);
    return () => {
      document.removeEventListener("mousedown", away);
      document.removeEventListener("keydown", escape);
    };
  }, [open]);

  function close() {
    setOpen(false);
    setMode("menu");
    setFailure(null);
  }

  function run(action: () => Promise<{ status: "ok" | "error"; message?: string }>, after?: () => void) {
    setFailure(null);
    startTransition(async () => {
      const result = await action();
      if (result.status === "error") {
        setFailure(result.message ?? t("app.common.errorGeneric"));
        return;
      }
      close();
      if (after) after();
      else router.refresh();
    });
  }

  return (
    <div ref={root} className="relative">
      <button
        type="button"
        onClick={() => (open ? close() : setOpen(true))}
        aria-label={t("lesson.menu.more")}
        aria-expanded={open}
        className="pressable flex size-10 items-center justify-center rounded-full bg-surface text-ink shadow-floating"
      >
        <Ellipsis aria-hidden="true" className="size-5" strokeWidth={2.6} />
      </button>

      {open ? (
        <div role="dialog" className="absolute right-0 top-12 z-30 w-[300px] rounded-group bg-surface p-2 shadow-floating">
          {mode === "menu" ? (
            <div className="flex flex-col">
              <MenuRow icon={<Pencil aria-hidden="true" className="size-4" />} label={t("lesson.menu.rename")} onClick={() => { setDraft(title); setMode("rename"); }} />
              <MenuRow icon={<RotateCcw aria-hidden="true" className="size-4" />} label={t("lesson.menu.reset")} disabled={!canReset} onClick={() => setMode("reset")} />
              <MenuRow icon={<Trash2 aria-hidden="true" className="size-4" />} label={t("lesson.menu.delete")} destructive onClick={() => setMode("delete")} />
            </div>
          ) : null}

          {mode === "rename" ? (
            <form
              className="flex flex-col gap-3 p-2"
              onSubmit={(event) => {
                event.preventDefault();
                run(() => renameLesson(lessonId, draft));
              }}
            >
              <label className="text-[15px] font-extrabold text-ink" htmlFor="lesson-title">
                {t("lesson.menu.renameTitle")}
              </label>
              <input
                id="lesson-title"
                autoFocus
                value={draft}
                onChange={(event) => setDraft(event.target.value)}
                placeholder={t("lesson.menu.renamePlaceholder")}
                maxLength={120}
                className="h-11 rounded-tile border border-stroke-strong bg-surface px-3 text-[15px] text-ink outline-none focus-visible:ring-2 focus-visible:ring-ring"
              />
              <div className="flex justify-end gap-2">
                <Button variant="ghost" size="sm" disabled={pending} onClick={() => setMode("menu")}>
                  {t("lesson.menu.cancel")}
                </Button>
                <Button size="sm" type="submit" loading={pending} disabled={!draft.trim()}>
                  {t("lesson.menu.save")}
                </Button>
              </div>
            </form>
          ) : null}

          {mode === "reset" ? (
            <Confirm
              title={t("lesson.menu.resetTitle")}
              body={t("lesson.menu.resetMessage")}
              confirm={t("lesson.menu.reset")}
              cancel={t("lesson.menu.cancel")}
              pending={pending}
              onCancel={() => setMode("menu")}
              onConfirm={() => run(() => restartLesson(lessonId))}
            />
          ) : null}

          {mode === "delete" ? (
            <Confirm
              title={t("lesson.menu.deleteTitle")}
              body={t("lesson.menu.deleteMessage")}
              confirm={t("lesson.menu.delete")}
              cancel={t("lesson.menu.cancel")}
              destructive
              pending={pending}
              onCancel={() => setMode("menu")}
              onConfirm={() =>
                run(
                  () => deleteLesson(lessonId),
                  () => {
                    router.push(LESSONS_PATH);
                    router.refresh();
                  },
                )
              }
            />
          ) : null}

          {failure ? (
            <p className="px-2 pb-1 pt-2 text-[12.5px] text-negative" role="alert">
              {failure}
            </p>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function MenuRow({
  icon,
  label,
  onClick,
  disabled,
  destructive,
}: {
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
  disabled?: boolean;
  destructive?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={`flex h-11 items-center gap-3 rounded-tile px-3 text-left text-[15px] font-semibold hover:bg-surface-muted disabled:opacity-40 ${
        destructive ? "text-negative" : "text-ink"
      }`}
    >
      {icon}
      {label}
    </button>
  );
}

function Confirm({
  title,
  body,
  confirm,
  cancel,
  destructive,
  pending,
  onCancel,
  onConfirm,
}: {
  title: string;
  body: string;
  confirm: string;
  cancel: string;
  destructive?: boolean;
  pending: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  return (
    <div className="flex flex-col gap-3 p-2">
      <p className="text-[15px] font-extrabold text-ink">{title}</p>
      <p className="text-[13.5px] leading-relaxed text-ink-secondary">{body}</p>
      <div className="flex justify-end gap-2">
        <Button variant="ghost" size="sm" disabled={pending} onClick={onCancel}>
          {cancel}
        </Button>
        <Button variant={destructive ? "destructive" : "default"} size="sm" loading={pending} onClick={onConfirm}>
          {confirm}
        </Button>
      </div>
    </div>
  );
}
