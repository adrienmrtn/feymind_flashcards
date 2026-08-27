/**
 * Transposition LaTeX → Unicode, portée depuis `FormulaRenderer` iOS.
 *
 * Micabo n'embarque pas de moteur mathématique. Les commandes qui fuient dans une
 * carte — `1914 \rightarrow 1918` — doivent quand même se lire. Les fragments `$…$`
 * passent par le mode formule (fractions, indices, grec) ; le texte nu ne convertit
 * que les commandes, pour ne pas transformer un `_` de phrase en indice.
 */

const SYMBOLS: Record<string, string> = {
  "\\times": "×",
  "\\div": "÷",
  "\\pm": "±",
  "\\mp": "∓",
  "\\cdot": "·",
  "\\leq": "≤",
  "\\geq": "≥",
  "\\neq": "≠",
  "\\approx": "≈",
  "\\equiv": "≡",
  "\\propto": "∝",
  "\\sim": "∼",
  "\\infty": "∞",
  "\\degree": "°",
  "\\circ": "∘",
  "\\rightarrow": "→",
  "\\to": "→",
  "\\leftarrow": "←",
  "\\Rightarrow": "⇒",
  "\\Leftrightarrow": "⇔",
  "\\iff": "⇔",
  "\\mapsto": "↦",
  "\\sum": "∑",
  "\\prod": "∏",
  "\\int": "∫",
  "\\partial": "∂",
  "\\nabla": "∇",
  "\\in": "∈",
  "\\notin": "∉",
  "\\forall": "∀",
  "\\exists": "∃",
  "\\cup": "∪",
  "\\cap": "∩",
  "\\subset": "⊂",
  "\\supset": "⊃",
  "\\emptyset": "∅",
  "\\ldots": "…",
  "\\dots": "…",
  "\\cdots": "⋯",
  "\\angle": "∠",
  "\\perp": "⊥",
  "\\alpha": "α",
  "\\beta": "β",
  "\\gamma": "γ",
  "\\delta": "δ",
  "\\epsilon": "ε",
  "\\varepsilon": "ε",
  "\\zeta": "ζ",
  "\\eta": "η",
  "\\theta": "θ",
  "\\iota": "ι",
  "\\kappa": "κ",
  "\\lambda": "λ",
  "\\mu": "μ",
  "\\nu": "ν",
  "\\xi": "ξ",
  "\\pi": "π",
  "\\rho": "ρ",
  "\\sigma": "σ",
  "\\tau": "τ",
  "\\upsilon": "υ",
  "\\phi": "φ",
  "\\varphi": "φ",
  "\\chi": "χ",
  "\\psi": "ψ",
  "\\omega": "ω",
  "\\Gamma": "Γ",
  "\\Delta": "Δ",
  "\\Theta": "Θ",
  "\\Lambda": "Λ",
  "\\Xi": "Ξ",
  "\\Pi": "Π",
  "\\Sigma": "Σ",
  "\\Phi": "Φ",
  "\\Psi": "Ψ",
  "\\Omega": "Ω",
  "\\mathbb{R}": "ℝ",
  "\\mathbb{N}": "ℕ",
  "\\mathbb{Z}": "ℤ",
  "\\mathbb{Q}": "ℚ",
  "\\mathbb{C}": "ℂ",
};

const SORTED_COMMANDS = Object.keys(SYMBOLS).sort((a, b) => b.length - a.length);

const SUPERSCRIPTS: Record<string, string> = {
  "0": "⁰",
  "1": "¹",
  "2": "²",
  "3": "³",
  "4": "⁴",
  "5": "⁵",
  "6": "⁶",
  "7": "⁷",
  "8": "⁸",
  "9": "⁹",
  "+": "⁺",
  "-": "⁻",
  "=": "⁼",
  "(": "⁽",
  ")": "⁾",
  a: "ᵃ",
  b: "ᵇ",
  c: "ᶜ",
  d: "ᵈ",
  e: "ᵉ",
  f: "ᶠ",
  g: "ᵍ",
  h: "ʰ",
  i: "ⁱ",
  j: "ʲ",
  k: "ᵏ",
  l: "ˡ",
  m: "ᵐ",
  n: "ⁿ",
  o: "ᵒ",
  p: "ᵖ",
  r: "ʳ",
  s: "ˢ",
  t: "ᵗ",
  u: "ᵘ",
  v: "ᵛ",
  w: "ʷ",
  x: "ˣ",
  y: "ʸ",
  z: "ᶻ",
};

const SUBSCRIPTS: Record<string, string> = {
  "0": "₀",
  "1": "₁",
  "2": "₂",
  "3": "₃",
  "4": "₄",
  "5": "₅",
  "6": "₆",
  "7": "₇",
  "8": "₈",
  "9": "₉",
  "+": "₊",
  "-": "₋",
  "=": "₌",
  "(": "₍",
  ")": "₎",
  a: "ₐ",
  e: "ₑ",
  h: "ₕ",
  i: "ᵢ",
  j: "ⱼ",
  k: "ₖ",
  l: "ₗ",
  m: "ₘ",
  n: "ₙ",
  o: "ₒ",
  p: "ₚ",
  r: "ᵣ",
  s: "ₛ",
  t: "ₜ",
  u: "ᵤ",
  v: "ᵥ",
  x: "ₓ",
};

