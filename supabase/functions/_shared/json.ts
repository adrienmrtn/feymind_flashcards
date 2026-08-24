/**
 * Lecture du JSON renvoyé par un modèle.
 *
 * Les LLM produisent un JSON « presque » valide : virgule oubliée, deux-points
 * manquant, antislash de LaTeX non doublé, guillemet dans une phrase. `JSON.parse`
 * refuse tout. On répare ce qui est réparable, on échoue seulement si ça reste
 * illisible.
 */

const VALID_ESCAPE = new Set(["\"", "\\", "/", "b", "f", "n", "r", "t", "u"]);

/** Premier objet ou tableau, même entouré de prose ou de balises ```json. */
export function extractJSONCandidate(output: string): string {
  let text = output.trim();
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced) text = fenced[1].trim();

  const firstBrace = text.indexOf("{");
  const firstBracket = text.indexOf("[");
  const start = firstBrace === -1
    ? firstBracket
    : firstBracket === -1
    ? firstBrace
    : Math.min(firstBrace, firstBracket);

  if (start === -1) {
    throw new Error("Le modèle n'a pas renvoyé de JSON.");
  }

  const slice = text.slice(start);
  const balanced = sliceBalanced(slice);
  return balanced ?? slice;
}

export function parseModelJSON<T>(output: string): T {
  const candidate = extractJSONCandidate(output);
  const attempts = [
    candidate,
    repairModelJSON(candidate),
    closeOpenStructures(candidate),
    closeOpenStructures(repairModelJSON(candidate)),
  ];

  let lastError: Error = new Error("JSON invalide.");
  for (const attempt of attempts) {
    try {
      return JSON.parse(attempt) as T;
    } catch (error) {
      lastError = error as Error;
    }
  }
  throw lastError;
}

/** Répare les fautes que les modèles font le plus souvent dans un JSON. */
export function repairModelJSON(source: string): string {
  let text = source;
  text = stripComments(text);
  text = repairStrings(text);
  text = quoteUnquotedKeys(text);
  text = insertMissingPunctuation(text);
  text = text.replace(/\}\s*\{/g, "},{");
  text = text.replace(/\]\s*\[/g, "],[");
  text = removeTrailingCommas(text);
  return text;
}

/**
 * Recolle un JSON coupé en fin de génération (limite de jetons).
 *
 * C'est le cas « Expected ',' or ']' after array element » à la ligne 500 :
 * le modèle a été interrompu au milieu de `blocks`. On referme les chaînes
 * et les crochets, et on jette la dernière propriété inachevée.
 */
export function closeOpenStructures(source: string): string {
  let text = source.trim();
  if (text.length === 0) return text;

  const first = scanStructure(text);
  if (first.inString) text += "\"";

  text = stripIncompleteTail(text);

  const next = scanStructure(text);
  for (let index = next.stack.length - 1; index >= 0; index--) {
    text += next.stack[index] === "{" ? "}" : "]";
  }
  return text;
}

function scanStructure(text: string): { inString: boolean; stack: Array<"{" | "["> } {
  const stack: Array<"{" | "["> = [];
  let inString = false;
  let escape = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      if (escape) escape = false;
      else if (ch === "\\") escape = true;
      else if (ch === "\"") inString = false;
      continue;
    }
    if (ch === "\"") {
      inString = true;
      continue;
    }
    if (ch === "{") stack.push("{");
    else if (ch === "[") stack.push("[");
    else if (ch === "}" && stack[stack.length - 1] === "{") stack.pop();
    else if (ch === "]" && stack[stack.length - 1] === "[") stack.pop();
  }

  return { inString, stack };
}

function stripIncompleteTail(text: string): string {
  let current = text.replace(/[\s,]+$/, "");
  let previous = "";

  while (current !== previous) {
    previous = current;
    current = current
      .replace(/,\s*$/, "")
      .replace(/,\s*\{\s*$/, "")
      .replace(/,\s*\[\s*$/, "")
      .replace(/,\s*"[^"\\]*"\s*:\s*$/, "")
      .replace(/,\s*"[^"\\]*"\s*$/, "")
      .replace(/:\s*$/, "");
  }

  return current;
}

function sliceBalanced(text: string): string | null {
  if (text[0] !== "{" && text[0] !== "[") return null;

  const stack: string[] = [];
  let inString = false;
  let escape = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      if (escape) escape = false;
      else if (ch === "\\") escape = true;
      else if (ch === "\"") inString = false;
      continue;
    }
    if (ch === "\"") {
      inString = true;
      continue;
    }
    if (ch === "{" || ch === "[") {
      stack.push(ch === "{" ? "}" : "]");
      continue;
    }
    if (ch === "}" || ch === "]") {
      if (stack[stack.length - 1] !== ch) continue;
      stack.pop();
      if (stack.length === 0) return text.slice(0, i + 1);
    }
  }

  return null;
}

function stripComments(text: string): string {
  let out = "";
  let i = 0;
  let inString = false;
  let escape = false;

  while (i < text.length) {
    const ch = text[i];
    const next = text[i + 1];

    if (inString) {
      out += ch;
      if (escape) escape = false;
      else if (ch === "\\") escape = true;
      else if (ch === "\"") inString = false;
      i++;
      continue;
    }

    if (ch === "\"") {
      inString = true;
      out += ch;
      i++;
      continue;
    }

    if (ch === "/" && next === "/") {
      while (i < text.length && text[i] !== "\n") i++;
      continue;
    }
    if (ch === "/" && next === "*") {
      i += 2;
      while (i < text.length && !(text[i] === "*" && text[i + 1] === "/")) i++;
      i += 2;
      continue;
    }

    out += ch;
    i++;
  }

  return out;
}

