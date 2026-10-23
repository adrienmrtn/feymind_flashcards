"use client";

import { useEffect, useRef, useState } from "react";
import { Camera, FileText, Images, Mic, Square, Upload, X } from "lucide-react";

import { type ComposerSupport, type SupportKind } from "@micabo/core";

import { LessonPrimaryButton, LessonSecondaryButton } from "@/components/lesson/LessonButtons";
import { MicaboIcon } from "@/components/lesson/MicaboIcon";
import { SUPPORT_ICONS } from "@micabo/core";
import { useI18n } from "@/lib/i18n/client";
import { isYouTubeUrl } from "@/lib/import/youtube";
import { SupportError, readFileSupport, readPhotos, readYouTube, transcribeAudio } from "@/lib/lesson/read-support";

/**
 * **Déposer un support** : une feuille par icône. PDF (et Word, et texte) par fichier ; Photo
 * par l'appareil ou la photothèque ; Audio par un fichier ou un enregistrement en direct ;
 * YouTube par un lien ; Texte par un collage. La pastille apparaît tout de suite « en lecture »
 * dans la barre, et se remplit (ou échoue) quand la lecture est finie. Jumeau de
 * `LessonImportPickers.swift`.
 */
export function ImportSheet({
  kind,
  onClose,
  onBegin,
  onUpdate,
}: {
  kind: SupportKind;
  onClose: () => void;
  /** La pastille est posée dans la barre, « en lecture ». */
  onBegin: (support: ComposerSupport) => void;
  onUpdate: (id: string, patch: Partial<ComposerSupport>) => void;
}) {
  const { t, locale } = useI18n();

  useEffect(() => {
    function escape(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    document.addEventListener("keydown", escape);
    return () => document.removeEventListener("keydown", escape);
  }, [onClose]);

  function begin(title: string, job: () => Promise<{ text: string; images?: string[]; docKind?: "pdf" | "docx" | "text"; title?: string }>) {
    const id = crypto.randomUUID();
    onBegin({ id, kind, title, state: "reading", text: "", images: [] });
    job()
      .then((content) => {
        if (!content.text.trim() && !(content.images?.length)) throw new SupportError(t("lesson.import.unreadable"), "unreadable");
        onUpdate(id, { state: "ready", text: content.text, images: content.images ?? [], docKind: content.docKind, title: content.title ?? title });
      })
      .catch((error: unknown) => {
        const message = error instanceof SupportError && error.code !== "unreadable" && error.code !== "too_short" ? error.message : t("lesson.import.unreadable");
        onUpdate(id, { state: "failed", failure: message });
      });
  }

  const title = t(`lesson.import.${kind}`);
  const subtitle = t(`lesson.import.${kind}Sub`);

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 p-0 sm:items-center sm:p-6" role="dialog" aria-modal="true" aria-label={title} onClick={onClose}>
      <div className="score-in flex w-full max-w-[520px] flex-col gap-5 rounded-t-[28px] bg-canvas p-5 pb-[max(1.25rem,env(safe-area-inset-bottom))] sm:rounded-[28px]" onClick={(event) => event.stopPropagation()}>
        <div className="flex items-center gap-3">
          <MicaboIcon id={SUPPORT_ICONS[kind]} size={44} />
          <div className="flex min-w-0 flex-1 flex-col">
            <h2 className="text-[20px] font-extrabold leading-tight text-ink">{title}</h2>
            <p className="text-[14px] font-medium text-ink-secondary">{subtitle}</p>
          </div>
          <button type="button" onClick={onClose} aria-label={t("lesson.circle.close")} className="pressable flex size-9 items-center justify-center rounded-full text-ink-secondary hover:bg-surface-muted">
            <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
          </button>
        </div>

        {kind === "pdf" ? <FileBody onPick={(file) => begin(file.name, () => readFileSupport(file))} /> : null}
        {kind === "photo" ? <PhotoBody onPick={(files) => begin(files.length === 1 ? files[0]!.name : `${t("lesson.import.photo")} · ${files.length}`, () => readPhotos(files))} /> : null}
        {kind === "audio" ? <AudioBody onPick={(blob, name) => begin(name, () => transcribeAudio(blob, locale))} /> : null}
        {kind === "youtube" ? (
          <LinkBody
            onPick={(url) =>
              begin(url, async () => {
                const video = await readYouTube(url);
                return { text: video.text, images: [], title: video.title };
              })
            }
          />
        ) : null}
        {kind === "text" ? <TextBody onPick={(text) => begin(t("lesson.import.pastedName"), async () => ({ text, images: [], docKind: "text" as const }))} /> : null}
      </div>
    </div>
  );
}

