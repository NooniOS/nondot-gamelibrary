/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - lanza el ayudante del mando (contents/code/mando.py).

    Cada orden del ayudante imprime una línea y termina; run() devuelve esa
    línea al callback. Los argumentos se validan antes de llegar al shell.
*/

import QtQuick
import org.kde.plasma.plasma5support as P5Support

import "games.js" as Games

P5Support.DataSource {
    id: helper

    readonly property string script: Games.urlToPath(Qt.resolvedUrl("../code/mando.py"))
    property var callbacks: ({})
    property int seq: 0

    // Un botón ("k304", "a9") o una combinación ("k314+k315").
    function validSpec(spec, single) {
        const re = single ? /^[ka]\d{1,3}$/ : /^[ka]\d{1,3}(\+[ka]\d{1,3}){0,3}$/
        return typeof spec === "string" && re.test(spec)
    }

    // args: solo letras, números, "+", espacios y puntos (ya validados).
    function run(args, cb) {
        if (!/^[A-Za-z0-9+. ]+$/.test(args))
            return ""
        const src = "python3 -I " + Games.quote(script) + " " + args + " #gp" + (++seq)
        callbacks[src] = cb
        connectSource(src)
        return src
    }

    function cancel(src) {
        if (src && callbacks[src] !== undefined) {
            delete callbacks[src]
            disconnectSource(src)
        }
    }

    engine: "executable"
    connectedSources: []
    onNewData: (source, data) => {
        const cb = callbacks[source]
        delete callbacks[source]
        disconnectSource(source)
        if (cb)
            cb(data["exit code"], (data.stdout || "").trim(), (data.stderr || "").trim())
    }
}
