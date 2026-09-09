"use client";

import { useCallback, useEffect, useRef, useState, useTransition } from "react";
import { createPortal } from "react-dom";

import { SHEET_HIGHLIGHTS, type SheetBlock, type SheetHighlight } from "@micabo/core";

import { Button } from "@/components/ui/button";
import { saveSheet } from "@/lib/actions/sheet";
import { useI18n } from "@/lib/i18n/client";
import { blocksToHtml, htmlToBlocks } from "@/lib/sheet/document";
import { READING_SIZES, readingStyle, type ReadingSize } from "@/lib/sheet/reading-size";
import { useReadingSize } from "@/lib/sheet/use-reading-size";

import { FormulaEditor, type FormulaDraft } from "./FormulaEditor";
import { currentBlock, toggleHighlight, toggleMark, type Mark } from "./marks";
import { MathBlock, MathInline } from "./Math";

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

const SIZE_LABEL: Record<ReadingSize, string> = {
  petit: "app.sheet.size.petit",
  normal: "app.sheet.size.normal",
  grand: "app.sheet.size.grand",
};

type Style = "h1" | "h2" | "p" | "ul" | "ol";

interface FormulaTarget {
  /** La formule qu'on rouvre, ou `null` pour une nouvelle. */
  node: HTMLElement | null;
  /** Le point d'insertion, figé au clic. */
  range: Range | null;
  draft: FormulaDraft;
}

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
  const [size, setSize] = useReadingSize();
  /**
   * La formule ouverte dans son éditeur, et **où elle va**.
   *
   * `node` est la formule déjà posée qu'on rouvre - le `div` d'un bloc, ou le `span` d'une
   * formule prise dans une phrase. Quand on en crée une, il n'y a pas encore de nœud : ce qui
   * compte alors est `range`, la sélection **telle qu'elle était au moment du clic**.
   *
   * C'est tout le bug qu'on répare ici. L'ancre était relue au moment d'appliquer, alors que
   * le curseur était depuis longtemps parti dans le champ de l'éditeur : on ne trouvait plus
   * de bloc courant, et la formule tombait en fin de document. Une formule doit se poser là
   * où on la demande.
   */
  const [editing, setEditing] = useState<FormulaTarget | null>(null);
  /** Change quand une formule est posée, corrigée ou retirée : les portails se refont. */
  const [formulaKey, setFormulaKey] = useState(0);
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

  /**
   * Le clic qui rouvre une formule, posé **à la main** sur le document.
   *
   * Un `onClick` de React ne suffit pas ici, et c'est ce qui rendait les formules déjà
   * écrites impossibles à corriger. Ce qu'on voit d'une formule est rendu dans un portail ;
   * or un évènement né dans un portail remonte l'arbre **React** - où le portail est un
   * frère du document - et non l'arbre du DOM. Le `div` de la fiche ne le voyait donc jamais.
   * Un écouteur natif, lui, suit le DOM : le portail est bien dans le document, et le clic
   * arrive.
   */
  useEffect(() => {
    const root = editor.current;
    if (!root || readOnly) return;

    function reopen(event: MouseEvent) {
      const target = event.target as HTMLElement | null;
      const formula = target?.closest?.("[data-formula],[data-math]");
      if (formula instanceof HTMLElement) openFormula(formula);
    }

    root.addEventListener("click", reopen);
    return () => root.removeEventListener("click", reopen);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [readOnly]);

  function touched() {
    setDirty(true);
    setSaved(false);
  }

  function mark(kind: Mark) {
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

  /**
   * Ouvre l'éditeur sur une formule déjà écrite.
   *
   * Les deux formes s'y rouvrent : le bloc posé seul (`data-formula`) et la formule prise
   * dans une phrase (`data-math`). C'est ce qui manquait : une écriture mathématique déjà
   * là ne se corrigeait pas, il fallait la supprimer et la refaire.
   */
  function openFormula(node: HTMLElement) {
    if (readOnly) return;
    const isInline = node.dataset.math !== undefined;
    setEditing({
      node,
      range: null,
      draft: {
        latex: (isInline ? node.dataset.math : node.dataset.latex) ?? "",
        caption: node.dataset.caption ?? "",
        inline: isInline,
      },
    });
  }

  /**
   * Une nouvelle formule, posée là où est le curseur.
   *
   * La sélection est **clonée maintenant** : le clic sur le bouton la garde (la barre
   * annule son `mousedown`), mais l'éditeur qui s'ouvre ensuite prend le focus et la
   * déplace. Ce clone est le seul souvenir fiable de l'endroit visé.
   *
   * Le défaut se choisit tout seul : le curseur est dans une phrase, donc la formule y
   * entre ; il n'y a pas de curseur, donc elle se pose seule à la fin.
   */
  function addFormula() {
    if (readOnly) return;
    const root = editor.current;
    const selection = window.getSelection();
    const live =
      selection && selection.rangeCount > 0 ? selection.getRangeAt(0) : null;
    const inside = live && root?.contains(live.commonAncestorContainer) ? live.cloneRange() : null;

    setEditing({
      node: null,
      range: inside,
      draft: { latex: "", caption: "", inline: inside !== null },
    });
  }

  /**
   * Écrit la formule : celle qu'on corrige, ou celle qu'on pose.
   *
   * Poser une formule en ligne, c'est l'écrire **dans la phrase**, à la place de la sélection.
   * Poser un bloc, c'est l'écrire après le paragraphe où était le curseur. Dans les deux cas
   * on part de `editing.range`, capturé à l'ouverture ; la fin du document n'est plus qu'un
   * dernier recours, quand rien ne disait où aller.
   *
   * Changer d'avis entre les deux formes remplace le nœud plutôt que de le réécrire : ce ne
   * sont pas les mêmes balises, et une formule en ligne dans un `div` ne se lirait pas.
   */
  function applyFormula(draft: FormulaDraft) {
    const root = editor.current;
    if (!root || readOnly || !editing) return;

    const previous = editing.node;
    const sameShape = previous !== null && (previous.dataset.math !== undefined) === draft.inline;
    const node = sameShape ? previous! : createFormulaNode(draft.inline);

    if (draft.inline) {
      node.dataset.math = draft.latex;
      node.removeAttribute("data-latex");
      node.removeAttribute("data-caption");
    } else {
      node.dataset.latex = draft.latex;
      node.dataset.caption = draft.caption;
      node.removeAttribute("data-math");
    }

    if (!sameShape) {
      if (previous) previous.replaceWith(node);
      else if (draft.inline) insertInline(root, node, editing.range);
      else insertBlock(root, node, editing.range);
    }

    setEditing(null);
    touched();
    // Le portail qui compose la formule se remonte sur le nouvel attribut.
    setFormulaKey((key) => key + 1);
  }

  function removeFormula() {
    editing?.node?.remove();
    setEditing(null);
    touched();
    setFormulaKey((key) => key + 1);
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
      return;
    }
    // Cmd+Maj+X : le raccourci du barré partout ailleurs.
    if (key === "x" && event.shiftKey) {
      event.preventDefault();
      mark("strike");
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
          <ToolButton label={t("app.sheet.strike")} onPress={() => mark("strike")}>
            <span className="text-[15px] line-through">S</span>
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

          <span aria-hidden className="mx-1 h-5 w-px bg-stroke" />

          <ToolButton label={t("app.formula.add")} onPress={addFormula}>
            <span className="text-[15px] font-serif">∑</span>
          </ToolButton>

          {/* La taille de lecture : elle n'entre pas dans la fiche, elle reste sur
              l'appareil. Elle est donc à droite des marques, séparée d'elles. */}
          <div
            role="group"
            aria-label={t("app.sheet.size.label")}
            className="flex items-center gap-0.5 rounded-button bg-surface-muted p-0.5"
          >
            {READING_SIZES.map((value, index) => (
              <button
                key={value}
                type="button"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => setSize(value)}
                aria-pressed={value === size}
                title={t(SIZE_LABEL[value])}
                aria-label={t(SIZE_LABEL[value])}
                className={`pressable flex h-8 w-8 items-center justify-center rounded-[calc(var(--radius-button)-2px)] font-semibold transition-colors duration-hover ${
                  value === size ? "bg-surface text-ink shadow-paper" : "text-ink-tertiary"
                }`}
                style={{ fontSize: `${11 + index * 2}px` }}
              >
                A
              </button>
            ))}
          </div>

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
        style={readingStyle(size)}
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

      <Formulas key={formulaKey} root={editor} blocks={blocks} />

      {editing ? (
        <FormulaEditor
          initial={editing.draft}
          onSave={applyFormula}
          onDelete={editing.node ? removeFormula : undefined}
          onClose={() => setEditing(null)}
        />
      ) : null}
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
 * rendue par KaTeX, qui est un composant. On les porte donc dans des portails, un par formule,
 * ce qui laisse le document maître de sa structure et React maître du rendu mathématique. Le
 * LaTeX vit dans l'attribut : c'est lui qui sera enregistré, et il survit à tout ce que
 * l'étudiant peut faire autour.
 *
 * Deux formes cohabitent : le bloc posé seul, encadré et légendé, et la formule prise dans
 * une phrase, qui doit tenir sur la ligne du texte sans la faire respirer autrement.
 */
function Formulas({
  root,
  blocks,
}: {
  root: React.RefObject<HTMLDivElement | null>;
  blocks: SheetBlock[];
}) {
  const [nodes, setNodes] = useState<
    { node: HTMLElement; latex: string; caption?: string; inline: boolean }[]
  >([]);

  useEffect(() => {
    if (!root.current) return;
    const found = Array.from(
      root.current.querySelectorAll<HTMLElement>("[data-formula],[data-math]"),
    ).map((node) => {
      const inline = node.dataset.math !== undefined;
      return {
        node,
        inline,
        latex: (inline ? node.dataset.math : node.dataset.latex) ?? "",
        caption: inline ? undefined : node.dataset.caption || undefined,
      };
    });
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
  inline,
}: {
  node: HTMLElement;
  latex: string;
  caption?: string;
  inline: boolean;
}) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    node.replaceChildren();
    setReady(true);
  }, [node]);

  if (!ready) return null;

  if (inline) {
    return createPortal(
      <span className="cursor-pointer rounded-[6px] px-[3px] transition-colors duration-hover hover:bg-surface-muted">
        <MathInline latex={latex} />
      </span>,
      node,
    );
  }

  return createPortal(
    <div className="rounded-group bg-surface-muted px-5 py-4">
      <MathBlock latex={latex} />
      {caption ? <p className="mt-2 text-[13px] text-ink-tertiary">{caption}</p> : null}
    </div>,
    node,
  );
}

