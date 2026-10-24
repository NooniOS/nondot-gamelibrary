// SPDX-FileCopyrightText: 2026 NooniOS
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Prueba del teclado: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_keyboard.qml
import QtQuick
import QtTest
import "../package/contents/ui"

Item {
    id: root
    width: 1000
    height: 900

    function makeGames(n) {
        const g = []
        for (let i = 0; i < n; ++i)
            g.push({ id: "k" + i, name: "Juego " + i, color: "#2d6cdf" })
        return g
    }

    Shelf {
        id: shelf
        width: 300; height: implicitHeight; boxH: 150; openDuration: 0
        games: root.makeGames(12)
        property int launched: -1
        property int exits: 0
        onLaunchRequested: (i) => launched = i
        onKeyboardExit: exits++
    }
    Item {
        id: other
        focus: false
    }

    Jukebox {
        id: juke
        y: 600; width: 420; height: implicitHeight; boxH: 150; openDuration: 0
        games: root.makeGames(14)
        property int launched: -1
        onLaunchRequested: (i) => launched = i
    }

    TestCase {
        name: "keyboard"
        when: windowShown

        function test_shelfArrows() {
            verify(shelf.rows >= 2, "hacen falta dos repisas")
            shelf.lastIndex = 0   // otras pruebas dejan recordado otro juego
            shelf.exits = 0
            shelf.keyboardEnter()
            verify(shelf.activeFocus)
            compare(shelf.openIndex, 0)
            keyClick(Qt.Key_Right); keyClick(Qt.Key_Right)
            compare(shelf.openIndex, 2)
            keyClick(Qt.Key_Left)
            compare(shelf.openIndex, 1)
            // ↓ va a la repisa de abajo y ↑ vuelve
            keyClick(Qt.Key_Down)
            compare(shelf.layout.rs[shelf.openIndex], 1)
            keyClick(Qt.Key_Up)
            compare(shelf.layout.rs[shelf.openIndex], 0)
            keyClick(Qt.Key_End)
            compare(shelf.openIndex, 11)
            keyClick(Qt.Key_Right)
            compare(shelf.openIndex, 0, "del último se pasa al primero")
            keyClick(Qt.Key_Left)
            compare(shelf.openIndex, 11, "del primero se pasa al último")
            keyClick(Qt.Key_Home)
            compare(shelf.openIndex, 0)
            keyClick(Qt.Key_Return)
            compare(shelf.launched, 0)
            // tras jugar deja de escuchar y la caja vuelve a su sitio
            verify(!shelf.keyboard)
            compare(shelf.openIndex, -1)
            shelf.launched = -1
            keyClick(Qt.Key_Return)
            compare(shelf.launched, -1, "un segundo Enter no debe volver a lanzarlo")
            compare(shelf.exits, 0, "jugar no cuenta como salir con Esc")
            shelf.keyboardEnter()
            keyClick(Qt.Key_Escape)
            compare(shelf.openIndex, -1)
            compare(shelf.exits, 1)
            verify(!shelf.activeFocus)
            // al volver, recuerda el último juego
            shelf.keyboardEnter()
            compare(shelf.openIndex, 0)
            keyClick(Qt.Key_Right); keyClick(Qt.Key_Escape)
            shelf.keyboardEnter()
            compare(shelf.openIndex, 1)
            keyClick(Qt.Key_Escape)
        }

        function test_jukeboxKeepsSelectionVisible() {
            juke.keyboardEnter()
            verify(juke.activeFocus)
            for (let i = 0; i < 12; ++i)
                keyClick(Qt.Key_Right)
            compare(juke.openIndex, 12)
            // en la rocola también da la vuelta, y el elegido sigue a la vista
            keyClick(Qt.Key_Right); keyClick(Qt.Key_Right)
            compare(juke.openIndex, 0)
            const first = juke.targetLeft(0, 0)
            verify(first >= 0 && first + juke.baseW * juke.grow <= juke.width, "el primero no se ve: " + first)
            keyClick(Qt.Key_Left)
            compare(juke.openIndex, 13)
            keyClick(Qt.Key_Left)
            compare(juke.openIndex, 12)
            const left = juke.targetLeft(12, 12)
            verify(left >= 0 && left + juke.baseW * juke.grow <= juke.width, "la elegida no se ve: " + left)
            keyClick(Qt.Key_Space)
            compare(juke.launched, 12)
            verify(!juke.keyboard)
            compare(juke.openIndex, -1)
        }

        // Con la animación del disco: se lanza una sola vez, la tapa se abre
        // y Esc la cancela.
        function test_launchAnimation() {
            shelf.launchAnimation = true
            shelf.exits = 0
            shelf.lastIndex = 2
            shelf.keyboardEnter()
            let count = 0
            const conn = (i) => count++
            shelf.launchRequested.connect(conn)
            keyClick(Qt.Key_Return)
            compare(count, 1)
            compare(shelf.launchingIndex, 2)
            verify(shelf.keyboard, "sigue escuchando para poder cancelar")
            keyClick(Qt.Key_Return)
            keyClick(Qt.Key_Right)
            compare(count, 1, "mientras gira no se vuelve a lanzar")
            compare(shelf.openIndex, 2, "mientras gira no se cambia de juego")
            tryCompare(shelf.children.find(c => c.launching === true), "lid", 1, 2000)
            keyClick(Qt.Key_Escape)
            // primero se cierra la caja y después vuelve a su sitio
            verify(shelf.launchClosing)
            tryCompare(shelf, "launchingIndex", -1, 2000)
            compare(shelf.openIndex, -1)
            compare(shelf.exits, 1)
            // al terminar (aparece el juego) se avisa y se deja de escuchar
            let finished = 0
            shelf.launchFinished.connect(() => finished++)
            // y con la duración elegida termina sola
            shelf.launchSeconds = 1
            shelf.lastIndex = 0
            shelf.keyboardEnter()
            keyClick(Qt.Key_Space)
            compare(shelf.launchingIndex, 0)
            tryCompare(shelf, "launchingIndex", -1, 4000)
            compare(finished, 1)
            verify(!shelf.keyboard)
            shelf.launchSeconds = 5
            shelf.launchRequested.disconnect(conn)
            shelf.launchAnimation = false
        }

        // Sonidos: "pasar" al moverse; al jugar, abrir y disco (sin "pasar");
        // al cancelar, se para el disco y suena el cierre.
        function test_sounds() {
            const heard = []
            const conn = (name, i) => heard.push(name)
            shelf.soundRequested.connect(conn)
            shelf.launchAnimation = true
            shelf.lastIndex = 0
            shelf.keyboardEnter()
            keyClick(Qt.Key_Right)
            verify(heard.filter(n => n === "navigate").length >= 2, "pasar: " + heard)
            heard.length = 0
            keyClick(Qt.Key_Return)
            tryVerify(() => heard.indexOf("spinStart") >= 0, 3000, "el disco no empezó: " + heard)
            verify(heard.indexOf("open") >= 0 && heard.indexOf("open") < heard.indexOf("spinStart"), "orden: " + heard)
            compare(heard.indexOf("navigate"), -1, "al jugar no suena pasar")
            heard.length = 0
            keyClick(Qt.Key_Escape)
            compare(heard[0], "spinStop")
            tryVerify(() => heard.indexOf("close") >= 0, 2000, "no sonó el cierre: " + heard)
            tryCompare(shelf, "launchingIndex", -1, 2000)
            shelf.soundRequested.disconnect(conn)
            shelf.launchAnimation = false
        }

        // Si otra cosa se lleva el foco mientras se navega, el juego vuelve a su sitio.
        function test_focusLossReturnsGame() {
            shelf.keyboardEnter()
            keyClick(Qt.Key_Right)
            compare(shelf.openIndex, 1)
            other.forceActiveFocus()
            verify(!shelf.keyboard)
            compare(shelf.openIndex, -1)
        }
    }
}
