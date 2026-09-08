"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";

import {
  BLOCK_BOUNDS,
  DEFAULT_SHEET_LENGTH,
  DEFAULT_VISIBILITY,
  SOURCE_LANGUAGE,
  clampBlocks,
  defaultBlocks,
  lengthContaining,
  type CourseVisibility,
  type GenerationLanguage,
  type SheetLength,
} from "@micabo/core";

import { GenerationStatus } from "@/components/app/GenerationStatus";
import { LanguageChoices } from "@/components/app/LanguageChoices";
import { VisibilityChoices } from "@/components/app/VisibilityChoices";
import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";
import { copySheetLengthTitle, type Translator } from "@/lib/i18n/copy";
import { youtubePreview, youtubeTranscript } from "@/lib/actions/course";
import {
  beginStandaloneWrite,
  holdImportHandoff,
  openGeneratedPage,
  releaseImportHandoff,
  rememberWrittenCourse,
  waitForPaint,
} from "@/lib/import-handoff";
import { requestPaywall } from "@/lib/paywall";
import { writeSheetFromBrowser } from "@/lib/import/write-sheet";
import { isAnkiFileName } from "@/lib/import/anki";
import {
  MIN_TEXT_LENGTH,
  classifyReadFailure,
  failureDetail,
  readDocument,
  type ReadFailureCode,
} from "@/lib/import/read-document";
import {
  isYouTubeUrl,
  preferredLanguages,
  previewYouTubeInBrowser,
  readYouTubeInBrowser,
  youtubeBlockingReason,
  youtubeDurationLabel,
  MAX_DURATION_SECONDS,
  type YouTubePreview,
} from "@/lib/import/youtube";

/**
 * **L'import s'arrête à l'aperçu.** On dépose, on voit le document ou la
 * vidéo, on règle, puis on écrit la fiche. Générer au moment du dépôt
 * brûlait un appel avant d'avoir rien relu.
 *
 * Le fichier est lu **dans l'onglet** : le texte, et les pages d'un PDF
 * pour en extraire les schémas. YouTube suit le même chemin que l'iPhone :
 * l'onglet d'abord (l'IP n'est pas un datacenter), le serveur en repli.
 */

type Extra = null | "coller" | "video";
type Phase = "repos" | "lecture" | "apercu" | "ecriture";
type SourceKind = "text" | "pdf" | "docx" | "youtube";

interface Draft {
  text: string;
  title: string;
  sourceName?: string;
  source: SourceKind;
  fileUrl?: string;
  video?: YouTubePreview;
  /** Pages JPEG en data URL, pour extraire les schémas du PDF. */
  images?: string[];
}

