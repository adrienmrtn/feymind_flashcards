"use client";

import { useEffect, useRef, useState } from "react";

import { useI18n } from "@/lib/i18n/client";
import { typesetMath } from "@/lib/math/typeset";

import { MathBlock, MathInline } from "./Math";

/**
 * **Corriger une formule sans savoir écrire du LaTeX.**
 *
 * Une formule était le seul endroit de la fiche qu'on ne pouvait pas toucher. Elle est
 * composée - une fraction a sa barre, une somme ses bornes - donc on ne peut pas taper
 * dedans comme dans une phrase ; et lui coller un champ où l'on écrirait
 * `\\frac{\\partial u}{\\partial t}` revient à demander à un lycéen d'apprendre un langage
 * pour corriger un exposant.
 *
 * Trois choses rendent ce champ utilisable par quelqu'un qui n'a jamais vu de LaTeX :
 *
 * 1. **L'aperçu est composé pendant qu'on tape.** On regarde la formule, pas le code. C'est
 *    la seule chose qui compte : personne ne relit du LaTeX, tout le monde relit une
 *    fraction.
 * 2. **Les constructions s'insèrent au bouton.** Fraction, puissance, indice, racine, somme,
 *    intégrale, et les symboles qu'on cherche dans un menu de traitement de texte. Chaque
 *    bouton pose un gabarit avec des cases `□`, et sélectionne la première : on tape
 *    par-dessus.
 * 3. **Une formule qui ne se compose pas le dit.** Le moteur retombe sur la transposition
 *    Unicode plutôt que d'écrire du rouge dans la page ; ici, on prévient au lieu de laisser
 *    croire que c'est normal.
 *
 * Le LaTeX reste visible et modifiable pour qui le connaît - c'est plus rapide - mais il
 * n'est plus le seul chemin.
 */

/** La case à remplir d'un gabarit. Elle ne survit pas à l'enregistrement. */
const SLOT = "□";

interface Insert {
  label: string;
  latex: string;
  /** Ce que le bouton montre, quand l'étiquette n'est pas le symbole lui-même. */
  preview?: string;
}

const SHAPES: Insert[] = [
  { label: "a/b", latex: `\\frac{${SLOT}}{${SLOT}}` },
  { label: "x²", latex: `${SLOT}^{${SLOT}}` },
  { label: "xᵢ", latex: `${SLOT}_{${SLOT}}` },
  { label: "√", latex: `\\sqrt{${SLOT}}` },
  { label: "Σ", latex: `\\sum_{${SLOT}}^{${SLOT}} ${SLOT}` },
  { label: "∫", latex: `\\int_{${SLOT}}^{${SLOT}} ${SLOT}` },
  { label: "( )", latex: `\\left( ${SLOT} \\right)` },
  { label: "|x|", latex: `\\left| ${SLOT} \\right|` },
];

const SYMBOLS: Insert[] = [
  { label: "×", latex: "\\times " },
  { label: "÷", latex: "\\div " },
  { label: "±", latex: "\\pm " },
  { label: "≤", latex: "\\leq " },
  { label: "≥", latex: "\\geq " },
  { label: "≠", latex: "\\neq " },
  { label: "≈", latex: "\\approx " },
  { label: "→", latex: "\\rightarrow " },
  { label: "∞", latex: "\\infty " },
  { label: "π", latex: "\\pi " },
  { label: "α", latex: "\\alpha " },
  { label: "β", latex: "\\beta " },
  { label: "θ", latex: "\\theta " },
  { label: "λ", latex: "\\lambda " },
  { label: "Δ", latex: "\\Delta " },
  { label: "∂", latex: "\\partial " },
];

export interface FormulaDraft {
  latex: string;
  caption: string;
  /**
   * Dans le texte, ou posée seule.
   *
   * Une formule n'est pas forcément un bloc, et c'était le défaut du premier jet : tout ce
   * qu'on écrivait descendait en bas de page, encadré, alors que la moitié des formules d'un
   * cours vivent **dans** la phrase - « on note $v = d/t$ la vitesse ». Posée seule, elle
   * passe en mode display : une somme met alors ses bornes au-dessus et en dessous, une
   * fraction prend sa hauteur. C'est la seule différence, et elle se choisit.
   */
  inline: boolean;
}

