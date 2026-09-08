"use client";

import { useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import { DEFAULT_VISIBILITY, type CourseVisibility } from "@micabo/core";

import { VisibilityChoices } from "@/components/app/VisibilityChoices";
import { Button } from "@/components/ui/button";
import { addDeckCards, createDeck } from "@/lib/actions/decks";
import { DECK_CHUNK } from "@/lib/deck";
import {
  ANKI_CARD_LIMIT,
  AnkiError,
  isAnkiFileName,
  readAnkiPackage,
  readAnkiTextExport,
  type AnkiCard,
  type AnkiPackage,
} from "@/lib/import/anki";
import { useI18n } from "@/lib/i18n/client";
import type { Translator } from "@/lib/i18n/copy";
import { requestPaywall } from "@/lib/paywall";

/**
 * Ouvrir un **paquet** : des cartes, sans cours.
 *
 * L'écran d'import demande un document et rend une fiche. Celui-ci ne demande rien et rend
 * des cartes, parce que la moitié de ce qu'on révise n'a pas de cours à ficher : du
 * vocabulaire, des dates, des déclinaisons, une liste de médicaments. C'est l'écran que
 * l'iPhone a depuis longtemps (`CreateDeckView`), et qui manquait ici.
 *
 * Deux départs, une seule arrivée - l'atelier des cartes :
 *
 * 1. **Un fichier Anki.** Les cartes arrivent telles qu'elles sont écrites, sans passer par
 *    le modèle. C'est le seul chemin du produit qui ne dépense rien : on reprend un travail
 *    déjà fait, il n'y a rien à rédiger.
 * 2. **Rien.** Le paquet démarre nu et se remplit à la main, carte par carte.
 *
 * Le fichier est lu **dans l'onglet**, comme un PDF ou un Word : le serveur reçoit des
 * cartes, jamais l'archive. Elles y partent ensuite par paquets de deux cents, parce que
 * mille cartes ne tiennent pas dans un corps d'action serveur - et parce qu'un versement
 * qui avance à l'écran vaut mieux qu'une attente muette.
 */

type Phase = "repos" | "lecture" | "creation";

export function DeckPanel() {
  const { t } = useI18n();
  const router = useRouter();
  const fileInput = useRef<HTMLInputElement>(null);

  const [title, setTitle] = useState("");
  const [subject, setSubject] = useState("");
  const [visibility, setVisibility] = useState<CourseVisibility>(DEFAULT_VISIBILITY);

  const [imported, setImported] = useState<AnkiPackage | null>(null);
  const [fileName, setFileName] = useState<string | null>(null);
  const [excluded, setExcluded] = useState<Set<string>>(new Set());
  const [dragging, setDragging] = useState(false);

  const [phase, setPhase] = useState<Phase>("repos");
  const [poured, setPoured] = useState(0);
  const [failure, setFailure] = useState<string | null>(null);
  /** Le paquet ouvert, quand le versement casse ensuite : il existe, il faut pouvoir y aller. */
  const [opened, setOpened] = useState<string | null>(null);

  const busy = phase !== "repos";
  const chosen = imported
    ? imported.cards.filter((card) => !excluded.has(card.deck))
    : [];
  const canCreate = title.trim().length > 0 && (!imported || chosen.length > 0);

  async function handleFile(file: File) {
    setFailure(null);
    setFileName(file.name);
    setPhase("lecture");

    try {
      const parsed = isAnkiFileName(file.name)
        ? await readAnkiPackage(new Uint8Array(await file.arrayBuffer()), file.name)
        : readAnkiTextExport(await file.text(), file.name);

      setImported(parsed);
      setExcluded(new Set());
      if (!title.trim() && parsed.title) setTitle(parsed.title);
      setPhase("repos");
    } catch (error) {
      setImported(null);
      setFileName(null);
      setPhase("repos");
      setFailure(ankiFailure(error, t));
    }
  }

  function drop() {
    setImported(null);
    setFileName(null);
    setExcluded(new Set());
    setFailure(null);
    if (fileInput.current) fileInput.current.value = "";
  }

  async function create() {
    if (busy || !canCreate) return;
    setFailure(null);
    setPhase("creation");
    setPoured(0);

    const deck = await createDeck({
      title,
      subject,
      visibility,
    });

    if (deck.status === "paywall") {
      setPhase("repos");
      requestPaywall();
      return;
    }
    if (deck.status !== "ok" || !deck.courseId) {
      setPhase("repos");
      setFailure(deck.message ?? t("app.common.errorGeneric"));
      return;
    }

    const courseId = deck.courseId;
    setOpened(courseId);

    // Le paquet existe, quoi qu'il arrive ensuite : un versement qui casse au milieu ne doit
    // pas faire perdre le nom qu'on vient de saisir, ni les cartes déjà arrivées. On reste
    // alors sur place avec le message et la porte du paquet, plutôt que d'emmener quelqu'un
    // sur un atelier à moitié rempli sans lui dire pourquoi.
    for (let at = 0; at < chosen.length; at += DECK_CHUNK) {
      const written = await addDeckCards({
        courseId,
        cards: chosen.slice(at, at + DECK_CHUNK).map(toDeckCard),
      });
      if (written.status !== "ok") {
        setFailure(written.message ?? t("app.common.errorGeneric"));
        return;
      }
      setPoured(Math.min(chosen.length, at + DECK_CHUNK));
    }

    router.push(`/app/paquets/${courseId}` as never);
  }

  if (phase === "creation" && failure && opened) {
    return (
      <div className="rounded-2xl border border-border bg-card p-5">
        <p className="text-[15px] font-semibold text-ink">{t("app.deck.partial")}</p>
        <p className="mt-1.5 text-[14px] leading-relaxed text-ink-secondary" role="alert">
          {failure}
        </p>
        <div className="mt-4">
          <Button render={<Link href={`/app/paquets/${opened}` as never} />}>
            {t("app.deck.openAnyway")}
          </Button>
        </div>
      </div>
    );
  }

  if (phase === "creation") {
    return (
      <div className="flex min-h-[260px] flex-col items-center justify-center gap-4 rounded-2xl border border-border bg-card px-6 py-10 text-center">
        <ThinkingOrb state={imported ? "searching" : "composing"} size={64} />
        <div className="min-w-0">
          <p className="text-[16px] font-semibold text-ink">
            {imported ? t("app.deck.pouring") : t("app.import.writing")}
          </p>
          <p className="numeral mt-1 text-[13px] text-ink-tertiary">
            {imported
              ? t("app.deck.pouringCount", { done: poured, total: chosen.length })
              : t("app.deck.openingHint")}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="rounded-2xl border border-border bg-card p-5">
        <label htmlFor="deck-title" className="eyebrow block text-ink-tertiary">
          {t("app.deck.nameLabel")}
        </label>
        <input
          id="deck-title"
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          placeholder={t("app.deck.namePlaceholder")}
          disabled={busy}
          maxLength={120}
          className="mt-2 h-11 w-full rounded-button bg-surface-muted px-4 text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
        />

        <label htmlFor="deck-subject" className="eyebrow mt-5 block text-ink-tertiary">
          {t("app.deck.subjectLabel")}
        </label>
        <input
          id="deck-subject"
          value={subject}
          onChange={(event) => setSubject(event.target.value)}
          placeholder={t("app.deck.subjectPlaceholder")}
          disabled={busy}
          maxLength={80}
          className="mt-2 h-11 w-full rounded-button bg-surface-muted px-4 text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
        />
        <p className="mt-2 text-[12.5px] leading-relaxed text-ink-tertiary">
          {t("app.deck.subjectHint")}
        </p>
      </div>

      {imported ? (
        <ImportedPreview
          t={t}
          parsed={imported}
          fileName={fileName}
          kept={chosen.length}
          excluded={excluded}
          onToggle={(deck) =>
            setExcluded((previous) => {
              const next = new Set(previous);
              if (next.has(deck)) next.delete(deck);
              else next.add(deck);
              return next;
            })
          }
          onDrop={drop}
        />
      ) : (
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
          className={`flex min-h-[180px] flex-col items-center justify-center rounded-2xl border border-dashed px-6 py-9 text-center transition-colors ${
            dragging ? "border-foreground bg-surface-muted" : "border-border bg-card"
          }`}
        >
          <input
            ref={fileInput}
            type="file"
            accept=".apkg,.colpkg,.anki2,.txt,.csv,.tsv"
            className="sr-only"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) void handleFile(file);
            }}
          />

          {phase === "lecture" ? (
            <div className="flex flex-col items-center gap-4">
              <ThinkingOrb state="searching" size={64} />
              <p className="text-[15px] font-semibold text-ink">{t("app.deck.reading")}</p>
              <p className="truncate text-[13px] text-ink-tertiary">{fileName}</p>
            </div>
          ) : (
            <>
              <span aria-hidden className="emoji text-[30px]">
                🃏
              </span>
              <p className="mt-3 text-base font-semibold text-foreground">
                {dragging ? t("app.deck.dropHere") : t("app.deck.ankiDrop")}
              </p>
              <p className="mt-1 max-w-[46ch] text-sm text-muted-foreground">
                {t("app.deck.ankiHint")}
              </p>
              <Button type="button" className="mt-5" onClick={() => fileInput.current?.click()}>
                {t("app.deck.chooseAnki")}
              </Button>
              <p className="mt-4 max-w-[52ch] text-[12.5px] leading-relaxed text-ink-tertiary">
                {t("app.deck.ankiScope")}
              </p>
            </>
          )}
        </div>
      )}

      <div className="rounded-2xl border border-border bg-card p-5">
        <p className="eyebrow text-ink-tertiary">{t("app.deck.visibilityLabel")}</p>
        <div className="mt-3.5">
          <VisibilityChoices value={visibility} onChange={setVisibility} disabled={busy} />
        </div>
        {/* Un paquet n'a pas de fiche, donc pas d'écran de cours où l'on pourrait le refermer
            après coup : le choix se fait ici, ou il ne se fait jamais. */}
        <p className="mt-3 text-[12.5px] leading-relaxed text-ink-tertiary">
          {t("app.deck.visibilityHint")}
        </p>
      </div>

      <div className="flex flex-wrap items-center justify-end gap-3 pt-1">
        {imported ? (
          <p className="numeral mr-auto text-[13px] text-ink-tertiary">
            {t("app.deck.willImport", { count: chosen.length })}
          </p>
        ) : null}
        <Button type="button" disabled={!canCreate || busy} onClick={() => void create()}>
          {imported ? t("app.deck.importCards") : t("app.deck.createEmpty")}
        </Button>
      </div>

      {failure ? (
        <p
          className="rounded-group bg-negative-soft px-5 py-4 text-[14px] leading-relaxed text-negative"
          role="alert"
        >
          {failure}
        </p>
      ) : null}
    </div>
  );
}

