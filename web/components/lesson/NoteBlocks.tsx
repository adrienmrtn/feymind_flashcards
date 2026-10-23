"use client";

import { useEffect, useState } from "react";
import { AlertTriangle, Check, ChevronDown, Lightbulb, Pin, Sparkles } from "lucide-react";

import type { CalloutKind, DateItem, LessonTone, NoteBlock, ThemeNotes } from "@micabo/core";

import { KeywordText } from "@/components/lesson/KeywordText";
import { MathBlock } from "@/components/sheet/Math";
import { useI18n } from "@/lib/i18n/client";

/**
 * **Les notes d'un thème**, mises en page comme le brief les décrit (`docs/refonte-parcours.md`
 * § 6) : « En une phrase » dans la couleur de la leçon, des blocs courts, les blocs spéciaux
 * quand le contenu le demande, « À retenir » dans la couleur de la leçon. Jumeau de
 * `ThemeNotesView.swift`.
 *
 * Trois couleurs et pas plus : la couleur de la leçon pour les encadrés et les puces, le violet
 * pour les mots-clés, le vert et le rouge pour les réponses. Seule exception, les encadrés qui
 * enseignent (`NoteCallout`) : leur teinte dit leur genre (piège, règle…).
 */

/** Le rythme vertical des notes : un pas régulier, plus d'air au-dessus d'un sous-titre, le sous-titre collé au bloc qu'il ouvre. */
export const NOTE_RHYTHM = { between: 18, beforeSubtitle: 28, afterSubtitle: 10 } as const;

export function noteSpacing(block: NoteBlock, previous: NoteBlock | null | undefined): number {
  if (!previous) return 0;
  if (previous.type === "subtitle") return NOTE_RHYTHM.afterSubtitle;
  if (block.type === "subtitle") return NOTE_RHYTHM.beforeSubtitle;
  return NOTE_RHYTHM.between;
}

export function ThemeNotesView({ notes, tone }: { notes: ThemeNotes; tone: LessonTone }) {
  const { t } = useI18n();
  return (
    <div className="flex flex-col gap-[18px]">
      <ToneBox label={t("lesson.notes.oneLiner")} tone={tone}>
        <p className="text-[18px] font-bold leading-snug text-ink">
          <KeywordText text={notes.oneLiner} />
        </p>
      </ToneBox>

      {notes.blocks.length > 0 ? <NoteBlockList blocks={notes.blocks} tone={tone} /> : null}

      {notes.takeaways.length > 0 ? (
        <ToneBox label={t("lesson.notes.takeaways")} tone={tone}>
          <ul className="flex flex-col gap-2.5">
            {notes.takeaways.map((line, index) => (
              <li key={index} className="flex items-baseline gap-2.5 text-[17px] leading-[1.35] text-ink">
                <Check aria-hidden="true" className="size-[13px] shrink-0 translate-y-px" strokeWidth={3.5} style={{ color: `var(--color-tone-${tone}-ink)` }} />
                <span>
                  <KeywordText text={line} />
                </span>
              </li>
            ))}
          </ul>
        </ToneBox>
      ) : null}
    </div>
  );
}

/** Une suite de blocs, au rythme des notes. */
export function NoteBlockList({ blocks, tone, reveal = false }: { blocks: readonly NoteBlock[]; tone: LessonTone; reveal?: boolean }) {
  return (
    <div className="flex flex-col">
      {blocks.map((block, index) => (
        <div
          key={index}
          className={reveal ? "notes-reveal" : undefined}
          style={{ paddingTop: noteSpacing(block, index > 0 ? blocks[index - 1] : null), animationDelay: reveal ? `${80 + index * 90}ms` : undefined }}
        >
          <NoteBlockView block={block} tone={tone} />
        </div>
      ))}
    </div>
  );
}

/** Un encadré dans la couleur de la leçon, avec son petit titre en capitales. */
export function ToneBox({ label, tone, children, className }: { label: string; tone: LessonTone; children: React.ReactNode; className?: string }) {
  return (
    <section className={`flex flex-col gap-2 rounded-[20px] p-[18px] ${className ?? ""}`} style={{ background: `var(--color-tone-${tone}-pale)` }}>
      <p className="text-[12px] font-bold uppercase tracking-caps" style={{ color: `var(--color-tone-${tone}-ink)` }}>
        {label}
      </p>
      {children}
    </section>
  );
}

const NOTES_TEXT = "text-[17px] leading-[1.35] text-ink";

