/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - la portada del disco recortada en círculo con
    ShapePath.fillItem (Qt 6.8 o superior). Va en su propio archivo: en un Qt
    más antiguo solo falla este archivo y se usa DiscLabelCompat.qml.
*/

import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string source: ""
    property color baseColor: "#d71921"
    property string name: ""
    readonly property real d: width

    DiscArt {
        id: art
        anchors.fill: parent
        source: root.source
        baseColor: root.baseColor
        name: root.name
    }
    // Copia de la portada (oculta el original) para rellenar el círculo.
    ShaderEffectSource {
        id: texture
        anchors.fill: parent
        sourceItem: art
        hideSource: true
        visible: false
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillItem: texture
            PathAngleArc {
                centerX: root.d / 2
                centerY: root.d / 2
                radiusX: root.d / 2
                radiusY: root.d / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
}