/** L'enveloppe d'une formule : un `span` dans la phrase, un `div` posé seul. */
function createFormulaNode(inline: boolean): HTMLElement {
  const node = document.createElement(inline ? "span" : "div");
  if (!inline) node.setAttribute("data-formula", "");
  // Une formule est composée : on la corrige par son LaTeX, pas en tapant au milieu des
  // symboles rendus.
  node.setAttribute("contenteditable", "false");
  return node;
}

/**
 * Glisse une formule dans la phrase, à la place de la sélection.
 *
 * L'espace qui suit n'est pas un détail : sans lui, une formule posée en fin de paragraphe
 * ferme le paragraphe sur un élément non modifiable, et le curseur n'a plus où se poser pour
 * écrire la suite. Il est retiré à l'enregistrement, qui coupe les bords.
 */
function insertInline(root: HTMLElement, node: HTMLElement, range: Range | null): void {
  if (!range || !root.contains(range.commonAncestorContainer)) {
    appendToLastBlock(root, node);
  } else {
    // Le `<br>` d'un bloc vide n'a plus lieu d'être une fois qu'il porte quelque chose.
    const host = blockOf(root, range.startContainer);
    range.deleteContents();
    range.insertNode(node);
    if (host && host.childNodes.length > 1) host.querySelector(":scope > br")?.remove();
  }

  const tail = document.createTextNode("\u00a0");
  node.after(tail);
  const after = document.createRange();
  after.setStart(tail, tail.length);
  after.collapse(true);
  const selection = window.getSelection();
  selection?.removeAllRanges();
  selection?.addRange(after);
}

