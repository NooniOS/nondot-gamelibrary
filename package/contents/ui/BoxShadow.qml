/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - sombra suave (RectangularShadow, Qt 6.9 o superior).
    Va en su propio archivo: en un Qt más antiguo solo falla este archivo, y
    SoftShadow carga entonces BoxShadowCompat.qml.
*/

import QtQuick
import QtQuick.Effects

Item {
    id: root
    property real offsetY: 0
    property real blur: 8
    property real cornerRadius: 3
    property real spread: 0
    property color shadowColor: Qt.rgba(0, 0, 0, 0.4)

    RectangularShadow {
        anchors.fill: parent
        offset.y: root.offsetY
        radius: root.cornerRadius
        blur: root.blur
        spread: root.spread
        color: root.shadowColor
    }
}
