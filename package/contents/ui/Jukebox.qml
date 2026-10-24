/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - modo rocola: las portadas de frente, en una fila.

    Al pasar el cursor, la portada crece y destaca (brillo, sombra, nombre
    debajo) y las demás se apagan un poco. Como en la estantería, las
    portadas van una tras otra con su ancho EN ESE MOMENTO, así que las
    vecinas se apartan y nunca se superponen.

    Si no caben todas, la fila es un carrusel. En el centro la fila está
    quieta y el cursor solo elige; en los bordes la fila se desliza mientras
    el cursor se queda ahí (más rápido cuanto más al borde), y mientras se
    desliza no se destaca ninguna portada, para que no parpadeen. La rueda
    del ratón pasa de un juego a otro. Con la barra o la rueda, el juego
    elegido se centra.

    Para saber qué hay bajo el cursor se usa la colocación final (portada
    elegida ya grande, carrusel ya desplazado), no la de la animación.

    No depende de Plasma, para poder probarla en un arnés con "qml".
*/

import QtQuick

Item {
    id: juke

    property var games: []
    // Modo compatibilidad (Qt anterior a 6.9): sombras y disco más simples.
    property bool compat: false
    property string steamArtDir: ""

    // Alto de una portada destacada; en reposo son un poco más pequeñas.
    property real boxH: 200
    readonly property real grow: 1.25
    readonly property real baseH: Math.round(boxH / grow)
    readonly property real baseW: Math.round(baseH * 0.693)

    property real gap: 10
    property real pad: 16
    readonly property real topPad: Math.round(boxH * 0.1)
    property real bottomPad: 12
    property real plateH: 7
    readonly property real nameH: 24
    property int openDuration: 260
    property int defaultSlots: 5

    property int openIndex: -1
    readonly property int count: games ? games.length : 0

    property bool scrubber: false
    readonly property real scrubberH: scrubber && count > 0 ? 30 : 0

    signal launchRequested(int index)

    // ---------- Teclado ----------
    // El widget toma el teclado al pulsar su atajo (keyboardEnter) o al
    // hacer clic en él. Esc lo devuelve y avisa con keyboardExit.
    property bool keyboard: false
    property int lastIndex: 0
    signal keyboardExit()
    // Se dejó de navegar porque otra ventana o elemento se llevó el foco.
    signal lostFocus()

    // Sonidos: el widget los reproduce (SoundBank) cuando la vista los pide.
    // "navigate", "open", "spinStart", "spinStop" y "close".
    signal soundRequested(string name, int index)

    onOpenIndexChanged: {
        if (openIndex < 0)
            return
        lastIndex = openIndex
        if (launchingIndex < 0)
            soundRequested("navigate", openIndex)
    }

    function keyboardEnter() {
        if (count === 0)
            return
        keyboard = true
        scrubTo(openIndex >= 0 ? openIndex : Math.min(lastIndex, count - 1))
        forceActiveFocus()
    }

    function keyboardLeave() {
        release()
        keyboardExit()
    }

    // Deja de escuchar el teclado y devuelve el juego a su sitio, sin tocar
    // las ventanas (al lanzar un juego, o al pasar a otra ventana).
    function release() {
        if (launchingIndex >= 0)
            soundRequested("spinStop", launchingIndex)
        soundOpen.stop()
        soundSpin.stop()
        launchingIndex = -1
        launchTimeout.stop()
        keyboard = false
        intent.stop()
        openIndex = -1
        focus = false
    }

    // Lanzar con teclado o mando: después se deja de escuchar, para que el
    // mismo botón dentro del juego no lo vuelva a lanzar.
    function launchAndRelease() {
        if (openIndex < 0 || launchingIndex >= 0)
            return
        const i = openIndex
        if (launchAnimation) {
            startLaunch(i)
            return
        }
        release()
        launchRequested(i)
    }

    // ---------- Animación al jugar ----------
    // La caja se abre del todo y el disco gira launchSeconds segundos;
    // luego se cierra y vuelve a su sitio. Un clic, Esc o el botón de salir
    // la cancelan. Mientras gira, jugar no hace nada (no se lanza dos veces).
    property bool launchAnimation: false
    property int launchSeconds: 5
    property int launchingIndex: -1
    property bool launchClosing: false
    signal launchFinished()

    function startLaunch(i) {
        intent.stop()
        mouse.edgeDir = 0
        // Antes que openIndex: así no suena "pasar de juego".
        const wasOpen = openIndex === i
        launchingIndex = i
        openIndex = i
        center(i)
        launchClosing = false
        // Lo que tarda en abrirse la caja más el tiempo elegido.
        launchTimeout.interval = 700 + Math.max(1, launchSeconds) * 1000
        launchTimeout.restart()
        soundOpen.interval = wasOpen ? 1 : 450
        soundOpen.restart()
        soundSpin.interval = (wasOpen ? 0 : 450) + 560
        soundSpin.restart()
        // El último: si no se puede lanzar, finishLaunch() para también los sonidos.
        launchRequested(i)
    }

    // Cierra la caja y, cuando está cerrada, la devuelve a su sitio.
    // cancelled: se salió con Esc o con el botón de salir.
    function finishLaunch(cancelled) {
        if (launchingIndex < 0 || launchClosing)
            return
        launchTimeout.stop()
        launchClosing = true
        launchClose.cancelled = !!cancelled
        launchClose.restart()
        soundOpen.stop()
        soundSpin.stop()
        soundRequested("spinStop", launchingIndex)
        soundClose.restart()
    }

    // Momentos de los sonidos de la animación: la tapa empieza a abrirse
    // cuando la caja ya está de frente; el disco gira cuando la tapa está casi
    // abierta; el cierre suena cuando la tapa llega abajo.
    Timer {
        id: soundOpen
        onTriggered: juke.soundRequested("open", juke.launchingIndex)
    }
    Timer {
        id: soundSpin
        onTriggered: juke.soundRequested("spinStart", juke.launchingIndex)
    }
    Timer {
        id: soundClose
        interval: 380
        onTriggered: juke.soundRequested("close", -1)
    }

    Timer {
        id: launchTimeout
        onTriggered: juke.finishLaunch(false)
    }

    Timer {
        id: launchClose
        property bool cancelled: false
        interval: 550
        onTriggered: {
            juke.launchClosing = false
            juke.release()
            if (cancelled)
                juke.keyboardExit()
            else
                juke.launchFinished()
        }
    }

    // Si la ventana del escritorio deja de estar activa (se abre un juego u
    // otra ventana) mientras se navega, el juego vuelve a la estantería.
    // Solo cuenta si dura un momento: mientras KWin minimiza ventanas, el
    // foco puede pasar un instante por otra.
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: if (!windowActive && (keyboard || launchingIndex >= 0)) focusCheck.restart()
    Timer {
        id: focusCheck
        interval: 300
        onTriggered: {
            // Mientras gira el disco no cuenta: la animación dura lo elegido.
            if (windowActive || launchingIndex >= 0)
                return
            if (keyboard) {
                release()
                lostFocus()
            }
        }
    }

    // ← → (y el mando): del último se pasa al primero y del primero al último.
    function step(delta) {
        const from = openIndex >= 0 ? openIndex : lastIndex
        scrubTo(((from + delta) % count + count) % count)
    }

    onActiveFocusChanged: if (!activeFocus && keyboard && launchingIndex < 0) { release(); lostFocus() }

    Keys.onPressed: (ev) => {
        if (count === 0)
            return
        keyboard = true
        // Mientras gira el disco solo se puede cancelar.
        if (launchingIndex >= 0) {
            if (ev.key === Qt.Key_Escape)
                finishLaunch(true)
            ev.accepted = true
            return
        }
        switch (ev.key) {
        case Qt.Key_Left: step(-1); break
        case Qt.Key_Right: step(1); break
        case Qt.Key_Up: rowStep(-1); break
        case Qt.Key_Down: rowStep(1); break
        case Qt.Key_Home: scrubTo(0); break
        case Qt.Key_End: scrubTo(count - 1); break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            launchAndRelease()
            break
        case Qt.Key_Escape: keyboardLeave(); break
        default: return
        }
        ev.accepted = true
    }

    // En la rocola solo hay una fila: ↑ ↓ también pasan de juego.
    function rowStep(delta) { step(delta) }

    // Línea donde se apoyan las portadas (la repisa).
    readonly property real floorY: topPad + boxH

    implicitWidth: 2 * pad + defaultSlots * (baseW + gap) + baseW * (grow - 1)
    implicitHeight: floorY + plateH + nameH + scrubberH + bottomPad

    // ---------- Colocación ----------

    readonly property real availW: width - 2 * pad
    // Ancho de la fila con una portada destacada (siempre igual, sea cual
    // sea: todas las portadas miden lo mismo).
    readonly property real fullRowW: count * baseW + Math.max(0, count - 1) * gap + baseW * (grow - 1)
    readonly property bool carousel: fullRowW > availW
    readonly property real maxScroll: Math.max(0, fullRowW - availW)

    // Desplazamiento del carrusel: el destino (para el hover) y el que se ve.
    property real scrollTarget: 0
    property real scroll: scrollTarget
    Behavior on scroll {
        SmoothedAnimation { velocity: 1400 }
    }
    onMaxScrollChanged: scrollTarget = Math.max(0, Math.min(maxScroll, scrollTarget))

    // Borde izquierdo de la portada i si la portada "open" está destacada.
    function targetLeft(i, open) {
        let x = i * (baseW + gap)
        if (open >= 0 && open < i)
            x += baseW * (grow - 1)
        if (carousel)
            return pad - scrollTarget + x
        const total = count * baseW + Math.max(0, count - 1) * gap + (open >= 0 ? baseW * (grow - 1) : 0)
        return pad + (availW - total) / 2 + x
    }

    // Portadas ya creadas (itemAt() no avisa cuando aparece una nueva).
    property int built: 0

    // Borde izquierdo de la portada i ahora mismo, con los anchos animados.
    function liveLeft(i) {
        if (built < 0)
            return 0
        let total = 0, before = 0
        for (let j = 0; j < count; ++j) {
            const it = covers.itemAt(j)
            const w = it ? it.adv : baseW
            total += w + (j > 0 ? gap : 0)
            if (j < i)
                before += w + gap
        }
        const start = carousel ? pad - scroll : pad + (availW - total) / 2
        return start + before
    }

    // Portada bajo el punto (x, y), o -1.
    function pick(x, y) {
        if (y < topPad - 4 || y > floorY + plateH + nameH)
            return -1
        for (let i = 0; i < count; ++i) {
            const left = targetLeft(i, openIndex)
            const w = i === openIndex ? baseW * grow : baseW
            if (x >= left - gap / 2 && x < left + w + gap / 2)
                return i
        }
        return -1
    }

    // Desplaza el carrusel para que la portada i quede centrada.
    function center(i) {
        if (!carousel || i < 0)
            return
        const x = i * (baseW + gap) + baseW * grow / 2
        scrollTarget = Math.max(0, Math.min(maxScroll, x - availW / 2))
    }

    // ---------- Bordes que deslizan el carrusel ----------
    readonly property real edgeZone: Math.min(availW * 0.2, baseW)
    property real edgeSpeed: 520   // px/s en el mismo borde

    // -1..1: hacia dónde y con qué fuerza desliza el cursor en x; 0 en el
    // centro o si ya no se puede ir más lejos por ese lado.
    function edgeDirAt(mx) {
        if (!carousel)
            return 0
        if (mx < pad + edgeZone && scrollTarget > 0)
            return -Math.min(1, (pad + edgeZone - mx) / edgeZone)
        if (mx > width - pad - edgeZone && scrollTarget < maxScroll)
            return Math.min(1, (mx - (width - pad - edgeZone)) / edgeZone)
        return 0
    }

    function scrubTo(i) {
        if (launchingIndex >= 0)
            return
        intent.stop()
        openIndex = i
        center(i)
    }

    function closeSoon() {
        if (launchingIndex >= 0)
            return
        intent.target = -1
        intent.interval = 160
        intent.restart()
    }

    onCountChanged: if (openIndex >= count) openIndex = -1

    // ---------- Dibujo ----------

    ShelfGlass {
        anchors.fill: parent
        plateH: juke.plateH
        plateYs: [juke.floorY]
    }

    // Las portadas, recortadas al interior del mueble (el carrusel no se
    // sale por los lados).
    Item {
        id: strip
        x: 6
        y: 0
        width: juke.width - 12
        height: juke.floorY + juke.plateH
        clip: true

        Repeater {
            id: covers
            model: juke.count
            onItemAdded: juke.built++
            onItemRemoved: juke.built++

            Item {
                id: cell
                required property int index
                readonly property var game: juke.games[index] || ({})
                readonly property bool isOpen: juke.openIndex === index
                property real u: 0
                // Al jugar: la tapa se abre y el disco gira.
                readonly property bool launching: juke.launchingIndex === index
                property real lid: launching && !juke.launchClosing && u > 0.98 ? 1 : 0
                Behavior on lid {
                    NumberAnimation { duration: cell.lid < 0.5 ? 700 : 500; easing.type: Easing.InOutCubic }
                }
                // Con la tapa levantada, la caja sobresale un poco por la
                // izquierda: si no cabe dentro del mueble, se desplaza.
                property real shiftX: launching
                    ? Math.max(0, juke.pad + juke.baseW * juke.grow * 0.3 - juke.targetLeft(index, index))
                    : 0
                Behavior on shiftX {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }

                NumberAnimation {
                    id: uAnim
                    target: cell
                    property: "u"
                    easing.type: Easing.InOutQuad
                }
                function animate() {
                    uAnim.stop()
                    uAnim.to = isOpen ? 1 : 0
                    uAnim.duration = juke.openDuration * Math.abs(uAnim.to - u)
                    uAnim.start()
                }
                onIsOpenChanged: animate()
                Component.onCompleted: u = isOpen ? 1 : 0

                readonly property real s: 1 + (juke.grow - 1) * u
                // Lo que avanza en la fila ahora mismo.
                readonly property real adv: juke.baseW * s

                x: juke.liveLeft(index) - strip.x + shiftX
                y: juke.floorY - juke.baseH
                width: juke.baseW
                height: juke.baseH
                scale: s
                transformOrigin: Item.BottomLeft
                z: isOpen ? 100 : (u > 0 ? 50 + u : 0)

                // Sombra, más honda en la portada destacada.
                SoftShadow {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    compat: juke.compat
                    offsetY: 3 + 6 * cell.u
                    cornerRadius: 3
                    blur: 8 + 14 * cell.u
                    shadowColor: Qt.rgba(0, 0, 0, 0.35 + 0.2 * cell.u)
                }
                // Brillo alrededor de la portada destacada.
                SoftShadow {
                    anchors.fill: parent
                    compat: juke.compat
                    cornerRadius: 3
                    blur: 16
                    spread: 1
                    shadowColor: Qt.rgba(1, 1, 1, 0.35)
                    opacity: cell.u
                    visible: cell.u > 0.01
                }

                GameCase {
                    compat: juke.compat
                    t: 1
                    lid: cell.lid
                    spinning: cell.launching && cell.lid > 0.9
                    discImage: cell.game.discImage || ""
                    spineW: 10
                    coverW: juke.baseW
                    boxH: juke.baseH
                    name: cell.game.name || ""
                    baseColor: cell.game.color || "#d71921"
                    coverImage: cell.game.coverImage || ""
                    steamId: cell.game.steamId || ""
                    steamArtDir: juke.steamArtDir
                }

                // Las demás se apagan un poco mientras hay una destacada.
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: "black"
                    opacity: juke.openIndex >= 0 && !cell.isOpen ? 0.32 * (1 - cell.u) : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.6 * cell.u)
                }
            }
        }
    }

    // Avisos de que el carrusel sigue por los lados.
    Repeater {
        model: juke.carousel ? 2 : 0
        Text {
            required property int index
            readonly property bool more: index === 0 ? juke.scroll > 1 : juke.scroll < juke.maxScroll - 1
            x: index === 0 ? 2 : juke.width - width - 2
            y: juke.topPad + juke.boxH / 2 - height / 2
            text: index === 0 ? "‹" : "›"
            color: "white"
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
            font.pixelSize: 26
            font.bold: true
            opacity: more ? 0.75 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            z: 900
        }
    }

    // Nombre del juego destacado.
    Text {
        id: nameLabel
        x: juke.pad
        width: juke.availW
        y: juke.floorY + juke.plateH + 2
        height: juke.nameH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: "white"
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.45)
        font.pixelSize: 13
        font.bold: true
        text: juke.openIndex >= 0 && juke.games[juke.openIndex] ? (juke.games[juke.openIndex].name || "") : ""
        opacity: juke.openIndex >= 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // ---------- Ratón ----------

    Timer {
        id: intent
        property int target: -1
        interval: 70
        onTriggered: juke.openIndex = target
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.bottomMargin: juke.scrubberH
        z: 1000
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: containsMouse && juke.pick(mouseX, mouseY) >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

        // Fuerza del borde donde está el cursor (0 si no desliza).
        property real edgeDir: 0

        function follow() {
            if (juke.launchingIndex >= 0) {
                edgeDir = 0
                return
            }
            edgeDir = containsMouse ? juke.edgeDirAt(mouseX) : 0
            if (edgeDir !== 0) {
                // Deslizando: ninguna portada destacada hasta que pare.
                intent.stop()
                juke.openIndex = -1
                return
            }
            const i = juke.pick(mouseX, mouseY)
            if (i === juke.openIndex) {
                intent.stop()
                return
            }
            if (intent.running && intent.target === i)
                return
            intent.target = i
            intent.interval = i < 0 ? 160 : 70
            intent.restart()
        }

        onPositionChanged: follow()
        onEntered: follow()
        onExited: {
            edgeDir = 0
            juke.closeSoon()
        }
        onPressed: juke.forceActiveFocus()
        onClicked: (ev) => {
            // Un clic mientras gira el disco lo cancela.
            if (juke.launchingIndex >= 0) {
                juke.finishLaunch(false)
                return
            }
            const i = juke.pick(ev.x, ev.y)
            if (i < 0)
                return
            intent.stop()
            if (juke.launchAnimation) {
                juke.startLaunch(i)
            } else {
                juke.openIndex = i
                juke.launchRequested(i)
            }
        }
        onWheel: (ev) => {
            if (juke.launchingIndex >= 0)
                return
            const step = ev.angleDelta.y < 0 || ev.angleDelta.x < 0 ? 1 : -1
            const from = juke.openIndex >= 0 ? juke.openIndex : (step > 0 ? -1 : juke.count)
            // También da la vuelta: del último al primero y al revés.
            juke.scrubTo(((from + step) % juke.count + juke.count) % juke.count)
        }
    }

    // Un Timer y no FrameAnimation: en el escritorio de Plasma una
    // FrameAnimation solo avanzaba cuando el cursor se movía (el escritorio
    // no dibuja fotogramas si nada cambia). El avance usa el tiempo real.
    Timer {
        id: edgeTimer
        property double last: 0
        interval: 16
        repeat: true
        running: mouse.edgeDir !== 0
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now()
            const dt = Math.min(0.1, (now - last) / 1000)
            last = now
            const next = juke.scrollTarget + mouse.edgeDir * juke.edgeSpeed * dt
            juke.scrollTarget = Math.max(0, Math.min(juke.maxScroll, next))
            // Al llegar al final se vuelve a elegir con el cursor.
            if (juke.scrollTarget <= 0 || juke.scrollTarget >= juke.maxScroll)
                mouse.follow()
        }
    }

    ScrubBar {
        visible: juke.scrubberH > 0
        x: juke.pad + 6
        y: juke.height - juke.bottomPad - juke.scrubberH + 4
        width: juke.width - 2 * (juke.pad + 6)
        height: juke.scrubberH - 8
        z: 1001
        count: juke.count
        current: juke.openIndex
        onScrubbed: (i) => juke.scrubTo(i)
        onChosen: (i) => juke.launchRequested(i)
        onDismissed: juke.closeSoon()
    }
}
