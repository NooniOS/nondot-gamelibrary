/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - widget de escritorio.
    Lee la lista de juegos (JSON) de la configuración y lanza el juego
    elegido.
*/

import QtQuick
import QtQuick.Layouts
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

import "games.js" as Games

PlasmoidItem {
    id: root

    // Único punto para cambiar cómo se abre un .desktop. Primero gtk-launch
    // (termina en cuanto lanza la app y falla al momento si no la encuentra;
    // "kstart --application" se quedaba colgado con nombres que acaban en
    // .desktop). Si no está instalado (es de GTK 3), se busca el archivo en
    // las carpetas de aplicaciones y se abre con kioclient, que viene con
    // Plasma. name ya está validado (Games.launcherKind === "desktop").
    function desktopLaunchCommand(name) {
        return "N=" + Games.quote(name) + "; "
            + "if command -v gtk-launch >/dev/null 2>&1; then gtk-launch \"$N\"; exit $?; fi; "
            + "for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" $(printf '%s' \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' ' '); do "
            + "if [ -f \"$d/applications/$N\" ]; then exec kioclient exec \"$d/applications/$N\"; fi; done; "
            + "echo \"not found: $N\" >&2; exit 1"
    }

    readonly property string steamArtDir: StandardPaths.writableLocation(StandardPaths.GenericDataLocation) + "/Steam/appcache/librarycache"

    property var games: []
    property string jsonError: ""

    // Aviso breve; lo muestra la representación completa.
    property string toastText: ""
    property int toastSerial: 0

    function reload() {
        const r = Games.parse(Plasmoid.configuration.gamesJson)
        games = r.games
        jsonError = r.error
    }

    function notify(text) {
        toastText = text
        toastSerial++
    }

    // Devuelve false si no se pudo lanzar (sin lanzador o no válido).
    function launch(index) {
        const g = games[index]
        if (!g)
            return false
        // Con id de Steam se abre por Steam directamente: no depende de
        // que exista el .desktop.
        let l = g.steamId !== "" ? "steam://rungameid/" + g.steamId : g.launcher
        // Modo prueba: todo sigue igual (animación, sonidos, ventanas…), solo
        // que el juego no se abre. Se comprueba el lanzador para avisar igual
        // que de verdad si no es válido.
        const testing = Plasmoid.configuration.testMode
        switch (Games.launcherKind(l)) {
        case "steam":
            if (testing)
                break
            Qt.openUrlExternally("steam://rungameid/" + Games.steamIdOf(l))
            break
        case "desktop":
            if (testing)
                break
            runner.connectSource(desktopLaunchCommand(l) + " #" + Date.now())
            break
        case "empty":
            notify(i18n("“%1” has no launcher. Add one in the settings.", g.name))
            return false
        default:
            notify(i18n("The launcher of “%1” is not valid.", g.name))
            return false
        }
        notify(testing ? i18n("Test mode: “%1” is not opened", g.name) : i18n("Opening %1…", g.name))
        soundEvent("launch", index)
        // Las ventanas vuelven detrás del juego, sin quitarle el foco. Con la
        // animación del disco vuelven cuando aparece el juego (launchFinished).
        if (!Plasmoid.configuration.launchAnimation)
            endWindows(false)
        return true
    }

    // ---------- Sonidos ----------
    // SoundBank va en un Loader: si falta Qt Multimedia, el widget sigue
    // funcionando, solo que sin sonido.
    Loader {
        id: sounds
        source: "SoundBank.qml"
    }
    Binding { target: sounds.item; property: "soundsOn"; value: Plasmoid.configuration.soundsEnabled; when: sounds.status === Loader.Ready }
    Binding { target: sounds.item; property: "volume"; value: Plasmoid.configuration.soundVolume / 100; when: sounds.status === Loader.Ready }
    Binding { target: sounds.item; property: "events"; value: root.soundEvents; when: sounds.status === Loader.Ready }
    Binding { target: sounds.item; property: "games"; value: root.games; when: sounds.status === Loader.Ready }

    readonly property var soundEvents: {
        try {
            const v = JSON.parse(Plasmoid.configuration.soundEvents || "{}")
            return v && typeof v === "object" ? v : {}
        } catch (e) {
            return {}
        }
    }

    function soundEvent(name, index) {
        const b = sounds.item
        if (!b)
            return
        if (name === "spinStart")
            b.spin(true)
        else if (name === "spinStop") {
            b.spin(false)
            b.stopDiscSound()
        }
        else
            b.play(name, index)
    }

    // ---------- Atajo de teclado ----------
    // El atajo se elige en la página "Atajos de teclado" de los ajustes del
    // widget. Al pulsarlo, Plasma emite activated() y da el foco al widget,
    // que toma entonces el teclado.
    signal keyboardRequested()

    Connections {
        target: Plasmoid
        function onActivated() {
            root.hideWindows()
            // Después de que Plasma termine de dar el foco al widget.
            Qt.callLater(root.keyboardRequested)
        }
    }

    // ---------- Ventanas del monitor del widget ----------
    // Para que se vea el widget se minimizan SOLO las ventanas de su monitor,
    // con un script de KWin (contents/code/ventanas.js) que recuerda cuáles
    // fueron y las devuelve al terminar. Si no se sabe el monitor, se usa
    // "mostrar el escritorio" de KWin, que afecta a todos.
    property string windowsMode: ""   // "", "script", "steam" (solo vigila Steam) o "global"
    readonly property string kwinTag: String(Plasmoid.id)
    readonly property string kwinTemplate: Games.urlToPath(Qt.resolvedUrl("../code/ventanas.js"))

    function dbus(args) {
        return "dbus-send --session --type=method_call " + args
    }

    readonly property bool outputKnown: /^[A-Za-z0-9._-]{1,40}$/.test(Screen.name) && /^\d+$/.test(kwinTag)

    // Carga el script de KWin. hide: minimizar ya las ventanas del monitor
    // (al abrir la librería); false: solo vigilar Steam (al jugar con el
    // ratón). after: órdenes que se ejecutan cuando ya está cargado.
    function loadKwinScript(hide, after) {
        const name = "nondot-gamelibrary-" + kwinTag
        const file = "$HOME/.cache/nondot-gamelibrary/kwin-" + kwinTag + ".js"
        // Si quedó un script de una sesión anterior (plasmashell reiniciado),
        // primero devuelve sus ventanas y se descarga.
        const cmd = [
            "mkdir -p \"$HOME/.cache/nondot-gamelibrary\"",
            dbus("--dest=org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut string:NonDotGameLibraryRelease" + kwinTag) + " 2>/dev/null",
            "sleep 0.15",
            dbus("--dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript string:" + name) + " 2>/dev/null",
            "sed -e 's/__OUTPUT__/" + Screen.name + "/g' -e 's/__TAG__/" + kwinTag + "/g' -e 's/__HIDE__/" + (hide ? "true" : "false") + "/g' " + Games.quote(kwinTemplate) + " > \"" + file + "\"",
            "ID=$(dbus-send --session --print-reply=literal --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript string:\"" + file + "\" string:" + name + " | awk '{print $2}')",
            "dbus-send --session --print-reply --dest=org.kde.KWin /Scripting/Script$ID org.kde.kwin.Script.run >/dev/null"
        ].concat(after || []).join("; ")
        kwin.connectSource(cmd + " #" + Date.now())
    }

    function hideWindows() {
        if (windowsMode !== "")
            return   // ya están ocultas (se pulsó el atajo otra vez)
        if (!outputKnown) {
            windowsMode = "global"
            kwin.connectSource(dbus("--dest=org.kde.KWin /KWin org.kde.KWin.showDesktop boolean:true") + " #" + Date.now())
            return
        }
        windowsMode = "script"
        loadKwinScript(true, [])
    }

    // Al empezar la animación del disco: las ventanas del cliente de Steam
    // (actualizaciones, "Preparando para iniciar"…) se minimizan en cuanto
    // aparecen, hasta que termina la animación.
    function keepSteamDown() {
        if (!Plasmoid.configuration.keepSteamMinimized || !/^\d+$/.test(kwinTag))
            return
        const invoke = dbus("--dest=org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut string:NonDotGameLibrarySteam" + kwinTag)
        if (windowsMode === "script") {
            kwin.connectSource(invoke + " #" + Date.now())
        } else if (windowsMode === "" && outputKnown) {
            windowsMode = "steam"
            loadKwinScript(false, ["sleep 0.1", invoke])
        }
    }

    // reactivate: volver a la ventana que se usaba antes (al salir con Esc o
    // con el botón de salir); false al jugar o al pasar a otra ventana.
    function endWindows(reactivate) {
        const mode = windowsMode
        windowsMode = ""
        if (mode === "global") {
            kwin.connectSource(dbus("--dest=org.kde.KWin /KWin org.kde.KWin.showDesktop boolean:false") + " #" + Date.now())
        } else if (mode === "script" || mode === "steam") {
            const name = "nondot-gamelibrary-" + kwinTag
            const cmd = [
                dbus("--dest=org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut string:" + (reactivate ? "NonDotGameLibraryRestore" : "NonDotGameLibraryRelease") + kwinTag),
                "sleep 0.2",
                dbus("--dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript string:" + name),
                dbus("--dest=org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister string:kwin string:NonDotGameLibraryRestore" + kwinTag),
                dbus("--dest=org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister string:kwin string:NonDotGameLibraryRelease" + kwinTag),
                dbus("--dest=org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister string:kwin string:NonDotGameLibrarySteam" + kwinTag)
            ].join("; ")
            kwin.connectSource(cmd + " #" + Date.now())
        }
    }

    P5Support.DataSource {
        id: kwin
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }

    // ---------- Mando ----------
    // El ayudante (contents/code/mando.py) espera la combinación elegida y,
    // al recibirla, el widget "pulsa" su propio atajo de Plasma: así se abre
    // igual que con el teclado (se muestra el escritorio y toma el foco).
    // Mientras se navega, el ayudante devuelve cada dirección o botón.
    GamepadHelper {
        id: pad
    }

    readonly property bool padOn: Plasmoid.configuration.gamepadEnabled
    readonly property string padCombo: Plasmoid.configuration.gamepadCombo
    property string comboSrc: ""
    property string navSrc: ""
    // true mientras el widget tiene el teclado (lo enlaza la representación).
    property bool navigating: false
    // La librería se abrió con el mando (para saber qué hacer si se desconecta).
    property bool openedByPad: false
    signal padCommand(string cmd)

    function watchCombo() {
        pad.cancel(comboSrc)
        comboSrc = ""
        if (!padOn || !pad.validSpec(padCombo, false))
            return
        const ms = Math.max(0, Math.min(3000, Plasmoid.configuration.gamepadHoldMs | 0))
        comboSrc = pad.run("combo " + padCombo + " " + ms, (code, out) => {
            comboSrc = ""
            if (code === 127)
                return   // no hay Python 3: los ajustes lo avisan
            if (out === "COMBO")
                openFromPad()
            comboRetry.start()
        })
    }

    function openFromPad() {
        openedByPad = true
        kwin.connectSource("dbus-send --session --type=method_call --dest=org.kde.kglobalaccel /component/plasmashell org.kde.kglobalaccel.Component.invokeShortcut string:'activate widget " + Plasmoid.id + "' #" + Date.now())
    }

    function navLoop(held, delay) {
        pad.cancel(navSrc)
        navSrc = ""
        if (!navigating || !padOn)
            return
        const ok = pad.validSpec(Plasmoid.configuration.gamepadOk, true) ? Plasmoid.configuration.gamepadOk : "k304"
        const back = pad.validSpec(Plasmoid.configuration.gamepadBack, true) ? Plasmoid.configuration.gamepadBack : "k305"
        navSrc = pad.run("nav " + ok + " " + back + (held ? " " + held + " " + delay : ""), (code, out) => {
            navSrc = ""
            if (!navigating || code !== 0)
                return
            if (out === "LEFT" || out === "RIGHT" || out === "UP" || out === "DOWN") {
                padCommand(out)
                // La primera repetición tarda medio segundo (un toque normal
                // dura unos 0,4 s); las siguientes, menos.
                navLoop(out, out === held ? 130 : 500)
            } else if (out === "OK" || out === "BACK") {
                padCommand(out)
                navLoop(null, 0)
            } else if (out === "LOST" || out === "NOPAD") {
                // Sin mando no se sigue escuchando. Si la librería se abrió con
                // el mando, se cierra; si se abrió con el teclado, sigue con él.
                if (out === "LOST" && openedByPad)
                    padCommand("BACK")
            } else {
                navLoop(null, 0)   // IDLE
            }
        })
    }

    Timer {
        id: comboRetry
        interval: 400
        onTriggered: root.watchCombo()
    }

    onPadOnChanged: { watchCombo(); navLoop(null, 0) }
    onPadComboChanged: watchCombo()
    onNavigatingChanged: {
        if (!navigating)
            openedByPad = false
        navLoop(null, 0)
    }
    Connections {
        target: Plasmoid.configuration
        function onGamepadHoldMsChanged() { root.watchCombo() }
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Component.onCompleted: {
        reload()
        watchCombo()
    }
    Connections {
        target: Plasmoid.configuration
        function onGamesJsonChanged() { root.reload() }
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (data["exit code"] !== 0)
                root.notify(i18n("Could not open the game: %1", (data.stderr || "").trim()))
            disconnectSource(source)
        }
    }

    fullRepresentation: Item {
        readonly property real boxH: Plasmoid.configuration.boxHeight
        Layout.preferredWidth: view.implicitWidth > 0 ? view.implicitWidth : 300
        Layout.preferredHeight: view.implicitHeight > 0 ? view.implicitHeight : 260
        Layout.minimumWidth: boxH * 0.8 + 32
        Layout.minimumHeight: boxH * 1.3

        // Estilo: 0 = estantería, 1 = rocola.
        Loader {
            id: view
            anchors.fill: parent
            sourceComponent: Plasmoid.configuration.layoutMode === 1 ? jukeboxView : shelfView
        }

        Connections {
            target: root
            function onKeyboardRequested() {
                if (view.item)
                    view.item.keyboardEnter()
            }
            function onPadCommand(cmd) {
                const v = view.item
                if (!v || !v.keyboard)
                    return
                // Mientras gira el disco: salir lo cancela; lo demás no hace nada.
                if (v.launchingIndex >= 0) {
                    if (cmd === "BACK")
                        v.finishLaunch(true)
                    return
                }
                if (cmd === "LEFT") v.step(-1)
                else if (cmd === "RIGHT") v.step(1)
                else if (cmd === "UP") v.rowStep(-1)
                else if (cmd === "DOWN") v.rowStep(1)
                else if (cmd === "OK") v.launchAndRelease()
                else if (cmd === "BACK") v.keyboardLeave()
            }
        }

        Binding {
            target: root
            property: "navigating"
            value: view.item ? view.item.keyboard : false
        }

        Component {
            id: shelfView
            Shelf {
                games: root.games
                compat: Plasmoid.configuration.compatMode
                steamArtDir: root.steamArtDir
                boxH: Plasmoid.configuration.boxHeight
                spineMode: Plasmoid.configuration.spineMode
                scrubber: Plasmoid.configuration.showScrubber
                launchAnimation: Plasmoid.configuration.launchAnimation
                launchSeconds: Plasmoid.configuration.launchSeconds
                onLaunchRequested: (i) => {
                    // Si no se pudo lanzar, el disco no se queda girando.
                    if (!root.launch(i)) {
                        if (launchingIndex >= 0)
                            finishLaunch(false)
                    } else if (launchingIndex >= 0) {
                        root.keepSteamDown()
                    }
                }
                onLaunchFinished: root.endWindows(false)
                onSoundRequested: (name, i) => root.soundEvent(name, i)
                onKeyboardExit: root.endWindows(true)
                onLostFocus: root.endWindows(false)
            }
        }

        Component {
            id: jukeboxView
            Jukebox {
                games: root.games
                compat: Plasmoid.configuration.compatMode
                steamArtDir: root.steamArtDir
                boxH: Plasmoid.configuration.boxHeight
                scrubber: Plasmoid.configuration.showScrubber
                launchAnimation: Plasmoid.configuration.launchAnimation
                launchSeconds: Plasmoid.configuration.launchSeconds
                onLaunchRequested: (i) => {
                    // Si no se pudo lanzar, el disco no se queda girando.
                    if (!root.launch(i)) {
                        if (launchingIndex >= 0)
                            finishLaunch(false)
                    } else if (launchingIndex >= 0) {
                        root.keepSteamDown()
                    }
                }
                onLaunchFinished: root.endWindows(false)
                onSoundRequested: (name, i) => root.soundEvent(name, i)
                onKeyboardExit: root.endWindows(true)
                onLostFocus: root.endWindows(false)
            }
        }

        // Estado vacío.
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 260)
            visible: root.games.length === 0
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.bold: true
                text: root.jsonError !== "" ? i18n("The game list is damaged") : i18n("Your shelf is empty")
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                opacity: 0.75
                text: root.jsonError !== "" ? i18n("Open the settings to check it (%1).", root.jsonError)
                                           : i18n("Add your games from the widget's settings.")
            }
            PlasmaComponents.Button {
                Layout.alignment: Qt.AlignHCenter
                icon.name: "configure"
                text: i18n("Add games…")
                onClicked: Plasmoid.internalAction("configure").trigger()
            }
        }

        // Etiqueta de modo prueba, para que no se olvide quitarlo.
        Rectangle {
            visible: Plasmoid.configuration.testMode
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            z: 2001
            width: testLabel.implicitWidth + 14
            height: testLabel.implicitHeight + 6
            radius: height / 2
            color: Qt.rgba(0.84, 0.1, 0.13, 0.85)
            Text {
                id: testLabel
                anchors.centerIn: parent
                text: i18n("TEST MODE")
                color: "white"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 0.8
            }
        }

        // Aviso breve (lanzando, errores).
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: toast.implicitWidth + 24
            height: toast.implicitHeight + 10
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.72)
            border.color: Qt.rgba(1, 1, 1, 0.2)
            opacity: toastTimer.running ? 1 : 0
            visible: opacity > 0
            z: 2000
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Text {
                id: toast
                anchors.centerIn: parent
                color: "white"
                font.pixelSize: 12
                text: root.toastText
            }
            Timer {
                id: toastTimer
                interval: 2600
            }
            Connections {
                target: root
                function onToastSerialChanged() { toastTimer.restart() }
            }
        }
    }
}
