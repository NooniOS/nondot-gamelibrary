#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 NooniOS
# SPDX-License-Identifier: GPL-2.0-or-later
#
# NonDot GameLibrary - ayudante del mando.
#
# Solo usa la biblioteca estándar. Lee los mandos de /dev/input/event* (el
# usuario de la sesión ya tiene permiso de lectura; no hace falta sudo) y
# nunca escribe en ellos. Cada orden imprime UNA línea y termina: el widget
# lo vuelve a lanzar cuando hace falta.
#
#   mando.py devices                    -> JSON con los mandos conectados
#   mando.py capture SEGUNDOS           -> "k314+k315" (lo que se pulsó) o "TIMEOUT"
#   mando.py combo SPEC MS              -> "COMBO" cuando SPEC se mantiene MS milisegundos, o "IDLE"
#   mando.py nav OK BACK [DIR RETARDO]  -> LEFT/RIGHT/UP/DOWN/OK/BACK, "IDLE",
#                                          "LOST" (se desconectó) o "NOPAD" (no hay)
#
# Un botón es "k<código>" (tecla o botón de evdev) o "a<código>" (gatillo
# analógico, pulsado si pasa de la mitad de su recorrido). Una combinación
# es una lista con "+": "k314+k315".

import fcntl
import json
import os
import select
import struct
import sys
import time

EVENT = struct.Struct("llHHi")
EV_KEY, EV_ABS = 1, 3
BTN_JOYSTICK, BTN_SOUTH = 0x120, 0x130
ABS_X, ABS_Y, ABS_Z, ABS_RX, ABS_RY, ABS_RZ = 0, 1, 2, 3, 4, 5
ABS_GAS, ABS_BRAKE, ABS_HAT0X, ABS_HAT0Y = 9, 10, 16, 17
PARENT = os.getppid()


def ioc_read(nr, size):
    return (2 << 30) | (size << 16) | (ord("E") << 8) | nr


def abs_info(fd, code):
    """(valor, mínimo, máximo) de un eje, o None si el mando no lo tiene."""
    try:
        v, mn, mx, _, _, _ = struct.unpack("6i", fcntl.ioctl(fd, ioc_read(0x40 + code, 24), bytes(24)))
        return v, mn, mx
    except OSError:
        return None


def keys_down(fd):
    """Códigos de los botones pulsados ahora mismo."""
    try:
        buf = fcntl.ioctl(fd, ioc_read(0x18, 96), bytes(96))
    except OSError:
        return set()
    return {i * 8 + b for i, byte in enumerate(buf) for b in range(8) if byte >> b & 1}


def find_pads(devices_file="/proc/bus/input/devices"):
    """Mandos según /proc: los que tienen botones de mando (BTN_SOUTH) o de joystick."""
    try:
        text = open(devices_file).read()
    except OSError:
        return []
    pads = []
    for block in text.split("\n\n"):
        name, event, keybits = "", None, ""
        for line in block.splitlines():
            if line.startswith("N: Name="):
                name = line[8:].strip().strip('"')
            elif line.startswith("H: Handlers="):
                for h in line[12:].split():
                    if h.startswith("event"):
                        event = h
            elif line.startswith("B: KEY="):
                keybits = line[7:].strip()
        if not event or not keybits:
            continue
        words = keybits.split()
        def has(bit):
            idx = len(words) - 1 - bit // 64
            return idx >= 0 and int(words[idx], 16) >> (bit % 64) & 1
        if has(BTN_SOUTH) or has(BTN_JOYSTICK):
            pads.append({"event": event, "name": name})
    return pads


