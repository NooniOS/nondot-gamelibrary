.pragma library

// SPDX-FileCopyrightText: 2026 NooniOS
// SPDX-License-Identifier: GPL-2.0-or-later
//
// NonDot GameLibrary - datos compartidos por el widget y los ajustes.

var palette = ["#d71921", "#2f6b4f", "#e8e1d3", "#2d6cdf", "#f2c94c",
               "#30343b", "#7a1c12", "#6b2a3a", "#c26a1b", "#1b3b4b"]

var STEAM_RE = /^steam:\/\/rungameid\/(\d{1,12})$/
// Nombre de un .desktop: sin rutas ni caracteres que el shell interprete.
// Se permiten espacios, comas y acentos (Steam crea "God of War.desktop").
var DESKTOP_RE = /^[^\/\\'"`$;&|<>*?(){}\[\]!#~\n\r]{1,200}\.desktop$/

function newId() {
    return "g" + Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36)
}

function cleanString(v, max) {
    return typeof v === "string" ? v.slice(0, max) : ""
}

// Sonido propio de un juego: un archivo de la carpeta del widget.
function cleanSound(v) {
    v = cleanString(v, 1000)
    return (v.indexOf("file:///") === 0 && v.indexOf("\n") < 0 && /\.(wav|ogg|oga|opus|mp3|flac)$/i.test(v)) ? v : ""
}

function cleanImage(v) {
    v = cleanString(v, 1000)
    return (v.indexOf("file:///") === 0 && v.indexOf("\n") < 0) ? v : ""
}

function cleanColor(v, i) {
    return (typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v)) ? v : palette[i % palette.length]
}

function sanitize(g, i) {
    if (!g || typeof g !== "object")
        return null
    const steamId = cleanString(g.steamId, 12)
    return {
        id: cleanString(g.id, 64) || newId(),
        name: cleanString(g.name, 120),
        launcher: cleanString(g.launcher, 260).trim(),
        steamId: /^\d+$/.test(steamId) ? steamId : "",
        spineImage: cleanImage(g.spineImage),
        coverImage: cleanImage(g.coverImage),
        logoImage: cleanImage(g.logoImage),
        discImage: cleanImage(g.discImage),
        soundFile: cleanSound(g.soundFile),
        color: cleanColor(g.color, i)
    }
}

// Devuelve { games: [...], error: "" }. Un JSON roto no rompe nada:
// lista vacía y el error para mostrarlo.
function parse(json) {
    if (!json || json.trim() === "")
        return { games: [], error: "" }
    let data
    try {
        data = JSON.parse(json)
    } catch (e) {
        return { games: [], error: String(e.message || e) }
    }
    if (!Array.isArray(data))
        return { games: [], error: "not a list" }
    const out = []
    for (let i = 0; i < data.length; ++i) {
        const g = sanitize(data[i], i)
        if (g)
            out.push(g)
    }
    return { games: out, error: "" }
}

// "steam" (con id), "desktop", "empty" o "invalid".
function launcherKind(l) {
    l = (l || "").trim()
    if (l === "")
        return "empty"
    if (STEAM_RE.test(l))
        return "steam"
    if (DESKTOP_RE.test(l))
        return "desktop"
    return "invalid"
}

function steamIdOf(l) {
    const m = STEAM_RE.exec((l || "").trim())
    return m ? m[1] : ""
}

// Comillas simples de shell: 'a'\''b'.
function quote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
}

// url "file:///a%20b" -> ruta "/a b"
function urlToPath(u) {
    u = String(u)
    if (u.indexOf("file://") === 0)
        u = u.slice(7)
    return decodeURIComponent(u)
}
