#!/usr/bin/env python3
"""
**Les systèmes scolaires de l'app Android, tirés de ceux de l'iPhone.**

L'iPhone décrit chaque pays filière par filière et année par année, dans la langue du pays
(`Micabo/Features/Onboarding/SchoolSystem.swift` et `SchoolSystemWorld.swift`). Ce script
recopie ces données en Kotlin, à l'identique, dans
`android/app/src/main/java/com/micabo/app/onboarding/SchoolSystemData.kt` : les mêmes
identifiants (`fr.terminale`), les mêmes titres, les mêmes matières et les mêmes examens. Le
serveur calibre les cours sur ces identifiants (`supabase/functions/_shared/calibration.ts`).

Relancer après une modification côté iPhone :

    python3 android/tools/generate_school_systems.py
"""
from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SWIFT = ROOT / "Micabo" / "Features" / "Onboarding"
OUT = ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "micabo" / "app" / "onboarding" / "SchoolSystemData.kt"

ENUMS = {
    "lycee", "prepa", "licence", "master", "sante", "concours", "other",
    "lowerSecondary", "upperSecondary", "preUniversity", "undergraduate", "graduate", "health", "competitive",
}


def strip_comments(text: str) -> str:
    out = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        out.append(line)
    return "\n".join(out)


def balanced(text: str, start: int, open_char: str, close_char: str) -> int:
    """L'indice du caractère qui ferme celui ouvert en `start` (hors chaînes)."""
    depth = 0
    i = start
    in_string = False
    while i < len(text):
        c = text[i]
        if in_string:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_string = False
        elif c == '"':
            in_string = True
        elif c == open_char:
            depth += 1
        elif c == close_char:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("non fermé")


def convert(body: str) -> str:
    """Une expression Swift de données → la même en Kotlin."""
    strings: list[str] = []

    def keep(match: re.Match) -> str:
        literal = match.group(0)
        # `\(x)` → `${x}`, `$0` → `it`.
        literal = re.sub(r"\\\(\$0\)", "${it}", literal)
        literal = re.sub(r"\\\((\w+)\)", r"${\1}", literal)
        strings.append(literal)
        return f"\u0000{len(strings) - 1}\u0000"

    text = re.sub(r'"(?:[^"\\]|\\.)*"', keep, body)
    # Les intervalles et leurs `map` (l'Allemagne).
    text = re.sub(r"\((\d+)\.\.\.(\d+)\)\.map \{", r"(\1..\2).map {", text)
    text = re.sub(r"\$0 == (\d+) \? \[([^\]]*)\] : \[\]", r"if (it == \1) listOf(\2) else listOf()", text)
    # Un dictionnaire d'examens par année (`[2: ["dk.x"]]`).
    text = re.sub(r"\[(\d+): \[", r"mapOf(\1 to [", text)
    # Les tableaux deviennent des listes.
    text = text.replace("[", "listOf(").replace("]", ")")
    # Les arguments nommés.
    text = re.sub(r"\b([a-zA-Z]+): ", r"\1 = ", text)
    # Les cas d'énumération deviennent des chaînes.
    text = re.sub(r"(?<![\w.])\.(\w+)\b", lambda m: f'"{m.group(1)}"' if m.group(1) in ENUMS else m.group(0), text)
    return re.sub("\u0000(\\d+)\u0000", lambda m: strings[int(m.group(1))], text)


def blocks(text: str) -> list[tuple[str, str]]:
    """Les `static let nom = [...]` d'un fichier, convertis."""
    out = []
    for match in re.finditer(r"static let (\w+)(?:: [^=]+)? = \[", text):
        name = match.group(1)
        if name == "describedRegions":
            continue
        start = match.end() - 1
        end = balanced(text, start, "[", "]")
        out.append((name, convert(text[start:end + 1])))
    return out


def function_body(text: str, signature: str) -> str:
    start = text.index(signature)
    brace = text.index("{", start)
    end = balanced(text, brace, "{", "}")
    return text[brace + 1:end]


CODES = {"es419": "es-419", "pt": "pt-PT", "ptBR": "pt-BR"}


def subject_names() -> dict[str, dict[str, str]]:
    """{matière du catalogue: {langue de l'app: nom}} (`SubjectDisplay.subjects`)."""
    i18n = ROOT / "Micabo" / "Services" / "I18n"
    out: dict[str, dict[str, str]] = {}
    entry = re.compile(r'^\s*"([^"]+)": \[(.*)\],?\s*$')
    pair = re.compile(r'\.(\w+): "((?:[^"\\]|\\.)*)"')
    for path, table in ((i18n / "SubjectDisplay.swift", "baseSubjects"), (i18n / "Locales" / "I18n+Regional.swift", "regionalSubjects")):
        text = path.read_text(encoding="utf-8")
        start = text.index(f"static let {table}")
        end = balanced(text, text.index("[", text.index("=", start)), "[", "]")
        for line in text[start:end].splitlines():
            match = entry.match(line)
            if not match:
                continue
            for code, label in pair.findall(match.group(2)):
                out.setdefault(match.group(1), {}).setdefault(CODES.get(code, code), label)
    simple = re.compile(r'^\s*"([^"]+)": "((?:[^"\\]|\\.)*)",?\s*$')
    for code in ("nb", "he", "ja", "lt", "lv", "ko"):
        text = (i18n / "Locales" / f"I18n+{code}.swift").read_text(encoding="utf-8")
        start = text.index(f"static let {code}Subjects")
        end = balanced(text, text.index("[", text.index("=", start)), "[", "]")
        for line in text[start:end].splitlines():
            match = simple.match(line)
            if match:
                out.setdefault(match.group(1), {}).setdefault(code, match.group(2))
    return out


