/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - sombra del modo compatibilidad: unas capas de
    rectángulos redondeados cada vez más grandes y más tenues. Funciona con
    cualquier Qt 6; se ve algo menos suave que RectangularShadow.
*/

import QtQuick

Item {
    id: root
    property real offsetY: 0
    property real blur: 8
    property real cornerRadius: 3
    property real spread: 0
    property color shadowColor: Qt.rgba(0, 0, 0, 0.4)

    readonly property int layers: 4

    Repeater {
        model: root.layers
        Rectangle {
            required property int index
            readonly property real grow: root.spread + root.blur * 0.55 * (index + 1) / root.layers
            x: -grow
            y: -grow + root.offsetY
            width: root.width + 2 * grow
            height: root.height + 2 * grow
            radius: root.cornerRadius + grow
            color: Qt.rgba(root.shadowColor.r, root.shadowColor.g, root.shadowColor.b,
                           root.shadowColor.a * 0.5 * (1 - index / root.layers))
        }
    }
}
