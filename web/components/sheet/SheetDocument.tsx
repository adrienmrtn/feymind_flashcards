"use client";

import { useCallback, useEffect, useRef, useState, useTransition } from "react";
import { createPortal } from "react-dom";

import { SHEET_HIGHLIGHTS, type SheetBlock, type SheetHighlight } from "@micabo/core";

import { Button } from "@/components/ui/button";
import { saveSheet } from "@/lib/actions/sheet";
import { useI18n } from "@/lib/i18n/client";
import { blocksToHtml, htmlToBlocks } from "@/lib/sheet/document";

import { currentBlock, toggleHighlight, toggleMark } from "./marks";
import { MathBlock } from "./Math";

/**
 * La fiche, **modifiable là où elle se lit.**
 *
 * Elle était un rendu figé de ce que le modèle avait écrit. Deux conséquences, et la seconde
 * est la pire. D'abord une erreur restait : un mot mal lu par la reconnaissance de caractères
 * se révisait tel quel jusqu'à l'épreuve. Ensuite, et surtout, **la fiche n'était pas celle de
 * l'étudiant** : il ne pouvait ni souligner ce qui compte pour lui, ni couper ce qu'il sait
 * déjà, ni ajouter la phrase que le professeur a dite à l'oral. Une fiche qu'on ne peut pas
 * annoter est une fiche qu'on recopie ailleurs.
 *
 * Donc : un document, comme un traitement de texte. **Pas de bouton Modifier** - il n'y a rien
 * à ouvrir, on écrit dans la page - et un bouton Enregistrer qui n'apparaît qu'une fois
 * quelque chose changé. La barre d'outils tient dans une ligne : gras, italique, cinq
 * surligneurs, et le style du bloc où se trouve le curseur.
 *
 * Ce qui est enregistré n'est pas le HTML de la page mais **des blocs**, relus par la même
 * normalisation que la fiche du modèle. Enregistrer une page collée depuis Word ne fait donc
 * pas entrer un tableau dans le format : le texte reste, la structure non.
 */
const HIGHLIGHT_LABEL: Record<SheetHighlight, string> = {
  jaune: "app.sheet.hl.jaune",
  menthe: "app.sheet.hl.menthe",
  bleu: "app.sheet.hl.bleu",
  rose: "app.sheet.hl.rose",
  lilas: "app.sheet.hl.lilas",
};

type Style = "h1" | "h2" | "p" | "ul" | "ol";

