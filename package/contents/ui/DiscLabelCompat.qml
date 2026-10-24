/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - la portada del disco en el modo compatibilidad:
    recortada con la máscara de MultiEffect (Qt 6.5 o superior). El borde
    puede verse un poco menos fino que con DiscLabel.
*/

import QtQuick
import QtQuick.Effects

Item {
    id: root
    property string source: ""
    property color baseColor: "#d71921"
    property string name: ""

    DiscArt {
        id: art
        anchors.fill: parent
        source: root.source
        baseColor: root.baseColor
        name: root.name
        visible: false
        layer.enabled: true
    }
    Rectangle {
        id: circle
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
        layer.smooth: true
    }
    MultiEffect {
        anchors.fill: parent
        source: art
        maskEnabled: true
        maskSource: circle
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
