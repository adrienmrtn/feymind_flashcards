"use client";

import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import { importFromText, importFromYouTube } from "@/lib/actions/course";

/**
 * Les trois entrées d'un import, et **l'extraction du texte côté navigateur.**
 *
 * Un PDF est lu ici, dans l'onglet, et non envoyé quelque part : c'est exactement la règle de
 * l'app, où le texte n'est jamais confié à un OCR distant. Seul le **texte extrait** part au
 * modèle, ce qui est aussi ce qui rend la facture prévisible — un PDF de trente pages pèse des
 * mégaoctets, son texte quelques dizaines de kilo-octets.
 *
 * `thinking-orbs` porte les deux attentes, et le découpage n'est pas décoratif : `searching`
 * pendant qu'on extrait le texte du document, `composing` pendant que la fiche s'écrit. Ce sont
 * les deux vraies phases du travail, et les nommer vaut mieux qu'un tourniquet unique.
 */

type Mode = "coller" | "fichier" | "video";
type Phase = "repos" | "lecture" | "ecriture";

export function ImportPanel() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("coller");
  const [phase, setPhase] = useState<Phase>("repos");
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const [text, setText] = useState("");
  const [title, setTitle] = useState("");
  const [url, setUrl] = useState("");
  const [fileName, setFileName] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  const busy = pending || phase !== "repos";

  function finish(result: { status: string; courseId?: string; message?: string }) {
    setPhase("repos");
    if (result.status === "ok" && result.courseId) {
      router.push(`/app/c/${result.courseId}` as never);
      return;
    }
    setFailure(result.message ?? "Ça n'a pas marché.");
  }

  function submitText(payload: { text: string; hintTitle?: string; sourceName?: string; source?: "text" | "pdf" }) {
    setFailure(null);
    setPhase("ecriture");
    startTransition(async () => finish(await importFromText(payload)));
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
          "Ce fichier ne contient pas de texte lisible. Un PDF fait de pages scannées n'a pas de texte à extraire — pour ceux-là, l'app iPhone les lit avec l'appareil photo.",
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
            source: file.name.toLowerCase().endsWith(".pdf") ? "pdf" : "text",
          }),
        ),
      );
    } catch {
      setPhase("repos");
      setFailure("Ce fichier n'a pas pu être lu.");
    }
  }

  return (
    <div className="mt-9">
      <div className="flex gap-1.5" role="tablist" aria-label="Source du cours">
        {(
          [
            ["coller", "Coller du texte"],
            ["fichier", "Un fichier"],
            ["video", "Une vidéo"],
          ] as const
        ).map(([value, label]) => (
          <button
            key={value}
            type="button"
            role="tab"
            aria-selected={mode === value}
            disabled={busy}
            onClick={() => {
              setMode(value);
              setFailure(null);
            }}
            className={`pressable rounded-button px-4 py-2.5 text-[14px] font-medium transition-colors duration-hover ${
              mode === value ? "bg-ink text-on-ink" : "bg-surface text-ink-secondary paper"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      <div className="mt-5">
        {mode === "coller" ? (
          <div className="paper rounded-group bg-surface p-5">
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
              rows={12}
              disabled={busy}
              className="mt-2 w-full resize-y rounded-button bg-surface-muted p-4 text-[15px] leading-relaxed text-ink outline-none placeholder:text-ink-tertiary"
            />

            <div className="mt-4 flex items-center justify-between gap-4">
              <p className="numeral text-[13px] text-ink-tertiary">
                {text.trim().length} caractère{text.trim().length > 1 ? "s" : ""}
              </p>
              <Action
                busy={busy}
                phase={phase}
                enabled={text.trim().length >= 40}
                onPress={() =>
                  submitText({ text, hintTitle: title.trim() || undefined, source: "text" })
                }
              />
            </div>
          </div>
        ) : null}

        {mode === "fichier" ? (
          <div
            onDragOver={(event) => {
              event.preventDefault();
              setDragging(true);
            }}
            onDragLeave={() => setDragging(false)}
            onDrop={(event) => {
              event.preventDefault();
              setDragging(false);
              const file = event.dataTransfer.files[0];
              if (file) void handleFile(file);
            }}
            className={`rounded-group border-2 border-dashed p-12 text-center transition-colors duration-hover ${
              dragging ? "border-accent bg-accent-soft" : "border-stroke-strong bg-surface"
            }`}
          >
            <input
              ref={fileInput}
              type="file"
              accept=".pdf,.txt,.md,.docx"
              className="sr-only"
              onChange={(event) => {
                const file = event.target.files?.[0];
                if (file) void handleFile(file);
              }}
            />

            {phase === "repos" ? (
              <>
                <p className="text-[16px] font-semibold text-ink">
                  {dragging ? "Lâche-le ici." : "Dépose un PDF, un Word ou un fichier texte."}
                </p>
                <p className="mx-auto mt-2 max-w-[44ch] text-[13.5px] leading-relaxed text-ink-tertiary">
                  Le fichier est lu <strong className="font-semibold text-ink-secondary">dans cet
                  onglet</strong> : seul le texte qu&apos;on en extrait part au modèle.
                </p>
                <button
                  type="button"
                  onClick={() => fileInput.current?.click()}
                  className="pressable mt-6 rounded-button bg-ink px-5 py-3 text-[15px] font-semibold text-on-ink"
                >
                  Choisir un fichier
                </button>
              </>
            ) : (
              <Waiting phase={phase} name={fileName} />
            )}
          </div>
        ) : null}

        {mode === "video" ? (
          <div className="paper rounded-group bg-surface p-5">
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
              Micabo lit les sous-titres, pas l&apos;image. Une vidéo sans sous-titres n&apos;a rien
              à donner, et une vidéo de plus d&apos;une heure et demie est refusée.
            </p>

            <div className="mt-5 flex justify-end">
              <Action
                busy={busy}
                phase={phase}
                enabled={url.trim().length > 10}
                onPress={() => {
                  setFailure(null);
                  setPhase("lecture");
                  startTransition(async () => finish(await importFromYouTube(url.trim())));
                }}
              />
            </div>
          </div>
        ) : null}
      </div>

      {phase !== "repos" && mode !== "fichier" ? (
        <div className="paper mt-4 rounded-group bg-surface p-5">
          <Waiting phase={phase} name={null} />
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

function Action({
  busy,
  phase,
  enabled,
  onPress,
}: {
  busy: boolean;
  phase: Phase;
  enabled: boolean;
  onPress: () => void;
}) {
  return (
    <button
      type="button"
      disabled={busy || !enabled}
      onClick={onPress}
      className={`pressable flex items-center gap-2.5 rounded-button px-5 py-3 text-[15px] font-semibold transition-colors duration-hover ${
        busy || !enabled
          ? "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
          : "bg-ink text-on-ink"
      }`}
    >
      {phase === "repos" ? "Écrire la fiche" : "Micabo travaille"}
    </button>
  );
}

/**
 * L'attente, nommée.
 *
 * On ne dit pas « chargement » : on dit ce qui se passe. L'app va plus loin — elle montre la page
 * en train de se faire — et c'est ce qu'il faudra reprendre ici. En attendant, deux états nommés
 * valent mieux qu'un tourniquet muet, et l'orbe est monochrome donc elle ne se bat pas avec le vert.
 */
function Waiting({ phase, name }: { phase: Phase; name: string | null }) {
  return (
    <div className="flex items-center gap-4">
      <ThinkingOrb state={phase === "lecture" ? "searching" : "composing"} size={64} />
      <div className="min-w-0">
        <p className="text-[15.5px] font-semibold text-ink">
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
 * dit — c'est le cas où l'iPhone, avec son appareil photo et sa reconnaissance de texte, fait
 * mieux que le web.
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
    // Un `.docx` est un ZIP dont `word/document.xml` porte le texte. L'app le lit à la main, sans
    // dépendance ; ici la même idée demanderait un décompresseur, donc c'est remis à plus tard et
    // dit franchement plutôt que fait à moitié.
    throw new Error("docx");
  }

  return file.text();
}
