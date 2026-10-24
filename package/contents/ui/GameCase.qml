/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - una caja de juego.

    La caja es un prisma visto de frente: el lomo mira al usuario y la
    portada es la cara derecha. "t" va de 0 (solo lomo) a 1 (solo portada).
    Las dos caras comparten la arista vertical que queda al frente; cada
    cara gira sobre esa arista con una Rotation en Y (con perspectiva), y
    el ancho visible sale de la proyección: lomo = ancho * cos, portada =
    ancho * sin. Así el ancho total de la caja cambia mientras gira.
*/

import QtQuick

Item {
    id: box

    property real spineW: 34
    property real coverW: 104
    property real boxH: 150

    property real t: 0

    property string name: ""
    property color baseColor: "#d71921"
    property string spineImage: ""
    property string coverImage: ""
    property string logoImage: ""
    // Animación al jugar: la tapa (la mitad delantera, con su grosor) se
    // levanta hasta 90° sobre la bisagra (lid 0..1) y el disco gira.
    property real lid: 0

    // Perspectiva propia para la tapa: Qt calcula la de Rotation desde el eje
    // de giro, y a 90° la tapa quedaría de canto, como una hoja. Aquí el ojo
    // mira la caja desde delante y algo a la derecha, así se ven la cara
    // interior y el canto de la tapa.
    readonly property real phi: Math.min(1, lid) * Math.PI / 2
    readonly property real lidT: Math.max(5, spineW * 0.5)        // grosor de la tapa
    readonly property real eyeX: spineVis + coverW * 1.6
    readonly property real eyeY: boxH / 2
    readonly property real eyeD: 900

    // Matriz que lleva un punto (p, v) de una cara a la pantalla, sabiendo
    // que en 3D X = ax*p + bx, Y = v, Z = az*p + bz (Z hacia quien mira).
    function faceMatrix(ax, bx, az, bz) {
        const d = eyeD, vx = eyeX, vy = eyeY
        return Qt.matrix4x4(ax - vx * az / d, 0, 0, bx - vx * bz / d,
                            -vy * az / d, 1, 0, -vy * bz / d,
                            0, 0, 0, 0,
                            -az / d, 0, 0, 1 - bz / d)
    }
    // ¿La cara (centro px,pz y normal nx,nz) mira hacia el ojo?
    function facing(px, pz, nx, nz) {
        return nx * (eyeX - px) + nz * (eyeD - pz) > 0
    }
    property bool spinning: false
    property string discImage: ""
    // Modo compatibilidad (Qt anterior a 6.9): sombras y disco más simples.
    property bool compat: false
    // Fuerza de la sombra que oscurece cada cara al ponerse de lado.
    property real shade: 1
    property string steamId: ""
    // Carpeta de arte de Steam (url "file:///.../librarycache"), o vacía.
    property string steamArtDir: ""

    readonly property real theta: Math.max(0, Math.min(1, t)) * Math.PI / 2
    readonly property real spineVis: spineW * Math.cos(theta)
    readonly property real coverVis: coverW * Math.sin(theta)

    readonly property string steamBase: (steamId !== "" && steamArtDir !== "") ? steamArtDir + "/" + steamId : ""
    readonly property string coverSource: coverImage !== "" ? coverImage
                                         : (steamBase !== "" ? steamBase + "/library_600x900.jpg" : "")
    readonly property string logoSource: logoImage !== "" ? logoImage
                                        : (steamBase !== "" ? steamBase + "/logo.png" : "")

    // Color de texto que contrasta con el color de reserva.
    readonly property real luma: 0.2126 * baseColor.r + 0.7152 * baseColor.g + 0.0722 * baseColor.b
    readonly property color inkColor: luma > 0.6 ? "#1a1a1a" : "#f4f4f4"
    readonly property bool thin: spineW < 28

    // Ancho / alto de la imagen del lomo, cuando ha cargado (0 si no hay).
    readonly property real naturalRatio: spineImg.status === Image.Ready && spineImg.implicitHeight > 0
                                         ? spineImg.implicitWidth / spineImg.implicitHeight : 0

    width: spineVis + coverVis
    height: boxH

    // ---------- Lomo ----------
    Item {
        id: spineFace
        width: box.spineW
        height: box.boxH
        x: box.spineVis - box.spineW
        visible: box.t < 0.999

        transform: Rotation {
            origin.x: box.spineW
            origin.y: box.boxH / 2
            axis { x: 0; y: 1; z: 0 }
            angle: -box.t * 90
            distanceToPlane: 520
        }

        Rectangle {
            anchors.fill: parent
            radius: 2
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.lighter(box.baseColor, 1.18) }
                GradientStop { position: 0.55; color: box.baseColor }
                GradientStop { position: 1.0; color: Qt.darker(box.baseColor, 1.35) }
            }

            Image {
                id: spineImg
                anchors.fill: parent
                source: box.spineImage
                // En modo real el lomo ya tiene la proporción de su imagen;
                // en modo grueso se estira (recortar haría zoom).
                fillMode: Image.Stretch
                asynchronous: true
                sourceSize.height: box.boxH * 2
                visible: status === Image.Ready
            }

            // Reserva: banda superior, nombre (o logo de Steam) y círculo inferior.
            Item {
                anchors.fill: parent
                visible: spineImg.status !== Image.Ready

                Rectangle {
                    id: band
                    width: parent.width
                    height: 22
                    color: Qt.rgba(box.inkColor.r, box.inkColor.g, box.inkColor.b, 0.85)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: 3
                        color: box.baseColor
                    }
                }

                Image {
                    id: logoImg
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    width: box.boxH - 62
                    height: box.spineW - (box.thin ? 6 : 10)
                    rotation: -90
                    source: box.logoSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: 256
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    width: box.boxH - 62
                    rotation: -90
                    visible: logoImg.status !== Image.Ready
                    text: box.name
                    color: box.inkColor
                    font.pixelSize: box.thin ? 11 : 12
                    font.bold: true
                    font.letterSpacing: box.thin ? 0.3 : 0.6
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    width: box.thin ? 10 : 14
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: box.inkColor
                    opacity: 0.85
                }
            }

            // Caja de plástico sobre el arte del lomo: brillo a la izquierda,
            // sombra a la derecha y los cantos de arriba y abajo.
            Item {
                anchors.fill: parent
                visible: spineImg.visible
                readonly property real cap: Math.max(2, Math.round(box.boxH * 0.018))
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.30) }
                        GradientStop { position: 0.18; color: Qt.rgba(1, 1, 1, 0.06) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                        GradientStop { position: 0.82; color: Qt.rgba(0, 0, 0, 0.12) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: parent.cap
                    color: "#141414"
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.25) }
                }
                Rectangle {
                    y: parent.height - height
                    width: parent.width
                    height: parent.cap
                    color: "#141414"
                }
            }

            // Brillo del plástico en el borde izquierdo.
            Rectangle {
                width: 2
                height: parent.height
                color: Qt.rgba(1, 1, 1, 0.28)
            }
            // Sombra al girar (el lomo se aleja de la luz).
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.55 * box.shade * Math.sin(box.theta)
            }
        }
    }

    // ---------- Interior: bandeja y disco ----------
    // Detrás de la portada; solo se ve cuando la tapa se abre.
    Loader {
        x: box.spineVis
        width: box.coverW
        height: box.boxH
        active: box.lid > 0.001
        visible: active
        sourceComponent: DiscTray {
            source: box.discImage !== "" ? box.discImage : box.coverSource
            baseColor: box.baseColor
            name: box.name
            spinning: box.spinning
            compat: box.compat
        }
    }

    // ---------- Portada ----------
    Item {
        id: coverFace
        x: box.spineVis
        width: box.coverW
        height: box.boxH
        readonly property real c: Math.cos(box.phi)
        readonly property real s: Math.sin(box.phi)
        visible: box.t > 0.001 && (box.lid <= 0.001
                 || box.facing(box.spineVis + c * box.coverW / 2, s * box.coverW / 2, -s, c))

        // Al girar la caja: Rotation. Al abrir la tapa: la matriz propia
        // (cara exterior de la tapa, sobre la bisagra).
        property Rotation turn: Rotation {
            origin.x: 0
            origin.y: box.boxH / 2
            axis { x: 0; y: 1; z: 0 }
            angle: 90 - box.t * 90
            distanceToPlane: 520
        }
        property Matrix4x4 opened: Matrix4x4 {
            matrix: box.faceMatrix(coverFace.c, 0, coverFace.s, 0)
        }
        transform: box.lid > 0.001 ? opened : turn

        Rectangle {
            anchors.fill: parent
            radius: 2
            clip: true
            color: box.baseColor

            Image {
                id: coverImg
                anchors.fill: parent
                source: box.coverSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.height: box.boxH * 2
                visible: status === Image.Ready
            }

            // Reserva: rejilla de puntos, aro y nombre.
            Item {
                anchors.fill: parent
                visible: coverImg.status !== Image.Ready

                Grid {
                    x: parent.width - width - 10
                    y: 12
                    columns: 6
                    spacing: 5
                    Repeater {
                        model: 36
                        Rectangle {
                            width: 3
                            height: 3
                            radius: 1.5
                            color: box.inkColor
                            opacity: 0.55
                        }
                    }
                }

                Rectangle {
                    x: -parent.width * 0.35
                    y: parent.height * 0.30
                    width: parent.width * 1.1
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 10
                    border.color: Qt.rgba(box.inkColor.r, box.inkColor.g, box.inkColor.b, 0.16)
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 9
                    text: box.name
                    color: box.inkColor
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
            }

            // Bisagra de la caja junto al lomo.
            Rectangle {
                width: 6
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                    GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.10) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
                }
            }
            // Reflejo del plástico.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                    GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.0) }
                    GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.10) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                }
            }
            // Sombra mientras la portada aún mira de lado.
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.5 * box.shade * Math.cos(box.theta)
            }
            Rectangle {
                anchors.fill: parent
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)
            }
        }
    }

    // ---------- Tapa abierta: cara interior y canto ----------
    // La cara interior está a lidT por debajo de la portada; el canto es el
    // borde libre de la tapa, que a 90° queda mirando a quien mira.
    Item {
        id: innerFace
        width: box.coverW
        height: box.boxH
        readonly property real c: Math.cos(box.phi)
        readonly property real s: Math.sin(box.phi)
        visible: box.lid > 0.001
                 && box.facing(c * box.coverW / 2 + box.lidT * s, s * box.coverW / 2 - box.lidT * c, s, -c)
        transform: Matrix4x4 {
            matrix: box.faceMatrix(innerFace.c, box.lidT * innerFace.s, innerFace.s, -box.lidT * innerFace.c)
        }
        CaseHalf {
            anchors.fill: parent
            clipsOnRight: true
        }
    }

    Rectangle {
        id: lidEdge
        width: box.lidT
        height: box.boxH
        radius: 1
        readonly property real c: Math.cos(box.phi)
        readonly property real s: Math.sin(box.phi)
        visible: box.lid > 0.001
                 && box.facing(box.coverW * c + box.lidT / 2 * s, box.coverW * s - box.lidT / 2 * c, c, s)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#3b3f46" }
            GradientStop { position: 0.4; color: "#2a2d33" }
            GradientStop { position: 1.0; color: "#17191c" }
        }
        transform: Matrix4x4 {
            matrix: box.faceMatrix(lidEdge.s, box.coverW * lidEdge.c, -lidEdge.c, box.coverW * lidEdge.s)
        }
    }
}
