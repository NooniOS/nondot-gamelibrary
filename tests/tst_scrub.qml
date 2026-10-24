// SPDX-FileCopyrightText: 2026 NooniOS
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Prueba de la barra: QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_scrub.qml
import QtQuick
import QtTest
import "../package/contents/ui"
Item { id: root; width: 600; height: 900
  Shelf { id: shelf; width: 300; height: implicitHeight; boxH: 150; scrubber: true; openDuration: 0
    games: [{id:"a",name:"A",color:"#d71921"},{id:"b",name:"B",color:"#2f6b4f"},{id:"c",name:"C",color:"#2d6cdf"},{id:"d",name:"D",color:"#f2c94c"}]
    property int launched: -1
    onLaunchRequested: (i) => launched = i }
  // Estantería llena: 2 repisas, sin hueco de sobra.
  Shelf { id: full; y: 0; x: 0; width: 260; height: implicitHeight; boxH: 200; openDuration: 500; visible: false
    games: { const g = []; for (let i = 0; i < 12; ++i) g.push({ id: "f" + i, name: "F" + i, color: "#2d6cdf" }); return g } }

  TestCase { name: "full"; when: windowShown
    function test_fullRowNoOverlap() {
      full.visible = true
      verify(full.rows >= 2)
      let worst = 0, maxRight = 0, minLeft = 1e9
      // cambios rápidos, también a mitad de animación
      const order = [0, 1, 2, 3, 2, 1, 4, 0]
      // y una tanda al azar (repetible)
      let seed = 7
      for (let n = 0; n < 40; ++n) {
        seed = (seed * 1103515245 + 12345) % 2147483648
        order.push(seed % 6)
      }
      for (const k of order) {
        full.openIndex = k
        const frames = 1 + (order.length % 5)
        for (let f = 0; f < frames; ++f) {
          wait(17 + (k * 13) % 40)
          const items = full.children.filter(c => c.visualW !== undefined).sort((a, b) => a.index - b.index)
          for (let i = 0; i < items.length; ++i) {
            const it = items[i]
            const left = it.x - it.width * full.popScale * it.t / 2
            const right = left + it.visualW
            if (full.layout.rs[i] === 0) {
              maxRight = Math.max(maxRight, right)
              minLeft = Math.min(minLeft, left)
            }
            if (i + 1 < items.length && full.layout.rs[i + 1] === full.layout.rs[i]) {
              const n = items[i + 1]
              worst = Math.max(worst, right - (n.x - n.width * full.popScale * n.t / 2))
            }
          }
        }
      }
      verify(worst <= 0.5, "superposición de " + worst + " px")
      verify(maxRight <= full.width - full.pad + 1, "se sale por la derecha: " + maxRight)
      verify(minLeft >= full.pad - 1, "se sale por la izquierda: " + minLeft)
      full.visible = false
    }
  }

  TestCase { name: "scrub"; when: windowShown
    // Bordes visibles [izq, der] de cada caja ahora mismo.
    function spans() {
      const out = []
      for (let i = 0; i < shelf.count; ++i) {
        const it = shelf.children.find(c => c.visualW !== undefined && c.index === i)
        const left = it.x - it.width * shelf.popScale * it.t / 2
        out.push([left, left + it.visualW])
      }
      return out
    }
    function test_noOverlap() {
      shelf.openDuration = 300
      let worst = 0, maxRight = 0, minLeft = 1e9
      const order = [1, 2, 3, 0, 2, 1]
      for (const k of order) {
        shelf.openIndex = k
        for (let f = 0; f < 8; ++f) {
          wait(25)
          const sp = spans()
          for (let i = 0; i + 1 < sp.length; ++i)
            worst = Math.max(worst, sp[i][1] - sp[i + 1][0])
          maxRight = Math.max(maxRight, sp[sp.length - 1][1])
          minLeft = Math.min(minLeft, sp[0][0])
        }
      }
      wait(400)
      verify(worst <= 0.5, "superposición de " + worst + " px")
      verify(maxRight <= shelf.width - shelf.pad + 0.5, "se sale por la derecha: " + maxRight)
      verify(minLeft >= shelf.pad - 0.5, "se sale por la izquierda: " + minLeft)
      shelf.openDuration = 0
      shelf.openIndex = -1
      wait(50)
    }
    function test_sweepRight() {
      // Recorrer la fila de izquierda a derecha: el juego abierto solo avanza.
      const y = shelf.topPad + 60
      let last = -1
      for (let x = shelf.pad + 1; x < shelf.width - shelf.pad; x += 2) {
        mouseMove(shelf, x, y)
        wait(5)
        const i = shelf.pick(x, y)
        if (i >= 0) {
          shelf.scrubTo(i)
          verify(i >= last, "retrocede de " + last + " a " + i + " en x=" + x)
          last = i
        }
      }
      compare(last, shelf.count - 1)
      shelf.openIndex = -1
    }
    function test_sweepLeft() {
      const y = shelf.topPad + 60
      let last = 99
      for (let x = shelf.width - shelf.pad - 1; x > shelf.pad; x -= 2) {
        mouseMove(shelf, x, y)
        wait(5)
        const i = shelf.pick(x, y)
        if (i >= 0) {
          shelf.scrubTo(i)
          verify(i <= last, "retrocede de " + last + " a " + i + " en x=" + x)
          last = i
        }
      }
      compare(last, 0)
      shelf.openIndex = -1
    }
    function barY() { return shelf.height - shelf.bottomPad - shelf.scrubberH / 2 }
    function test_scrub() {
      const x0 = shelf.pad + 6, w = shelf.width - 2 * x0
      mouseMove(shelf, x0 + w * 0.1, barY()); wait(50)
      compare(shelf.openIndex, 0)
      mouseMove(shelf, x0 + w * 0.6, barY()); wait(50)
      compare(shelf.openIndex, 2)
      mousePress(shelf, x0 + w * 0.6, barY())
      mouseMove(shelf, x0 + w * 0.9, barY()); wait(50)
      compare(shelf.openIndex, 3)
      mouseRelease(shelf, x0 + w * 0.9, barY()); wait(50)
      compare(shelf.launched, 3)
      // arrastrar fuera y soltar: no lanza
      shelf.launched = -1
      mousePress(shelf, x0 + w * 0.3, barY())
      mouseMove(shelf, x0 + w * 0.3, barY() - 120); wait(50)
      mouseRelease(shelf, x0 + w * 0.3, barY() - 120); wait(300)
      compare(shelf.launched, -1)
      // el hover normal sobre los lomos sigue funcionando
      mouseMove(shelf, shelf.targetLeft(1, shelf.openIndex) + 3, shelf.topPad + 60); wait(300)
      compare(shelf.openIndex, 1)
    }
  }
}
