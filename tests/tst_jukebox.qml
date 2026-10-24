// SPDX-FileCopyrightText: 2026 NooniOS
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Prueba de la rocola: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_jukebox.qml
import QtQuick
import QtTest
import "../package/contents/ui"

Item {
    id: root
    width: 1000
    height: 900

    function makeGames(n) {
        const g = []
        for (let i = 0; i < n; ++i)
            g.push({ id: "j" + i, name: "Juego " + i, color: "#2d6cdf" })
        return g
    }

    Jukebox { id: fits; y: 0; width: 900; height: implicitHeight; boxH: 150; games: root.makeGames(5); openDuration: 260; scrubber: true }
    Jukebox { id: car; y: 300; width: 420; height: implicitHeight; boxH: 150; games: root.makeGames(14); openDuration: 260; scrubber: true }

    TestCase {
        name: "jukebox"
        when: windowShown

        // Bordes visibles [izq, der] de cada portada ahora mismo.
        function spans(j) {
            const out = []
            const strip = j.children.find(c => c.clip === true)
            const cells = strip.children.filter(c => c.adv !== undefined).sort((a, b) => a.index - b.index)
            for (const c of cells) {
                const left = c.x + strip.x
                out.push([left, left + c.width * c.scale])
            }
            return out
        }

        function noOverlap(j) {
            let worst = 0, minLeft = 1e9, maxRight = -1e9
            let seed = 11
            for (let n = 0; n < 40; ++n) {
                seed = (seed * 1103515245 + 12345) % 2147483648
                j.scrubTo(seed % j.count)
                wait(12 + seed % 40)
                const sp = spans(j)
                for (let i = 0; i + 1 < sp.length; ++i)
                    worst = Math.max(worst, sp[i][1] - (sp[i + 1][0] - j.gap))
                minLeft = Math.min(minLeft, sp[0][0])
                maxRight = Math.max(maxRight, sp[sp.length - 1][1])
            }
            wait(400)
            verify(worst <= 0.5, "superposición de " + worst + " px")
            return [minLeft, maxRight]
        }

        function test_fitsNoOverlap() {
            verify(!fits.carousel)
            const e = noOverlap(fits)
            verify(e[0] >= fits.pad - 0.5 && e[1] <= fits.width - fits.pad + 0.5, "se sale: " + e)
            fits.openIndex = -1
        }

        function test_carouselNoOverlap() {
            verify(car.carousel)
            noOverlap(car)
            car.openIndex = -1
        }

        // En el centro la fila no se mueve y el cursor elige lo que tiene debajo.
        function test_middleIsStill() {
            car.openDuration = 0
            car.scrollTarget = car.maxScroll / 2
            wait(50)
            const y = car.topPad + car.boxH * 0.6
            const before = car.scrollTarget
            const mid = car.width / 2
            for (let dx = -40; dx <= 40; dx += 4) {
                mouseMove(car, mid + dx, y)
                wait(100)
                compare(car.scrollTarget, before, "la fila se movió en el centro")
                compare(car.openIndex, car.pick(mid + dx, y))
            }
            mouseMove(root, 990, 890)
            wait(250)
            car.openDuration = 260
        }

        // En el borde la fila se desliza (sin destacar nada) y, alternando
        // borde y centro, se llega a todos los juegos.
        function test_edgesReachAll() {
            car.openDuration = 0
            car.scrollTarget = 0
            wait(50)
            const y = car.topPad + car.boxH * 0.6
            const seen = {}
            const sweep = () => {
                for (let x = car.pad + car.edgeZone + 1; x < car.width - car.pad - car.edgeZone; x += 6) {
                    mouseMove(car, x, y)
                    wait(90)
                    if (car.openIndex >= 0)
                        seen[car.openIndex] = true
                }
            }
            sweep()
            let guard = 0
            while (car.scrollTarget < car.maxScroll - 0.5 && guard++ < 40) {
                mouseMove(car, car.width - car.pad - 3, y)
                wait(120)
                verify(car.scrollTarget >= car.maxScroll - 0.5 || car.openIndex === -1, "destaca mientras desliza")
                sweep()
            }
            verify(car.scrollTarget >= car.maxScroll - 0.5, "no llegó al final")
            // al final, el borde derecho ya no desliza y deja elegir
            mouseMove(car, car.width - car.pad - 3, y)
            wait(120)
            if (car.openIndex >= 0)
                seen[car.openIndex] = true
            compare(Object.keys(seen).length, car.count, "no se llega a todos: " + Object.keys(seen).sort((a, b) => a - b))
            mouseMove(root, 990, 890)
            wait(250)
            car.openDuration = 260
        }

        // Con el cursor QUIETO en el borde la fila sigue deslizándose.
        function test_edgeHoldStill() {
            car.scrollTarget = 0
            wait(50)
            const y = car.topPad + car.boxH * 0.6
            mouseMove(car, car.width - car.pad - 3, y)
            wait(50)
            const b = car.scrollTarget
            wait(500)
            verify(car.scrollTarget > b + 100, "no avanza con el cursor quieto: " + b + " -> " + car.scrollTarget)
            mouseMove(root, 990, 890)
            wait(250)
            car.scrollTarget = 0
        }

        function test_wheel() {
            car.openIndex = -1
            const y = car.y + car.topPad + car.boxH * 0.5
            mouseWheel(root, 200, y, 0, -120)
            compare(car.openIndex, 0)
            mouseWheel(root, 200, y, 0, -120)
            mouseWheel(root, 200, y, 0, -120)
            compare(car.openIndex, 2)
            mouseWheel(root, 200, y, 0, 120)
            compare(car.openIndex, 1)
            car.openIndex = -1
        }

        function test_barCentersSelection() {
            car.scrubTo(12)
            wait(600)
            const sp = spans(car)
            verify(sp[12][0] >= 0 && sp[12][1] <= car.width, "la elegida no se ve: " + sp[12])
            car.openIndex = -1
        }
    }
}
