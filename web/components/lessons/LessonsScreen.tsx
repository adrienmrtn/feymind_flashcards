"use client";

import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Check, ChevronRight, Ellipsis, Folder, FolderPlus, Pencil, Plus, Search, Trash2, X } from "lucide-react";

import { folderPath, type FolderNode, type LessonTone } from "@micabo/core";

import { LessonPrimaryButton, LessonSecondaryButton } from "@/components/lesson/LessonButtons";
import { Sheet } from "@/components/lesson/Sheet";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { Mika } from "@/components/mika/Mika";
import { createFolder, deleteFolder, moveCourse, renameFolder } from "@/lib/actions/folders";
import { deleteLesson, renameLesson } from "@/lib/actions/lesson";
import { useI18n } from "@/lib/i18n/client";
import { HOME_PATH, lessonPath } from "@/lib/lesson/routes";

/**
 * **L'onglet Leçons** : la liste, les plus récentes d'abord. Chaque carte dit où l'on en est
 * (« Cercle 4 sur 11 », « À ouvrir », « Leçon terminée »), ce qu'il y a à réviser et le
 * compte à rebours de l'examen. On cherche, on trie, on range dans des dossiers. Jumeau de
 * `LessonsScreen.swift`, avec les dossiers du site en plus.
 */
export interface LessonListItem {
  id: string;
  title: string;
  icon: string | null;
  tone: LessonTone;
  folderId: string | null;
  /** Un ancien cours, pas encore converti en parcours : il s'ouvre, et se convertit là. */
  legacy: boolean;
  opened: boolean;
  circleNumber: number | null;
  circleTotal: number;
  percent: number;
  finished: boolean;
  due: number;
  exam: { name: string; days: number } | null;
  /** Le dernier geste dessus, en millisecondes : le tri « récentes ». */
  recency: number;
}

type Sort = "recent" | "alpha" | "due";

