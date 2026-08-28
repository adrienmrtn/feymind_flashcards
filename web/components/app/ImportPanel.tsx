"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import {
  BLOCK_BOUNDS,
  DEFAULT_SHEET_LENGTH,
  clampBlocks,
  defaultBlocks,
  lengthContaining,
  readingHint,
  sheetLengthTitle,
  type CourseVisibility,
  type SheetLength,
} from "@micabo/core";

import { VisibilityChoices } from "@/components/app/VisibilityChoices";
import { importFromText, importFromYouTube } from "@/lib/actions/course";
import { DocxError, extractDocxText } from "@/lib/import/docx";
import { readYouTubeInBrowser } from "@/lib/import/youtube";

/**
 * **L'import est une zone de dépôt.** C'est ce qu'on fait devant un clavier : on prend le fichier
 * et on le lâche. Trois onglets de même poids obligeaient à choisir une source avant d'avoir rien
 * fait, et le premier était un formulaire de texte - le geste le plus rare, mis en premier.
 *
 * Coller du texte et donner une vidéo restent, en **second rang** : ce sont des cas, pas la voie
 * normale. Ils s'ouvrent sous la zone quand on les demande.
 *
 * Le fichier est lu **dans l'onglet** et non envoyé quelque part : c'est la règle de l'app, où le
 * texte n'est jamais confié à un OCR distant. Seul le texte extrait part au modèle, ce qui rend
 * aussi la facture prévisible - un PDF de trente pages pèse des mégaoctets, son texte quelques
 * dizaines de kilo-octets.
 *
 * Les deux réglages du cours sont ceux de l'app, et ils sortent du **noyau partagé** : la longueur
 * en blocs et la visibilité. Le choix de visibilité se fait ici et pas après - un cours qui part
 * public le temps qu'on y pense est un cours qui a été visible.
 */

