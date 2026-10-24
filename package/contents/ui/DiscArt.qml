/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - la imagen cuadrada de la portada del disco (o, si no
    hay, el color del juego con su nombre). DiscLabel la recorta en círculo.
*/

import QtQuick

Item {
    id: root
    property string source: ""
    property color baseColor: "#d71921"
    property string name: ""

    Rectangle {
        anchors.fill: parent
        color: root.baseColor
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.width * 0.28
            width: root.width * 0.6
            horizontalAlignment: Text.AlignHCenter
            text: root.name
            color: "white"
            font.pixelSize: Math.max(8, root.width * 0.08)
            font.bold: true
            elide: Text.ElideRight
        }
    }
    Image {
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width * 2
    }
}
