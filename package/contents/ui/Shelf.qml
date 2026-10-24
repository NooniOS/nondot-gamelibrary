/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - la estantería: reparte las cajas en repisas según el
    ancho disponible y decide qué caja está abierta.

    Las cajas de una repisa van una detrás de otra según su ancho EN ESE
    MOMENTO, y cada repisa va centrada: cuando una caja se abre, sus vecinas
    se apartan a los dos lados para dejarle sitio, y nunca se superponen
    aunque una se cierre mientras otra se abre. Cada repisa reserva el
    sitio que necesita una portada.

    Un solo MouseArea controla el hover de toda la estantería. Para saber
    qué hay bajo el cursor se usa la colocación final (con la caja abierta
    ya abierta), no la de la animación, para que el hover no "persiga" a
    las cajas mientras se mueven.

    No depende de Plasma, para poder probarla en un arnés con "qml".
*/

import QtQuick

Item {
    id: shelf

    property var games: []
    // Modo compatibilidad (Qt anterior a 6.9): sombras y disco más simples.
    property bool compat: false
    property string steamArtDir: ""

    // Medidas: todo sale del alto de la caja. La portada tiene la
    // proporción de una caja Amaray; el lomo depende del modo.
    property real boxH: 200
    property int spineMode: 0   // 0 = proporción real de su imagen, 1 = grueso
    readonly property real coverW: Math.round(boxH * 0.693)
    readonly property real thickW: Math.round(boxH * 0.227)
    readonly property real plainW: Math.round(boxH * 0.1)
    readonly property real amarayRatio: 0.077

    property real gap: 3
    property real pad: 16
    readonly property real topPad: Math.round(boxH * 0.19)
    readonly property real rowGap: Math.round(boxH * 0.19)
    property real bottomPad: 12
    property real plateH: 7
    readonly property real lift: Math.round(boxH * 0.08)
    property real popScale: 0.06
    property int openDuration: 500
    // Cerrar es más rápido que abrir: a medio giro una caja es más ancha
    // que abierta o cerrada, y si una se cerrara al mismo ritmo que se abre
    // la otra, la repisa no cabría.
    property int closeDuration: Math.round(openDuration * 0.52)
    property int defaultSlots: 10
    // Ancho de una caja abierta (portada ya agrandada).
    readonly property real openW: coverW * (1 + popScale)

    // Lo que avanza la caja i en su repisa, cerrada y abierta.
    function closedAdv(i) { return layout.ws[i] }
    function openAdv(i) { return openW }

    property int openIndex: -1

    // Barra inferior para recorrer los juegos.
    property bool scrubber: false
    readonly property real scrubberH: scrubber && count > 0 ? 30 : 0
    readonly property int count: games ? games.length : 0

    // id del juego -> ancho/alto de la imagen de su lomo, cuando ha cargado.
    property var ratios: ({})

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
        // Antes que openIndex: así no suena "pasar de juego".
        const wasOpen = openIndex === i
        launchingIndex = i
        openIndex = i
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
        onTriggered: shelf.soundRequested("open", shelf.launchingIndex)
    }
    Timer {
        id: soundSpin
        onTriggered: shelf.soundRequested("spinStart", shelf.launchingIndex)
    }
    Timer {
        id: soundClose
        interval: 380
        onTriggered: shelf.soundRequested("close", -1)
    }

    Timer {
        id: launchTimeout
        onTriggered: shelf.finishLaunch(false)
    }

    Timer {
        id: launchClose
        property bool cancelled: false
        interval: 550
        onTriggered: {
            shelf.launchClosing = false
            shelf.release()
            if (cancelled)
                shelf.keyboardExit()
            else
                shelf.launchFinished()
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

    // ↑ ↓: la caja de la repisa de arriba o de abajo que quede más cerca.
    function rowStep(delta) {
        const from = openIndex >= 0 ? openIndex : lastIndex
        const r = layout.rs[from] + delta
        if (r < 0 || r >= rows)
            return
        const cx = targetLeft(from, -1) + layout.ws[from] / 2
        let best = -1, dist = 1e9
        for (let i = 0; i < count; ++i) {
            if (layout.rs[i] !== r)
                continue
            const d = Math.abs(targetLeft(i, -1) + layout.ws[i] / 2 - cx)
            if (d < dist) { dist = d; best = i }
        }
        if (best >= 0)
            scrubTo(best)
    }

    // Grosor del lomo del juego i.
    function spineWidthOf(i) {
        if (spineMode === 1)
            return thickW
        const g = games[i]
        if (!g || !g.spineImage)
            return plainW
        const r = ratios[g.id] || 0
        return Math.max(8, Math.round(boxH * (r > 0 ? r : amarayRatio)))
    }

    // Reparto en repisas: cada lomo con su ancho, de izquierda a derecha.
    readonly property var layout: {
        const xs = [], ws = [], rs = [], firsts = [], lasts = []
        let x = pad, row = 0, first = 0
        // Cada repisa reserva al final el sitio de una caja abierta.
        const limit = width - pad - openW
        for (let i = 0; i < count; ++i) {
            const w = spineWidthOf(i)
            if (x > pad && x + w > limit) {
                for (let j = first; j < i; ++j)
                    lasts.push(i - 1)
                row++
                x = pad
                first = i
            }
            xs.push(x)
            ws.push(w)
            rs.push(row)
            firsts.push(first)
            x += w + gap
        }
        for (let j = first; j < count; ++j)
            lasts.push(count - 1)
        return { xs: xs, ws: ws, rs: rs, firsts: firsts, lasts: lasts, rows: row + 1 }
    }
    readonly property int rows: layout.rows
    readonly property real rowPitch: boxH + plateH + rowGap

    implicitWidth: 2 * pad + defaultSlots * (plainW + gap) + openW
    implicitHeight: topPad + rows * rowPitch - rowGap + bottomPad + scrubberH

    function rowTop(r) { return topPad + r * rowPitch }

    // Borde izquierdo de la caja i en una repisa centrada donde la caja j
    // mide widthOf(j).
    function leftWith(i, widthOf) {
        const first = layout.firsts[i], last = layout.lasts[i]
        let total = gap * (last - first), before = 0
        for (let j = first; j <= last; ++j) {
            const w = widthOf(j)
            total += w
            if (j < i)
                before += w + gap
        }
        return pad + (width - 2 * pad - total) / 2 + before
    }

    // Colocación final con la caja "open" abierta (para el hover).
    function targetLeft(i, open) {
        return leftWith(i, j => j === open ? openAdv(j) : closedAdv(j))
    }

    // Cajas ya creadas: itemAt() no avisa cuando aparece una caja nueva, así
    // que la colocación lee este contador para recalcularse.
    property int built: 0

    // Colocación de ahora mismo, con los anchos de la animación.
    function liveLeft(i) {
        if (built < 0)
            return 0
        return leftWith(i, j => {
            const it = boxes.itemAt(j)
            return it ? it.visualW : closedAdv(j)
        })
    }

    // Hueco bajo el punto (x, y), o -1.
    function slotAt(x, y) {
        const r = Math.floor((y - topPad + rowGap / 2) / rowPitch)
        if (r < 0 || r >= rows)
            return -1
        for (let i = 0; i < count; ++i) {
            if (layout.rs[i] !== r)
                continue
            const left = targetLeft(i, openIndex)
            const w = i === openIndex ? openAdv(i) : closedAdv(i)
            if (x >= left - gap / 2 && x < left + w + gap / 2)
                return i
        }
        return -1
    }

    // Zona que ocupa la caja i completamente abierta (incluida la parte
    // que sube por encima de la repisa).
    function insideOpen(i, x, y) {
        if (i < 0 || i >= count)
            return false
        const w = openAdv(i)
        const left = targetLeft(i, i)
        const top = rowTop(layout.rs[i]) - lift - boxH * popScale
        const bottom = rowTop(layout.rs[i]) + boxH + plateH
        return x >= left - 2 && x <= left + w + 2 && y >= top - 2 && y <= bottom
    }

    // Abre la caja i al momento (la barra no usa el retardo del hover).
    function scrubTo(i) {
        if (launchingIndex >= 0)
            return
        intent.stop()
        openIndex = i
    }

    function closeSoon() {
        if (launchingIndex >= 0)
            return
        intent.target = -1
        intent.interval = 160
        intent.restart()
    }

    function pick(x, y) {
        if (insideOpen(openIndex, x, y))
            return openIndex
        return slotAt(x, y)
    }

    onCountChanged: if (openIndex >= count) openIndex = -1

    ShelfGlass {
        anchors.fill: parent
        plateH: shelf.plateH
        plateYs: {
            const ys = []
            for (let r = 0; r < shelf.rows; ++r)
                ys.push(shelf.rowTop(r) + shelf.boxH)
            return ys
        }
    }

    Repeater {
        id: boxes
        model: shelf.count
        onItemAdded: shelf.built++
        onItemRemoved: shelf.built++

        Item {
            id: slot
            required property int index
            readonly property var game: shelf.games[index] || ({})
            readonly property bool isOpen: shelf.openIndex === index
            property real t: 0
            // Al jugar: la tapa se abre cuando la caja ya está de frente.
            readonly property bool launching: shelf.launchingIndex === index
            property real lid: launching && !shelf.launchClosing && t > 0.98 ? 1 : 0
            Behavior on lid {
                NumberAnimation { duration: slot.lid < 0.5 ? 700 : 500; easing.type: Easing.InOutCubic }
            }
            // Con la tapa levantada, la caja sobresale un poco por la izquierda:
            // si no cabe dentro del mueble, se desplaza a la derecha.
            property real shiftX: launching
                ? Math.max(0, shelf.pad + shelf.coverW * 0.3 - shelf.targetLeft(index, index))
                : 0
            Behavior on shiftX {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }

            // La animación se configura aquí y no con un Behavior: así la
            // duración y la curva son seguro las del cambio que toca (abrir
            // o cerrar), sin depender del orden en que Qt actualiza enlaces.
            NumberAnimation {
                id: tAnim
                target: slot
                property: "t"
            }
            function animate() {
                tAnim.stop()
                tAnim.to = isOpen ? 1 : 0
                tAnim.duration = isOpen ? shelf.openDuration * (1 - t * 0.5)
                                        : shelf.closeDuration * Math.max(0.3, t)
                tAnim.easing.type = isOpen ? Easing.InOutCubic : Easing.OutCubic
                tAnim.start()
            }
            onIsOpenChanged: animate()
            Component.onCompleted: t = isOpen ? 1 : 0

            // Lo que avanza esta caja en la repisa ahora mismo: su ancho
            // visible (con el aumento de la caja que sale).
            readonly property real visualW: gameCase.width * (1 + shelf.popScale * t)

            // La escala crece desde el centro: se compensa para que el borde
            // izquierdo visible quede donde toca.
            x: shelf.liveLeft(index) + gameCase.width * shelf.popScale * t / 2 + shiftX
            y: shelf.rowTop(shelf.layout.rs[index] || 0) - shelf.lift * t
            width: gameCase.width
            height: shelf.boxH
            z: isOpen ? 100 : (t > 0 ? 50 + t : 0)
            scale: 1 + shelf.popScale * t
            transformOrigin: Item.Bottom

            SoftShadow {
                anchors.fill: parent
                anchors.topMargin: 6
                compat: shelf.compat
                offsetY: 2 + 8 * slot.t
                cornerRadius: 3
                blur: 6 + 18 * slot.t
                shadowColor: Qt.rgba(0, 0, 0, 0.30 + 0.25 * slot.t)
            }

            GameCase {
                id: gameCase
                compat: shelf.compat
                t: slot.t
                lid: slot.lid
                spinning: slot.launching && slot.lid > 0.9
                discImage: slot.game.discImage || ""
                spineW: shelf.layout.ws[slot.index] || shelf.plainW
                coverW: shelf.coverW
                boxH: shelf.boxH
                name: slot.game.name || ""
                baseColor: slot.game.color || "#d71921"
                spineImage: slot.game.spineImage || ""
                coverImage: slot.game.coverImage || ""
                logoImage: slot.game.logoImage || ""
                steamId: slot.game.steamId || ""
                steamArtDir: shelf.steamArtDir
                onNaturalRatioChanged: {
                    const id = slot.game.id
                    if (!id || naturalRatio <= 0 || shelf.ratios[id] === naturalRatio)
                        return
                    const m = Object.assign({}, shelf.ratios)
                    m[id] = naturalRatio
                    shelf.ratios = m
                }
            }
        }
    }

    // Retardo corto antes de abrir: al barrer la repisa con el cursor no se
    // dispara una animación por cada lomo.
    Timer {
        id: intent
        property int target: -1
        interval: 90
        onTriggered: shelf.openIndex = target
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.bottomMargin: shelf.scrubberH
        z: 1000
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: containsMouse && shelf.pick(mouseX, mouseY) >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

        function follow() {
            if (shelf.launchingIndex >= 0)
                return
            const i = shelf.pick(mouseX, mouseY)
            if (i === shelf.openIndex) {
                intent.stop()
                return
            }
            if (intent.running && intent.target === i)
                return
            intent.target = i
            intent.interval = i < 0 ? 160 : 90
            intent.restart()
        }

        onPositionChanged: follow()
        onEntered: follow()
        onExited: {
            intent.target = -1
            intent.interval = 160
            intent.restart()
        }
        onPressed: shelf.forceActiveFocus()
        onClicked: (ev) => {
            // Un clic mientras gira el disco lo cancela.
            if (shelf.launchingIndex >= 0) {
                shelf.finishLaunch(false)
                return
            }
            const i = shelf.pick(ev.x, ev.y)
            if (i < 0)
                return
            intent.stop()
            if (shelf.launchAnimation) {
                shelf.startLaunch(i)
            } else {
                shelf.openIndex = i
                shelf.launchRequested(i)
            }
        }
    }

    // ---------- Barra para recorrer ----------
    ScrubBar {
        visible: shelf.scrubberH > 0
        x: shelf.pad + 6
        y: shelf.height - shelf.bottomPad - shelf.scrubberH + 4
        width: shelf.width - 2 * (shelf.pad + 6)
        height: shelf.scrubberH - 8
        z: 1001
        count: shelf.count
        current: shelf.openIndex
        onScrubbed: (i) => shelf.scrubTo(i)
        onChosen: (i) => shelf.launchRequested(i)
        onDismissed: shelf.closeSoon()
    }
}