function DropZone({ accept, multiple, capture, icon: Icon, label, onFiles }: { accept: string; multiple?: boolean; capture?: "environment"; icon: typeof Upload; label: string; onFiles: (files: File[]) => void }) {
  const input = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  return (
    <button
      type="button"
      onClick={() => input.current?.click()}
      onDragOver={(event) => {
        event.preventDefault();
        setDragging(true);
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(event) => {
        event.preventDefault();
        setDragging(false);
        const files = [...event.dataTransfer.files];
        if (files.length > 0) onFiles(multiple ? files : files.slice(0, 1));
      }}
      className={`pressable flex w-full flex-col items-center gap-2 rounded-[20px] border-2 border-dashed px-4 py-7 text-center ${dragging ? "border-accent bg-accent-soft" : "border-stroke-strong bg-surface"}`}
    >
      <Icon aria-hidden="true" className="size-7 text-ink-secondary" strokeWidth={2.2} />
      <span className="text-[16px] font-bold text-ink">{label}</span>
      <input
        ref={input}
        type="file"
        accept={accept}
        multiple={multiple}
        capture={capture}
        className="sr-only"
        onChange={(event) => {
          const files = [...(event.target.files ?? [])];
          event.target.value = "";
          if (files.length > 0) onFiles(files);
        }}
      />
    </button>
  );
}

function FileBody({ onPick }: { onPick: (file: File) => void }) {
  const { t } = useI18n();
  return <DropZone accept=".pdf,.docx,.txt,.md,application/pdf,text/plain" icon={FileText} label={t("lesson.import.pdfSub")} onFiles={(files) => onPick(files[0]!)} />;
}

function PhotoBody({ onPick }: { onPick: (files: File[]) => void }) {
  const { t } = useI18n();
  return (
    <div className="flex flex-col gap-3">
      <DropZone accept="image/*" multiple capture="environment" icon={Camera} label={t("lesson.import.scan")} onFiles={onPick} />
      <DropZone accept="image/*" multiple icon={Images} label={t("lesson.import.library")} onFiles={onPick} />
    </div>
  );
}

const MAX_RECORDING_SECONDS = 90 * 60;

/** Un fichier audio, ou un enregistrement en direct : `MediaRecorder`, dans le format que le navigateur sait écrire. */
function AudioBody({ onPick }: { onPick: (blob: Blob, name: string) => void }) {
  const { t } = useI18n();
  const [recording, setRecording] = useState(false);
  const [seconds, setSeconds] = useState(0);
  const [denied, setDenied] = useState(false);
  const recorder = useRef<MediaRecorder | null>(null);
  const chunks = useRef<Blob[]>([]);
  const timer = useRef<number | null>(null);

  useEffect(() => {
    return () => {
      if (timer.current) window.clearInterval(timer.current);
      recorder.current?.stream.getTracks().forEach((track) => track.stop());
    };
  }, []);

  async function start() {
    setDenied(false);
    let stream: MediaStream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch {
      setDenied(true);
      return;
    }
    const type = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4", "audio/ogg"].find((candidate) => MediaRecorder.isTypeSupported(candidate));
    const media = new MediaRecorder(stream, type ? { mimeType: type } : undefined);
    chunks.current = [];
    media.ondataavailable = (event) => {
      if (event.data.size > 0) chunks.current.push(event.data);
    };
    media.onstop = () => {
      stream.getTracks().forEach((track) => track.stop());
      const blob = new Blob(chunks.current, { type: media.mimeType || "audio/webm" });
      if (blob.size > 0) onPick(blob, t("lesson.import.recordingName"));
    };
    recorder.current = media;
    media.start(1000);
    setRecording(true);
    setSeconds(0);
    timer.current = window.setInterval(() => {
      setSeconds((value) => {
        if (value + 1 >= MAX_RECORDING_SECONDS) stop();
        return value + 1;
      });
    }, 1000);
  }

  function stop() {
    if (timer.current) window.clearInterval(timer.current);
    timer.current = null;
    setRecording(false);
    if (recorder.current?.state !== "inactive") recorder.current?.stop();
  }

  const clock = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-col items-center gap-3 rounded-[20px] bg-surface px-4 py-6 text-center shadow-[inset_0_0_0_1px_var(--color-stroke)]">
        <p className="text-[16px] font-bold text-ink">{t("lesson.import.recordTitle")}</p>
        <p className="text-[13px] font-medium text-ink-secondary">{t("lesson.import.recordLimit")}</p>
        {recording ? <p className="numeral text-[28px] font-extrabold text-wrong-ink">{clock}</p> : null}
        {denied ? <p className="text-[13px] font-bold text-wrong-ink">{t("lesson.audio.micDenied")}</p> : null}
        {recording ? (
          <LessonSecondaryButton onClick={stop}>
            <Square aria-hidden="true" className="size-4 fill-current text-wrong" />
            {t("lesson.import.recordStop")}
          </LessonSecondaryButton>
        ) : (
          <LessonPrimaryButton onClick={() => void start()}>
            <Mic aria-hidden="true" className="size-5" strokeWidth={2.4} />
            {t("lesson.import.record")}
          </LessonPrimaryButton>
        )}
      </div>
      <DropZone accept="audio/*,.m4a,.mp3,.wav,.ogg,.webm" icon={Upload} label={t("lesson.import.audioFile")} onFiles={(files) => onPick(files[0]!, files[0]!.name)} />
    </div>
  );
}

