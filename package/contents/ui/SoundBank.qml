/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - los sonidos del widget.

    Eventos: "navigate" (pasar de un juego a otro), "open" (abrir la caja),
    "spin" (el disco girando, en bucle), "launch" (jugar) y "close" (cerrar
    la caja). Cada uno usa su sonido del widget (contents/sounds) o un
    archivo elegido por el usuario; el de jugar puede ser propio de cada
    juego. Se carga con un Loader: si falta Qt Multimedia, el widget sigue
    funcionando sin sonido.
*/

import QtQuick

Item {
    id: bank

    property bool soundsOn: true
    property real volume: 0.6
    // { navigate: { on: true, file: "" }, … } — file vacío = sonido del widget.
    property var events: ({})
    property var games: []

    readonly property var defaults: ({
        navigate: "pasar.wav", open: "abrir.wav", spin: "disco.wav", launch: "jugar.wav", close: "cerrar.wav"
    })
    readonly property var names: ["navigate", "open", "spin", "launch", "close"]

    function eventOn(name) {
        const e = events[name]
        return !e || e.on !== false
    }

    function fileFor(name) {
        const e = events[name] || {}
        return e.file ? e.file : Qt.resolvedUrl("../sounds/" + defaults[name])
    }

    function voiceFor(name) {
        return { navigate: navigateVoice, open: openVoice, spin: spinVoice, launch: launchVoice, close: closeVoice }[name]
    }

    // index: juego (para su sonido propio al jugar).
    function play(name, index) {
        if (!soundsOn || !eventOn(name))
            return
        if (name === "launch") {
            const g = games[index]
            gameVoice.source = g && g.soundFile ? g.soundFile : ""
            if (String(gameVoice.source) !== "") {
                gameVoice.play()
                return
            }
        }
        const v = voiceFor(name)
        if (v)
            v.play()
    }

    function spin(on) {
        if (on && soundsOn && eventOn("spin"))
            spinVoice.play()
        else
            spinVoice.stop()
    }

    // Al terminar la animación: el sonido propio del disco (que puede ser
    // largo, como el tema del juego) se apaga suavemente.
    function stopDiscSound() {
        gameVoice.fadeOut()
    }

    // Ajustes: probar un archivo cualquiera.
    function preview(url) {
        previewVoice.source = url
        previewVoice.play()
    }

    Voice { id: navigateVoice; source: bank.fileFor("navigate"); volume: bank.volume; voices: 3 }
    Voice { id: openVoice; source: bank.fileFor("open"); volume: bank.volume }
    Voice { id: spinVoice; source: bank.fileFor("spin"); volume: bank.volume * 0.7; loop: true }
    Voice { id: launchVoice; source: bank.fileFor("launch"); volume: bank.volume }
    Voice { id: closeVoice; source: bank.fileFor("close"); volume: bank.volume }
    Voice { id: gameVoice; volume: bank.volume }
    Voice { id: previewVoice; volume: bank.volume }
}
