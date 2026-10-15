#!/usr/bin/env python3
"""Remet en images les rendus que la CI imprime dans son journal.

    python3 scripts/ci-renders.py journal.txt dossier/

Le journal est celui du job « Compiler et tester » (texte brut, ou le JSON que rend l'API) ;
chaque rendu y est encadré par « === RENDU nom === » et « === FIN nom === ».
"""
import base64
import json
import os
import re
import sys


def main(source: str, target: str) -> None:
    text = open(source, encoding="utf-8", errors="replace").read()
    try:
        payload = json.loads(text)
        text = payload.get("logs_content") or payload.get("content") or text
    except ValueError:
        pass
    text = text.replace("\\n", "\n")
    os.makedirs(target, exist_ok=True)
    stamp = re.compile(r"^\S+Z\s")
    current, chunks, count = None, [], 0
    for raw in text.splitlines():
        line = stamp.sub("", raw).strip()
        start = re.match(r"=== RENDU (\S+) ===", line)
        end = re.match(r"=== FIN (\S+) ===", line)
        if start:
            current, chunks = start.group(1), []
        elif end and current:
            data = base64.b64decode("".join(chunks))
            with open(os.path.join(target, f"{current}.jpg"), "wb") as handle:
                handle.write(data)
            count += 1
            current = None
        elif current and re.fullmatch(r"[A-Za-z0-9+/=]+", line):
            chunks.append(line)
    print(f"{count} rendu(s) dans {target}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
