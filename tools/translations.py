# SPDX-FileCopyrightText: 2026 NooniOS
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Traducciones del widget (necesita gettext: xgettext, msgmerge y msgfmt).
#
#   python3 tools/translations.py
#
# 1. Extrae los textos de package/ a po/template.pot.
# 2. Actualiza cada po/<idioma>.po con los textos nuevos o cambiados.
# 3. Compila cada .po en package/contents/locale/<idioma>/LC_MESSAGES/,
#    con el dominio que Plasma usa para el widget: plasma_applet_<Id>.
import glob
import json
import os
import subprocess

repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
package = os.path.join(repo, "package")
po_dir = os.path.join(repo, "po")

with open(os.path.join(package, "metadata.json")) as f:
    meta = json.load(f)["KPlugin"]
domain = "plasma_applet_" + meta["Id"]

sources = sorted(
    os.path.relpath(p, repo)
    for p in glob.glob(os.path.join(package, "contents", "**", "*"), recursive=True)
    if p.endswith((".qml", ".js"))
)
pot = os.path.join(po_dir, "template.pot")
subprocess.run(
    ["xgettext", "--from-code=UTF-8", "--language=JavaScript", "--sort-by-file",
     "--package-name=" + meta["Name"], "--package-version=" + meta["Version"],
     "--msgid-bugs-address=" + meta["BugReportUrl"],
     "--no-wrap", "-ki18n:1", "-ki18nc:1c,2", "-ki18np:1,2", "-ki18ncp:1c,2,3",
     "-o", pot] + sources,
    cwd=repo, check=True)

for po in sorted(glob.glob(os.path.join(po_dir, "*.po"))):
    lang = os.path.splitext(os.path.basename(po))[0]
    subprocess.run(["msgmerge", "--quiet", "--update", "--backup=none", po, pot], check=True)
    out_dir = os.path.join(package, "contents", "locale", lang, "LC_MESSAGES")
    os.makedirs(out_dir, exist_ok=True)
    # Sin --check-format: los %1 de KDE no son formatos de printf.
    subprocess.run(["msgfmt", "--check-header", "--check-domain", "--statistics", "-o",
                    os.path.join(out_dir, domain + ".mo"), po], check=True)
    print(lang, "->", os.path.relpath(out_dir, repo))
