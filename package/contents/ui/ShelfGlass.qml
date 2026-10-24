/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - el mueble de cristal: marco, fondo translúcido,
    reflejos diagonales y las repisas. Las cajas van encima (en Shelf.qml).
    Las repisas se dibujan en "plateYs" (posición y de cada repisa).
*/

import QtQuick

Item {
    id: glass

    property var plateYs: []
    property real plateH: 7
    property real plateInset: 8
    property real radius: 12

    // Fondo muy translúcido con un velo superior.
    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.04) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.10) }
        }
    }

    // Reflejos diagonales.
    Item {
        anchors.fill: parent
        anchors.margins: 3
        clip: true

        Rectangle {
            width: 46
            height: parent.height * 2
            x: parent.width * 0.18
            y: -parent.height * 0.5
            rotation: 24
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
        Rectangle {
            width: 14
            height: parent.height * 2
            x: parent.width * 0.18 + 58
            y: -parent.height * 0.5
            rotation: 24
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.06) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    // Marco: línea clara por fuera y oscura por dentro, para que se vea
    // tanto sobre fondos oscuros como claros.
    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.32)
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: glass.radius - 1
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.22)
    }

    // Repisas.
    Repeater {
        model: glass.plateYs

        Item {
            required property real modelData
            x: glass.plateInset
            y: modelData
            width: glass.width - 2 * glass.plateInset
            height: glass.plateH

            // Sombra que la repisa proyecta hacia abajo.
            Rectangle {
                y: parent.height
                width: parent.width
                height: 12
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.20) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.18)
            }
            // Canto superior iluminado y canto frontal verdoso, como el vidrio real.
            Rectangle {
                x: 1
                width: parent.width - 2
                height: 1
                color: Qt.rgba(1, 1, 1, 0.55)
            }
            Rectangle {
                x: 1
                y: parent.height - 3
                width: parent.width - 2
                height: 2
                color: Qt.rgba(0.66, 0.88, 0.85, 0.45)
            }
        }
    }
}
