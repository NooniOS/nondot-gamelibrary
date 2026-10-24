# SPDX-FileCopyrightText: 2026 NooniOS
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Empaqueta package/ como nondot-gamelibrary-<versión>.plasmoid en la raíz
# del repositorio. Solo usa la biblioteca estándar de Python.
# Uso: python3 tools/pack.py
import json
import os
import zipfile

repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
root = os.path.join(repo, "package")

with open(os.path.join(root, "metadata.json")) as f:
    version = json.load(f)["KPlugin"]["Version"]

out = os.path.join(repo, f"nondot-gamelibrary-{version}.plasmoid")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x != "__pycache__")
        for name in sorted(files):
            if name.endswith(".pyc"):
                continue
            path = os.path.join(d, name)
            z.write(path, os.path.relpath(path, root))
print(os.path.relpath(out))
