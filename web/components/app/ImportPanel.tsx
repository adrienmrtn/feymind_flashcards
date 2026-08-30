"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import {
  BLOCK_BOUNDS,
  DEFAULT_SHEET_LENGTH,
  DEFAULT_VISIBILITY,
  SOURCE_LANGUAGE,
  clampBlocks,
  defaultBlocks,
  lengthContaining,
  readingHint,
  sheetLengthTitle,
  type CourseVisibility,
  type GenerationLanguage,
  type SheetLength,
} from "@micabo/core";

import { LanguageChoices } from "@/components/app/LanguageChoices";
import { VisibilityChoices } from "@/components/app/VisibilityChoices";
import { Button } from "@/components/ui/button";
import { importFromText, youtubePreview, youtubeTranscript } from "@/lib/actions/course";
import { DocxError, extractDocxText } from "@/lib/import/docx";
import {
  isYouTubeUrl,
  preferredLanguages,
  previewYouTubeInBrowser,
  readYouTubeInBrowser,
  youtubeBlockingReason,
  youtubeDurationLabel,
  type YouTubePreview,
} from "@/lib/import/youtube";

/**
 * **L'import s'arrête à l'aperçu.** On dépose, on voit le document ou la
 * vidéo, on règle, puis on écrit la fiche. Générer au moment du dépôt
 * brûlait un appel avant d'avoir rien relu.
 *
 * Le fichier est lu **dans l'onglet** : seul le texte extrait part au
 * modèle. YouTube suit le même chemin que l'iPhone : l'onglet d'abord
 * (l'IP n'est pas un datacenter), le serveur en repli.
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
}

export function ImportPanel({
  initialLength = DEFAULT_SHEET_LENGTH,
}: {
  initialLength?: SheetLength;
}) {
  const router = useRouter();
  const [extra, setExtra] = useState<Extra>(null);
  const [phase, setPhase] = useState<Phase>("repos");
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const [blocks, setBlocks] = useState(() => defaultBlocks(initialLength));
  const [visibility, setVisibility] = useState<CourseVisibility>(DEFAULT_VISIBILITY);
  const [language, setLanguage] = useState<GenerationLanguage>(SOURCE_LANGUAGE);

  const [text, setText] = useState("");
  const [title, setTitle] = useState("");
  const [url, setUrl] = useState("");
  const [fileName, setFileName] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const [draft, setDraft] = useState<Draft | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const busy = pending || phase === "lecture" || phase === "ecriture";
  const length = lengthContaining(blocks);
  const previewing = draft !== null;

  useEffect(() => {
    return () => {
      if (draft?.fileUrl) URL.revokeObjectURL(draft.fileUrl);
    };
  }, [draft?.fileUrl]);

  function finish(result: { status: string; courseId?: string; message?: string }) {
    setPhase(draft ? "apercu" : "repos");
    if (result.status === "ok" && result.courseId) {
      router.push(`/app/c/${result.courseId}` as never);
      return;
    }
    setFailure(result.message ?? "Ça n'a pas marché.");
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

  function generate(payload: Draft) {
    setFailure(null);
    setPhase("ecriture");
    startTransition(async () =>
      finish(
        await importFromText({
          text: payload.text,
          hintTitle: title.trim() || payload.title,
          sourceName: payload.sourceName,
          source: payload.source,
          blocks,
          length,
          visibility,
          language,
        }),
      ),
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
    const fromServer = remoteVideo(remote);
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
          : "La page de la vidéo n'a pas pu être lue.",
    );
  }

  async function generateVideo() {
    if (!draft || draft.source !== "youtube") return;
    const link = url.trim();
    setFailure(null);
    setPhase("lecture");

    const local = await readYouTubeInBrowser(link);
    if (local.status === "ok") {
      generate({ ...draft, text: local.text, title: local.title, sourceName: local.title });
      return;
    }

    const remote = await youtubeTranscript(link, preferredLanguages());
    if (remote.status === "ok") {
      generate({ ...draft, text: remote.text, title: remote.title, sourceName: remote.title });
      return;
    }

    setPhase("apercu");
    setFailure(remote.message ?? local.message);
  }

  async function handleFile(file: File) {
    setFailure(null);
    setFileName(file.name);
    setPhase("lecture");

    try {
      const extracted = await extractText(file);
      if (extracted.trim().length < 40) {
        setPhase("repos");
        setFailure(
          "Ce fichier ne contient pas de texte lisible. Un PDF fait de pages scannées n'a pas de texte à extraire - pour ceux-là, l'app iPhone les lit avec l'appareil photo.",
        );
        return;
      }

      const name = file.name.toLowerCase();
      const source: SourceKind = name.endsWith(".pdf")
        ? "pdf"
        : name.endsWith(".docx")
          ? "docx"
          : "text";

      showDraft({
        text: extracted,
        title: file.name.replace(/\.[^.]+$/, ""),
        sourceName: file.name,
        source,
        fileUrl: source === "pdf" ? URL.createObjectURL(file) : undefined,
      }, file.name);
    } catch (error) {
      setPhase("repos");
      setFailure(docxFailure(error));
    }
  }

  const videoBlocked = draft?.video ? youtubeBlockingReason(draft.video) : null;
  const canGenerate = previewing && (
    draft.source === "youtube"
      ? Boolean(draft.video && !videoBlocked)
      : draft.text.trim().length >= 40
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
            accept=".pdf,.txt,.md,.markdown,.docx"
            className="sr-only"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) void handleFile(file);
            }}
          />

          {phase === "lecture" ? (
            <Waiting phase={phase} name={fileName} />
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
                {dragging ? "Lâche-le ici." : "Dépose ton cours"}
              </p>
              <p className="mt-1 text-sm text-muted-foreground">PDF, Word ou texte.</p>

              <Button
                type="button"
                className="mt-5"
                onClick={() => fileInput.current?.click()}
              >
                Choisir un fichier
              </Button>

              <div className="mt-6 flex flex-wrap items-center justify-center gap-x-5 gap-y-2 text-[13.5px]">
                <button
                  type="button"
                  onClick={() => setExtra(extra === "coller" ? null : "coller")}
                  className="underline-draw font-medium text-ink-secondary"
                >
                  Coller du texte
                </button>
                <span aria-hidden className="text-ink-tertiary">
                  ·
                </span>
                <button
                  type="button"
                  onClick={() => setExtra(extra === "video" ? null : "video")}
                  className="underline-draw font-medium text-ink-secondary"
                >
                  Une vidéo YouTube
                </button>
              </div>
            </>
          )}
        </div>
      ) : null}

      {previewing && draft ? (
        <Preview
          draft={draft}
          title={title}
          blocked={videoBlocked}
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
            Titre, si tu veux
          </label>
          <input
            id="import-title"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="Micabo le devine sinon"
            disabled={busy}
            className="mt-2 h-11 w-full rounded-button bg-surface-muted px-4 text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
          />

          <label htmlFor="import-text" className="eyebrow mt-5 block text-ink-tertiary">
            Ton cours
          </label>
          <textarea
            id="import-text"
            value={text}
            onChange={(event) => setText(event.target.value)}
            placeholder="Colle ici tes notes, un chapitre, un polycopié…"
            rows={10}
            disabled={busy}
            className="mt-2 w-full resize-y rounded-button bg-surface-muted p-4 text-[15px] leading-relaxed text-ink outline-none placeholder:text-ink-tertiary"
          />

          <div className="mt-4 flex items-center justify-between gap-4">
            <p className="numeral text-[13px] text-ink-tertiary">
              {text.trim().length} caractère{text.trim().length > 1 ? "s" : ""}
            </p>
            <Button
              type="button"
              disabled={busy || text.trim().length < 40}
              onClick={() =>
                showDraft({
                  text,
                  title: title.trim() || "Notes collées",
                  source: "text",
                })
              }
            >
              Voir le texte
            </Button>
          </div>
        </div>
      ) : null}

      {extra === "video" && !previewing && phase !== "lecture" ? (
        <div className="mt-4 rounded-2xl border border-border bg-card p-5">
          <label htmlFor="import-url" className="eyebrow block text-ink-tertiary">
            Lien de la vidéo
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
          <p className="mt-2 text-[13px] text-ink-tertiary">Sous-titres requis · 90 min max.</p>

          <div className="mt-5 flex justify-end">
            <Button
              type="button"
              disabled={busy || !isYouTubeUrl(url)}
              onClick={() => void loadVideo(url.trim())}
            >
              Voir la vidéo
            </Button>
          </div>
        </div>
      ) : null}

      <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <div className="rounded-2xl border border-border bg-card p-5">
          <div className="flex items-baseline justify-between gap-3">
            <p className="eyebrow text-ink-tertiary">Longueur de la fiche</p>
            <p className="text-[13px] font-medium text-ink">
              {sheetLengthTitle(length)}{" "}
              <span className="text-ink-tertiary">· {readingHint(blocks)}</span>
            </p>
          </div>

          <input
            type="range"
            min={BLOCK_BOUNDS.min}
            max={BLOCK_BOUNDS.max}
            value={blocks}
            disabled={busy}
            aria-label="Longueur de la fiche, en blocs"
            onChange={(event) => setBlocks(clampBlocks(Number(event.target.value)))}
            className="mt-4 w-full accent-[var(--color-accent)]"
          />
          <p className="numeral mt-2 text-[12.5px] text-ink-tertiary">{blocks} blocs</p>
        </div>

        <div className="rounded-2xl border border-border bg-card p-5">
          <p className="eyebrow text-ink-tertiary">Langue de la fiche</p>
          <div className="mt-3.5">
            <LanguageChoices value={language} onChange={setLanguage} disabled={busy} />
          </div>
        </div>

        <div className="rounded-2xl border border-border bg-card p-5 sm:col-span-2 lg:col-span-1">
          <p className="eyebrow text-ink-tertiary">Qui peut la retrouver</p>
          <div className="mt-3.5">
            <VisibilityChoices value={visibility} onChange={setVisibility} disabled={busy} />
          </div>
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
              generate(draft);
            }}
          >
            {phase === "ecriture"
              ? "Micabo écrit la fiche…"
              : phase === "lecture"
                ? "Lecture des sous-titres…"
                : "Écrire la fiche"}
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
  draft,
  title,
  blocked,
  reading,
  writing,
  onChange,
}: {
  draft: Draft;
  title: string;
  blocked: string | null;
  reading: boolean;
  writing: boolean;
  onChange: () => void;
}) {
  if (reading || writing) {
    return (
      <div className="flex min-h-[200px] flex-col items-center justify-center rounded-2xl border border-border bg-card px-6 py-10">
        <Waiting phase={writing ? "ecriture" : "lecture"} name={draft.sourceName ?? title} />
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
                    ? `Sous-titres automatiques · ${draft.video.captions[0].name}`
                    : `Sous-titres · ${draft.video.captions[0].name}`
                  : null,
              ]
                .filter(Boolean)
                .join(" · ")}
            </p>
            {blocked ? (
              <p className="mt-3 text-[13.5px] leading-relaxed text-caution" role="status">
                {blocked}
              </p>
            ) : null}
          </div>
          <Button type="button" variant="ghost" onClick={onChange}>
            Changer
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-2xl border border-border bg-card">
      {draft.fileUrl ? (
        <iframe
          title={draft.sourceName ?? "Document importé"}
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
            {draft.sourceName ?? "Texte collé"}
            {" · "}
            {draft.text.trim().length} caractères
          </p>
        </div>
        <Button type="button" variant="ghost" onClick={onChange}>
          Changer
        </Button>
      </div>
    </div>
  );
}

function Waiting({ phase, name }: { phase: Phase; name: string | null }) {
  return (
    <div className="flex flex-col items-center gap-4">
      <ThinkingOrb state={phase === "lecture" ? "searching" : "composing"} size={64} />
      <div className="min-w-0 text-center">
        <p className="text-[16px] font-semibold text-ink">
          {phase === "lecture" ? "Micabo lit…" : "Micabo écrit la fiche…"}
        </p>
        <p className="mt-1 truncate text-[13px] text-ink-tertiary">
          {name ?? "Une dizaine de secondes, en général."}
        </p>
      </div>
    </div>
  );
}

async function extractText(file: File): Promise<string> {
  const name = file.name.toLowerCase();

  if (name.endsWith(".pdf")) {
    const pdfjs = await import("pdfjs-dist");
    pdfjs.GlobalWorkerOptions.workerSrc = new URL(
      "pdfjs-dist/build/pdf.worker.min.mjs",
      import.meta.url,
    ).toString();

    const document = await pdfjs.getDocument({ data: await file.arrayBuffer() }).promise;
    const pages: string[] = [];

    for (let index = 1; index <= document.numPages; index += 1) {
      const page = await document.getPage(index);
      const content = await page.getTextContent();
      pages.push(
        content.items
          .map((item) => ("str" in item ? item.str : ""))
          .join(" ")
          .replace(/\s+/g, " ")
          .trim(),
      );
    }

    return pages.filter(Boolean).join("\n\n");
  }

  if (name.endsWith(".docx")) {
    return extractDocxText(new Uint8Array(await file.arrayBuffer()));
  }

  if (name.endsWith(".doc")) {
    throw new DocxError("notDocx");
  }

  return file.text();
}

function remoteVideo(
  result: { status: string; video?: unknown; message?: string },
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
    title: typeof raw.title === "string" && raw.title.length > 0 ? raw.title : "Vidéo YouTube",
    author: typeof raw.author === "string" ? raw.author : "",
    thumbnailUrl: typeof raw.thumbnailUrl === "string"
      ? raw.thumbnailUrl
      : `https://i.ytimg.com/vi/${raw.id}/hqdefault.jpg`,
    durationSeconds: typeof raw.durationSeconds === "number" ? raw.durationSeconds : 0,
    captions,
    captionsKnown: raw.captionsKnown === true || captions.length > 0,
  };
}

function docxFailure(error: unknown): string {
  if (error instanceof DocxError) {
    if (error.code === "empty") return "Ce Word n'a presque pas de texte. Colle le contenu ici.";
    if (error.code === "missingDocument") return "Ce fichier Word n'a pas pu être lu.";
    if (error.code === "notDocx") {
      return "Enregistre le document en .docx - l'ancien format Word n'est pas lisible ici.";
    }
  }
  return "Ce fichier n'a pas pu être lu.";
}
