/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - importar el arte de una caja completa
    (contraportada | lomo | portada en una sola imagen).

    El usuario coloca las guías: los dos bordes del lomo, el borde derecho
    de la portada y los bordes superior e inferior. El lomo y la portada son
    la imagen completa desplazada dentro de un recorte (mover las guías no
    vuelve a decodificar la imagen) y se guardan como PNG con grabToImage,
    así que el resto del widget solo ve dos imágenes normales.
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: dlg

    property url source
    // Rutas de destino (sin "file://"); las pone quien abre el diálogo.
    property string spineDest: ""
    property string coverDest: ""

    // Guías, en fracciones de la imagen (0..1).
    property real spineL: 0.475
    property real spineR: 0.525
    property real frontR: 1
    property real top: 0
    property real bottom: 1

    readonly property real outH: 600
    readonly property real srcW: full.implicitWidth
    readonly property real srcH: full.implicitHeight
    readonly property bool ready: full.status === Image.Ready && srcW > 0

    readonly property rect spineRect: Qt.rect(spineL * srcW, top * srcH, (spineR - spineL) * srcW, (bottom - top) * srcH)
    readonly property rect coverRect: Qt.rect(spineR * srcW, top * srcH, (frontR - spineR) * srcW, (bottom - top) * srcH)

    signal imported(string spineUrl, string coverUrl)

    // La imagen completa, escalada y desplazada para que "rect" (en px de
    // la imagen original) llene a su padre.
    component CropImage: Image {
        required property rect rect
        required property real fullW
        required property real fullH
        readonly property real sx: parent.width / Math.max(1, rect.width)
        readonly property real sy: parent.height / Math.max(1, rect.height)
        x: -rect.x * sx
        y: -rect.y * sy
        width: fullW * sx
        height: fullH * sy
        fillMode: Image.Stretch
        smooth: true
        mipmap: true
    }

    title: i18n("Import full box")
    preferredWidth: Kirigami.Units.gridUnit * 46
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.Cancel
    customFooterActions: [
        Kirigami.Action {
            text: i18n("Create spine and cover")
            icon.name: "dialog-ok-apply"
            enabled: dlg.ready && !dlg.busy
            onTriggered: dlg.apply()
        }
    ]

    property bool busy: false
    property string error: ""

    // Al cargar una imagen nueva, coloca las guías según la plantilla
    // habitual (Amaray de steamgamecovers: 2000 x 1545 con márgenes). Si la
    // proporción no coincide, supone una imagen sin márgenes.
    function resetGuides() {
        if (!ready)
            return
        const template = Math.abs(srcW / srcH - 2000 / 1545) < 0.03
        spineL = 0.475
        spineR = 0.525
        frontR = template ? 1975 / 2000 : 1
        top = template ? 118 / 1545 : 0
        bottom = template ? 1428 / 1545 : 1
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
        let pending = 2
        let failed = false
        const done = (ok) => {
            failed = failed || !ok
            if (--pending > 0)
                return
            busy = false
            if (failed) {
                error = i18n("Could not save the images to %1.", spineDest.slice(0, spineDest.lastIndexOf("/")))
                return
            }
            imported("file://" + spineDest, "file://" + coverDest)
            close()
        }
        spineCrop.grabToImage(r => done(r.saveToFile(spineDest)))
        coverCrop.grabToImage(r => done(r.saveToFile(coverDest)))
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: i18n("Drag the lines to mark both edges of the spine, the right edge of the front cover and the top and bottom edges. The back cover is not used.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            visible: dlg.error !== ""
            text: dlg.error
        }

        RowLayout {
            spacing: Kirigami.Units.largeSpacing

            // Imagen con las guías.
            Item {
                id: stage
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 20
                Layout.minimumWidth: Kirigami.Units.gridUnit * 20

                Image {
                    id: full
                    anchors.fill: parent
                    source: dlg.source
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                // Zona pintada de la imagen.
                Item {
                    id: area
                    x: (stage.width - full.paintedWidth) / 2
                    y: (stage.height - full.paintedHeight) / 2
                    width: full.paintedWidth
                    height: full.paintedHeight
                    visible: dlg.ready

                    readonly property real xL: dlg.spineL * width
                    readonly property real xM: dlg.spineR * width
                    readonly property real xR: dlg.frontR * width
                    readonly property real yT: dlg.top * height
                    readonly property real yB: dlg.bottom * height

                    // Oscurece lo que no se usa.
                    Rectangle { x: 0; y: 0; width: parent.width; height: area.yT; color: "#99000000" }
                    Rectangle { x: 0; y: area.yB; width: parent.width; height: parent.height - area.yB; color: "#99000000" }
                    Rectangle { x: 0; y: area.yT; width: area.xL; height: area.yB - area.yT; color: "#99000000" }
                    Rectangle { x: area.xR; y: area.yT; width: parent.width - area.xR; height: area.yB - area.yT; color: "#99000000" }
                    Rectangle {
                        x: area.xL; y: area.yT; width: area.xM - area.xL; height: area.yB - area.yT
                        color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.25)
                    }

                    Repeater {
                        model: [
                            { kind: "v", key: "spineL" }, { kind: "v", key: "spineR" }, { kind: "v", key: "frontR" },
                            { kind: "h", key: "top" }, { kind: "h", key: "bottom" }
                        ]
                        Rectangle {
                            required property var modelData
                            readonly property bool vertical: modelData.kind === "v"
                            readonly property real pos: dlg[modelData.key] * (vertical ? area.width : area.height)
                            x: vertical ? pos - 1 : 0
                            y: vertical ? 0 : pos - 1
                            width: vertical ? 2 : area.width
                            height: vertical ? area.height : 2
                            color: guideMouse.active === modelData.key ? Kirigami.Theme.highlightColor : "#ffffff"
                            border.width: 0
                            opacity: 0.95
                        }
                    }

                    MouseArea {
                        id: guideMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        property string active: ""

                        function nearest(mx, my) {
                            const x = mx - 6, y = my - 6
                            let best = "", dist = 9
                            for (const k of ["spineL", "spineR", "frontR"]) {
                                const d = Math.abs(dlg[k] * area.width - x)
                                if (d < dist) { dist = d; best = k }
                            }
                            for (const k of ["top", "bottom"]) {
                                const d = Math.abs(dlg[k] * area.height - y)
                                if (d < dist) { dist = d; best = k }
                            }
                            return best
                        }

                        cursorShape: {
                            const k = active !== "" ? active : (containsMouse ? nearest(mouseX, mouseY) : "")
                            return k === "" ? Qt.ArrowCursor : (k === "top" || k === "bottom") ? Qt.SplitVCursor : Qt.SplitHCursor
                        }

                        onPressed: (ev) => active = nearest(ev.x, ev.y)
                        onReleased: active = ""
                        onPositionChanged: (ev) => {
                            if (active === "")
                                return
                            const gap = 0.004
                            const fx = Math.max(0, Math.min(1, (ev.x - 6) / area.width))
                            const fy = Math.max(0, Math.min(1, (ev.y - 6) / area.height))
                            if (active === "spineL")
                                dlg.spineL = Math.min(fx, dlg.spineR - gap)
                            else if (active === "spineR")
                                dlg.spineR = Math.max(dlg.spineL + gap, Math.min(fx, dlg.frontR - 0.05))
                            else if (active === "frontR")
                                dlg.frontR = Math.max(fx, dlg.spineR + 0.05)
                            else if (active === "top")
                                dlg.top = Math.min(fy, dlg.bottom - 0.1)
                            else if (active === "bottom")
                                dlg.bottom = Math.max(fy, dlg.top + 0.1)
                        }
                    }
                }

                QQC2.BusyIndicator {
                    anchors.centerIn: parent
                    running: full.status === Image.Loading
                    visible: running
                }
            }

            // Resultado: estos mismos elementos se guardan con grabToImage,
            // a 600 px de alto; aquí se ven a escala.
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                QQC2.Label {
                    text: i18n("Result")
                    font.bold: true
                }
                Row {
                    id: previewRow
                    spacing: Kirigami.Units.smallSpacing
                    readonly property real k: 150 / dlg.outH

                    Item {
                        width: spineCrop.width * parent.k
                        height: 150
                        Item {
                            id: spineCrop
                            width: Math.max(8, Math.round(dlg.outH * dlg.spineRect.width / Math.max(1, dlg.spineRect.height)))
                            height: dlg.outH
                            scale: previewRow.k
                            transformOrigin: Item.TopLeft
                            clip: true
                            CropImage {
                                rect: dlg.spineRect
                                fullW: dlg.srcW
                                fullH: dlg.srcH
                                source: dlg.ready ? dlg.source : ""
                            }
                        }
                    }
                    Item {
                        width: coverCrop.width * parent.k
                        height: 150
                        Item {
                            id: coverCrop
                            width: Math.round(dlg.outH * dlg.coverRect.width / Math.max(1, dlg.coverRect.height))
                            height: dlg.outH
                            scale: previewRow.k
                            transformOrigin: Item.TopLeft
                            clip: true
                            CropImage {
                                rect: dlg.coverRect
                                fullW: dlg.srcW
                                fullH: dlg.srcH
                                source: dlg.ready ? dlg.source : ""
                            }
                        }
                    }
                }
                QQC2.Label {
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 9
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    text: i18n("With the spine set to “Real proportions”, the spine is shown as is, without stretching.")
                }
            }
        }
    }
}