export function FormulaEditor({
  initial,
  onSave,
  onDelete,
  onClose,
}: {
  initial: FormulaDraft;
  onSave: (draft: FormulaDraft) => void;
  /** Absent quand la formule vient d'être posée : annuler suffit à ne rien laisser. */
  onDelete?: () => void;
  onClose: () => void;
}) {
  const { t } = useI18n();
  const [latex, setLatex] = useState(initial.latex);
  const [caption, setCaption] = useState(initial.caption);
  const [inline, setInline] = useState(initial.inline);
  const field = useRef<HTMLTextAreaElement>(null);

  const filled = !latex.includes(SLOT);
  const trimmed = latex.trim();
  const composes = trimmed.length === 0 || typesetMath(trimmed).kind === "typeset";
  const ready = trimmed.length > 0 && filled && composes;

  useEffect(() => {
    field.current?.focus();
    field.current?.setSelectionRange(latex.length, latex.length);
    // Une seule fois, à l'ouverture : replacer le curseur à chaque frappe le renverrait
    // sans cesse à la fin.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  /**
   * Pose un gabarit là où est le curseur, et sélectionne sa première case.
   *
   * Sans cette sélection, il faudrait aller cliquer dans le petit carré pour le remplacer,
   * ce qui est exactement le geste qu'on cherche à éviter.
   */
  function insert(snippet: string) {
    const node = field.current;
    const start = node?.selectionStart ?? latex.length;
    const end = node?.selectionEnd ?? latex.length;
    const next = latex.slice(0, start) + snippet + latex.slice(end);
    setLatex(next);

    const slot = next.indexOf(SLOT, start);
    window.requestAnimationFrame(() => {
      node?.focus();
      if (slot >= 0) node?.setSelectionRange(slot, slot + SLOT.length);
      else node?.setSelectionRange(start + snippet.length, start + snippet.length);
    });
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={t("app.formula.title")}
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className="rise max-h-full w-full max-w-[540px] overflow-y-auto rounded-group bg-surface p-6 shadow-floating">
        <p className="section-title">{t("app.formula.title")}</p>
        <p className="mt-1 text-[13px] leading-relaxed text-ink-tertiary">
          {t("app.formula.lead")}
        </p>

        <div className="mt-4 flex min-h-[86px] items-center justify-center rounded-group bg-surface-muted px-4 py-5">
          {trimmed.length > 0 ? (
            // L'aperçu compose dans le mode où la formule ira : une somme en ligne et une
            // somme posée seule n'ont pas la même allure, et c'est justement ce qu'on choisit.
            inline ? (
              <p className="text-[15px] text-ink-reading">
                <MathInline latex={trimmed.replaceAll(SLOT, "\\square")} />
              </p>
            ) : (
              <MathBlock latex={trimmed.replaceAll(SLOT, "\\square")} />
            )
          ) : (
            <p className="text-[13.5px] text-ink-tertiary">{t("app.formula.empty")}</p>
          )}
        </div>

        <div
          role="group"
          aria-label={t("app.formula.placement")}
          className="mt-3 grid grid-cols-2 gap-1 rounded-button bg-surface-muted p-1"
        >
          {[true, false].map((value) => (
            <button
              key={String(value)}
              type="button"
              onClick={() => setInline(value)}
              aria-pressed={value === inline}
              className={`pressable h-9 rounded-[calc(var(--radius-button)-3px)] text-[13.5px] font-medium transition-colors duration-hover ${
                value === inline ? "bg-surface text-ink shadow-paper" : "text-ink-secondary"
              }`}
            >
              {value ? t("app.formula.inline") : t("app.formula.block")}
            </button>
          ))}
        </div>

        <div className="mt-4 flex flex-wrap gap-1.5">
          {SHAPES.map((shape) => (
            <PaletteButton key={shape.label} entry={shape} onPress={insert} />
          ))}
        </div>
        <div className="mt-1.5 flex flex-wrap gap-1.5">
          {SYMBOLS.map((symbol) => (
            <PaletteButton key={symbol.label} entry={symbol} onPress={insert} />
          ))}
        </div>

        <label htmlFor="formula-latex" className="mt-5 block text-[13px] text-ink-tertiary">
          {t("app.formula.source")}
        </label>
        <textarea
          id="formula-latex"
          ref={field}
          value={latex}
          onChange={(event) => setLatex(event.target.value)}
          rows={3}
          spellCheck={false}
          className="mt-2 w-full resize-y rounded-button bg-surface-muted px-3 py-2.5 font-mono text-[13.5px] text-ink outline-none"
        />

        {!filled ? (
          <p className="mt-2 text-[13px] text-caution">{t("app.formula.slots")}</p>
        ) : !composes ? (
          <p className="mt-2 text-[13px] text-caution">{t("app.formula.broken")}</p>
        ) : null}

        {/* Une légende sous une formule prise dans une phrase n'aurait nulle part où se
            poser : c'est la phrase elle-même qui dit ce que les symboles veulent dire. */}
        {inline ? null : (
          <>
            <label htmlFor="formula-caption" className="mt-4 block text-[13px] text-ink-tertiary">
              {t("app.formula.caption")}
            </label>
            <input
              id="formula-caption"
              value={caption}
              onChange={(event) => setCaption(event.target.value)}
              placeholder={t("app.formula.captionPlaceholder")}
              className="mt-2 h-10 w-full rounded-button bg-surface-muted px-3 text-[14px] text-ink outline-none placeholder:text-ink-tertiary"
            />
          </>
        )}

        <div className="mt-5 flex flex-wrap items-center gap-2">
          <button
            type="button"
            disabled={!ready}
            onClick={() =>
              onSave({ latex: trimmed, caption: inline ? "" : caption.trim(), inline })
            }
            className="pressable h-10 rounded-button bg-accent px-4 text-[13.5px] font-semibold text-on-ink disabled:opacity-40"
          >
            {t("app.formula.apply")}
          </button>
          <button
            type="button"
            onClick={onClose}
            className="pressable h-10 rounded-button px-3 text-[13.5px] text-ink-secondary"
          >
            {t("app.common.cancel")}
          </button>
          <span className="flex-1" />
          {onDelete ? (
            <button
              type="button"
              onClick={onDelete}
              className="pressable h-10 rounded-button px-3 text-[13.5px] font-medium text-negative"
            >
              {t("app.formula.remove")}
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function PaletteButton({
  entry,
  onPress,
}: {
  entry: Insert;
  onPress: (latex: string) => void;
}) {
  return (
    <button
      type="button"
      onClick={() => onPress(entry.latex)}
      title={entry.latex.trim()}
      className="pressable flex h-9 min-w-9 items-center justify-center rounded-button bg-surface-muted px-2.5 text-[14px] text-ink transition-colors duration-hover hover:bg-accent-soft hover:text-accent"
    >
      {entry.preview ?? entry.label}
    </button>
  );
}