export function ImportPanel({
  initialLength = DEFAULT_SHEET_LENGTH,
}: {
  initialLength?: SheetLength;
}) {
  const { t } = useI18n();
  const [extra, setExtra] = useState<Extra>(null);
  const [phase, setPhase] = useState<Phase>("repos");
  const [failure, setFailure] = useState<string | null>(null);
  const [blocks, setBlocks] = useState(() => defaultBlocks(initialLength));
  const [visibility, setVisibility] = useState<CourseVisibility>(DEFAULT_VISIBILITY);
  const [language, setLanguage] = useState<GenerationLanguage>(SOURCE_LANGUAGE);
  const [instructions, setInstructions] = useState("");

  const [text, setText] = useState("");
  const [title, setTitle] = useState("");
  const [url, setUrl] = useState("");
  const [fileName, setFileName] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const [draft, setDraft] = useState<Draft | null>(null);
  /** Un paquet Anki déposé ici : il n'y a rien à ficher, donc on montre la bonne porte. */
  const [ankiFile, setAnkiFile] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const busy = phase === "lecture" || phase === "ecriture";
  const length = lengthContaining(blocks);
  const previewing = draft !== null;

  useEffect(() => {
    return () => {
      if (draft?.fileUrl) URL.revokeObjectURL(draft.fileUrl);
    };
  }, [draft?.fileUrl]);

  useEffect(() => {
    // Un voile resté d'une écriture cassée recouvrait l'import au rechargement.
    releaseImportHandoff();
  }, []);

  function finish(result: { status: string; courseId?: string; message?: string }) {
    if (result.status === "ok" && result.courseId) {
      rememberWrittenCourse(result.courseId);
      // Lever le voile **avant** le chargement : le garder hydratait la
      // fiche avec un état que le serveur n'a pas.
      releaseImportHandoff();
      openGeneratedPage(`/app/c/${result.courseId}`);
      return;
    }
    releaseImportHandoff();
    setPhase(draft ? "apercu" : "repos");
    if (result.status === "paywall") {
      requestPaywall();
      return;
    }
    setFailure(result.message ?? t("app.common.errorGeneric"));
  }

  function showDraft(next: Draft, name?: string) {
    setDraft((previous) => {
      if (previous?.fileUrl) URL.revokeObjectURL(previous.fileUrl);
      return next;
    });
    setFileName(name ?? next.sourceName ?? null);
    if (next.title && !title.trim()) setTitle(next.title);
    setPhase("apercu");
    setFailure(null);
  }

  function resetDraft() {
    setDraft((previous) => {
      if (previous?.fileUrl) URL.revokeObjectURL(previous.fileUrl);
      return null;
    });
    setFileName(null);
    setPhase("repos");
    setFailure(null);
  }

  async function generate(payload: Draft) {
    const name = title.trim() || payload.sourceName || payload.title;
    // On quitte Next **avant** le POST. Tant que React peint l'import, un
    // vol RSC avorté affiche « This page couldn't load » pendant l'écriture.
    const left = beginStandaloneWrite(
      {
        text: payload.text,
        hintTitle: title.trim() || payload.title,
        sourceName: payload.sourceName,
        source: payload.source,
        blocks,
        length,
        visibility,
        language,
        instructions: instructions.trim() || undefined,
        images: payload.images,
      },
      {
        writing: t("app.import.writing"),
        waitHint: name.trim() || t("app.import.waitHint"),
      },
    );
    if (left) {
      await new Promise(() => {});
      return;
    }
    setFailure(null);
    setPhase("ecriture");
    holdImportHandoff({ name });
    await waitForPaint();
    finish(
      await Promise.race([
        writeSheetFromBrowser({
          text: payload.text,
          hintTitle: title.trim() || payload.title,
          sourceName: payload.sourceName,
          source: payload.source,
          blocks,
          length,
          visibility,
          language,
          instructions: instructions.trim() || undefined,
          images: payload.images,
        }),
        new Promise<{ status: "error"; message: string }>((resolve) => {
          setTimeout(
            () =>
              resolve({
                status: "error",
                message: t("app.import.timeout"),
              }),
            90_000,
          );
        }),
      ]),
    );
  }

  async function loadVideo(link: string) {
    if (phase === "lecture" || phase === "ecriture") return;
    setFailure(null);
    setPhase("lecture");
    const [local, remote] = await Promise.all([
      previewYouTubeInBrowser(link),
      youtubePreview(link, preferredLanguages()),
    ]);
    const fromServer = remoteVideo(remote, t);
    const video = fromServer?.captionsKnown
      ? fromServer
      : local.status === "ok"
        ? local.video
        : fromServer;

    if (video) {
      showDraft({
        text: "",
        title: video.title,
        sourceName: video.title,
        source: "youtube",
        video,
      });
      return;
    }

    setPhase("repos");
    setFailure(
      remote.status === "error"
        ? remote.message
        : local.status === "error"
          ? local.message
          : t("app.import.videoUnreadable"),
    );
  }

  async function generateVideo() {
    if (!draft || draft.source !== "youtube") return;
    const link = url.trim();
    setFailure(null);
    setPhase("lecture");

    const local = await readYouTubeInBrowser(link);
    if (local.status === "ok") {
      void generate({ ...draft, text: local.text, title: local.title, sourceName: local.title });
      return;
    }

    const remote = await youtubeTranscript(link, preferredLanguages());
    if (remote.status === "ok") {
      void generate({ ...draft, text: remote.text, title: remote.title, sourceName: remote.title });
      return;
    }

    setPhase("apercu");
    setFailure(remote.message ?? local.message);
  }

  async function handleFile(file: File) {
    setFailure(null);
    setAnkiFile(null);

    // Un `.apkg` n'est pas un document : c'est un paquet de cartes déjà écrites. L'envoyer au
    // modèle donnerait une fiche sur un fichier binaire. On renvoie donc vers l'écran qui sait
    // le lire, plutôt que d'échouer sur « ce document ne contient pas assez de contenu ».
    if (isAnkiFileName(file.name)) {
      setAnkiFile(file.name);
      setFileName(null);
      setPhase("repos");
      return;
    }

    setFileName(file.name);
    setPhase("lecture");

    try {
      const read = await readDocument(file);
      if (read.text.trim().length < MIN_TEXT_LENGTH && read.images.length === 0) {
        setPhase("repos");
        setFailure(t("app.import.scannedPdf"));
        return;
      }

      showDraft({
        text: read.text,
        title: file.name.replace(/\.[^.]+$/, ""),
        sourceName: file.name,
        source: read.kind,
        fileUrl: read.kind === "pdf" ? URL.createObjectURL(file) : undefined,
        images: read.images,
      }, file.name);
    } catch (error) {
      // Le message dit ce qui s'est passé ; la console garde de quoi le confirmer.
      console.error("[micabo] lecture du document refusée", error);
      setPhase("repos");
      setFailure(readFailureMessage(error, t));
    }
  }

  const videoBlocked = draft?.video ? youtubeBlockingReason(draft.video) : null;
  const videoNotice =
    draft?.video && draft.video.durationSeconds > MAX_DURATION_SECONDS
      ? t("app.import.longVideo", {
          duration: youtubeDurationLabel(draft.video.durationSeconds) ?? "",
        })
      : null;
  const canGenerate = previewing && (
    draft.source === "youtube"
      ? Boolean(draft.video && !videoBlocked)
      : draft.text.trim().length >= 40 || (draft.images?.length ?? 0) > 0
  );

  return (
    <div>
      {!previewing ? (
        <div
          onDragOver={(event) => {
            event.preventDefault();
            if (!busy) setDragging(true);
          }}
          onDragLeave={() => setDragging(false)}
          onDrop={(event) => {
            event.preventDefault();
            setDragging(false);
            if (busy) return;
            const file = event.dataTransfer.files[0];
            if (file) void handleFile(file);
          }}
          className={`flex min-h-[200px] flex-col items-center justify-center rounded-2xl border border-dashed px-6 py-10 text-center transition-colors ${
            dragging ? "border-foreground bg-surface-muted" : "border-border bg-card"
          }`}
        >
          <input
            ref={fileInput}
            type="file"
            accept=".pdf,.txt,.md,.markdown,.docx,.apkg,.colpkg"
            className="sr-only"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) void handleFile(file);
            }}
          />

          {phase === "lecture" ? (
            <Waiting t={t} phase={phase} name={fileName} />
          ) : (
            <>
              <svg
                aria-hidden
                viewBox="0 0 24 24"
                className={`h-9 w-9 ${dragging ? "text-ink" : "text-ink-tertiary"}`}
              >
                <path
                  d="M12 16V4M7 9l5-5 5 5M4 17v2a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-2"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>

              <p className="mt-4 text-base font-semibold text-foreground">
                {dragging ? t("app.import.dropHere") : t("app.import.drop")}
              </p>
              <p className="mt-1 text-sm text-muted-foreground">{t("app.import.formatsHint")}</p>

              <Button
                type="button"
                className="mt-5"
                onClick={() => fileInput.current?.click()}
              >
                {t("app.import.chooseFile")}
              </Button>

              <div className="mt-6 flex flex-wrap items-center justify-center gap-x-5 gap-y-2 text-[13.5px]">
                <button
                  type="button"
                  onClick={() => setExtra(extra === "coller" ? null : "coller")}
                  className="underline-draw font-medium text-ink-secondary"
                >
                  {t("app.import.pasteAction")}
                </button>
                <span aria-hidden className="text-ink-tertiary">
                  ·
                </span>
                <button
                  type="button"
                  onClick={() => setExtra(extra === "video" ? null : "video")}
                  className="underline-draw font-medium text-ink-secondary"
                >
                  {t("app.import.youtubeAction")}
                </button>
                <span aria-hidden className="text-ink-tertiary">
                  ·
                </span>
                {/* La troisième porte ne mène pas à une fiche : elle mène à des cartes sans
                    cours, et c'est aussi par là qu'entre un paquet Anki. */}
                <Link
                  href={"/app/paquet" as never}
                  className="underline-draw font-medium text-ink-secondary"
                >
                  {t("app.import.deckAction")}
                </Link>
              </div>
            </>
          )}
        </div>
      ) : null}

      {ankiFile ? (
        <div className="mt-4 flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-border bg-card p-5">
          <div className="min-w-0">
            <p className="text-[15px] font-semibold text-ink">{t("app.import.ankiTitle")}</p>
            <p className="mt-1 text-[13.5px] leading-relaxed text-ink-secondary">
              {t("app.import.ankiHint", { name: ankiFile })}
            </p>
          </div>
          <Button render={<Link href={"/app/paquet" as never} />}>
            {t("app.import.ankiAction")}
          </Button>
        </div>
      ) : null}

      {previewing && draft ? (
        <Preview
          t={t}
          draft={draft}
          title={title}
          blocked={videoBlocked}
          notice={videoNotice}
          reading={phase === "lecture"}
          writing={phase === "ecriture"}
          onChange={() => {
            if (draft.source === "youtube") {
              setUrl("");
            }
            resetDraft();
          }}
        />
      ) : null}

      {extra === "coller" && !previewing && phase === "repos" ? (
        <div className="mt-4 rounded-2xl border border-border bg-card p-5">
          <label htmlFor="import-title" className="eyebrow block text-ink-tertiary">
            {t("app.import.optionalTitle")}
          </label>
          <input
            id="import-title"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder={t("app.import.titleGuess")}
            disabled={busy}
            className="mt-2 h-11 w-full rounded-button bg-surface-muted px-4 text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
          />

          <label htmlFor="import-text" className="eyebrow mt-5 block text-ink-tertiary">
            {t("app.import.yourCourse")}
          </label>
          <textarea
            id="import-text"
            value={text}
            onChange={(event) => setText(event.target.value)}
            placeholder={t("app.import.pastePlaceholder")}
            rows={10}
            disabled={busy}
            className="mt-2 w-full resize-y rounded-button bg-surface-muted p-4 text-[15px] leading-relaxed text-ink outline-none placeholder:text-ink-tertiary"
          />

          <div className="mt-4 flex items-center justify-between gap-4">
            <p className="numeral text-[13px] text-ink-tertiary">
              {t("app.import.charCount", { count: text.trim().length })}
            </p>
            <Button
              type="button"
              disabled={busy || text.trim().length < 40}
              onClick={() =>
                showDraft({
                  text,
                  title: title.trim() || t("app.import.pasteTitle"),
                  source: "text",
                })
              }
            >
              {t("app.import.seeText")}
            </Button>
          </div>
        </div>
      ) : null}

      {extra === "video" && !previewing && phase !== "lecture" ? (
        <div className="mt-4 rounded-2xl border border-border bg-card p-5">
          <label htmlFor="import-url" className="eyebrow block text-ink-tertiary">
            {t("app.import.videoLink")}
          </label>
          <input
            id="import-url"
            value={url}
            onChange={(event) => {
              const next = event.target.value;
              setUrl(next);
              if (isYouTubeUrl(next) && !busy) void loadVideo(next.trim());
            }}
            placeholder="https://www.youtube.com/watch?v=…"
            disabled={busy}
            className="mt-2 h-12 w-full rounded-button bg-surface-muted px-4 text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
            onKeyDown={(event) => {
              if (event.key === "Enter" && isYouTubeUrl(url)) {
                event.preventDefault();
                void loadVideo(url.trim());
              }
            }}
          />
          <p className="mt-2 text-[13px] text-ink-tertiary">{t("app.import.subsRequired")}</p>

          <div className="mt-5 flex justify-end">
            <Button
              type="button"
              disabled={busy || !isYouTubeUrl(url)}
              onClick={() => void loadVideo(url.trim())}
            >
              {t("app.import.seeVideo")}
            </Button>
          </div>
        </div>
      ) : null}

      <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <div className="rounded-2xl border border-border bg-card p-5">
          <div className="flex items-baseline justify-between gap-3">
            <p className="eyebrow text-ink-tertiary">{t("app.import.sheetLength")}</p>
            <p className="text-[13px] font-medium text-ink">
              {copySheetLengthTitle(t, length)}{" "}
              <span className="text-ink-tertiary">
                · {t("app.import.readingMins", { minutes: Math.max(1, Math.round(blocks / 4.5)) })}
              </span>
            </p>
          </div>

          <input
            type="range"
            min={BLOCK_BOUNDS.min}
            max={BLOCK_BOUNDS.max}
            value={blocks}
            disabled={busy}
            aria-label={t("app.import.blocksAria")}
            onChange={(event) => setBlocks(clampBlocks(Number(event.target.value)))}
            className="mt-4 w-full accent-[var(--color-accent)]"
          />
          <p className="numeral mt-2 text-[12.5px] text-ink-tertiary">
            {t("app.import.blockCount", { count: blocks })}
          </p>
        </div>

        <div className="rounded-2xl border border-border bg-card p-5">
          <p className="eyebrow text-ink-tertiary">{t("app.import.sheetLanguage")}</p>
          <div className="mt-3.5">
            <LanguageChoices value={language} onChange={setLanguage} disabled={busy} />
          </div>
        </div>

        <div className="rounded-2xl border border-border bg-card p-5 sm:col-span-2 lg:col-span-1">
          <p className="eyebrow text-ink-tertiary">{t("app.course.visibility.label")}</p>
          <div className="mt-3.5">
            <VisibilityChoices value={visibility} onChange={setVisibility} disabled={busy} />
          </div>
        </div>
      </div>

      <div className="mt-3 rounded-2xl border border-border bg-card p-5">
        <label htmlFor="import-instructions" className="eyebrow block text-ink-tertiary">
          {t("app.import.instructionsLabel")}
        </label>
        <textarea
          id="import-instructions"
          value={instructions}
          onChange={(event) => setInstructions(event.target.value.slice(0, 2_000))}
          placeholder={t("app.import.instructionsPlaceholder")}
          rows={4}
          maxLength={2_000}
          disabled={busy}
          className="mt-3 w-full resize-y rounded-button bg-surface-muted p-4 text-[15px] leading-relaxed text-ink outline-none placeholder:text-ink-tertiary disabled:opacity-60"
        />
        <div className="mt-2 flex items-baseline justify-between gap-3">
          <p className="text-[12.5px] leading-relaxed text-ink-tertiary">
            {t("app.import.instructionsHint")}
          </p>
          {instructions.trim().length > 0 ? (
            <p className="numeral shrink-0 text-[12.5px] text-ink-tertiary">
              {instructions.trim().length} / 2000
            </p>
          ) : null}
        </div>
      </div>

      {previewing ? (
        <div className="mt-4 flex justify-end">
          <Button
            type="button"
            disabled={busy || !canGenerate}
            onClick={() => {
              if (!draft) return;
              if (draft.source === "youtube") {
                void generateVideo();
                return;
              }
              void generate(draft);
            }}
          >
            {phase === "ecriture"
              ? t("app.import.writing")
              : phase === "lecture"
                ? t("app.import.readingSubs")
                : t("app.import.writeSheet")}
          </Button>
        </div>
      ) : null}

      {failure ? (
        <p
          className="mt-4 rounded-group bg-negative-soft px-5 py-4 text-[14px] leading-relaxed text-negative"
          role="alert"
        >
          {failure}
        </p>
      ) : null}
    </div>
  );
}

