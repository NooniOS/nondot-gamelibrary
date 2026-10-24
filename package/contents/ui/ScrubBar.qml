/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - barra para recorrer los juegos.

    Un punto por juego y un tramo igual para cada uno. Al pasar el cursor
    avisa del juego que hay debajo (scrubbed); al soltar el botón sobre la
    barra lo elige (chosen). Si se arrastra fuera y se suelta allí, no se
    elige nada (dismissed).
*/

import QtQuick

Item {
    id: bar

    property int count: 0
    property int current: -1

    signal scrubbed(int index)
    signal chosen(int index)
    signal dismissed()

    readonly property real seg: width / Math.max(1, count)
    readonly property bool active: scrub.containsMouse || scrub.pressed
    readonly property real knobX: active ? Math.max(0, Math.min(width, scrub.mouseX + scrub.x))
                                         : (current >= 0 ? centerOf(current) : 0)

    // x en coordenadas de la barra (el área del ratón es algo más grande).
    function indexAt(x) { return Math.max(0, Math.min(count - 1, Math.floor(x / seg))) }
    function centerOf(i) { return (i + 0.5) * seg }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.22)
    }

    Repeater {
        model: bar.count
        Rectangle {
            required property int index
            readonly property bool isCurrent: index === bar.current
            x: bar.centerOf(index) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: isCurrent ? 6 : 4
            height: width
            radius: width / 2
            color: isCurrent ? "white" : Qt.rgba(1, 1, 1, 0.5)
        }
    }

    Rectangle {
        id: knob
        x: bar.knobX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: scrub.pressed ? 16 : 13
        height: width
        radius: width / 2
        color: "white"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
        opacity: bar.active || bar.current >= 0 ? 1 : 0.45
        Behavior on x {
            enabled: !bar.active
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on width { NumberAnimation { duration: 120 } }

        Rectangle {
            anchors.centerIn: parent
            width: 5
            height: 5
            radius: 2.5
            color: "#d71921"
            visible: scrub.pressed
        }
    }

    MouseArea {
        id: scrub
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: bar.scrubbed(bar.indexAt(mouseX + x))
        onPositionChanged: bar.scrubbed(bar.indexAt(mouseX + x))
        onReleased: (ev) => {
            if (containsMouse)
                bar.chosen(bar.indexAt(ev.x + x))
            else
                bar.dismissed()
        }
        onExited: if (!pressed) bar.dismissed()
        onCanceled: bar.dismissed()
    }
}