type Extra = null | "coller" | "video";
type Phase = "repos" | "lecture" | "ecriture";

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
  const [visibility, setVisibility] = useState<CourseVisibility>("public");

  const [text, setText] = useState("");
  const [title, setTitle] = useState("");
  const [url, setUrl] = useState("");
  const [fileName, setFileName] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  const busy = pending || phase !== "repos";
  const length = lengthContaining(blocks);

  function finish(result: { status: string; courseId?: string; message?: string }) {
    setPhase("repos");
    if (result.status === "ok" && result.courseId) {
      router.push(`/app/c/${result.courseId}` as never);
      return;
    }
    setFailure(result.message ?? "Ça n'a pas marché.");
  }

  function submitText(payload: {
    text: string;
    hintTitle?: string;
    sourceName?: string;
    source?: "text" | "pdf";
  }) {
    setFailure(null);
    setPhase("ecriture");
    startTransition(async () =>
      finish(await importFromText({ ...payload, blocks, length, visibility })),
    );
  }

  /**
   * L'onglet d'abord : YouTube bloque les IP de datacenter, pas celle
   * de l'utilisateur. Le serveur ne sert que de repli.
   */
  async function importVideo() {
    const link = url.trim();
    const local = await readYouTubeInBrowser(link);
    if (local.status === "ok") {
      setPhase("ecriture");
      return importFromText({
        text: local.text,
        hintTitle: local.title,
        sourceName: local.title,
        source: "youtube",
        blocks,
        length,
        visibility,
      });
    }

    const remote = await importFromYouTube(link, { blocks, length, visibility });
    if (remote.status === "ok") return remote;
    return {
      status: "error" as const,
      message: remote.message ?? local.message,
    };
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
      setPhase("ecriture");
      startTransition(async () =>
        finish(
          await importFromText({
            text: extracted,
            hintTitle: file.name.replace(/\.[^.]+$/, ""),
            sourceName: file.name,
            source: file.name.toLowerCase().endsWith(".pdf")
              ? "pdf"
              : file.name.toLowerCase().endsWith(".docx")
                ? "docx"
                : "text",
            blocks,
            length,
            visibility,
          }),
        ),
      );
    } catch (error) {
      setPhase("repos");
      setFailure(docxFailure(error));
    }
  }

  return (
    <div className="mt-8">
      {/* La zone, et rien d'autre au premier rang. */}
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
        className={`flex min-h-[280px] flex-col items-center justify-center rounded-sheet border-2 border-dashed px-6 py-12 text-center transition-colors duration-hover ${
          dragging ? "border-ink bg-surface-muted" : "border-stroke-strong bg-surface"
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

        {phase === "repos" ? (
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

            <p className="mt-5 text-[19px] font-semibold text-ink">
              {dragging ? "Lâche-le ici." : "Dépose ton cours"}
            </p>
            <p className="mx-auto mt-2 max-w-[46ch] text-[13.5px] leading-relaxed text-ink-tertiary">
              PDF, Word, texte. Le fichier est lu{" "}
              <strong className="font-semibold text-ink-secondary">dans cet onglet</strong> : seul
              le texte qu&apos;on en extrait part au modèle.
            </p>

            <button
              type="button"
              onClick={() => fileInput.current?.click()}
              className="pressable mt-7 rounded-button bg-ink px-6 py-3.5 text-[15px] font-semibold text-on-ink"
            >
              Choisir un fichier
            </button>

            {/* Les deux autres voies, au second rang : ce sont des cas. */}
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
        ) : (
          <Waiting phase={phase} name={fileName} />
        )}
      </div>

      {extra === "coller" && phase === "repos" ? (
        <div className="paper rise mt-4 rounded-group bg-surface p-5">
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
            <Action
              busy={busy}
              enabled={text.trim().length >= 40}
              onPress={() =>
                submitText({ text, hintTitle: title.trim() || undefined, source: "text" })
              }
            />
          </div>
        </div>
      ) : null}

      {extra === "video" && phase === "repos" ? (
        <div className="paper rise mt-4 rounded-group bg-surface p-5">
          <label htmlFor="import-url" className="eyebrow block text-ink-tertiary">
            Lien de la vidéo
          </label>
          <input
            id="import-url"
            value={url}
            onChange={(event) => setUrl(event.target.value)}
            placeholder="https://www.youtube.com/watch?v=…"
            disabled={busy}
            className="mt-2 h-12 w-full rounded-button bg-surface-muted px-4 text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
          />
          <p className="mt-3 text-[13px] leading-relaxed text-ink-tertiary">
            Micabo lit les sous-titres, pas l&apos;image. Une vidéo sans sous-titres n&apos;a rien à
            donner, et une vidéo de plus d&apos;une heure et demie est refusée.
          </p>

          <div className="mt-5 flex justify-end">
            <Action
              busy={busy}
              enabled={url.trim().length > 10}
              onPress={() => {
                setFailure(null);
                setPhase("lecture");
                startTransition(async () => finish(await importVideo()));
              }}
            />
          </div>
        </div>
      ) : null}

      {/* Les réglages du cours, sous la zone : ils valent pour la voie qu'on prendra. */}
      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        <div className="paper rounded-group bg-surface p-5">
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

        <div className="paper rounded-group bg-surface p-5">
          <p className="eyebrow text-ink-tertiary">Qui peut la retrouver</p>
          <div className="mt-3.5">
            <VisibilityChoices value={visibility} onChange={setVisibility} disabled={busy} />
          </div>
        </div>
      </div>

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

function Action({
  busy,
  enabled,
  onPress,
}: {
  busy: boolean;
  enabled: boolean;
  onPress: () => void;
}) {
  return (
    <button
      type="button"
      disabled={busy || !enabled}
      onClick={onPress}
      className={`pressable rounded-button px-5 py-3 text-[15px] font-semibold transition-colors duration-hover ${
        busy || !enabled
          ? "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
          : "bg-ink text-on-ink"
      }`}
    >
      {busy ? "Micabo travaille" : "Écrire la fiche"}
    </button>
  );
}

/**
 * L'attente, nommée.
 *
 * On ne dit pas « chargement » : on dit ce qui se passe. `searching` pendant qu'on extrait le
 * texte, `composing` pendant que la fiche s'écrit - ce sont les deux vraies phases du travail, et
 * les nommer vaut mieux qu'un tourniquet unique.
 */
function Waiting({ phase, name }: { phase: Phase; name: string | null }) {
  return (
    <div className="flex flex-col items-center gap-4">
      <ThinkingOrb state={phase === "lecture" ? "searching" : "composing"} size={64} />
      <div className="min-w-0 text-center">
        <p className="text-[16px] font-semibold text-ink">
          {phase === "lecture" ? "Micabo lit ton document…" : "Micabo écrit la fiche…"}
        </p>
        <p className="mt-1 truncate text-[13px] text-ink-tertiary">
          {name ?? "Une dizaine de secondes, en général."}
        </p>
      </div>
    </div>
  );
}

/**
 * L'extraction du texte, dans le navigateur.
 *
 * Le texte brut et le markdown sont immédiats. Le **PDF** passe par `pdfjs-dist`, chargé
 * paresseusement : la bibliothèque pèse plus lourd que le reste de la page, et la plupart des
 * imports ne sont pas des PDF. Un PDF fait de pages scannées n'a pas de texte à extraire, et on le
 * dit - c'est le cas où l'iPhone, avec son appareil photo et sa reconnaissance de texte, fait mieux
 * que le web.
 */
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