/**
 * Ce que le fichier contient, avant de verser quoi que ce soit.
 *
 * Les paquets d'Anki sont montrés **et décochables** : un `.apkg` partagé porte souvent la
 * matière entière quand on ne voulait qu'un chapitre, et découvrir six cents cartes de
 * pharmacologie dans son paquet de latin ne se répare qu'à la main.
 */
function ImportedPreview({
  t,
  parsed,
  fileName,
  kept,
  excluded,
  onToggle,
  onDrop,
}: {
  t: Translator;
  parsed: AnkiPackage;
  fileName: string | null;
  kept: number;
  excluded: Set<string>;
  onToggle: (deck: string) => void;
  onDrop: () => void;
}) {
  const sample = parsed.cards.filter((card) => !excluded.has(card.deck)).slice(0, 6);

  return (
    <div className="overflow-hidden rounded-2xl border border-border bg-card">
      <div className="flex items-start justify-between gap-4 border-b border-border px-5 py-4">
        <div className="min-w-0">
          <p className="truncate text-[15px] font-semibold text-ink">
            {fileName ?? t("app.deck.ankiFile")}
          </p>
          <p className="numeral mt-0.5 text-[13px] text-ink-tertiary">
            {[
              t("app.deck.cardsFound", { count: parsed.cards.length }),
              parsed.skipped > 0 ? t("app.deck.skipped", { count: parsed.skipped }) : null,
              parsed.cards.length >= ANKI_CARD_LIMIT
                ? t("app.deck.capped", { limit: ANKI_CARD_LIMIT })
                : null,
            ]
              .filter(Boolean)
              .join(" · ")}
          </p>
        </div>
        <Button type="button" variant="ghost" onClick={onDrop}>
          {t("app.common.change")}
        </Button>
      </div>

      {parsed.decks.length > 1 ? (
        <div className="border-b border-border px-5 py-4">
          <p className="eyebrow text-ink-tertiary">{t("app.deck.whichDecks")}</p>
          <div className="mt-3 flex flex-wrap gap-2">
            {parsed.decks.map((deck) => {
              const on = !excluded.has(deck.name);
              return (
                <button
                  key={deck.name}
                  type="button"
                  aria-pressed={on}
                  onClick={() => onToggle(deck.name)}
                  className={`pressable rounded-button px-3 py-2 text-[13px] font-medium transition-colors duration-hover ${
                    on
                      ? "bg-accent text-on-ink"
                      : "bg-surface-muted text-ink-tertiary hover:bg-surface-sunken"
                  }`}
                >
                  {deck.name || t("app.deck.unnamedDeck")}
                  <span className="numeral ml-1.5 opacity-70">{deck.cards}</span>
                </button>
              );
            })}
          </div>
        </div>
      ) : null}

      {kept > 0 ? (
        <ul className="divide-y divide-hairline">
          {sample.map((card, index) => (
            <li key={`${card.deck}-${index}`} className="px-5 py-3.5">
              <p className="line-clamp-2 text-[14.5px] leading-snug text-ink">{card.front}</p>
              <p className="mt-1 line-clamp-2 text-[13px] leading-snug text-ink-secondary">
                {card.back}
              </p>
            </li>
          ))}
        </ul>
      ) : (
        <p className="px-5 py-6 text-[14px] text-ink-tertiary">{t("app.deck.nothingSelected")}</p>
      )}

      {kept > sample.length ? (
        <p className="numeral border-t border-border px-5 py-3 text-[12.5px] text-ink-tertiary">
          {t("app.deck.andMore", { count: kept - sample.length })}
        </p>
      ) : null}
    </div>
  );
}

function toDeckCard(card: AnkiCard) {
  return { kind: card.kind, front: card.front, back: card.back, hint: card.hint };
}

function ankiFailure(error: unknown, t: Translator): string {
  if (error instanceof AnkiError) {
    if (error.code === "notPackage") return t("app.deck.errors.notPackage");
    if (error.code === "noCollection") return t("app.deck.errors.noCollection");
    if (error.code === "empty") return t("app.deck.errors.empty");
    if (error.code === "noZstd") return t("app.deck.errors.noZstd");
  }
  return t("app.deck.errors.unreadable");
}