function repairStrings(text: string): string {
  let out = "";
  let i = 0;

  while (i < text.length) {
    if (text[i] === "\"") {
      const repaired = takeString(text, i);
      out += repaired.value;
      i = repaired.end;
      continue;
    }
    out += text[i];
    i++;
  }

  return out;
}

function takeString(text: string, start: number): { value: string; end: number } {
  let out = "\"";
  let i = start + 1;

  while (i < text.length) {
    const ch = text[i];

    if (ch === "\\") {
      const next = text[i + 1];
      if (next === undefined) {
        out += "\\\\";
        i++;
        continue;
      }
      if (VALID_ESCAPE.has(next)) {
        out += ch + next;
        i += 2;
        if (next === "u") {
          const hex = text.slice(i, i + 4);
          if (/^[0-9a-fA-F]{4}$/.test(hex)) {
            out += hex;
            i += 4;
          }
        }
        continue;
      }
      out += "\\\\" + next;
      i += 2;
      continue;
    }

    if (ch === "\n" || ch === "\r") {
      out += "\\n";
      i++;
      if (ch === "\r" && text[i] === "\n") i++;
      continue;
    }

    if (ch === "\t") {
      out += "\\t";
      i++;
      continue;
    }

    if (ch === "\"") {
      const follower = nextNonWhitespace(text, i + 1);
      if (follower === "" || ",}]:".includes(follower)) {
        out += "\"";
        return { value: out, end: i + 1 };
      }
      if (follower === "\"") {
        out += "\"";
        return { value: out, end: i + 1 };
      }
      out += "\\\"";
      i++;
      continue;
    }

    out += ch;
    i++;
  }

  out += "\"";
  return { value: out, end: text.length };
}

function nextNonWhitespace(text: string, from: number): string {
  for (let i = from; i < text.length; i++) {
    if (!/\s/.test(text[i])) return text[i];
  }
  return "";
}

function quoteUnquotedKeys(text: string): string {
  return text.replace(/([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:/g, (match, prefix, key) => {
    if (key === "true" || key === "false" || key === "null") return match;
    return `${prefix}"${key}":`;
  });
}

function removeTrailingCommas(text: string): string {
  return text.replace(/,(\s*[}\]])/g, "$1");
}

/**
 * Insère les `:` et `,` oubliés, hors des chaînes.
 *
 * C'est le cas de « after property name » : `"type" "paragraph"` au lieu de
 * `"type": "paragraph"`, ou deux propriétés collées sans virgule.
 */
function insertMissingPunctuation(text: string): string {
  let out = "";
  let i = 0;
  let inString = false;
  let escape = false;
  /** Ce qu'on attend à l'extérieur d'une chaîne. */
  let expect: "value" | "key-or-end" | "colon" | "comma-or-end" = "value";
  const stack: Array<"object" | "array"> = [];

  const setExpectAfterOpen = (kind: "object" | "array") => {
    expect = kind === "object" ? "key-or-end" : "value";
  };

  while (i < text.length) {
    const ch = text[i];

    if (inString) {
      out += ch;
      if (escape) escape = false;
      else if (ch === "\\") escape = true;
      else if (ch === "\"") inString = false;
      i++;
      continue;
    }

    if (/\s/.test(ch)) {
      out += ch;
      i++;
      continue;
    }

    if (ch === "\"") {
      if (expect === "colon") {
        out += ":";
        expect = "value";
      } else if (expect === "comma-or-end") {
        out += ",";
        expect = stack[stack.length - 1] === "object" ? "key-or-end" : "value";
      }

      inString = true;
      out += ch;
      if (expect === "key-or-end") expect = "colon";
      else if (expect === "value") expect = "comma-or-end";
      i++;
      continue;
    }

    if (ch === "{") {
      if (expect === "colon") {
        out += ":";
      } else if (expect === "comma-or-end") {
        out += ",";
      }
      stack.push("object");
      setExpectAfterOpen("object");
      out += ch;
      i++;
      continue;
    }

    if (ch === "[") {
      if (expect === "colon") {
        out += ":";
      } else if (expect === "comma-or-end") {
        out += ",";
      }
      stack.push("array");
      setExpectAfterOpen("array");
      out += ch;
      i++;
      continue;
    }

    if (ch === "}" || ch === "]") {
      stack.pop();
      expect = "comma-or-end";
      out += ch;
      i++;
      continue;
    }

    if (ch === ":") {
      expect = "value";
      out += ch;
      i++;
      continue;
    }

    if (ch === ",") {
      expect = stack[stack.length - 1] === "object" ? "key-or-end" : "value";
      out += ch;
      i++;
      continue;
    }

    // Nombre, true, false, null.
    if (expect === "colon") {
      out += ":";
      expect = "value";
    } else if (expect === "comma-or-end") {
      out += ",";
      expect = "value";
    }

    out += ch;
    if (expect === "value" || expect === "key-or-end") {
      while (i + 1 < text.length && /[A-Za-z0-9.+-]/.test(text[i + 1])) {
        i++;
        out += text[i];
      }
      expect = "comma-or-end";
    }
    i++;
  }

  return out;
}
