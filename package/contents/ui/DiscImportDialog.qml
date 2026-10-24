/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - importar la portada de un disco desde una plantilla
    (por ejemplo, la "Disc face" de steamgamecovers.com: 1800 x 1800 con
    márgenes, marcas de corte y texto).

    El usuario coloca un círculo sobre el disco: se arrastra desde dentro
    para moverlo y desde el borde para cambiar su tamaño. Se guarda el
    cuadrado que rodea al círculo (600 x 600) con grabToImage; el widget ya
    recorta el disco en círculo al dibujarlo.
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: dlg

    property url source
    // Ruta de destino (sin "file://"); la pone quien abre el diálogo.
    property string dest: ""

    // Círculo, en fracciones: centro (de ancho y alto) y radio (del ancho).
    property real cx: 0.5
    property real cy: 0.5
    property real r: 0.45

    readonly property real srcW: full.implicitWidth
    readonly property real srcH: full.implicitHeight
    readonly property bool ready: full.status === Image.Ready && srcW > 0
    // El cuadrado que rodea al círculo, en px de la imagen original.
    readonly property rect discRect: Qt.rect((cx - r) * srcW, cy * srcH - r * srcW, 2 * r * srcW, 2 * r * srcW)

    property bool busy: false
    property string error: ""

    signal imported(string discUrl)

    title: i18n("Import disc art")
    preferredWidth: Kirigami.Units.gridUnit * 40
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.Cancel
    customFooterActions: [
        Kirigami.Action {
            text: i18n("Use this disc")
            icon.name: "dialog-ok-apply"
            enabled: dlg.ready && !dlg.busy
            onTriggered: dlg.apply()
        }
    ]

    // Plantilla cuadrada de steamgamecovers: disco centrado, radio 710 de
    // 1800 px. Si no es cuadrada, el círculo más grande que quepa.
    function resetGuides() {
        if (!ready)
            return
        cx = 0.5
        cy = 0.5
        r = Math.abs(srcW / srcH - 1) < 0.03 ? 710 / 1800 : Math.min(srcW, srcH) / 2 / srcW * 0.98
    }

    onReadyChanged: resetGuides()
    onOpened: {
        error = ""
        busy = false
        resetGuides()
    }

    function apply() {
        busy = true
        error = ""
        crop.grabToImage(res => {
            busy = false
            if (!res.saveToFile(dest)) {
                error = i18n("Could not save the image to %1.", dest.slice(0, dest.lastIndexOf("/")))
                return
            }
            imported("file://" + dest)
            close()
        })
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: i18n("Fit the circle to the edge of the disc: drag it from inside to move it and from its edge to resize it.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            visible: dlg.error !== ""
            text: dlg.error
        }

        RowLayout {
            spacing: Kirigami.Units.largeSpacing

            Item {
                id: stage
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 20
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18

                Image {
                    id: full
                    anchors.fill: parent
                    source: dlg.source
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                Item {
                    id: area
                    x: (stage.width - full.paintedWidth) / 2
                    y: (stage.height - full.paintedHeight) / 2
                    width: full.paintedWidth
                    height: full.paintedHeight
                    visible: dlg.ready

                    readonly property real pcx: dlg.cx * width
                    readonly property real pcy: dlg.cy * height
                    readonly property real pr: dlg.r * width

                    // Oscurece lo que queda fuera del círculo.
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "#99000000"
                            fillRule: ShapePath.OddEvenFill
                            strokeColor: "transparent"
                            PathSvg {
                                path: "M 0 0 L " + area.width + " 0 L " + area.width + " " + area.height + " L 0 " + area.height + " Z "
                                    + "M " + (area.pcx - area.pr) + " " + area.pcy
                                    + " A " + area.pr + " " + area.pr + " 0 1 0 " + (area.pcx + area.pr) + " " + area.pcy
                                    + " A " + area.pr + " " + area.pr + " 0 1 0 " + (area.pcx - area.pr) + " " + area.pcy + " Z"
                            }
                        }
                    }
                    Rectangle {
                        x: area.pcx - area.pr
                        y: area.pcy - area.pr
                        width: area.pr * 2
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: guideMouse.mode !== "" ? Kirigami.Theme.highlightColor : "white"
                        border.width: 2
                    }
                    // Asa del borde (para cambiar el tamaño).
                    Rectangle {
                        x: area.pcx + area.pr - 6
                        y: area.pcy - 6
                        width: 12
                        height: 12
                        radius: 6
                        color: Kirigami.Theme.highlightColor
                        border.color: "white"
                        border.width: 2
                    }

                    MouseArea {
                        id: guideMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        // "", "move" o "resize".
                        property string mode: ""
                        property real grabDx: 0
                        property real grabDy: 0

                        function modeAt(x, y) {
                            const d = Math.hypot(x - area.pcx, y - area.pcy)
                            if (Math.abs(d - area.pr) < 10)
                                return "resize"
                            return d < area.pr ? "move" : ""
                        }

                        cursorShape: {
                            const m = mode !== "" ? mode : modeAt(mouseX, mouseY)
                            return m === "resize" ? Qt.SizeHorCursor : m === "move" ? Qt.SizeAllCursor : Qt.ArrowCursor
                        }

                        onPressed: (ev) => {
                            mode = modeAt(ev.x, ev.y)
                            grabDx = ev.x - area.pcx
                            grabDy = ev.y - area.pcy
                        }
                        onReleased: mode = ""
                        onPositionChanged: (ev) => {
                            if (mode === "move") {
                                dlg.cx = Math.max(0, Math.min(1, (ev.x - grabDx) / area.width))
                                dlg.cy = Math.max(0, Math.min(1, (ev.y - grabDy) / area.height))
                            } else if (mode === "resize") {
                                const d = Math.hypot(ev.x - area.pcx, ev.y - area.pcy)
                                dlg.r = Math.max(0.05, Math.min(0.75, d / area.width))
                            }
                        }
                    }
                }

                QQC2.BusyIndicator {
                    anchors.centerIn: parent
                    running: full.status === Image.Loading
                    visible: running
                }
            }

            // Resultado: el cuadrado que se guarda (a 600 px), visto a escala y
            // con el círculo marcado.
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                QQC2.Label {
                    text: i18n("Result")
                    font.bold: true
                }
                Item {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 150
                    Item {
                        id: crop
                        width: 600
                        height: 600
                        scale: 150 / 600
                        transformOrigin: Item.TopLeft
                        clip: true
                        Image {
                            readonly property real k: crop.width / Math.max(1, dlg.discRect.width)
                            x: -dlg.discRect.x * k
                            y: -dlg.discRect.y * k
                            width: dlg.srcW * k
                            height: dlg.srcH * k
                            source: dlg.ready ? dlg.source : ""
                            fillMode: Image.Stretch
                            smooth: true
                            mipmap: true
                        }
                    }
                    // Se ve en círculo, como en el widget.
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: Kirigami.Theme.backgroundColor
                            fillRule: ShapePath.OddEvenFill
                            strokeColor: "transparent"
                            PathSvg {
                                path: "M 0 0 L 150 0 L 150 150 L 0 150 Z M 0 75 A 75 75 0 1 0 150 75 A 75 75 0 1 0 0 75 Z"
                            }
                        }
                    }
                }
                QQC2.Label {
                    Layout.maximumWidth: 150
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    text: i18n("The widget adds the hole and the center ring.")
                }
            }
        }
    }
}
