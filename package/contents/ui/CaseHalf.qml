/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - una mitad abierta de la caja vista por dentro: borde
    de plástico y fondo hundido. La de la tapa lleva las pestañas que
    sujetan el folleto.
*/

import QtQuick

Rectangle {
    id: half

    property bool clipsOnRight: false

    radius: 4
    color: "#2a2d33"
    border.color: "#3a3e45"
    border.width: 1

    // Fondo hundido.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(3, half.width * 0.035)
        radius: 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1c1e22" }
            GradientStop { position: 1.0; color: "#131417" }
        }
        border.color: "#0b0c0e"
        border.width: 1
    }

    // Pestañas del folleto.
    Repeater {
        model: half.clipsOnRight ? [0.1, 0.82] : []
        Rectangle {
            required property real modelData
            x: half.width * 0.80
            y: half.height * modelData
            width: half.width * 0.12
            height: half.height * 0.07
            radius: 2
            color: "#2f3339"
            border.color: "#40444b"
            border.width: 1
        }
    }
}