export function LessonsScreen({ lessons, folders }: { lessons: LessonListItem[]; folders: FolderNode[] }) {
  const { t } = useI18n();
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState<Sort>("recent");
  const [folderId, setFolderId] = useState<string | null>(null);
  const [folderDraft, setFolderDraft] = useState<{ mode: "new" | "rename"; name: string } | null>(null);
  const [confirmFolder, setConfirmFolder] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const selectedFolder = folders.find((folder) => folder.id === folderId) ?? null;
  const folderNames = useMemo(() => {
    const names = new Map<string, string>();
    for (const folder of folders) names.set(folder.id, folderPath(folders, folder.id).map((step) => (step.emoji ? `${step.emoji} ${step.name}` : step.name)).join(" / "));
    return names;
  }, [folders]);

  const shown = useMemo(() => {
    const needle = query.trim().toLowerCase();
    const list = lessons.filter((lesson) => {
      if (folderId && !folderPath(folders, lesson.folderId).some((step) => step.id === folderId)) return false;
      return needle.length === 0 || lesson.title.toLowerCase().includes(needle);
    });
    if (sort === "alpha") return list.sort((a, b) => a.title.localeCompare(b.title));
    if (sort === "due") return list.sort((a, b) => b.due - a.due || b.recency - a.recency);
    return list.sort((a, b) => b.recency - a.recency);
  }, [folderId, folders, lessons, query, sort]);

  function run(action: () => Promise<{ status: "ok" | "error"; message?: string; id?: string }>, after?: (id?: string) => void) {
    setFailure(null);
    startTransition(async () => {
      const result = await action();
      if (result.status === "error") {
        setFailure(result.message ?? t("app.common.errorGeneric"));
        return;
      }
      after?.(result.id);
      router.refresh();
    });
  }

  const sorts: { id: Sort; label: string }[] = [
    { id: "recent", label: t("app.lessonsList.sortRecent") },
    { id: "alpha", label: t("app.lessonsList.sortAlpha") },
    { id: "due", label: t("app.lessonsList.sortDue") },
  ];

  return (
    <div className="mx-auto flex w-full max-w-[640px] flex-col gap-5 pb-6" data-tour="lecons-liste">
      <header className="flex items-end justify-between gap-3 pt-1">
        <div className="flex flex-col gap-0.5">
          <h1 className="text-[32px] font-extrabold leading-tight tracking-tight-title text-ink">{t("lesson.tab.lessons")}</h1>
          <p className="text-[15px] font-semibold text-ink-secondary">{t("lesson.lessons.count", { count: lessons.length })}</p>
        </div>
        <Link href={HOME_PATH} className="pressable flex h-11 items-center gap-1.5 rounded-pill bg-ink px-4 text-[15px] font-extrabold text-on-ink">
          <Plus aria-hidden="true" className="size-[18px]" strokeWidth={2.8} />
          {t("lesson.lessons.new")}
        </Link>
      </header>

      {lessons.length === 0 ? (
        <div className="flex flex-col items-center gap-4 rounded-[28px] bg-surface px-6 py-10 text-center shadow-floating">
          <Mika mood="sleep" size={150} label="" />
          <h2 className="text-[22px] font-extrabold text-ink">{t("lesson.lessons.emptyTitle")}</h2>
          <p className="max-w-[380px] text-[15.5px] font-medium text-ink-secondary">{t("lesson.lessons.emptyBody")}</p>
          <div className="w-full max-w-[320px] pt-2">
            <Link href={HOME_PATH} className="lesson-btn-primary" style={{ background: "var(--color-accent)" }}>
              {t("lesson.lessons.new")}
            </Link>
          </div>
        </div>
      ) : (
        <>
          <div className="flex flex-col gap-3">
            <label className="flex h-12 items-center gap-2.5 rounded-pill bg-surface px-4 shadow-[inset_0_0_0_1.5px_var(--color-stroke)] focus-within:shadow-[inset_0_0_0_2px_var(--color-accent)]">
              <Search aria-hidden="true" className="size-5 shrink-0 text-ink-tertiary" strokeWidth={2.4} />
              <input
                type="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder={t("app.lessonsList.search")}
                aria-label={t("app.lessonsList.search")}
                className="min-w-0 flex-1 bg-transparent text-[16px] font-semibold text-ink outline-none placeholder:text-ink-tertiary"
              />
              {query ? (
                <button type="button" onClick={() => setQuery("")} aria-label={t("app.common.cancel")} className="pressable text-ink-tertiary">
                  <X aria-hidden="true" className="size-[18px]" strokeWidth={2.6} />
                </button>
              ) : null}
            </label>

            <div className="flex items-center gap-2 overflow-x-auto [scrollbar-width:none]" role="group" aria-label={t("app.lessonsList.sort")}>
              {sorts.map((entry) => (
                <button
                  key={entry.id}
                  type="button"
                  aria-pressed={sort === entry.id}
                  onClick={() => setSort(entry.id)}
                  className={`pressable h-9 shrink-0 rounded-pill px-3.5 text-[14px] font-extrabold ${sort === entry.id ? "bg-ink text-on-ink" : "bg-surface text-ink-secondary shadow-[inset_0_0_0_1.5px_var(--color-stroke)]"}`}
                >
                  {entry.label}
                </button>
              ))}
            </div>

            <div className="flex items-center gap-2 overflow-x-auto [scrollbar-width:none]" role="group" aria-label={t("app.folders.root")}>
              <FolderChip on={folderId === null} onClick={() => setFolderId(null)} label={t("app.lessonsList.allFolders")} />
              {folders.map((folder) => (
                <FolderChip key={folder.id} on={folderId === folder.id} onClick={() => setFolderId(folder.id)} label={folderNames.get(folder.id) ?? folder.name} icon />
              ))}
              <button
                type="button"
                onClick={() => setFolderDraft({ mode: "new", name: "" })}
                aria-label={t("app.folders.new")}
                className="pressable flex size-9 shrink-0 items-center justify-center rounded-full bg-surface text-ink-secondary shadow-[inset_0_0_0_1.5px_var(--color-stroke)]"
              >
                <FolderPlus aria-hidden="true" className="size-[18px]" strokeWidth={2.4} />
              </button>
            </div>

            {selectedFolder ? (
              <div className="flex items-center gap-2 rounded-[16px] bg-surface-muted px-3.5 py-2.5">
                <Folder aria-hidden="true" className="size-[18px] text-ink-secondary" strokeWidth={2.4} />
                <span className="flex-1 truncate text-[14px] font-bold text-ink">{folderNames.get(selectedFolder.id)}</span>
                <button type="button" onClick={() => setFolderDraft({ mode: "rename", name: selectedFolder.name })} className="pressable flex items-center gap-1 text-[13px] font-bold text-ink-secondary">
                  <Pencil aria-hidden="true" className="size-4" strokeWidth={2.4} />
                  {t("app.folders.rename")}
                </button>
                <button type="button" onClick={() => setConfirmFolder(true)} className="pressable flex items-center gap-1 text-[13px] font-bold text-wrong-ink">
                  <Trash2 aria-hidden="true" className="size-4" strokeWidth={2.4} />
                  {t("app.folders.delete")}
                </button>
              </div>
            ) : null}
          </div>

          {failure ? (
            <p role="alert" className="text-[14px] font-bold text-wrong-ink">
              {failure}
            </p>
          ) : null}

          {shown.length === 0 ? (
            <p className="py-8 text-center text-[15.5px] font-semibold text-ink-secondary">{t("app.lessonsList.noResult")}</p>
          ) : (
            <ul className="flex flex-col gap-3">
              {shown.map((lesson) => (
                <li key={lesson.id}>
                  <LessonCard lesson={lesson} folders={folders} folderNames={folderNames} pending={pending} run={run} />
                </li>
              ))}
            </ul>
          )}
        </>
      )}

      {folderDraft ? (
        <Sheet onClose={() => setFolderDraft(null)} title={folderDraft.mode === "new" ? t("app.folders.new") : t("app.folders.rename")}>
          <input
            autoFocus
            value={folderDraft.name}
            onChange={(event) => setFolderDraft({ ...folderDraft, name: event.target.value })}
            placeholder={t("app.folders.namePlaceholder")}
            maxLength={60}
            className="rounded-[16px] bg-surface px-4 py-4 text-[18px] font-semibold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)] outline-none focus-visible:shadow-[inset_0_0_0_2px_var(--color-accent)]"
          />
          <LessonPrimaryButton
            disabled={folderDraft.name.trim().length === 0 || pending}
            style={{ background: "var(--color-accent)" }}
            onClick={() => {
              const name = folderDraft.name.trim();
              if (folderDraft.mode === "new") run(() => createFolder(name, folderId), (id) => setFolderId(id ?? folderId));
              else if (selectedFolder) run(() => renameFolder(selectedFolder.id, name));
              setFolderDraft(null);
            }}
          >
            {folderDraft.mode === "new" ? t("app.folders.create") : t("app.folders.rename")}
          </LessonPrimaryButton>
        </Sheet>
      ) : null}

      {confirmFolder && selectedFolder ? (
        <Sheet onClose={() => setConfirmFolder(false)} title={t("app.folders.deleteQ")}>
          <p className="text-[15.5px] font-medium text-ink-secondary">{t("app.folders.deleteMsg")}</p>
          <LessonPrimaryButton
            style={{ background: "var(--color-wrong)" }}
            disabled={pending}
            onClick={() => {
              const id = selectedFolder.id;
              setConfirmFolder(false);
              run(() => deleteFolder(id), () => setFolderId(selectedFolder.parentId));
            }}
          >
            {t("app.folders.delete")}
          </LessonPrimaryButton>
          <LessonSecondaryButton onClick={() => setConfirmFolder(false)}>{t("app.common.cancel")}</LessonSecondaryButton>
        </Sheet>
      ) : null}
    </div>
  );
}

