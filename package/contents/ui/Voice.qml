/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - un sonido (wav, ogg, oga, opus, mp3, flac).

    Siempre con MediaPlayer y no con SoundEffect: SoundEffect sale con el
    papel "event", que PipeWire trata como sonido de notificación, y si el
    usuario tiene silenciadas las notificaciones el widget tampoco suena.
    MediaPlayer sale como "music".

    voices: cuántos reproductores se turnan (para sonidos cortos que se
    repiten deprisa, como pasar de un juego a otro: uno no corta al otro).
*/

import QtQuick
import QtMultimedia

Item {
    id: voice

    property url source
    property real volume: 0.6
    property bool loop: false
    property int voices: 1

    property int nextVoice: 0
    // Para apagarlo suavemente (fadeOut).
    property real fade: 1

    NumberAnimation {
        id: fadeAnim
        target: voice
        property: "fade"
        to: 0
        duration: 600
        onFinished: {
            voice.stop()
            voice.fade = 1
        }
    }

    function isPlaying() {
        for (let i = 0; i < pool.count; ++i) {
            if (pool.itemAt(i).player.playbackState === MediaPlayer.PlayingState)
                return true
        }
        return false
    }

    function fadeOut() {
        if (isPlaying())
            fadeAnim.restart()
    }

    Repeater {
        id: pool
        model: voice.voices
        Item {
            readonly property alias player: mp
            MediaPlayer {
                id: mp
                source: voice.source
                loops: voice.loop ? MediaPlayer.Infinite : 1
                audioOutput: AudioOutput {
                    volume: voice.volume * voice.fade
                }
            }
        }
    }

    function play() {
        if (String(source) === "" || pool.count === 0)
            return
        fadeAnim.stop()
        fade = 1
        const p = pool.itemAt(nextVoice).player
        nextVoice = (nextVoice + 1) % pool.count
        p.stop()
        p.play()
    }

    function stop() {
        for (let i = 0; i < pool.count; ++i)
            pool.itemAt(i).player.stop()
    }

    // Para las pruebas: ¿el sonido se puede reproducir?
    readonly property bool ready: pool.count > 0 && pool.itemAt(0) !== null
                                  && (pool.itemAt(0).player.mediaStatus === MediaPlayer.LoadedMedia
                                      || pool.itemAt(0).player.mediaStatus === MediaPlayer.BufferedMedia
                                      || pool.itemAt(0).player.mediaStatus === MediaPlayer.EndOfMedia)
}