/** Un bloc des notes. */
export function NoteBlockView({ block, tone }: { block: NoteBlock; tone: LessonTone }) {
  const { t } = useI18n();
  const vivid = `var(--color-tone-${tone}-vivid)`;
  switch (block.type) {
    case "subtitle":
      return (
        <h3 className="flex items-center gap-2.5 text-[20px] font-bold leading-snug text-ink">
          <span aria-hidden="true" className="h-5 w-1 shrink-0 rounded-pill" style={{ background: vivid }} />
          <KeywordText text={block.text} />
        </h3>
      );

    case "paragraph":
      return (
        <p className={NOTES_TEXT}>
          <KeywordText text={block.text} />
        </p>
      );

    case "list":
      return (
        <ul className="flex flex-col gap-2.5">
          {block.items.map((item, index) => (
            <li key={index} className={`flex items-baseline gap-3 ${NOTES_TEXT}`}>
              <span aria-hidden="true" className="size-[7px] shrink-0 rounded-full" style={{ background: vivid }} />
              <span>
                <KeywordText text={item} />
              </span>
            </li>
          ))}
        </ul>
      );

    case "definition":
      return <NoteDefinition term={block.term} text={block.text} />;

    case "dates":
      return <DatesTimeline items={block.items} tone={tone} />;

    case "formula":
      return (
        <div className="flex flex-col items-center gap-2 rounded-[20px] bg-surface p-[18px] shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
          <div className="max-w-full overflow-x-auto text-[20px] text-ink">
            <MathBlock latex={block.latex} />
          </div>
          {block.caption ? (
            <p className="text-center text-[15px] font-medium text-ink-secondary">
              <KeywordText text={block.caption} />
            </p>
          ) : null}
        </div>
      );

    case "example":
      return (
        <div className="flex flex-col gap-1.5 rounded-[18px] bg-surface-muted p-4">
          <p className="text-[12px] font-bold uppercase tracking-caps text-ink-secondary">{t("lesson.notes.example")}</p>
          <p className={NOTES_TEXT}>
            <KeywordText text={block.text} />
          </p>
        </div>
      );

    case "steps":
      return <NoteSteps items={block.items} tone={tone} />;

    case "table":
      return <NoteTable columns={block.columns} rows={block.rows} tone={tone} />;

    case "quote":
      return (
        <blockquote className="relative rounded-[18px] bg-surface-muted p-[18px] ps-[34px]">
          <span aria-hidden="true" className="absolute bottom-[18px] left-[18px] top-[18px] w-1 rounded-pill" style={{ background: vivid }} />
          <p className="text-[18px] font-medium italic leading-snug text-ink">
            <KeywordText text={block.text} />
          </p>
          {block.author ? <footer className="mt-2.5 text-[15px] font-bold text-ink-secondary">— {block.author.replaceAll("**", "")}</footer> : null}
        </blockquote>
      );

    case "callout":
      return <NoteCallout kind={block.kind} title={block.title} text={block.text} tone={tone} />;
  }
}

/**
 * Une définition : le terme en violet, replié ; un appui l'ouvre. Sur papier, tout est ouvert :
 * une feuille ne se déplie pas, donc `beforeprint` révèle le texte avant que la page parte.
 */
function NoteDefinition({ term, text }: { term: string; text: string }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  useEffect(() => {
    const reveal = () => setOpen(true);
    window.addEventListener("beforeprint", reveal);
    return () => window.removeEventListener("beforeprint", reveal);
  }, []);
  return (
    <button
      type="button"
      aria-expanded={open}
      onClick={() => setOpen((value) => !value)}
      className="pressable flex w-full flex-col gap-2 rounded-[18px] bg-surface p-4 text-start shadow-[inset_0_0_0_1.5px_color-mix(in_srgb,var(--color-keyword)_35%,transparent)]"
    >
      <span className="flex items-center justify-between">
        <span className="text-[12px] font-bold uppercase tracking-caps text-ink-secondary">{t("lesson.notes.definition")}</span>
        <ChevronDown aria-hidden="true" className={`size-4 text-keyword transition-transform ${open ? "rotate-180" : ""}`} strokeWidth={2.6} />
      </span>
      <span className="text-[19px] font-extrabold leading-snug text-keyword">
        <KeywordText text={term} tints={false} />
      </span>
      {open ? (
        <span className={`notes-reveal ${NOTES_TEXT}`}>
          <KeywordText text={text} />
        </span>
      ) : null}
    </button>
  );
}

/** Les dates clés, sur une frise qu'on fait glisser. */
function DatesTimeline({ items, tone }: { items: DateItem[]; tone: LessonTone }) {
  const vivid = `var(--color-tone-${tone}-vivid)`;
  return (
    <ol className="-mx-1 flex overflow-x-auto px-1 py-1 [scrollbar-width:none]">
      {items.map((item, index) => (
        <li key={index} className="flex w-[150px] shrink-0 flex-col gap-2">
          <span className="flex items-center">
            <span aria-hidden="true" className="size-3.5 shrink-0 rounded-full" style={{ background: vivid }} />
            <span aria-hidden="true" className="h-[3px] flex-1" style={{ background: index === items.length - 1 ? "transparent" : `color-mix(in srgb, ${vivid} 50%, transparent)` }} />
          </span>
          <span className="text-[17px] font-extrabold leading-tight" style={{ color: `var(--color-tone-${tone}-ink)` }}>
            <KeywordText text={item.date} tints={false} />
          </span>
          <span className="w-[130px] text-[15px] font-medium leading-snug text-ink">
            <KeywordText text={item.text} />
          </span>
        </li>
      ))}
    </ol>
  );
}