function FolderChip({ on, onClick, label, icon }: { on: boolean; onClick: () => void; label: string; icon?: boolean }) {
  return (
    <button
      type="button"
      aria-pressed={on}
      onClick={onClick}
      className={`pressable flex h-9 shrink-0 items-center gap-1.5 rounded-pill px-3.5 text-[14px] font-extrabold ${on ? "bg-accent-soft text-accent shadow-[inset_0_0_0_2px_var(--color-accent)]" : "bg-surface text-ink-secondary shadow-[inset_0_0_0_1.5px_var(--color-stroke)]"}`}
    >
      {icon ? <Folder aria-hidden="true" className="size-4" strokeWidth={2.4} /> : null}
      <span className="max-w-[180px] truncate">{label}</span>
    </button>
  );
}

/** **Une leçon** : l'icône sur le pastel de sa couleur, le titre, où elle en est, la barre, et ce qui l'attend. */
function LessonCard({
  lesson,
  folders,
  folderNames,
  pending,
  run,
}: {
  lesson: LessonListItem;
  folders: FolderNode[];
  folderNames: Map<string, string>;
  pending: boolean;
  run: (action: () => Promise<{ status: "ok" | "error"; message?: string }>, after?: () => void) => void;
}) {
  const { t } = useI18n();
  const [menu, setMenu] = useState<"closed" | "menu" | "move" | "rename" | "delete">("closed");
  const [draft, setDraft] = useState(lesson.title);
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (menu !== "menu") return;
    function away(event: MouseEvent) {
      if (root.current && !root.current.contains(event.target as Node)) setMenu("closed");
    }
    document.addEventListener("mousedown", away);
    return () => document.removeEventListener("mousedown", away);
  }, [menu]);

  const status = lesson.legacy
    ? t("app.lessonsList.legacy")
    : lesson.finished
      ? t("lesson.lessons.finished")
      : !lesson.opened || lesson.circleNumber === null
        ? t("lesson.lessons.toOpen")
        : t("lesson.lessons.circle", { n: lesson.circleNumber, total: lesson.circleTotal });
  const tone = lesson.tone;

  return (
    <div ref={root} className="relative">
      <Link href={lessonPath(lesson.id)} className="pressable flex items-center gap-3.5 rounded-[22px] bg-surface p-3.5 pr-12 shadow-floating">
        <span className="flex size-[64px] shrink-0 items-center justify-center rounded-[18px]" style={{ background: `var(--color-tone-${tone}-pale)` }}>
          <MicaboIcon id={lesson.icon} size={44} />
        </span>
        <span className="flex min-w-0 flex-1 flex-col gap-1.5">
          <span className="line-clamp-2 text-[17px] font-bold leading-snug text-ink">{lesson.title}</span>
          <span className="truncate text-[14px] font-semibold text-ink-secondary">{status}</span>
          {!lesson.legacy ? (
            <span className="h-2 w-full overflow-hidden rounded-pill bg-track" role="progressbar" aria-valuenow={lesson.percent} aria-valuemin={0} aria-valuemax={100}>
              <span className="block h-full rounded-pill" style={{ width: `${lesson.finished ? 100 : lesson.percent}%`, background: `var(--color-tone-${tone}-vivid)` }} />
            </span>
          ) : null}
          {lesson.due > 0 || lesson.exam ? (
            <span className="flex flex-wrap items-center gap-1.5">
              {lesson.due > 0 ? <span className="rounded-pill bg-caution-soft px-2 py-0.5 text-[12px] font-extrabold text-caution-ink">{t("lesson.lessons.due", { count: lesson.due })}</span> : null}
              {lesson.exam ? (
                <span className="truncate rounded-pill bg-accent-soft px-2 py-0.5 text-[12px] font-extrabold text-accent">
                  {t("lesson.lessons.examDays", { days: lesson.exam.days })} · {lesson.exam.name}
                </span>
              ) : null}
            </span>
          ) : null}
        </span>
        <ChevronRight aria-hidden="true" className="absolute right-11 top-1/2 size-5 -translate-y-1/2 text-ink-tertiary" strokeWidth={2.6} />
      </Link>
      <button
        type="button"
        aria-label={t("lesson.menu.more")}
        aria-expanded={menu === "menu"}
        onClick={() => setMenu(menu === "menu" ? "closed" : "menu")}
        className="pressable absolute right-2 top-2 flex size-9 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted"
      >
        <Ellipsis aria-hidden="true" className="size-5" strokeWidth={2.6} />
      </button>

      {menu === "menu" ? (
        <div role="menu" className="score-in absolute right-2 top-11 z-20 flex w-[220px] flex-col rounded-[18px] bg-canvas p-1.5 shadow-floating">
          <MenuRow icon={Folder} label={t("app.lessonsList.move")} onClick={() => setMenu("move")} />
          <MenuRow icon={Pencil} label={t("lesson.menu.rename")} onClick={() => setMenu("rename")} />
          <MenuRow icon={Trash2} label={t("lesson.menu.delete")} onClick={() => setMenu("delete")} danger />
        </div>
      ) : null}

      {menu === "move" ? (
        <Sheet onClose={() => setMenu("closed")} title={t("app.lessonsList.move")}>
          <ul className="flex max-h-[50svh] flex-col gap-1.5 overflow-y-auto">
            {[{ id: null as string | null, label: t("app.lessonsList.noFolder") }, ...folders.map((folder) => ({ id: folder.id as string | null, label: folderNames.get(folder.id) ?? folder.name }))].map((target) => {
              const on = (lesson.folderId ?? null) === target.id;
              return (
                <li key={target.id ?? "root"}>
                  <button
                    type="button"
                    disabled={pending}
                    onClick={() => {
                      setMenu("closed");
                      if (!on) run(() => moveCourse(lesson.id, target.id));
                    }}
                    className={`pressable flex w-full items-center gap-2.5 rounded-[14px] px-3.5 py-3 text-left text-[15px] font-bold ${on ? "bg-accent-soft text-accent" : "text-ink hover:bg-surface-muted"}`}
                  >
                    <Folder aria-hidden="true" className="size-[18px]" strokeWidth={2.4} />
                    <span className="flex-1 truncate">{target.label}</span>
                    {on ? <Check aria-hidden="true" className="size-[18px]" strokeWidth={2.8} /> : null}
                  </button>
                </li>
              );
            })}
          </ul>
        </Sheet>
      ) : null}

      {menu === "rename" ? (
        <Sheet onClose={() => setMenu("closed")} title={t("lesson.lessons.renameTitle")}>
          <input
            autoFocus
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            placeholder={t("lesson.lessons.renamePlaceholder")}
            maxLength={120}
            className="rounded-[16px] bg-surface px-4 py-4 text-[18px] font-semibold text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke)] outline-none focus-visible:shadow-[inset_0_0_0_2px_var(--color-accent)]"
          />
          <LessonPrimaryButton
            disabled={draft.trim().length === 0 || pending}
            style={{ background: "var(--color-accent)" }}
            onClick={() => {
              setMenu("closed");
              run(() => renameLesson(lesson.id, draft.trim()));
            }}
          >
            {t("lesson.menu.save")}
          </LessonPrimaryButton>
        </Sheet>
      ) : null}

      {menu === "delete" ? (
        <Sheet onClose={() => setMenu("closed")} title={t("lesson.menu.deleteTitle")}>
          <p className="text-[15.5px] font-medium text-ink-secondary">{t("lesson.menu.deleteMessage")}</p>
          <LessonPrimaryButton
            style={{ background: "var(--color-wrong)" }}
            disabled={pending}
            onClick={() => {
              setMenu("closed");
              run(() => deleteLesson(lesson.id));
            }}
          >
            {t("lesson.menu.delete")}
          </LessonPrimaryButton>
          <LessonSecondaryButton onClick={() => setMenu("closed")}>{t("lesson.menu.cancel")}</LessonSecondaryButton>
        </Sheet>
      ) : null}
    </div>
  );
}

function MenuRow({ icon: Icon, label, onClick, danger }: { icon: typeof Folder; label: string; onClick: () => void; danger?: boolean }) {
  return (
    <button type="button" role="menuitem" onClick={onClick} className={`pressable flex items-center gap-2.5 rounded-[12px] px-3 py-2.5 text-left text-[15px] font-bold hover:bg-surface-muted ${danger ? "text-wrong-ink" : "text-ink"}`}>
      <Icon aria-hidden="true" className="size-[18px]" strokeWidth={2.4} />
      {label}
    </button>
  );
}
