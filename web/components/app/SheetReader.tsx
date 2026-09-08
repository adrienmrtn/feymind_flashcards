"use client";

import { useEffect, useRef, useState } from "react";
import { ThinkingOrb } from "thinking-orbs";

import type { SheetBlock } from "@micabo/core";

import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import { createCard } from "@/lib/actions/cards";
import { explainSelection, type Explanation } from "@/lib/actions/cards";
import { useI18n } from "@/lib/i18n/client";
import {
  placeExplanation,
  windowViewport,
  type ExplanationAnchor,
} from "@/lib/sheet/explanation-place";

/**
 * La fiche, **et le passage qu'on ne comprend pas.**
 *
 * On sélectionne trois mots, le bouton apparaît **à côté du passage**, pas en bas de page.
 * L'explication aussi : une carte flottante, fermable, ancrée sur le texte qu'on vient de
 * pointer. La coller en fin de fiche obligeait à quitter le paragraphe, donc à perdre le
 * fil - c'est précisément ce qu'une explication ne doit pas faire.
 */
export function SheetReader({
  courseId,
  blocks,
  tint,
}: {
  courseId: string;
  blocks: SheetBlock[];
  tint: string;
}) {
  const { t } = useI18n();
  const container = useRef<HTMLDivElement>(null);
  const passage = useRef<DOMRect | null>(null);
  const range = useRef<Range | null>(null);
  const [selection, setSelection] = useState<string | null>(null);
  const [anchor, setAnchor] = useState<ExplanationAnchor | null>(null);
  const [panel, setPanel] = useState<"repos" | "attente" | "reponse">("repos");
  const [explanation, setExplanation] = useState<Explanation | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    function read() {
      const active = window.getSelection();
      const text = active?.toString().trim() ?? "";
      if (!active || active.rangeCount === 0 || text.length < 2) {
        if (panel === "repos") {
          setSelection(null);
          setAnchor(null);
          passage.current = null;
          range.current = null;
        }
        return;
      }
      const node = active.anchorNode;
      if (!node || !container.current?.contains(node)) {
        if (panel === "repos") {
          setSelection(null);
          setAnchor(null);
          passage.current = null;
          range.current = null;
        }
        return;
      }
      const live = active.getRangeAt(0);
      const rect = live.getBoundingClientRect();
      range.current = live.cloneRange();
      passage.current = rect;
      setSelection(text.slice(0, 600));
      setAnchor(placeExplanation(rect, windowViewport()));
    }

    document.addEventListener("selectionchange", read);
    return () => document.removeEventListener("selectionchange", read);
  }, [panel]);

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") dismiss();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  useEffect(() => {
    function relayout() {
      const live = livePassage();
      if (!live) return;
      passage.current = live;
      setAnchor(placeExplanation(live, windowViewport()));
    }
    window.addEventListener("resize", relayout);
    window.addEventListener("scroll", relayout, true);
    return () => {
      window.removeEventListener("resize", relayout);
      window.removeEventListener("scroll", relayout, true);
    };
  }, []);

  function dismiss() {
    setPanel("repos");
    setExplanation(null);
    setFailure(null);
    setSelection(null);
    setAnchor(null);
    passage.current = null;
    range.current = null;
  }

  function livePassage(): DOMRect | null {
    try {
      const saved = range.current;
      if (saved) {
        const rect = saved.getBoundingClientRect();
        if (rect.width > 0 || rect.height > 0) return rect;
      }
    } catch {
      // Le nœud a disparu avec un re-rendu.
    }
    return passage.current;
  }

  async function ask() {
    if (!selection) return;
    setPanel("attente");
    setFailure(null);
    setExplanation(null);
    setSaved(false);

    const result = await explainSelection({ selection, courseId });
    if (result.status === "error" || !result.explanation) {
      setPanel("repos");
      setFailure(result.message ?? t("app.sheetReader.error"));
      return;
    }
    setExplanation(result.explanation);
    setPanel("reponse");
  }

  async function keepCard() {
    if (!explanation?.card) return;
    const result = await createCard({
      courseId,
      front: explanation.card.front,
      back: explanation.card.back,
    });
    if (result.status === "ok") setSaved(true);
  }

  const floating = Boolean(anchor && (selection || panel !== "repos" || failure));

  return (
    <div>
      <div ref={container} className="w-full max-w-page">
        <SheetBlocks blocks={blocks} tint={tint} />
      </div>

      {floating && anchor ? (
        <div
          className="fixed z-40 w-[min(420px,calc(100vw-2rem))]"
          style={
            anchor.bottom != null
              ? { left: anchor.left, bottom: anchor.bottom }
              : { left: anchor.left, top: anchor.top }
          }
          data-print="hide"
        >
          <div className="rise">
          {panel === "repos" && selection ? (
            <div className="flex items-center gap-3 rounded-pill bg-ink px-4 py-2.5 shadow-floating">
              <span className="max-w-[28ch] truncate text-[13px] text-on-ink-muted">
                « {selection} »
              </span>
              <button
                type="button"
                onClick={ask}
                className="pressable shrink-0 rounded-pill bg-on-ink px-3.5 py-1.5 text-[13.5px] font-semibold text-ink"
              >
                {t("app.sheetReader.ask")}
              </button>
            </div>
          ) : null}

          {panel === "attente" ? (
            <div className="paper flex items-center gap-3 rounded-group bg-surface p-4 shadow-floating">
              <ThinkingOrb state="composing" size={64} />
              <p className="text-[14.5px] font-semibold text-ink" role="status">
                {t("app.sheetReader.reading")}
              </p>
            </div>
          ) : null}

          {panel === "reponse" && explanation ? (
            <aside
              className="paper overflow-y-auto rounded-group bg-surface p-5 shadow-floating"
              style={{ maxHeight: anchor.maxHeight }}
            >
              <div className="sticky top-0 z-10 -mx-5 -mt-5 mb-3 flex items-start justify-between gap-3 bg-surface px-5 pt-5 pb-2">
                <p className="eyebrow text-accent">{t("app.sheetReader.title")}</p>
                <button
                  type="button"
                  onClick={dismiss}
                  aria-label={t("app.a11y.closeExplanation")}
                  className="pressable -mr-1 -mt-1 text-[15px] text-ink-tertiary"
                >
                  ✕
                </button>
              </div>

              {selection ? (
                <p className="mt-2 rounded-button bg-accent-soft px-3 py-2 text-[13px] text-accent">
                  « {selection} »
                </p>
              ) : null}

              <p className="mt-3 text-[16px] font-semibold leading-snug text-ink">
                <InlineMarkup text={explanation.headline} />
              </p>

              {explanation.body ? (
                <p className="mt-2.5 text-[14.5px] leading-relaxed text-ink-reading">
                  <InlineMarkup text={explanation.body} />
                </p>
              ) : null}

              {explanation.example ? (
                <div className="mt-3 rounded-button bg-surface-muted px-3 py-2.5">
                  <p className="eyebrow text-ink-tertiary">{t("app.sheetTone.exemple")}</p>
                  <p className="mt-1 text-[13.5px] leading-relaxed text-ink-reading">
                    <InlineMarkup text={explanation.example} />
                  </p>
                </div>
              ) : null}

              {explanation.watchOut ? (
                <div className="mt-2 rounded-button bg-caution-soft px-3 py-2.5">
                  <p className="eyebrow text-caution">{t("app.sheetTone.attention")}</p>
                  <p className="mt-1 text-[13.5px] leading-relaxed text-ink-reading">
                    <InlineMarkup text={explanation.watchOut} />
                  </p>
                </div>
              ) : null}

              {explanation.card ? (
                <div className="mt-4 border-t border-hairline pt-4">
                  <p className="text-[12.5px] text-ink-tertiary">
                    {t("app.sheetReader.proposeCard")}
                  </p>
                  <p className="mt-1.5 text-[14px] font-medium text-ink">{explanation.card.front}</p>
                  <p className="mt-1 text-[13.5px] text-ink-secondary">{explanation.card.back}</p>
                  <button
                    type="button"
                    onClick={keepCard}
                    disabled={saved}
                    className={`pressable mt-3 rounded-button px-4 py-2 text-[13.5px] font-semibold ${
                      saved ? "bg-accent-soft text-accent" : "bg-accent text-on-ink"
                    }`}
                  >
                    {saved ? t("app.sheetReader.cardSaved") : t("app.sheetReader.keepCard")}
                  </button>
                </div>
              ) : null}
            </aside>
          ) : null}

          {failure ? (
            <p className="mt-2 rounded-button bg-negative-soft px-3 py-2 text-[13px] text-negative" role="alert">
              {failure}
            </p>
          ) : null}
          </div>
        </div>
      ) : null}
    </div>
  );
}
