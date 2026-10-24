/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - ajustes del mando.

    Los botones se eligen pulsándolos: así da igual cómo numere los botones
    cada marca de mando. El ayudante solo lee el mando, nunca escribe en él.
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: page

    property bool cfg_gamepadEnabled
    property bool cfg_gamepadEnabledDefault
    property string cfg_gamepadCombo
    property string cfg_gamepadComboDefault
    property int cfg_gamepadHoldMs
    property int cfg_gamepadHoldMsDefault
    property string cfg_gamepadOk
    property string cfg_gamepadOkDefault
    property string cfg_gamepadBack
    property string cfg_gamepadBackDefault

    // Estado de la búsqueda de mandos.
    property bool searching: false
    property bool noPython: false
    property var pads: []

    // Qué se está capturando ahora: "", "combo", "ok" o "back".
    property string capturing: ""
    property string captureSrc: ""
    property string message: ""
    property bool messageIsError: false

    readonly property bool playstation: pads.some(p => /DualSense|DualShock|Sony|PlayStation/i.test(p.name))

    Component.onCompleted: refresh()

    GamepadHelper {
        id: helper
    }

    function refresh() {
        searching = true
        helper.run("devices", (code, out, err) => {
            searching = false
            noPython = code === 127
            try {
                pads = code === 0 ? JSON.parse(out) : []
            } catch (e) {
                pads = []
            }
        })
    }

    function capture(what) {
        helper.cancel(captureSrc)
        capturing = what
        message = ""
        captureSrc = helper.run("capture 10", (code, out, err) => {
            captureSrc = ""
            const kind = capturing
            capturing = ""
            if (code !== 0 || out === "TIMEOUT" || out === "") {
                say(i18n("No button was received. Check that the gamepad is connected and try again."), true)
                return
            }
            if (kind === "combo") {
                if (!helper.validSpec(out, false)) {
                    say(i18n("That combination can't be used (4 buttons at once at most)."), true)
                    return
                }
                if (out.indexOf("+") < 0)
                    say(i18n("You chose a single button. Keep in mind you'll also press it while playing: a combination is safer."), true)
                cfg_gamepadCombo = out
                return
            }
            if (!helper.validSpec(out, true)) {
                say(i18n("Choose a single button."), true)
                return
            }
            if (kind === "ok")
                cfg_gamepadOk = out
            else
                cfg_gamepadBack = out
        })
    }

    // Nombres de los botones (distribución de un mando de Xbox; entre
    // paréntesis, el equivalente de PlayStation).
    readonly property var padNames: ({
        k304: "A (✕)", k305: "B (○)", k307: "X (□)", k308: "Y (△)",
        k310: "LB (L1)", k311: "RB (R1)", k312: "LT (L2)", k313: "RT (R2)",
        k314: i18n("View (Share)"), k315: i18n("Menu (Options)"), k316: "Xbox (PS)",
        k317: i18n("Left stick"), k318: i18n("Right stick"), k167: i18n("Share"),
        a10: "LT (L2)", a9: "RT (R2)", a2: "LT (L2)", a5: "RT (R2)"
    })

    function describePad(spec) {
        if (!spec)
            return "—"
        return spec.split("+").map(code => padNames[code] || i18n("button %1", code.slice(1))).join(" + ")
    }

    function say(text, isError) {
        message = text
        messageIsError = isError
    }

    Kirigami.FormLayout {
        // ----- Teclado -----
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Keyboard")
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Shortcut:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            text: i18n("Set it on the “Keyboard Shortcuts” page of this same window.")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font.bold: true
            text: i18n("A shortcut is required for the gamepad to work: the gamepad opens the library by triggering that shortcut.")
        }
        QQC2.Label {
            Kirigami.FormData.label: i18n("With the library open:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            text: i18n("← → to move, ↑ ↓ to change shelf, Enter to play and Esc to leave.")
        }

        // ----- Mando -----
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Gamepad")
        }

        Kirigami.InlineMessage {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            visible: page.noPython
            text: i18n("Python 3 was not found; the widget needs it to read the gamepad. Install it with your distribution's package manager.")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Use gamepad:")
            text: i18n("Open and browse the library with a gamepad")
            checked: page.cfg_gamepadEnabled
            enabled: !page.noPython
            onToggled: page.cfg_gamepadEnabled = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            text: i18n("Requires a keyboard shortcut (Keyboard section, above).")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Connected:")
            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                wrapMode: Text.Wrap
                text: page.searching ? i18n("Searching…")
                    : page.pads.length > 0 ? page.pads.map(p => p.name).join(", ")
                    : i18n("No gamepad. Connect it via USB or Bluetooth and press “Search”.")
                opacity: page.pads.length > 0 ? 1 : 0.7
            }
            QQC2.Button {
                icon.name: "view-refresh"
                text: i18n("Search")
                onClicked: page.refresh()
            }
        }

        // Dibujo del mando con líneas que señalan cada función.
        PadDiagram {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 32
            Layout.preferredHeight: implicitHeight
            opacity: page.cfg_gamepadEnabled ? 1 : 0.55
            comboSpec: page.cfg_gamepadCombo
            okSpec: page.cfg_gamepadOk
            backSpec: page.cfg_gamepadBack
            holdMs: page.cfg_gamepadHoldMs
            playstation: page.playstation
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Buttons")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Open the library:")
            enabled: page.cfg_gamepadEnabled
            QQC2.Label {
                text: page.capturing === "combo" ? i18n("Press the combination on the gamepad and release it…") : page.describePad(page.cfg_gamepadCombo)
                font.bold: page.capturing !== "combo"
            }
            QQC2.Button {
                text: i18n("Change…")
                enabled: page.capturing === ""
                onClicked: page.capture("combo")
            }
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Hold it for:")
            enabled: page.cfg_gamepadEnabled
            from: 0
            to: 3000
            stepSize: 100
            value: page.cfg_gamepadHoldMs
            textFromValue: (v) => (v / 1000).toLocaleString(Qt.locale(), "f", 1) + " s"
            valueFromText: (t) => Math.round(Number.fromLocaleString(Qt.locale(), t.replace(/[^0-9.,]/g, "")) * 1000)
            onValueModified: page.cfg_gamepadHoldMs = value
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Play:")
            enabled: page.cfg_gamepadEnabled
            QQC2.Label {
                text: page.capturing === "ok" ? i18n("Press a button…") : page.describePad(page.cfg_gamepadOk)
                font.bold: page.capturing !== "ok"
            }
            QQC2.Button {
                text: i18n("Change…")
                enabled: page.capturing === ""
                onClicked: page.capture("ok")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Leave:")
            enabled: page.cfg_gamepadEnabled
            QQC2.Label {
                text: page.capturing === "back" ? i18n("Press a button…") : page.describePad(page.cfg_gamepadBack)
                font.bold: page.capturing !== "back"
            }
            QQC2.Button {
                text: i18n("Change…")
                enabled: page.capturing === ""
                onClicked: page.capture("back")
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Move:")
            text: i18n("D-pad or left stick")
        }

        Kirigami.InlineMessage {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            visible: page.message !== ""
            type: page.messageIsError ? Kirigami.MessageType.Warning : Kirigami.MessageType.Information
            text: page.message
            showCloseButton: true
        }

        QQC2.Label {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.Wrap
            opacity: 0.75
            text: i18n("The gamepad keeps listening while you play, so choose a combination you don't use in games. If you ever press it by accident, increase the hold time. With Steam open, Steam Input may create a second virtual gamepad: if a button counts twice, disable Steam Input for the desktop.")
        }
    }
}