/** Des étapes numérotées : une pastille par étape dans la couleur de la leçon, reliées par un filet qui dit « puis ». */
function NoteSteps({ items, tone }: { items: string[]; tone: LessonTone }) {
  const vivid = `var(--color-tone-${tone}-vivid)`;
  return (
    <ol className="flex flex-col rounded-[18px] bg-surface p-4 shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
      {items.map((item, index) => {
        const isLast = index === items.length - 1;
        return (
          <li key={index} className="relative flex items-start gap-3.5">
            {!isLast ? <span aria-hidden="true" className="absolute bottom-0 left-[14px] top-[30px] w-0.5" style={{ background: `color-mix(in srgb, ${vivid} 35%, transparent)` }} /> : null}
            <span className="numeral relative flex size-[30px] shrink-0 items-center justify-center rounded-full text-[15px] font-extrabold text-on-ink" style={{ background: vivid }}>
              {index + 1}
            </span>
            <span className={`flex-1 pt-1 ${isLast ? "" : "pb-4"} ${NOTES_TEXT}`}>
              <KeywordText text={item} />
            </span>
          </li>
        );
      })}
    </ol>
  );
}

/**
 * **Un petit tableau** : l'en-tête en gras sur la teinte de la leçon, une ligne sur deux
 * teintée, des cellules qui reviennent à la ligne. Trop de colonnes pour la largeur, et le
 * tableau glisse en travers plutôt que d'écraser ses cellules.
 */
function NoteTable({ columns, rows, tone }: { columns: string[]; rows: string[][]; tone: LessonTone }) {
  return (
    <div className="overflow-x-auto rounded-[18px] shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
      <table className="w-full border-collapse text-[15px]" style={{ minWidth: columns.length > 3 ? columns.length * 150 : undefined }}>
        <thead>
          <tr style={{ background: `var(--color-tone-${tone}-pale)` }}>
            {columns.map((column, index) => (
              <th key={index} className="px-3 py-2.5 text-start align-top font-extrabold" style={{ color: `var(--color-tone-${tone}-ink)` }}>
                <KeywordText text={column} tints={false} />
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((cells, rowIndex) => (
            <tr key={rowIndex} className={rowIndex % 2 === 1 ? "bg-surface-muted" : "bg-surface"}>
              {columns.map((_, column) => (
                <td key={column} className="px-3 py-2.5 align-top font-medium text-ink">
                  <KeywordText text={cells[column] ?? ""} />
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

const CALLOUT_ICONS: Record<CalloutKind, typeof Lightbulb> = { why: Lightbulb, mistake: AlertTriangle, tip: Sparkles, remember: Pin };

/**
 * **Un encadré qui enseigne** : pourquoi ça compte, le piège classique, une astuce, une règle à
 * retenir. Chaque genre a sa teinte et son pictogramme : le bleu de l'information, le rouge de
 * l'erreur, la couleur de la leçon pour l'astuce, le jaune de l'attention pour la règle.
 */
export function NoteCallout({ kind, title, text, tone }: { kind: CalloutKind; title: string | null; text: string; tone: LessonTone }) {
  const { t } = useI18n();
  const Icon = CALLOUT_ICONS[kind];
  const ink =
    kind === "why" ? "var(--color-info)" : kind === "mistake" ? "var(--color-negative)" : kind === "tip" ? `var(--color-tone-${tone}-ink)` : "var(--color-caution)";
  const wash =
    kind === "why"
      ? "var(--color-info-soft)"
      : kind === "mistake"
        ? "var(--color-negative-soft)"
        : kind === "tip"
          ? `var(--color-tone-${tone}-pale)`
          : "var(--color-caution-soft)";
  return (
    <aside className="flex flex-col gap-2 rounded-[18px] p-4" style={{ background: wash, boxShadow: `inset 0 0 0 1.5px color-mix(in srgb, ${ink} 25%, transparent)` }}>
      <p className="flex items-center gap-2 text-[12px] font-bold uppercase tracking-caps" style={{ color: ink }}>
        <Icon aria-hidden="true" className="size-3.5" strokeWidth={2.6} />
        {t(`lesson.notes.callout.${kind}`)}
      </p>
      {title ? (
        <p className="text-[18px] font-bold leading-snug text-ink">
          <KeywordText text={title} tints={false} />
        </p>
      ) : null}
      <p className={NOTES_TEXT}>
        <KeywordText text={text} />
      </p>
    </aside>
  );
}