export function SheetDocument({
  courseId,
  blocks,
  lockedCount,
  readOnly = false,
  tool,
}: {
  courseId: string;
  blocks: SheetBlock[];
  /**
   * Les blocs que le mur d'abonnement cache en bas de fiche.
   *
   * Ils ne sont pas rendus, donc pas modifiables, donc **ils ne doivent pas disparaître à
   * l'enregistrement**. Le compte part au serveur, qui les recolle derrière ce qui a été
   * écrit. Sans ça, un compte gratuit effacerait la moitié de sa fiche en corrigeant une
   * faute de frappe.
   */
  lockedCount: number;
  readOnly?: boolean;
  /**
   * Un outil de plus dans la barre, posé par le parent.
   *
   * C'est « Explique-moi » qui passe par là. Il vivait dans une pastille flottante qui
   * apparaissait dès qu'on sélectionnait trois mots ; sur un document qu'on écrit, cette
   * pastille se déclencherait à chaque fois qu'on sélectionne un mot pour le mettre en gras.
   * Dans la barre, la sélection sert aux deux gestes sans qu'ils se disputent l'écran.
   */
  tool?: React.ReactNode;
}) {
  const { t } = useI18n();
  const editor = useRef<HTMLDivElement>(null);
  const [dirty, setDirty] = useState(false);
  const [style, setStyle] = useState<Style>("p");
  const [saved, setSaved] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  // Le document est monté **une seule fois**, à la main. React ne doit jamais reprendre la
  // main sur ces nœuds : il les remplacerait à chaque frappe, et le curseur repartirait au
  // début du paragraphe.
  useEffect(() => {
    if (editor.current) editor.current.innerHTML = blocksToHtml(blocks);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [courseId]);

  const readStyle = useCallback(() => {
    const node = editor.current ? currentBlock(editor.current) : null;
    const name = node?.tagName.toLowerCase();
    setStyle(name === "h1" || name === "h2" || name === "ul" || name === "ol" ? name : "p");
  }, []);

  useEffect(() => {
    document.addEventListener("selectionchange", readStyle);
    return () => document.removeEventListener("selectionchange", readStyle);
  }, [readStyle]);

  function touched() {
    setDirty(true);
    setSaved(false);
  }

  function mark(kind: "bold" | "italic") {
    if (!editor.current || readOnly) return;
    if (toggleMark(editor.current, kind)) touched();
  }

  function highlight(color: SheetHighlight) {
    if (!editor.current || readOnly) return;
    if (toggleHighlight(editor.current, color)) touched();
  }

  /**
   * Changer le style du bloc courant.
   *
   * On remplace l'élément plutôt que d'en changer les classes : c'est son nom de balise qui
   * dit ce qu'il est, à la relecture comme à l'enregistrement. Une liste emporte le bloc
   * entier dans un point unique ; en sortir le rend au paragraphe.
   */
  function setBlockStyle(next: Style) {
    const root = editor.current;
    if (!root || readOnly) return;
    const node = currentBlock(root);
    if (!node || node.parentElement !== root) {
      // Dans une liste, le bloc courant est le `li` : on remonte à la liste elle-même.
      const list = node?.closest("ul,ol");
      if (list && list.parentElement === root) return replaceBlock(root, list as HTMLElement, next);
      return;
    }
    replaceBlock(root, node, next);
  }

  function replaceBlock(root: HTMLElement, node: HTMLElement, next: Style) {
    const html = node.tagName === "UL" || node.tagName === "OL"
      ? Array.from(node.children).map((item) => item.innerHTML).join("<br>")
      : node.innerHTML;

    const created = document.createElement(next === "ul" || next === "ol" ? next : next);
    if (next === "ul" || next === "ol") {
      for (const part of html.split("<br>")) {
        const item = document.createElement("li");
        item.innerHTML = part.trim().length > 0 ? part : "<br>";
        created.appendChild(item);
      }
    } else {
      created.innerHTML = html.trim().length > 0 ? html : "<br>";
    }

    node.replaceWith(created);
    placeCaretAtEnd(created);
    setStyle(next);
    touched();
  }

  function save() {
    const root = editor.current;
    if (!root) return;
    setFailure(null);
    const next = htmlToBlocks(root);
    startTransition(async () => {
      const result = await saveSheet(courseId, next, lockedCount);
      if (result.status === "error") {
        setFailure(result.message ?? t("app.common.errorGeneric"));
        return;
      }
      setDirty(false);
      setSaved(true);
    });
  }

  // Cmd+S enregistre, Cmd+B et Cmd+I marquent. Un document qui ne répond pas aux raccourcis
  // d'un traitement de texte n'est pas un document.
  function onKeyDown(event: React.KeyboardEvent) {
    if (!(event.metaKey || event.ctrlKey)) return;
    const key = event.key.toLowerCase();
    if (key === "s") {
      event.preventDefault();
      if (dirty) save();
      return;
    }
    if (key === "b") {
      event.preventDefault();
      mark("bold");
      return;
    }
    if (key === "i") {
      event.preventDefault();
      mark("italic");
    }
  }

  return (
    <div>
      {readOnly ? null : (
        <div
          className="panel sticky top-2 z-20 mb-5 flex flex-wrap items-center gap-1.5 p-2"
          data-print="hide"
        >
          <select
            value={style}
            onChange={(event) => setBlockStyle(event.target.value as Style)}
            aria-label={t("app.sheet.style")}
            className="h-9 rounded-button bg-surface-muted px-2.5 text-[13.5px] font-medium text-ink outline-none"
          >
            <option value="h1">{t("app.sheet.styleTitle")}</option>
            <option value="h2">{t("app.sheet.styleSubtitle")}</option>
            <option value="p">{t("app.sheet.styleBody")}</option>
            <option value="ul">{t("app.sheet.styleBullets")}</option>
            <option value="ol">{t("app.sheet.styleNumbers")}</option>
          </select>

          <span aria-hidden className="mx-1 h-5 w-px bg-stroke" />

          <ToolButton label={t("app.sheet.bold")} onPress={() => mark("bold")}>
            <span className="text-[15px] font-bold">B</span>
          </ToolButton>
          <ToolButton label={t("app.sheet.italic")} onPress={() => mark("italic")}>
            <span className="text-[15px] font-serif italic">I</span>
          </ToolButton>

          <span aria-hidden className="mx-1 h-5 w-px bg-stroke" />

          {SHEET_HIGHLIGHTS.map((color) => (
            <button
              key={color}
              type="button"
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => highlight(color)}
              title={t(HIGHLIGHT_LABEL[color])}
              aria-label={t(HIGHLIGHT_LABEL[color])}
              className="pressable h-7 w-7 rounded-full border border-stroke-strong transition-transform duration-hover hover:scale-110"
              style={{ backgroundColor: `var(--color-hl-${color})` }}
            />
          ))}

          {tool ? (
            <>
              <span aria-hidden className="mx-1 h-5 w-px bg-stroke" />
              {tool}
            </>
          ) : null}

          <span className="flex-1" />

          {failure ? (
            <p className="text-[12.5px] text-negative" role="alert">
              {failure}
            </p>
          ) : saved ? (
            <p className="text-[12.5px] text-ink-tertiary" role="status">
              {t("app.sheet.saved")}
            </p>
          ) : null}

          <Button size="sm" disabled={!dirty || pending} onClick={save}>
            {pending ? t("app.sheet.saving") : t("app.sheet.save")}
          </Button>
        </div>
      )}

      <div
        ref={editor}
        className="sheet-doc text-ink-reading"
        contentEditable={!readOnly}
        suppressContentEditableWarning
        spellCheck={false}
        onInput={touched}
        onKeyDown={onKeyDown}
        onKeyUp={readStyle}
        onMouseUp={readStyle}
        role={readOnly ? undefined : "textbox"}
        aria-multiline={readOnly ? undefined : true}
        aria-label={readOnly ? undefined : t("app.sheet.aria")}
      />

      <Formulas root={editor} blocks={blocks} />
    </div>
  );
}

