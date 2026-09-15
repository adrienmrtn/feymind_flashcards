#!/usr/bin/env python3
"""**Deux fautes de Swift qui ne se voient qu'au build, et qu'on peut lire sans compilateur.**

Ce dépôt se développe souvent sans chaîne Swift — la compilation se fait dans Xcode Cloud.
Les tests de parité (`exam-agenda-parity`, `sheet-parity`) couvrent déjà la divergence entre
les deux copies de la même règle. Il restait une classe d'erreur que rien ne rattrapait, et
elle a coûté un build entier :

    @Observable
    @MainActor
    /// La documentation d'une struct qu'on vient d'insérer là.
    struct MaStruct { … }

    final class MonService { … }

Les deux attributs qualifient désormais la struct. Le service perd `@Observable`, donc
`@Environment(MonService.self)` ne compile plus dans **chaque** écran qui l'injecte ; il perd
`@MainActor`, donc ses accès à l'état isolé deviennent des erreurs ; et la struct, devenue
observable, perd son initialiseur membre à membre et sa conformance `Codable`. Une seule
insertion mal placée, vingt erreurs réparties sur six fichiers, et aucune ne nomme la cause.

Le contrôle est textuel et volontairement étroit : il ne comprend pas Swift, il vérifie deux
invariants qu'un humain vérifierait à l'œil s'il pensait à regarder.

    python3 scripts/swift-attributes.py

Sortie non nulle s'il trouve quelque chose.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "Micabo"

#: Le début d'une déclaration réelle, attributs et modificateurs sautés.
DECL = re.compile(
    r"^\s*(?:public |internal |private |fileprivate |final |@\w+(?:\([^)]*\))? )*"
    r"(class|actor|struct|enum|extension|protocol|func|var|let)\b"
)

#: Les structs dont on vérifie les étiquettes d'appel. Ce sont celles qu'on construit à la
#: main un peu partout et dont l'initialiseur est celui que le compilateur synthétise : y
#: ajouter une propriété sans toucher aux appels passe inaperçu jusqu'au build.
WATCHED = ["AgendaOverride", "AgendaDone", "AgendaEvent", "ExamPlanOverrideRecord"]


def swift_files() -> list[pathlib.Path]:
    return sorted(ROOT.rglob("*.swift"))


def attribute_problems(paths: list[pathlib.Path]) -> list[str]:
    """Un attribut de macro doit toucher la déclaration qu'il qualifie."""
    found: list[str] = []

    for path in paths:
        lines = path.read_text(encoding="utf8").splitlines()
        for index, line in enumerate(lines):
            if line.strip() not in ("@Observable", "@MainActor"):
                continue

            # On avance jusqu'à la première déclaration, en sautant ce qui a le droit de
            # s'intercaler : d'autres attributs, et rien d'autre.
            cursor = index + 1
            while cursor < len(lines):
                ahead = lines[cursor].strip()
                if ahead.startswith(("@", "///", "//")) or ahead == "":
                    cursor += 1
                    continue
                break
            if cursor >= len(lines):
                continue

            match = DECL.match(lines[cursor])
            kind = match.group(1) if match else "?"
            here = f"{path.relative_to(ROOT)}:{index + 1}"

            if line.strip() == "@Observable" and kind not in ("class", "actor"):
                found.append(
                    f"{here} @Observable porte sur un `{kind}` "
                    f"(ligne {cursor + 1} : {lines[cursor].strip()[:70]})"
                )
                continue

            # Un commentaire de documentation entre l'attribut et sa déclaration signale
            # presque toujours qu'un bloc s'est glissé au milieu.
            if any(lines[k].strip().startswith("///") for k in range(index + 1, cursor)):
                found.append(
                    f"{here} {line.strip()} est séparé de sa déclaration par de la "
                    f"documentation (ligne {cursor + 1})"
                )

    return found


def stored_properties(source: str, name: str) -> list[str] | None:
    """Les propriétés stockées d'une struct, dans l'ordre : c'est son initialiseur."""
    opening = re.search(rf"\nstruct {name}\b[^{{]*\{{", source)
    if not opening:
        return None

    depth, cursor, body = 0, opening.end() - 1, []
    while cursor < len(source):
        char = source[cursor]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                break
        body.append(char)
        cursor += 1

    properties = []
    for line in "".join(body).splitlines():
        text = line.strip()
        match = re.match(r"(?:var|let)\s+(\w+)\s*:", text)
        # Une propriété calculée n'entre pas dans l'initialiseur membre à membre.
        if match and not text.rstrip().endswith("{") and "{ " not in text:
            properties.append(match.group(1))
    return properties


def label_problems(paths: list[pathlib.Path]) -> list[str]:
    """Une étiquette d'appel qui ne correspond à aucune propriété du type."""
    sources = {path: path.read_text(encoding="utf8") for path in paths}
    whole = "\n".join(sources.values())
    found: list[str] = []

    for name in WATCHED:
        properties = stored_properties(whole, name)
        if properties is None:
            found.append(f"struct {name} : introuvable")
            continue

        # Un initialiseur écrit à la main peut accepter ce qu'il veut : on ne juge que les
        # types dont le compilateur synthétise l'initialiseur.
        if re.search(rf"struct {name}\b[\s\S]{{0,2500}}?\n    init\(", whole):
            continue

        for path, text in sources.items():
            for call in re.finditer(rf"\b{name}\(\s*\n?([^()]*(?:\([^()]*\)[^()]*)*)\)", text):
                labels = re.findall(r"(\w+)\s*:", call.group(1))
                unknown = [label for label in labels if label not in properties]
                if unknown:
                    line = text[: call.start()].count("\n") + 1
                    found.append(
                        f"{path.relative_to(ROOT)}:{line} {name}(…) : étiquette(s) "
                        f"{unknown} absente(s) de {properties}"
                    )

    return found


def main() -> int:
    paths = swift_files()
    problems = attribute_problems(paths) + label_problems(paths)

    print(f"{len(paths)} fichiers Swift relus.")
    if not problems:
        print("Rien à signaler.")
        return 0

    print("À corriger :")
    for problem in problems:
        print(f"  - {problem}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