/** Remplace uniquement les commandes connues. Un texte de carte y passe tout entier. */
export function latexCommandsToUnicode(source: string): string {
  if (!source.includes("\\")) return source;

  let output = "";
  let index = 0;

  while (index < source.length) {
    if (source[index] === "\\") {
      const match = matchCommand(source, index);
      if (match) {
        output += match.symbol;
        index = match.end;
        const next = source[index];
        const after = source[index + 1] ?? "";
        if (match.absorbsSpace && next === " " && isLetterOrDigit(after)) {
          index += 1;
        }
        continue;
      }
    }

    output += source[index];
    index += 1;
  }

  return output;
}

/**
 * Transpose un fragment de formule : fractions, racines, commandes, exposants.
 * C'est le mode des `$…$` et des blocs `formula`.
 */
export function latexToUnicode(source: string): string {
  let text = replacingFractions(source);
  text = replacingRoots(text);
  text = latexCommandsToUnicode(text);
  text = replacingScripts(text, "^", SUPERSCRIPTS);
  text = replacingScripts(text, "_", SUBSCRIPTS);
  text = strippingMarkup(text);
  return text.replace(/ {2,}/g, " ").trim();
}

function matchCommand(
  source: string,
  index: number,
): { symbol: string; end: number; absorbsSpace: boolean } | null {
  for (const name of SORTED_COMMANDS) {
    if (!source.startsWith(name, index)) continue;
    const symbol = SYMBOLS[name]!;
    const isLetter = [...symbol].length === 1 && /\p{L}/u.test(symbol);
    return { symbol, end: index + name.length, absorbsSpace: isLetter };
  }
  return null;
}

function replacingFractions(source: string): string {
  let output = "";
  let index = 0;

  while (index < source.length) {
    if (source.startsWith("\\frac", index)) {
      const numerator = braceGroup(source, index + 5);
      const denominator = numerator ? braceGroup(source, numerator.end) : null;
      if (numerator && denominator) {
        const top = latexToUnicode(numerator.content);
        const bottom = latexToUnicode(denominator.content);
        output += `${wrapped(top)}/${wrapped(bottom)}`;
        index = denominator.end;
        continue;
      }
    }
    output += source[index];
    index += 1;
  }

  return output;
}

function replacingRoots(source: string): string {
  let output = "";
  let index = 0;

  while (index < source.length) {
    if (source.startsWith("\\sqrt", index)) {
      const group = braceGroup(source, index + 5);
      if (group) {
        output += `√${wrapped(latexToUnicode(group.content))}`;
        index = group.end;
        continue;
      }
    }
    output += source[index];
    index += 1;
  }

  return output;
}

function replacingScripts(source: string, marker: string, map: Record<string, string>): string {
  let output = "";
  let index = 0;

  while (index < source.length) {
    if (source[index] === marker && index + 1 < source.length) {
      let content: string;
      let next: number;
      if (source[index + 1] === "{") {
        const group = braceGroup(source, index + 1);
        if (!group) {
          output += source[index];
          index += 1;
          continue;
        }
        content = group.content;
        next = group.end;
      } else {
        content = source[index + 1]!;
        next = index + 2;
      }

      const converted = convertScript(content, map);
      output += converted ?? `${marker}(${content})`;
      index = next;
      continue;
    }

    output += source[index];
    index += 1;
  }

  return output;
}

function convertScript(content: string, map: Record<string, string>): string | null {
  let result = "";
  for (const character of content) {
    const replacement = map[character];
    if (!replacement) return null;
    result += replacement;
  }
  return result.length > 0 ? result : null;
}

function strippingMarkup(source: string): string {
  let text = source;
  for (const noise of ["\\left", "\\right", "\\displaystyle", "\\text", "\\mathrm"]) {
    text = text.split(noise).join("");
  }
  text = text.replace(/\\[,;! ]/g, " ");
  return text.replace(/[{}\\]/g, "");
}

function braceGroup(source: string, index: number): { content: string; end: number } | null {
  if (source[index] !== "{") return null;

  let depth = 0;
  let content = "";
  let cursor = index;

  while (cursor < source.length) {
    const character = source[cursor]!;
    if (character === "{") {
      depth += 1;
      if (depth === 1) {
        cursor += 1;
        continue;
      }
    } else if (character === "}") {
      depth -= 1;
      if (depth === 0) return { content, end: cursor + 1 };
    }
    content += character;
    cursor += 1;
  }

  return null;
}

function wrapped(term: string): string {
  const needsParentheses = term.length > 1 && /[ +\-*/=]/.test(term);
  return needsParentheses ? `(${term})` : term;
}

function isLetterOrDigit(value: string): boolean {
  return /\p{L}|\p{N}/u.test(value);
}