function ToolButton({
  label,
  onPress,
  children,
}: {
  label: string;
  onPress: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      // Sans ça, le clic vide la sélection avant que la marque soit posée.
      onMouseDown={(event) => event.preventDefault()}
      onClick={onPress}
      title={label}
      aria-label={label}
      className="pressable flex h-9 w-9 items-center justify-center rounded-button text-ink transition-colors duration-hover hover:bg-surface-muted"
    >
      {children}
    </button>
  );
}

/**
 * Les formules, composées **dans** le document.
 *
 * Le document est monté à la main et React n'y touche plus ; une formule doit pourtant être
 * rendue par KaTeX, qui est un composant. On les porte donc dans des portails, un par bloc
 * `data-formula`, ce qui laisse le document maître de sa structure et React maître du rendu
 * mathématique. Le LaTeX vit dans l'attribut : c'est lui qui sera enregistré, et il survit à
 * tout ce que l'étudiant peut faire autour.
 */
function Formulas({
  root,
  blocks,
}: {
  root: React.RefObject<HTMLDivElement | null>;
  blocks: SheetBlock[];
}) {
  const [nodes, setNodes] = useState<{ node: HTMLElement; latex: string; caption?: string }[]>([]);

  useEffect(() => {
    if (!root.current) return;
    const found = Array.from(root.current.querySelectorAll<HTMLElement>("[data-formula]")).map(
      (node) => ({
        node,
        latex: node.dataset.latex ?? "",
        caption: node.dataset.caption || undefined,
      }),
    );
    setNodes(found);
  }, [root, blocks]);

  return (
    <>
      {nodes.map((entry, index) => (
        <FormulaPortal key={index} {...entry} />
      ))}
    </>
  );
}

function FormulaPortal({
  node,
  latex,
  caption,
}: {
  node: HTMLElement;
  latex: string;
  caption?: string;
}) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    node.replaceChildren();
    setReady(true);
  }, [node]);

  if (!ready) return null;

  return createPortal(
    <div className="rounded-group bg-surface-muted px-5 py-4">
      <MathBlock latex={latex} />
      {caption ? <p className="mt-2 text-[13px] text-ink-tertiary">{caption}</p> : null}
    </div>,
    node,
  );
}

function placeCaretAtEnd(node: HTMLElement): void {
  const range = document.createRange();
  range.selectNodeContents(node);
  range.collapse(false);
  const selection = window.getSelection();
  selection?.removeAllRanges();
  selection?.addRange(range);
}
