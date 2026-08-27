"use client";

import { useEffect, useId, useRef, useState, useTransition } from "react";

import { createOcclusionCards } from "@/lib/actions/cards";

/**
 * Création de cartes à occlusion, comme `OcclusionEditorSheet` sur iOS.
 *
 * On choisit un schéma, on trace les zones au pointeur, on nomme chacune, et
 * Micabo en fait une carte par zone. C'est le format des matières qui
 * s'apprennent sur une image - anatomie, géographie, géologie.
 */

interface Zone {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  label: string;
}

interface Draft {
  originX: number;
  originY: number;
  x: number;
  y: number;
  width: number;
  height: number;
}

export function OcclusionEditor({
  courseId,
  onDone,
}: {
  courseId: string;
  onDone: () => void;
}) {
  const pickerId = useId();
  const surface = useRef<HTMLDivElement>(null);
  const [image, setImage] = useState<string | null>(null);
  const [zones, setZones] = useState<Zone[]>([]);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const named = zones.filter((zone) => zone.label.trim().length > 0);
  const canSave = Boolean(image) && named.length > 0;

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") onDone();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onDone]);

  async function pick(file: File | undefined) {
    if (!file) return;
    setFailure(null);
    try {
      const prepared = await prepareImage(file);
      setImage(prepared);
      setZones([]);
      setDraft(null);
    } catch {
      setFailure("Cette image n'a pas pu être lue.");
    }
  }

  function pointInImage(event: React.PointerEvent<HTMLDivElement>) {
    const box = event.currentTarget.getBoundingClientRect();
    if (box.width <= 0 || box.height <= 0) return { x: 0, y: 0 };
    return {
      x: clamp((event.clientX - box.left) / box.width),
      y: clamp((event.clientY - box.top) / box.height),
    };
  }

  function onPointerDown(event: React.PointerEvent<HTMLDivElement>) {
    if (event.button !== 0) return;
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    const point = pointInImage(event);
    setDraft({
      originX: point.x,
      originY: point.y,
      x: point.x,
      y: point.y,
      width: 0,
      height: 0,
    });
  }

  function onPointerMove(event: React.PointerEvent<HTMLDivElement>) {
    if (!draft) return;
    const point = pointInImage(event);
    setDraft({
      ...draft,
      x: Math.min(draft.originX, point.x),
      y: Math.min(draft.originY, point.y),
      width: Math.abs(point.x - draft.originX),
      height: Math.abs(point.y - draft.originY),
    });
  }

  function onPointerUp() {
    if (!draft) return;
    if (draft.width > 0.02 && draft.height > 0.02) {
      setZones((current) => [
        ...current,
        {
          id: crypto.randomUUID(),
          x: draft.x,
          y: draft.y,
          width: draft.width,
          height: draft.height,
          label: "",
        },
      ]);
    }
    setDraft(null);
  }

  function save() {
    if (!image || !canSave) return;
    setFailure(null);
    startTransition(async () => {
      const result = await createOcclusionCards({
        courseId,
        image,
        zones: named,
      });
      if (result.status === "error") setFailure(result.message ?? "Ça n'a pas marché.");
      else onDone();
    });
  }

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-ink/35 p-4 sm:items-center">
      <button type="button" className="absolute inset-0" aria-label="Fermer" onClick={onDone} />
      <div
        ref={surface}
        className="relative max-h-[92svh] w-full max-w-[640px] overflow-y-auto rounded-sheet bg-canvas p-6 shadow-floating"
      >
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="eyebrow text-ink-tertiary">Schéma</p>
            <h2 className="mt-1 text-[22px] font-bold text-ink">Masquer un schéma</h2>
          </div>
          <button
            type="button"
            onClick={onDone}
            className="pressable text-[18px] text-ink-tertiary"
            aria-label="Fermer"
          >
            ✕
          </button>
        </div>

        {image ? (
          <>
            <p className="eyebrow mt-6 text-ink-tertiary">Trace les zones</p>
            <div
              className="relative mt-2 select-none overflow-hidden rounded-md bg-surface paper touch-none"
              onPointerDown={onPointerDown}
              onPointerMove={onPointerMove}
              onPointerUp={onPointerUp}
              onPointerCancel={() => setDraft(null)}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={image} alt="" className="block w-full" draggable={false} />
              {zones.map((zone, index) => (
                <ZoneBox key={zone.id} zone={zone} index={index + 1} draft={false} />
              ))}
              {draft ? <ZoneBox zone={draft} index={zones.length + 1} draft /> : null}
            </div>
            <p className="mt-2 text-[12.5px] leading-relaxed text-ink-tertiary">
              Glisse sur l&apos;image pour dessiner un cache. Une zone par notion : chacune
              devient une carte.
            </p>

            <label className="mt-3 inline-flex cursor-pointer text-[13.5px] text-ink-secondary underline-draw">
              Changer l&apos;image
              <input
                type="file"
                accept="image/*"
                className="sr-only"
                onChange={(event) => void pick(event.target.files?.[0])}
              />
            </label>

            {zones.length === 0 ? (
              <p className="mt-5 text-[13px] text-ink-tertiary">Aucune zone pour l&apos;instant.</p>
            ) : (
              <div className="mt-5">
                <p className="eyebrow text-ink-tertiary">Nomme chaque zone</p>
                <div className="paper mt-2 overflow-hidden rounded-group bg-surface">
                  {zones.map((zone, index) => (
                    <div
                      key={zone.id}
                      className={`flex items-center gap-3 px-4 py-3 ${
                        index > 0 ? "border-t border-hairline" : ""
                      }`}
                    >
                      <span
                        aria-hidden
                        className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-accent text-[12px] font-bold text-on-ink"
                      >
                        {index + 1}
                      </span>
                      <input
                        value={zone.label}
                        onChange={(event) => {
                          const label = event.target.value;
                          setZones((current) =>
                            current.map((item) =>
                              item.id === zone.id ? { ...item, label } : item,
                            ),
                          );
                        }}
                        placeholder="Nom de la zone"
                        className="h-10 min-w-0 flex-1 rounded-button bg-canvas px-3 text-[14px] text-ink outline-none"
                      />
                      <button
                        type="button"
                        aria-label={`Retirer la zone ${index + 1}`}
                        onClick={() =>
                          setZones((current) => current.filter((item) => item.id !== zone.id))
                        }
                        className="pressable px-1.5 text-[13px] text-ink-tertiary"
                      >
                        ✕
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        ) : (
          <label
            htmlFor={pickerId}
            className="mt-6 flex min-h-[220px] cursor-pointer flex-col items-center justify-center rounded-group border-2 border-dashed border-stroke-strong bg-surface px-6 py-12 text-center"
          >
            <span className="flex h-12 w-12 items-center justify-center rounded-tile bg-accent-soft text-[20px] text-accent">
              +
            </span>
            <span className="mt-3 text-[16px] font-semibold text-ink">Choisir une image</span>
            <span className="mt-1 text-[13px] text-ink-tertiary">Depuis tes fichiers</span>
            <input
              id={pickerId}
              type="file"
              accept="image/*"
              className="sr-only"
              onChange={(event) => void pick(event.target.files?.[0])}
            />
          </label>
        )}

        <div className="mt-6 flex flex-wrap items-center gap-2">
          <button
            type="button"
            disabled={!canSave || pending}
            onClick={save}
            className={`pressable rounded-button px-4 py-2.5 text-[14px] font-semibold ${
              canSave && !pending
                ? "bg-ink text-on-ink"
                : "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
            }`}
          >
            {pending ? "…" : "Créer les cartes"}
          </button>
          <button
            type="button"
            onClick={onDone}
            className="pressable rounded-button px-3 py-2.5 text-[14px] text-ink-secondary"
          >
            Annuler
          </button>
        </div>

        {failure ? (
          <p className="mt-3 text-[13px] text-negative" role="alert">
            {failure}
          </p>
        ) : null}
      </div>
    </div>
  );
}

function ZoneBox({
  zone,
  index,
  draft,
}: {
  zone: { x: number; y: number; width: number; height: number };
  index: number;
  draft: boolean;
}) {
  return (
    <div
      className={`pointer-events-none absolute flex items-center justify-center rounded-[6px] text-[12px] font-bold text-on-ink ${
        draft ? "bg-accent/45" : "bg-accent/85"
      }`}
      style={{
        left: `${zone.x * 100}%`,
        top: `${zone.y * 100}%`,
        width: `${zone.width * 100}%`,
        height: `${zone.height * 100}%`,
      }}
    >
      {index}
    </div>
  );
}

function clamp(value: number): number {
  return Math.min(1, Math.max(0, value));
}

/** Un schéma de carte n'a pas besoin de 12 Mpx : on réduit avant d'envoyer. */
async function prepareImage(file: File): Promise<string> {
  const url = URL.createObjectURL(file);
  try {
    const image = await loadImage(url);
    const max = 1_200;
    const scale = Math.min(1, max / Math.max(image.width, image.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(image.width * scale));
    canvas.height = Math.max(1, Math.round(image.height * scale));
    const context = canvas.getContext("2d");
    if (!context) throw new Error("canvas");
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL("image/jpeg", 0.72);
  } finally {
    URL.revokeObjectURL(url);
  }
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("image"));
    image.src = src;
  });
}