/** Pose une formule seule, juste après le bloc où était le curseur. */
function insertBlock(root: HTMLElement, node: HTMLElement, range: Range | null): void {
  const anchor = range && root.contains(range.commonAncestorContainer)
    ? blockOf(root, range.startContainer)
    : null;
  if (anchor) anchor.after(node);
  else root.appendChild(node);
}

/** Le bloc de premier niveau qui contient ce nœud. */
function blockOf(root: HTMLElement, node: Node): HTMLElement | null {
  let cursor: Node | null = node;
  while (cursor && cursor.parentNode !== root) cursor = cursor.parentNode;
  return cursor instanceof HTMLElement ? cursor : null;
}

/** Le dernier recours : la formule rejoint la fin du dernier paragraphe, ou un nouveau. */
function appendToLastBlock(root: HTMLElement, node: HTMLElement): void {
  const last = root.lastElementChild;
  const host = last instanceof HTMLElement && last.dataset.formula === undefined
    ? last
    : root.appendChild(document.createElement("p"));
  host.querySelector(":scope > br")?.remove();
  host.appendChild(node);
}

function placeCaretAtEnd(node: HTMLElement): void {
  const range = document.createRange();
  range.selectNodeContents(node);
  range.collapse(false);
  const selection = window.getSelection();
  selection?.removeAllRanges();
  selection?.addRange(range);
}
