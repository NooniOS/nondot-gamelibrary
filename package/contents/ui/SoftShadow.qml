/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - sombra que elige su versión: la suave (BoxShadow,
    Qt 6.9+) o la del modo compatibilidad (BoxShadowCompat). Si la suave no
    puede cargarse (Qt más antiguo), pasa sola a la compatible.
*/

import QtQuick

Item {
    id: shadow

    property real offsetY: 0
    property real blur: 8
    property real cornerRadius: 3
    property real spread: 0
    property color shadowColor: Qt.rgba(0, 0, 0, 0.4)
    property bool compat: false

    property bool modernFailed: false

    Loader {
        anchors.fill: parent
        source: shadow.compat || shadow.modernFailed ? "BoxShadowCompat.qml" : "BoxShadow.qml"
        onStatusChanged: if (status === Loader.Error && !shadow.compat) shadow.modernFailed = true
        onLoaded: {
            item.offsetY = Qt.binding(() => shadow.offsetY)
            item.blur = Qt.binding(() => shadow.blur)
            item.cornerRadius = Qt.binding(() => shadow.cornerRadius)
            item.spread = Qt.binding(() => shadow.spread)
            item.shadowColor = Qt.binding(() => shadow.shadowColor)
        }
    }
}
