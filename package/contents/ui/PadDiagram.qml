/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - dibujo de un mando genérico con líneas que señalan
    qué hace cada botón (abrir la librería, jugar, salir, moverse).

    Todo se dibuja en un lienzo de 640 x 340 y se escala al ancho
    disponible: el mando va en el centro y las etiquetas a los lados. Los
    colores salen del tema de Plasma. Los botones se identifican por su
    código de evdev ("k304", "a9"…), el mismo que guardan los ajustes.
*/

import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: diagram

    property string comboSpec: ""
    property string okSpec: ""
    property string backSpec: ""
    property int holdMs: 800
    // true = letras de PlayStation (✕ ○ □ △).
    property bool playstation: false

    readonly property color ink: Kirigami.Theme.textColor
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color accentText: Kirigami.Theme.highlightedTextColor
    readonly property color bg: Kirigami.Theme.backgroundColor
    function mix(a, b, f) { return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1) }
    readonly property color bodyTop: mix(bg, ink, 0.10)
    readonly property color bodyBottom: mix(bg, ink, 0.20)
    readonly property color well: mix(bg, ink, 0.30)
    readonly property color cap: mix(bg, ink, 0.16)
    readonly property color edge: Qt.rgba(ink.r, ink.g, ink.b, 0.38)

    readonly property real k: width / 640
    implicitWidth: 640
    implicitHeight: 340 * k

    // Centro de cada botón en el lienzo, por código.
    readonly property var centers: ({
        k310: [214, 92], k311: [426, 92],
        k312: [222, 70], a10: [222, 70], a2: [222, 70],
        k313: [418, 70], a9: [418, 70], a5: [418, 70],
        k317: [232, 152], k318: [368, 212],
        k314: [292, 152], k315: [348, 152], k316: [320, 118], k167: [320, 176],
        k304: [410, 180], k305: [436, 154], k307: [384, 154], k308: [410, 128]
    })

    // Radio aproximado de cada botón: las líneas empiezan en su borde.
    readonly property var radii: ({ k317: 27, k318: 27, k316: 14, k314: 7, k315: 7, k167: 8,
                                    k310: 8, k311: 8, k312: 8, k313: 8, a10: 8, a9: 8, a2: 8, a5: 8 })
    function radiusOf(code) { return radii[code] || 12 }

    function specCodes(spec) {
        return spec ? spec.split("+").filter(c => centers[c] !== undefined) : []
    }

    function marked(code) {
        return specCodes(comboSpec).indexOf(code) >= 0 || specCodes(okSpec).indexOf(code) >= 0
            || specCodes(backSpec).indexOf(code) >= 0
    }

    // Etiquetas con sus líneas. Cada una se pone en el lado de sus botones
    // y, en cada lado, se reparten de arriba abajo sin pisarse.
    readonly property var callouts: {
        const list = []
        const add = (codes, title, sub) => {
            const pts = codes.map(c => [centers[c][0], centers[c][1], radiusOf(c)])
            if (pts.length === 0)
                return
            const avgX = pts.reduce((a, p) => a + p[0], 0) / pts.length
            const avgY = pts.reduce((a, p) => a + p[1], 0) / pts.length
            // Los botones del centro llevan la etiqueta arriba.
            const side = Math.abs(avgX - 320) < 45 ? "top" : avgX < 320 ? "left" : "right"
            list.push({ pts: pts, title: title, sub: sub, side: side, want: avgY })
        }
        add(specCodes(comboSpec), i18n("Open the library"),
            holdMs > 0 ? i18n("hold %1 s", (holdMs / 1000).toLocaleString(Qt.locale(), "f", 1)) : i18n("press together"))
        add(specCodes(okSpec), i18n("Play"), "")
        add(specCodes(backSpec), i18n("Leave"), "")
        list.push({ pts: [[272, 212, 24], [232, 152, 27]], title: i18n("Move"), sub: i18n("d-pad or stick"), side: "left", want: 212 })
        for (const side of ["left", "right"]) {
            const mine = list.filter(c => c.side === side).sort((a, b) => a.want - b.want)
            let y = 60
            for (const c of mine) {
                c.y = Math.max(y, Math.min(310, c.want))
                y = c.y + 46
            }
        }
        // Arriba solo cabe una etiqueta; si hubiera más, van a los lados.
        let topUsed = false
        for (const c of list) {
            if (c.side !== "top")
                continue
            if (topUsed) {
                c.side = "right"
                c.y = 300
            } else {
                c.y = 24
                topUsed = true
            }
        }
        return list
    }

    Item {
        width: 640
        height: 340
        scale: diagram.k
        transformOrigin: Item.TopLeft

        // ---------- Mando ----------

        // Gatillos (asoman detrás de los bumpers).
        Repeater {
            model: [false, true]
            Shape {
                required property bool modelData
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { origin.x: 320; xScale: modelData ? -1 : 1 }
                readonly property bool on: diagram.marked("k312") || diagram.marked("a10") || diagram.marked("a2")
                readonly property bool onR: diagram.marked("k313") || diagram.marked("a9") || diagram.marked("a5")
                readonly property bool lit: modelData ? onR : on
                ShapePath {
                    fillColor: parent.lit ? diagram.accent : diagram.well
                    strokeColor: diagram.edge
                    strokeWidth: 1.5
                    PathSvg { path: "M 204 90 C 206 76, 222 68, 244 70 C 249 76, 251 83, 250 90 C 234 89, 218 90, 204 95 Z" }
                }
            }
        }

        // Bumpers, pegados al borde de arriba.
        Repeater {
            model: [false, true]
            Shape {
                required property bool modelData
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { origin.x: 320; xScale: modelData ? -1 : 1 }
                readonly property bool lit: diagram.marked(modelData ? "k311" : "k310")
                ShapePath {
                    fillColor: parent.lit ? diagram.accent : diagram.cap
                    strokeColor: diagram.edge
                    strokeWidth: 1.5
                    PathSvg { path: "M 168 116 C 180 94, 210 82, 262 80 L 266 92 C 222 94, 196 104, 182 122 Z" }
                }
            }
        }

        // Cuerpo con un degradado suave.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: diagram.edge
                strokeWidth: 2
                fillGradient: LinearGradient {
                    x1: 0; y1: 90; x2: 0; y2: 310
                    GradientStop { position: 0; color: diagram.bodyTop }
                    GradientStop { position: 1; color: diagram.bodyBottom }
                }
                PathSvg {
                    path: "M 228 92 C 270 84, 370 84, 412 92 C 462 100, 492 138, 500 196 C 508 254, 500 298, 468 304 C 442 309, 420 288, 404 262 C 392 244, 376 238, 358 238 L 282 238 C 264 238, 248 244, 236 262 C 220 288, 198 309, 172 304 C 140 298, 132 254, 140 196 C 148 138, 178 100, 228 92 Z"
                }
            }
        }

        // Sticks: hueco y capuchón con su aro.
        Repeater {
            model: [{ c: "k317", x: 232, y: 152 }, { c: "k318", x: 368, y: 212 }]
            Item {
                required property var modelData
                readonly property bool lit: diagram.marked(modelData.c)
                readonly property bool move: modelData.c === "k317"
                x: modelData.x - 27; y: modelData.y - 27; width: 54; height: 54
                Rectangle { anchors.fill: parent; radius: width / 2; color: diagram.well; border.color: diagram.edge; border.width: 1.5 }
                Rectangle {
                    anchors.centerIn: parent; width: 38; height: 38; radius: 19
                    color: parent.lit || parent.move ? diagram.accent : diagram.cap
                    border.color: diagram.edge; border.width: 1.5
                    Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: "transparent"; border.color: Qt.rgba(diagram.ink.r, diagram.ink.g, diagram.ink.b, 0.25); border.width: 1.5 }
                }
            }
        }

        // Cruceta (moverse).
        Item {
            x: 272 - 24; y: 212 - 24; width: 48; height: 48
            Rectangle { anchors.centerIn: parent; width: 52; height: 52; radius: 26; color: diagram.well; opacity: 0.6 }
            Repeater {
                model: [{ x: 16, y: 2, w: 16, h: 44 }, { x: 2, y: 16, w: 44, h: 16 }]
                Rectangle {
                    required property var modelData
                    x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h; radius: 3
                    color: diagram.accent
                    border.color: diagram.edge; border.width: 1.5
                }
            }
        }

        // Botones de la derecha y del centro.
        Repeater {
            model: [
                { c: "k308", x: 410, y: 128, r: 12, label: diagram.playstation ? "△" : "Y" },
                { c: "k307", x: 384, y: 154, r: 12, label: diagram.playstation ? "□" : "X" },
                { c: "k305", x: 436, y: 154, r: 12, label: diagram.playstation ? "○" : "B" },
                { c: "k304", x: 410, y: 180, r: 12, label: diagram.playstation ? "✕" : "A" },
                { c: "k314", x: 292, y: 152, r: 7, label: "" },
                { c: "k315", x: 348, y: 152, r: 7, label: "" },
                { c: "k316", x: 320, y: 118, r: 14, label: "" },
                { c: "k167", x: 320, y: 176, r: 4, label: "", w: 16 }
            ]
            Rectangle {
                required property var modelData
                readonly property bool lit: diagram.marked(modelData.c)
                x: modelData.x - width / 2; y: modelData.y - height / 2
                width: modelData.w || modelData.r * 2; height: modelData.r * 2
                radius: modelData.r
                color: lit ? diagram.accent : diagram.cap
                border.color: diagram.edge
                border.width: 1.5
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: parent.lit ? diagram.accentText : diagram.ink
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        // ---------- Líneas y etiquetas ----------
        Repeater {
            model: diagram.callouts
            Item {
                id: callout
                required property var modelData
                readonly property bool onLeft: modelData.side === "left"
                readonly property bool onTop: modelData.side === "top"
                // Punto donde la línea llega a la etiqueta y codo de la línea.
                readonly property real endX: onLeft ? 128 : 512
                readonly property real elbowX: onLeft ? 150 : 490
                anchors.fill: parent

                // En ángulo recto: del botón en horizontal hasta el codo,
                // luego en vertical y por último hasta la etiqueta. Arriba,
                // en forma de corchete hasta la etiqueta del centro.
                function route(p) {
                    const r = p[2] + 2
                    if (onTop)
                        return [Qt.point(p[0], p[1] - r), Qt.point(p[0], 52), Qt.point(320, 52), Qt.point(320, 44)]
                    const sx = p[0] + (onLeft ? -r : r)
                    return [Qt.point(sx, p[1]), Qt.point(elbowX, p[1]), Qt.point(elbowX, modelData.y), Qt.point(endX, modelData.y)]
                }

                Repeater {
                    model: callout.modelData.pts
                    Shape {
                        required property var modelData
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: diagram.accent
                            strokeWidth: 1.5
                            fillColor: "transparent"
                            PathPolyline {
                                path: callout.route(modelData)
                            }
                        }
                    }
                }
                Column {
                    x: callout.onTop ? 220 : callout.onLeft ? 4 : 516
                    y: callout.onTop ? 2 : callout.modelData.y - (callout.modelData.sub ? 17 : 9)
                    width: callout.onTop ? 200 : 120
                    Text {
                        width: parent.width
                        horizontalAlignment: callout.onTop ? Text.AlignHCenter : callout.onLeft ? Text.AlignRight : Text.AlignLeft
                        text: callout.modelData.title
                        color: diagram.ink
                        font.pixelSize: 13
                        font.bold: true
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: callout.onTop ? Text.AlignHCenter : callout.onLeft ? Text.AlignRight : Text.AlignLeft
                        visible: text !== ""
                        text: callout.modelData.sub
                        color: Qt.rgba(diagram.ink.r, diagram.ink.g, diagram.ink.b, 0.65)
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