function Preview({
  t,
  draft,
  title,
  blocked,
  notice,
  reading,
  writing,
  onChange,
}: {
  t: Translator;
  draft: Draft;
  title: string;
  blocked: string | null;
  notice: string | null;
  reading: boolean;
  writing: boolean;
  onChange: () => void;
}) {
  if (reading || writing) {
    return (
      <div className="flex min-h-[200px] flex-col items-center justify-center rounded-2xl border border-border bg-card px-6 py-10">
        <Waiting t={t} phase={writing ? "ecriture" : "lecture"} name={draft.sourceName ?? title} />
      </div>
    );
  }

  if (draft.video) {
    return (
      <div className="overflow-hidden rounded-2xl border border-border bg-card">
        <div className="relative aspect-video bg-surface-muted">
          <iframe
            title={draft.video.title}
            src={`https://www.youtube-nocookie.com/embed/${draft.video.id}`}
            allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
            className="absolute inset-0 h-full w-full"
          />
        </div>
        <div className="flex items-start justify-between gap-4 p-5">
          <div className="min-w-0">
            <p className="text-[16px] font-semibold text-ink">{draft.video.title}</p>
            {draft.video.author ? (
              <p className="mt-1 text-[13px] text-ink-tertiary">{draft.video.author}</p>
            ) : null}
            <p className="mt-2 text-[13px] text-ink-tertiary">
              {[
                youtubeDurationLabel(draft.video.durationSeconds),
                draft.video.captions[0]
                  ? draft.video.captions[0].isAutomatic
                    ? t("app.import.autoCaptions", { name: draft.video.captions[0].name })
                    : t("app.import.captions", { name: draft.video.captions[0].name })
                  : null,
              ]
                .filter(Boolean)
                .join(" · ")}
            </p>
            {blocked ? (
              <p className="mt-3 text-[13.5px] leading-relaxed text-caution" role="status">
                {blocked}
              </p>
            ) : notice ? (
              <p className="mt-3 text-[13.5px] leading-relaxed text-ink-secondary" role="status">
                {notice}
              </p>
            ) : null}
          </div>
          <Button type="button" variant="ghost" onClick={onChange}>
            {t("app.common.change")}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-border bg-card">
      {draft.fileUrl ? (
        <iframe
          title={draft.sourceName ?? t("app.import.importedDoc")}
          src={draft.fileUrl}
          className="h-[min(70vh,640px)] w-full bg-surface-muted"
        />
      ) : (
        <pre className="max-h-[min(70vh,640px)] overflow-auto whitespace-pre-wrap p-5 text-[14.5px] leading-relaxed text-ink">
          {draft.text}
        </pre>
      )}
      <div className="flex items-center justify-between gap-4 border-t border-border px-5 py-4">
        <div className="min-w-0">
          <p className="truncate text-[15px] font-semibold text-ink">
            {title.trim() || draft.title}
          </p>
          <p className="mt-0.5 text-[13px] text-ink-tertiary">
            {draft.sourceName ?? t("app.import.pastedText")}
            {" · "}
            {t("app.import.charCount", { count: draft.text.trim().length })}
          </p>
        </div>
        <Button type="button" variant="ghost" onClick={onChange}>
          {t("app.common.change")}
        </Button>
      </div>
    </div>
  );
}

function Waiting({
  t,
  phase,
  name,
}: {
  t: Translator;
  phase: Phase;
  name: string | null;
}) {
  return (
    <GenerationStatus
      title={phase === "lecture" ? t("app.import.reading") : t("app.import.writing")}
      hint={name ?? t("app.import.waitHint")}
    />
  );
}

function remoteVideo(
  result: { status: string; video?: unknown; message?: string },
  t: Translator,
): YouTubePreview | null {
  if (result.status !== "ok" || !result.video || typeof result.video !== "object") return null;
  const raw = result.video as {
    id?: unknown;
    title?: unknown;
    author?: unknown;
    thumbnailUrl?: unknown;
    durationSeconds?: unknown;
    captions?: unknown;
    captionLanguages?: unknown;
    captionsKnown?: unknown;
  };
  if (typeof raw.id !== "string" || raw.id.length === 0) return null;
  const rawCaptions = Array.isArray(raw.captions)
    ? raw.captions
    : Array.isArray(raw.captionLanguages)
      ? raw.captionLanguages
      : [];
  const captions = rawCaptions.flatMap((entry) => {
    if (!entry || typeof entry !== "object") return [];
    const item = entry as { code?: unknown; name?: unknown; isAutomatic?: unknown };
    if (typeof item.code !== "string" || item.code.length === 0) return [];
    return [{
      code: item.code,
      name: typeof item.name === "string" ? item.name : item.code,
      isAutomatic: item.isAutomatic === true,
    }];
  });
  return {
    id: raw.id,
    title: typeof raw.title === "string" && raw.title.length > 0 ? raw.title : t("app.import.youtubeVideo"),
    author: typeof raw.author === "string" ? raw.author : "",
    thumbnailUrl: typeof raw.thumbnailUrl === "string"
      ? raw.thumbnailUrl
      : `https://i.ytimg.com/vi/${raw.id}/hqdefault.jpg`,
    durationSeconds: typeof raw.durationSeconds === "number" ? raw.durationSeconds : 0,
    captions,
    captionsKnown: raw.captionsKnown === true || captions.length > 0,
  };
}

/**
 * Une phrase par cause, et jamais « illisible » quand on sait mieux.
 *
 * Le dernier cas garde le nom de l'erreur : c'est la seule branche où l'on n'a
 * rien à expliquer, donc la seule où un détail technique vaut mieux que rien.
 * Sans lui, un rapport se résume à « ça ne marche pas », et on cherche à
 * l'aveugle - ce qui est exactement arrivé.
 */
function readFailureMessage(error: unknown, t: Translator): string {
  const messages: Record<ReadFailureCode, string> = {
    unsupported: "app.import.unsupportedFile",
    legacyWord: "app.import.docxLegacy",
    unreachable: "app.import.fileUnreachable",
    locked: "app.import.pdfLocked",
    damaged: "app.import.pdfDamaged",
    engine: "app.import.readerFailed",
    wordEmpty: "app.import.docxEmpty",
    wordUnreadable: "app.import.docxUnreadable",
    empty: "app.import.scannedPdf",
    unknown: "app.import.fileUnreadable",
  };

  const code = classifyReadFailure(error);
  if (code !== "unknown") return t(messages[code] as never);

  const detail = failureDetail(error);
  return detail
    ? t("app.import.fileUnreadableDetail", { detail })
    : t("app.import.fileUnreadable");
}
