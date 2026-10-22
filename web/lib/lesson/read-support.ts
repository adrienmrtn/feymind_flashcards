"use client";

import { youtubeTranscript } from "@/lib/actions/course";
import { readDocument, type ReadDocument } from "@/lib/import/read-document";
import { preferredLanguages, readYouTubeInBrowser } from "@/lib/import/youtube";
import { createClient } from "@/lib/supabase/client";

/**
 * **Lire un support dans l'onglet**, avant d'envoyer : un PDF, un Word ou un texte par
 * `readDocument` (pdf.js, les pages en image pour un scan), des photos recadrées en JPEG, un
 * enregistrement transcrit par `transcribe-audio`, une vidéo YouTube par ses sous-titres. Ce
 * qui en sort est ce que la barre de Home assemble (`composeCreation`).
 */

export interface SupportContent {
  text: string;
  images: string[];
  docKind?: "pdf" | "docx" | "text";
}

export class SupportError extends Error {
  readonly code: string | undefined;
  constructor(message: string, code?: string) {
    super(message);
    this.code = code;
  }
}

export async function readFileSupport(file: File): Promise<SupportContent> {
  const document: ReadDocument = await readDocument(file);
  return { text: document.text, images: document.images, docKind: document.kind };
}

const PHOTO_SIDE = 1_600;
const PHOTO_QUALITY = 0.82;

/** Une photo, recadrée à 1 600 pixels de côté au plus, en JPEG : ce que le modèle regarde. */
export async function readPhoto(file: File): Promise<string> {
  const bitmap = await createImageBitmap(file).catch(() => null);
  if (!bitmap) throw new SupportError("unreadable", "unreadable");
  const scale = Math.min(1, PHOTO_SIDE / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(bitmap.width * scale));
  canvas.height = Math.max(1, Math.round(bitmap.height * scale));
  const context = canvas.getContext("2d");
  if (!context) throw new SupportError("unreadable", "unreadable");
  context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close();
  return canvas.toDataURL("image/jpeg", PHOTO_QUALITY);
}

export async function readPhotos(files: readonly File[]): Promise<SupportContent> {
  const images: string[] = [];
  for (const file of files.slice(0, 6)) images.push(await readPhoto(file));
  return { text: "", images };
}

function toBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result ?? "");
      resolve(result.slice(result.indexOf(",") + 1));
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}

/** Le type que le serveur lit, sans les paramètres de codec. */
export function audioMimeType(blob: Blob): string {
  const base = (blob.type || "audio/mp4").split(";")[0]!.trim().toLowerCase();
  return base.startsWith("audio/") || base.startsWith("video/") ? base.replace("video/", "audio/") : "audio/mp4";
}

/**
 * Un enregistrement, mis en texte par `transcribe-audio`. L'appel part du navigateur, avec le
 * jeton de l'élève : un fichier d'une heure ne passe pas par le site, et la fonction tient
 * elle-même la porte (Pro) et le plafond.
 */
export async function transcribeAudio(blob: Blob, language: string): Promise<SupportContent> {
  const supabase = createClient();
  const { data, error } = await supabase.functions.invoke("transcribe-audio", {
    body: { audio: await toBase64(blob), mimeType: audioMimeType(blob), language },
  });
  if (error) {
    const context = (error as { context?: Response }).context;
    let message = error instanceof Error ? error.message : "error";
    let code: string | undefined;
    if (context && typeof context.json === "function") {
      try {
        const body = (await context.json()) as { error?: string; code?: string };
        if (body.error) message = body.error;
        code = body.code;
      } catch {
        // Un corps illisible : le message du transport.
      }
    }
    throw new SupportError(message, code);
  }
  const text = (data as { transcript?: { text?: string } } | null)?.transcript?.text ?? "";
  if (!text.trim()) throw new SupportError("empty", "too_short");
  return { text, images: [] };
}

export async function readYouTube(url: string): Promise<SupportContent & { title: string }> {
  const local = await readYouTubeInBrowser(url);
  if (local.status === "ok") return { text: local.text, images: [], title: local.title };
  const remote = await youtubeTranscript(url, preferredLanguages());
  if (remote.status === "ok") return { text: remote.text, images: [], title: remote.title };
  throw new SupportError(remote.message ?? "unreadable", "unreadable");
}
