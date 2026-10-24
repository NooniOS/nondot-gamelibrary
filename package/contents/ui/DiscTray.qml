/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - el interior de la caja: la bandeja de plástico y el
    disco, que gira mientras el juego arranca.

    La portada del disco es su imagen recortada en círculo (por defecto, la
    portada del juego). El reflejo no gira, como la luz sobre un disco real.
*/

import QtQuick
import QtQuick.Shapes

Item {
    id: tray

    property string source: ""
    property color baseColor: "#d71921"
    property string name: ""
    property bool spinning: false
    // Modo compatibilidad (Qt anterior a 6.9).
    property bool compat: false

    readonly property real d: Math.min(width * 0.9, height * 0.62)

    // Bandeja: mitad trasera de la caja, con borde y fondo hundido.
    CaseHalf {
        anchors.fill: parent
        // Borde moldeado alrededor del disco.
        Rectangle {
            anchors.centerIn: parent
            width: tray.d + 8
            height: width
            radius: width / 2
            color: "transparent"
            border.color: "#24272b"
            border.width: 3
        }
        // Pestañas de los lados, como en una caja Amaray.
        Repeater {
            model: [0.12, 0.88]
            Rectangle {
                required property real modelData
                x: parent.width * modelData - 3
                y: parent.height * 0.08
                width: 6
                height: parent.height * 0.12
                radius: 2
                color: "#202327"
            }
        }
    }

    // El disco, que gira.
    Item {
        id: disc
        anchors.centerIn: parent
        width: tray.d
        height: tray.d

        Item {
            id: spinner
            anchors.fill: parent

            // Portada del disco recortada en círculo. Va en un archivo aparte
            // (DiscLabel, Qt 6.8+) para que, si el Qt es más antiguo o se
            // elige el modo compatibilidad, se use DiscLabelCompat.
            Loader {
                id: labelLoader
                anchors.fill: parent
                property bool modernFailed: false
                source: tray.compat || modernFailed ? "DiscLabelCompat.qml" : "DiscLabel.qml"
                onStatusChanged: if (status === Loader.Error && !tray.compat) modernFailed = true
                onLoaded: {
                    item.source = Qt.binding(() => tray.source)
                    item.baseColor = Qt.binding(() => tray.baseColor)
                    item.name = Qt.binding(() => tray.name)
                }
            }

            // Aro transparente del centro y agujero.
            Rectangle {
                anchors.centerIn: parent
                width: tray.d * 0.34
                height: width
                radius: width / 2
                color: Qt.rgba(0.85, 0.88, 0.9, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.5)
                border.width: 1
            }
            Rectangle {
                anchors.centerIn: parent
                width: tray.d * 0.14
                height: width
                radius: width / 2
                color: "#16181b"
                border.color: "#3a3d42"
                border.width: 1
            }
            // Una marca descentrada para que se note que gira.
            Rectangle {
                x: parent.width * 0.5 - width / 2
                y: parent.height * 0.06
                width: tray.d * 0.05
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.75)
            }

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: tray.spinning
            }
        }

        // Reflejo fijo (no gira) y borde plateado.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(0.82, 0.84, 0.87, 0.9)
                strokeWidth: 2
                fillGradient: ConicalGradient {
                    centerX: tray.d / 2
                    centerY: tray.d / 2
                    angle: 30
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.0) }
                    GradientStop { position: 0.08; color: Qt.rgba(1, 1, 1, 0.28) }
                    GradientStop { position: 0.16; color: Qt.rgba(0.6, 0.9, 1, 0.0) }
                    GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0.0) }
                    GradientStop { position: 0.58; color: Qt.rgba(1, 0.9, 0.7, 0.22) }
                    GradientStop { position: 0.66; color: Qt.rgba(1, 1, 1, 0.0) }
                    GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.0) }
                }
                PathAngleArc {
                    centerX: tray.d / 2
                    centerY: tray.d / 2
                    radiusX: tray.d / 2 - 1
                    radiusY: tray.d / 2 - 1
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }
}
