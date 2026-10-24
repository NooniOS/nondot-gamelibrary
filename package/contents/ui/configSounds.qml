/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - ajustes de los sonidos.

    Cada evento usa el sonido del widget (contents/sounds) o un archivo del
    usuario, que se copia a ~/.local/share/nondot-gamelibrary para que no se pierda si
    se mueve el original. "Probar" lo reproduce con el volumen elegido.
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

import "games.js" as Games

KCMUtils.SimpleKCM {
    id: page

    property bool cfg_soundsEnabled
    property bool cfg_soundsEnabledDefault
    property int cfg_soundVolume
    property int cfg_soundVolumeDefault
    property string cfg_soundEvents
    property string cfg_soundEventsDefault

    property string message: ""
    property bool messageIsError: false

    readonly property string dataDir: Games.urlToPath(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))
    readonly property string artDir: dataDir + "/nondot-gamelibrary"

    readonly property var eventList: [
        { name: "navigate", title: i18n("Moving between games"), file: "pasar.wav" },
        { name: "open", title: i18n("Opening the box"), file: "abrir.wav" },
        { name: "spin", title: i18n("Spinning disc"), file: "disco.wav" },
        { name: "launch", title: i18n("Play (discs without their own sound)"), file: "jugar.wav" },
        { name: "close", title: i18n("Closing the box"), file: "cerrar.wav" }
    ]

    readonly property var events: {
        try {
            const v = JSON.parse(cfg_soundEvents || "{}")
            return v && typeof v === "object" ? v : {}
        } catch (e) {
            return {}
        }
    }

    function eventOf(name) {
        const e = events[name] || {}
        return { on: e.on !== false, file: typeof e.file === "string" ? e.file : "" }
    }

    function setEvent(name, key, value) {
        const all = Object.assign({}, events)
        const e = eventOf(name)
        e[key] = value
        all[name] = e
        cfg_soundEvents = JSON.stringify(all)
    }

    function fileFor(name) {
        const e = eventOf(name)
        if (e.file !== "")
            return e.file
        const item = eventList.find(x => x.name === name)
        return Qt.resolvedUrl("../sounds/" + item.file)
    }

    function preview(url) {
        if (!previewer.item)
            return
        previewer.item.volume = cfg_soundVolume / 100
        previewer.item.source = url
        previewer.item.play()
    }

    // Probar sonidos; con Loader, por si falta Qt Multimedia.
    Loader {
        id: previewer
        source: "Voice.qml"
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})
        property int seq: 0
        function run(cmd, cb) {
            const src = cmd + " #snd" + (++seq)
            callbacks[src] = cb
            connectSource(src)
        }
        onNewData: (source, data) => {
            const cb = callbacks[source]
            delete callbacks[source]
            disconnectSource(source)
            if (cb)
                cb(data["exit code"], data.stdout || "", data.stderr || "")
        }
    }

    FileDialog {
        id: soundDialog
        property string eventName: ""
        title: i18n("Choose a sound")
        nameFilters: [i18n("Sounds (*.wav *.ogg *.oga *.opus *.mp3 *.flac)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.MusicLocation)
        onAccepted: {
            const src = Games.urlToPath(selectedFile)
            const m = /\.(wav|ogg|oga|opus|mp3|flac)$/i.exec(src)
            if (!m || src.indexOf("\n") >= 0) {
                page.message = i18n("That file is not a sound the widget can use.")
                page.messageIsError = true
                return
            }
            const name = eventName
            const dest = page.artDir + "/evt" + name + "-sound-" + Date.now().toString(36) + "." + m[1].toLowerCase()
            shell.run("mkdir -p -- " + Games.quote(page.artDir) + " && cp -f -- " + Games.quote(src) + " " + Games.quote(dest), (code, out, err) => {
                if (code === 0) {
                    page.setEvent(name, "file", "file://" + dest)
                    page.message = ""
                } else {
                    page.message = i18n("Could not copy the sound: %1", err.trim())
                    page.messageIsError = true
                }
            })
        }
    }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Sounds")
        }

        Kirigami.InlineMessage {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            visible: previewer.status === Loader.Error
            text: i18n("Qt Multimedia was not found (package qt6-multimedia): the widget works, but without sound.")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Sounds:")
            text: i18n("Play sounds")
            checked: page.cfg_soundsEnabled
            onToggled: page.cfg_soundsEnabled = checked
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Volume:")
            enabled: page.cfg_soundsEnabled
            QQC2.Slider {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                from: 0
                to: 100
                stepSize: 5
                value: page.cfg_soundVolume
                onMoved: page.cfg_soundVolume = value
            }
            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                text: i18n("%1%", page.cfg_soundVolume)
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Each moment")
        }

        Repeater {
            model: page.eventList
            RowLayout {
                id: row
                required property var modelData
                readonly property var ev: page.eventOf(modelData.name)
                Kirigami.FormData.label: modelData.title + ":"
                enabled: page.cfg_soundsEnabled
                spacing: Kirigami.Units.smallSpacing

                QQC2.CheckBox {
                    checked: row.ev.on
                    onToggled: page.setEvent(row.modelData.name, "on", checked)
                    QQC2.ToolTip.text: i18n("Enable this sound")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    enabled: row.ev.on
                    elide: Text.ElideMiddle
                    text: row.ev.file !== "" ? row.ev.file.slice(row.ev.file.lastIndexOf("/") + 1) : i18n("Widget sound")
                    opacity: row.ev.file !== "" ? 1 : 0.7
                }
                QQC2.ToolButton {
                    icon.name: "media-playback-start"
                    enabled: row.ev.on
                    onClicked: page.preview(page.fileFor(row.modelData.name))
                    QQC2.ToolTip.text: i18n("Preview")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "document-open"
                    enabled: row.ev.on
                    onClicked: {
                        soundDialog.eventName = row.modelData.name
                        soundDialog.open()
                    }
                    QQC2.ToolTip.text: i18n("Choose your own file")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "edit-undo"
                    enabled: row.ev.file !== ""
                    onClicked: page.setEvent(row.modelData.name, "file", "")
                    QQC2.ToolTip.text: i18n("Back to the widget sound")
                    QQC2.ToolTip.visible: hovered
                }
            }
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Each disc can have its own sound when you select it: on the Games page, Disc section. The spinning disc loops while the animation lasts.")
        }

        Kirigami.InlineMessage {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            visible: page.message !== ""
            type: page.messageIsError ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            text: page.message
            showCloseButton: true
        }
    }
}