def main() -> None:
    system = strip_comments((SWIFT / "SchoolSystem.swift").read_text(encoding="utf-8"))
    world = strip_comments((SWIFT / "SchoolSystemWorld.swift").read_text(encoding="utf-8"))
    # Seule la partie des données : pas `SchoolSubjects`, écrit à la main.
    system = system[: system.index("enum SchoolSubjects")]

    cases = re.findall(r'case "([A-Z]{2})": (\w+)', world)
    switzerland = function_body(world, "private static func switzerland(german: Bool)")
    switzerland = convert(switzerland).replace("if german {", "if (german) {")

    lines = [
        "package com.micabo.app.onboarding",
        "",
        "// Engendré par android/tools/generate_school_systems.py depuis SchoolSystem.swift et",
        "// SchoolSystemWorld.swift. Ne pas éditer à la main : relancer le script.",
        "",
        "@Suppress(\"LargeClass\")",
        "internal object SchoolSystemData {",
        "    /** Les filières d'un pays décrit, par son code ISO en capitales. */",
        "    fun tracks(code: String, germanSwiss: Boolean): List<SchoolTrack> = when (code) {",
        '        "FR" -> france',
        '        "TR" -> turkey',
        '        "DE" -> germany',
        '        "ES" -> spain',
    ]
    for code, name in cases:
        if name.startswith("switzerland"):
            continue
        lines.append(f'        "{code}" -> {name}')
    lines.append('        "CH" -> switzerland(germanSwiss)')
    lines.append("        else -> emptyList()")
    lines.append("    }")
    lines.append("")
    lines.append(f"    val describedRegions: List<String> = listOf({', '.join(repr(c).replace(chr(39), chr(34)) for c in ['FR', 'TR', 'DE', 'ES'] + [c for c, _ in cases])})")
    lines.append("")
    lines.append("    private fun trLiseYears(prefix: String, subjects: List<String>): List<SchoolYear> = listOf(")
    lines.append('        SchoolYear("$prefix.9", "9. sınıf", subjects = subjects),')
    lines.append('        SchoolYear("$prefix.10", "10. sınıf", subjects = subjects),')
    lines.append('        SchoolYear("$prefix.11", "11. sınıf", subjects = subjects),')
    lines.append('        SchoolYear("$prefix.12", "12. sınıf", subjects = subjects + listOf("YKS"), exams = listOf("tr.yks")),')
    lines.append("    )")
    lines.append("")
    lines.append("    /** Une suite d'années aux mêmes matières, la dernière portant l'examen. */")
    lines.append("    private fun years(prefix: String, titles: List<String>, subjects: List<String> = emptyList(), lastExams: List<String> = emptyList(), exams: Map<Int, List<String>> = emptyMap()): List<SchoolYear> =")
    lines.append("        titles.mapIndexed { index, title ->")
    lines.append("            var yearExams = exams[index] ?: emptyList()")
    lines.append("            if (index == titles.size - 1) yearExams = lastExams + yearExams")
    lines.append('            SchoolYear("$prefix${index + 1}", title, subjects = subjects, exams = yearExams)')
    lines.append("        }")
    lines.append("")
    lines.append("    private fun track(id: String, title: String, emoji: String, level: String, tier: String, years: List<SchoolYear>, exams: List<String> = emptyList()): SchoolTrack =")
    lines.append("        SchoolTrack(id = id, title = title, emoji = emoji, level = level, tier = tier, years = years, exams = exams)")
    lines.append("")
    lines.append("    private fun switzerland(german: Boolean): List<SchoolTrack> {")
    lines.extend("    " + line for line in switzerland.strip("\n").splitlines())
    lines.append("    }")
    for source in (system, world):
        for name, body in blocks(source):
            lines.append("")
            lines.append(f"    private val {name} by lazy {{")
            lines.append("        " + body.strip())
            lines.append("    }")
    exams = strip_comments((SWIFT / "SchoolExams.swift").read_text(encoding="utf-8"))
    start = exams.index("private static let all: [SchoolExam] = [")
    bracket = exams.index("[", exams.index("=", start))
    lines.append("")
    lines.append("    /** Les examens de chaque pays, leur date habituelle (`SchoolExams.all`). */")
    lines.append("    val exams: List<SchoolExam> by lazy {")
    lines.append("        " + convert(exams[bracket:balanced(exams, bracket, "[", "]") + 1]).strip())
    lines.append("    }")
    lines.append("")
    lines.append("    /** Le nom d'une matière du catalogue dans chaque langue de l'app (`SubjectDisplay`). */")
    lines.append("    val subjectNames: Map<String, Map<String, String>> by lazy {")
    lines.append("        hashMapOf(")
    for name, labels in sorted(subject_names().items()):
        inner = ", ".join(f'"{k}" to "{v}"' for k, v in sorted(labels.items()))
        lines.append(f'            "{name}" to mapOf({inner}),')
    lines.append("        )")
    lines.append("    }")
    lines.append("}")
    text = "\n".join(lines) + "\n"
    # `private val x by lazy { listOf(...) }` : l'ordre de déclaration ne compte plus.
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)} : {len(cases) + 4} pays")


if __name__ == "__main__":
    main()