function LinkBody({ onPick }: { onPick: (url: string) => void }) {
  const { t } = useI18n();
  const [url, setUrl] = useState("");
  const valid = isYouTubeUrl(url.trim());
  return (
    <form
      className="flex flex-col gap-3"
      onSubmit={(event) => {
        event.preventDefault();
        if (valid) onPick(url.trim());
      }}
    >
      <label className="flex flex-col gap-2">
        <span className="text-[15px] font-bold text-ink">{t("lesson.import.youtubeTitle")}</span>
        <input
          type="url"
          inputMode="url"
          autoFocus
          value={url}
          onChange={(event) => setUrl(event.target.value)}
          placeholder={t("lesson.import.youtubePlaceholder")}
          className="rounded-[16px] bg-surface px-4 py-3 text-[16px] font-medium text-ink shadow-[inset_0_0_0_1px_var(--color-stroke)] outline-none focus-visible:shadow-[inset_0_0_0_2px_var(--color-accent)]"
        />
      </label>
      <LessonPrimaryButton type="submit" disabled={!valid}>
        {t("lesson.import.add")}
      </LessonPrimaryButton>
    </form>
  );
}

function TextBody({ onPick }: { onPick: (text: string) => void }) {
  const { t } = useI18n();
  const [text, setText] = useState("");
  const valid = text.trim().length >= 40;
  return (
    <form
      className="flex flex-col gap-3"
      onSubmit={(event) => {
        event.preventDefault();
        if (valid) onPick(text.trim());
      }}
    >
      <label className="flex flex-col gap-2">
        <span className="text-[15px] font-bold text-ink">{t("lesson.import.textTitle")}</span>
        <textarea
          autoFocus
          value={text}
          onChange={(event) => setText(event.target.value)}
          rows={8}
          maxLength={60_000}
          placeholder={t("lesson.import.textPlaceholder")}
          className="resize-y rounded-[16px] bg-surface px-4 py-3 text-[16px] font-medium leading-snug text-ink shadow-[inset_0_0_0_1px_var(--color-stroke)] outline-none focus-visible:shadow-[inset_0_0_0_2px_var(--color-accent)]"
        />
      </label>
      <LessonPrimaryButton type="submit" disabled={!valid}>
        {t("lesson.import.add")}
      </LessonPrimaryButton>
    </form>
  );
}