class Pads:
    """Los mandos abiertos y su estado (botones, gatillos, dirección)."""

    def __init__(self):
        self.fds = {}
        self.info = {}
        self.lost = False   # algún mando se desconectó mientras estaba abierto
        for pad in find_pads():
            path = "/dev/input/" + pad["event"]
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            except OSError:
                continue
            self.fds[fd] = pad
            self.info[fd] = self.triggers_of(fd)

    @staticmethod
    def triggers_of(fd):
        """Ejes que son gatillos en este mando. GAS y BRAKE siempre lo son.
        Z y RZ solo si el stick derecho está en RX/RY (Xbox por USB); si no,
        Z y RZ son el propio stick derecho (Xbox por Bluetooth)."""
        def real(c):
            i = abs_info(fd, c)
            return i is not None and i[2] > i[1]
        codes = [c for c in (ABS_GAS, ABS_BRAKE) if real(c)]
        if real(ABS_RX) and real(ABS_RY):
            codes += [c for c in (ABS_Z, ABS_RZ) if real(c)]
        return codes

    def close(self):
        for fd in self.fds:
            os.close(fd)

    def drop(self, fd):
        """Un mando desconectado: su dispositivo da error al leerlo."""
        try:
            os.close(fd)
        except OSError:
            pass
        self.fds.pop(fd, None)
        self.info.pop(fd, None)
        self.lost = True

    def pressed(self):
        """Botones pulsados ahora en cualquier mando, como "k…" y "a…"."""
        out = set()
        for fd in self.fds:
            out |= {"k%d" % c for c in keys_down(fd) if c >= 0x100 or c == 167}
            for c in self.info[fd]:
                cur = abs_info(fd, c)
                if cur and cur[0] > (cur[1] + cur[2]) / 2:
                    out.add("a%d" % c)
        return out

    def direction(self):
        """Dirección de la cruceta o del stick izquierdo, o None."""
        for fd in self.fds:
            hx, hy = abs_info(fd, ABS_HAT0X), abs_info(fd, ABS_HAT0Y)
            if hx and hx[0] < 0: return "LEFT"
            if hx and hx[0] > 0: return "RIGHT"
            if hy and hy[0] < 0: return "UP"
            if hy and hy[0] > 0: return "DOWN"
            sx, sy = abs_info(fd, ABS_X), abs_info(fd, ABS_Y)
            for axis, neg, pos in ((sx, "LEFT", "RIGHT"), (sy, "UP", "DOWN")):
                if axis and axis[2] > axis[1]:
                    centre = (axis[1] + axis[2]) / 2
                    half = (axis[2] - axis[1]) / 2
                    if axis[0] < centre - half * 0.6: return neg
                    if axis[0] > centre + half * 0.6: return pos
        return None

    def wait(self, timeout):
        """Espera a que llegue algo (o pase el tiempo) y vacía los eventos."""
        if not self.fds:
            time.sleep(min(timeout, 2))
            return False
        try:
            r, _, _ = select.select(list(self.fds), [], [], timeout)
        except (OSError, ValueError):
            r = list(self.fds)
        for fd in r:
            try:
                while os.read(fd, EVENT.size * 64):
                    pass
            except BlockingIOError:
                pass
            except OSError:
                self.drop(fd)
        return bool(r)


def parent_alive():
    # Si plasmashell se cierra, el ayudante queda huérfano: entonces termina.
    return os.getppid() == PARENT


def say(text):
    print(text, flush=True)


def cmd_devices():
    say(json.dumps(find_pads()))


def cmd_capture(seconds):
    end = time.time() + seconds
    pads = Pads()
    got = set()
    while time.time() < end and parent_alive():
        pads.wait(0.05)
        now = pads.pressed()
        if now:
            got |= now
        elif got:
            say("+".join(sorted(got)))
            return
    say("TIMEOUT")


def cmd_combo(spec, hold_ms):
    want = set(spec.split("+"))
    armed = False      # hasta que la combinación no esté suelta, no cuenta
    since = None
    pads, rescan = Pads(), time.time() + 3
    # Como mucho 10 minutos: el widget lo vuelve a lanzar. Así nunca queda
    # un proceso viejo esperando si el widget ya no lo escucha.
    give_up = time.time() + 600
    while parent_alive() and time.time() < give_up:
        if time.time() > rescan or pads.lost:   # mandos que se conectan o desconectan
            pads.close()
            pads, rescan = Pads(), time.time() + 3
            armed, since = False, None
        pads.wait(0.05)
        held = want <= pads.pressed()
        if not held:
            armed, since = True, None
            continue
        if armed:
            since = since or time.time()
            if (time.time() - since) * 1000 >= hold_ms:
                say("COMBO")
                return
    say("IDLE")


def cmd_nav(ok, back, held=None, delay_ms=0):
    pads = Pads()
    if not pads.fds:
        say("NOPAD")
        return
    start = time.time()
    before = pads.pressed()
    # Repetición: si la dirección anterior sigue igual tras el retardo, se repite.
    if held:
        while time.time() - start < delay_ms / 1000 and parent_alive():
            pads.wait(0.02)
            if pads.lost:
                say("LOST")
                return
            if pads.direction() != held:
                break
        else:
            if pads.direction() == held:
                say(held)
                return
        # Si cambió a otra dirección durante el retardo, esa cuenta ya.
        d = pads.direction()
        if d and d != held:
            say(d)
            return
    last_dir = pads.direction()
    idle_end = time.time() + 30
    while time.time() < idle_end and parent_alive():
        pads.wait(0.05)
        if pads.lost:
            say("LOST")
            return
        now = pads.pressed()
        new = now - before
        before = now
        if ok in new:
            say("OK"); return
        if back in new:
            say("BACK"); return
        d = pads.direction()
        if d and d != last_dir:
            say(d); return
        last_dir = d
    say("IDLE")


def main(argv):
    if len(argv) < 2:
        say("USO")
        return 2
    cmd = argv[1]
    if cmd == "devices":
        cmd_devices()
    elif cmd == "capture":
        cmd_capture(float(argv[2]) if len(argv) > 2 else 10)
    elif cmd == "combo":
        cmd_combo(argv[2], int(argv[3]) if len(argv) > 3 else 800)
    elif cmd == "nav":
        held = argv[4] if len(argv) > 4 and argv[4] in ("LEFT", "RIGHT", "UP", "DOWN") else None
        delay = int(argv[5]) if len(argv) > 5 else 0
        cmd_nav(argv[2], argv[3], held, delay)
    else:
        say("USO")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
