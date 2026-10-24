/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - ajustes: lista de juegos y editor del seleccionado.

    Las imágenes elegidas se copian a ~/.local/share/nondot-gamelibrary para que no
    se pierdan si se mueve el original. QML no puede copiar archivos, así
    que se usa "cp" por el motor "executable", siempre con rutas entre
    comillas simples y con el nombre de destino generado aquí.
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasma5support as P5Support

import "games.js" as Games

KCMUtils.SimpleKCM {
    id: page

    property string cfg_gamesJson
    property string cfg_gamesJsonDefault
    property string cfg_removedIds
    property string cfg_removedIdsDefault

    // Lista tal como estaba guardada al abrir los ajustes: sus imágenes no
    // se limpian aunque se cancelen los cambios.
    property string savedJson: ""
    property var unused: []
    property real unusedBytes: 0

    property var games: []
    property int current: -1
    property string loadError: ""
    property string status: ""
    property bool statusIsError: false
    property int pending: 0
    property string wrapGameId: ""

    readonly property var game: current >= 0 && current < games.length ? games[current] : null

    readonly property string dataDir: Games.urlToPath(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))
    readonly property string artDir: dataDir + "/nondot-gamelibrary"
    readonly property string steamCache: dataDir + "/Steam/appcache/librarycache"

    Component.onCompleted: {
        savedJson = cfg_gamesJson
        const r = Games.parse(cfg_gamesJson)
        games = r.games
        loadError = r.error
        current = games.length > 0 ? 0 : -1
        for (const g of games)
            rows.append(rowOf(g))
    }

    // Filas de la lista de la izquierda. Es un ListModel aparte (y no el
    // array "games") para poder mover, añadir o quitar una sola fila: así la
    // lista anima el cambio y no vuelve arriba cada vez.
    ListModel {
        id: rows
    }

    function rowOf(g) {
        return { gid: g.id, name: g.name, launcher: g.launcher, steamId: g.steamId,
                 coverImage: g.coverImage, color: g.color }
    }

    // Deja a la vista la fila i cuando la lista termine de colocarse.
    function showRow(i) {
        Qt.callLater(() => list.positionViewAtIndex(i, ListView.Contain))
    }

    function commit() {
        cfg_gamesJson = JSON.stringify(games)
    }

    function say(text, isError) {
        status = text
        statusIsError = !!isError
    }

    function setFieldFor(id, key, value) {
        const arr = games.slice()
        const i = arr.findIndex(g => g.id === id)
        if (i < 0)
            return
        const g = Object.assign({}, arr[i])
        g[key] = value
        arr[i] = g
        games = arr
        rows.set(i, rowOf(g))
        commit()
    }

    function setField(key, value) {
        if (game)
            setFieldFor(game.id, key, value)
    }

    function addGame() {
        const arr = games.slice()
        arr.push({
            id: Games.newId(), name: i18n("New game"), launcher: "", steamId: "",
            spineImage: "", coverImage: "", logoImage: "", discImage: "", soundFile: "",
            color: Games.palette[arr.length % Games.palette.length]
        })
        games = arr
        rows.append(rowOf(arr[arr.length - 1]))
        current = arr.length - 1
        commit()
        showRow(current)
    }

    function move(delta) {
        const j = current + delta
        if (!game || j < 0 || j >= games.length)
            return
        const arr = games.slice()
        const g = arr[current]
        arr[current] = arr[j]
        arr[j] = g
        games = arr
        rows.move(current, j, 1)
        current = j
        commit()
        showRow(j)
    }

    function removeCurrent() {
        if (!game)
            return
        const removed = removedIds()
        if (removed.indexOf(game.id) < 0)
            removed.push(game.id)
        cfg_removedIds = JSON.stringify(removed.slice(-500))
        const arr = games.slice()
        arr.splice(current, 1)
        games = arr
        rows.remove(current)
        current = Math.min(current, arr.length - 1)
        commit()
        if (current >= 0)
            showRow(current)
    }

    // ---------- Limpieza de imágenes ----------
    // Solo mira la carpeta propia del widget (~/.local/share/nondot-gamelibrary) y
    // solo archivos con el nombre que pone el widget (<id>-<tipo>-<marca>)
    // cuyo <id> es de un juego de ESTE widget (actual o quitado), para no
    // tocar las imágenes de otro widget.

    readonly property var artNameRe: /^([A-Za-z0-9_-]+)-(spine|cover|logo|disc|sound)-[a-z0-9]+\.(png|jpe?g|webp|wav|ogg|oga|opus|mp3|flac)$/

    function removedIds() {
        try {
            const v = JSON.parse(cfg_removedIds || "[]")
            return Array.isArray(v) ? v.filter(x => typeof x === "string") : []
        } catch (e) {
            return []
        }
    }

    function scanUnused() {
        const lists = [games, Games.parse(savedJson).games]
        const prefix = "file://" + artDir + "/"
        const used = {}, owned = {}
        for (const list of lists) {
            for (const g of list) {
                owned[g.id] = true
                for (const k of ["spineImage", "coverImage", "logoImage", "discImage", "soundFile"]) {
                    if (g[k].indexOf(prefix) === 0)
                        used[g[k].slice(prefix.length)] = true
                }
            }
        }
        for (const id of removedIds())
            owned[id] = true

        shell.run("find " + Games.quote(artDir) + " -maxdepth 1 -type f -printf '%f\\t%s\\n'", (code, out, err) => {
            const list = []
            let bytes = 0
            for (const line of out.split("\n")) {
                const parts = line.split("\t")
                const m = artNameRe.exec(parts[0])
                if (!m || !owned[m[1]] || used[parts[0]])
                    continue
                list.push(parts[0])
                bytes += Number(parts[1]) || 0
            }
            unused = list
            unusedBytes = bytes
            if (list.length === 0)
                say(i18n("There are no unused images."), false)
            else
                confirmClean.open()
        })
    }

    function cleanUnused() {
        const names = unused.filter(n => artNameRe.test(n))
        if (names.length === 0)
            return
        shell.run("rm -f -- " + names.map(n => Games.quote(artDir + "/" + n)).join(" "), (code, out, err) => {
            if (code === 0)
                say(i18np("Deleted %1 unused image.", "Deleted %1 unused images.", names.length), false)
            else
                say(i18n("Some images could not be deleted: %1", err.trim()), true)
            unused = []
        })
    }

    // ---------- Comandos ----------

    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})
        property int seq: 0

        function run(cmd, cb) {
            const src = cmd + " #gs" + (++seq)
            callbacks[src] = cb
            page.pending++
            connectSource(src)
        }

        onNewData: (source, data) => {
            const cb = callbacks[source]
            delete callbacks[source]
            disconnectSource(source)
            page.pending--
            if (cb)
                cb(data["exit code"], data.stdout || "", data.stderr || "")
        }
    }

    // Copia "srcPath" a la carpeta del widget y guarda la ruta en
    // <kind>Image del juego "gameId".
    function copyImage(srcPath, kind, gameId) {
        const m = /\.(png|jpe?g|webp)$/i.exec(srcPath)
        if (!m || srcPath.indexOf("\n") >= 0) {
            say(i18n("Only PNG, JPG or WEBP images are accepted."), true)
            return
        }
        const safeId = gameId.replace(/[^A-Za-z0-9_-]/g, "")
        const dest = artDir + "/" + safeId + "-" + kind + "-" + Date.now().toString(36) + "." + m[1].toLowerCase()
        shell.run("mkdir -p -- " + Games.quote(artDir) + " && cp -f -- " + Games.quote(srcPath) + " " + Games.quote(dest),
                  (code, out, err) => {
            if (code === 0) {
                setFieldFor(gameId, kind + "Image", "file://" + dest)
                if (statusIsError)
                    say("", false)
            } else {
                say(i18n("Could not copy the image: %1", err.trim()), true)
            }
        })
    }

    // Copia el sonido propio de un juego a la carpeta del widget.
    function copySound(srcPath, gameId) {
        const m = /\.(wav|ogg|oga|opus|mp3|flac)$/i.exec(srcPath)
        if (!m || srcPath.indexOf("\n") >= 0) {
            say(i18n("Only WAV, OGG, OPUS, MP3 or FLAC sounds are accepted."), true)
            return
        }
        const safeId = gameId.replace(/[^A-Za-z0-9_-]/g, "")
        const dest = artDir + "/" + safeId + "-sound-" + Date.now().toString(36) + "." + m[1].toLowerCase()
        shell.run("mkdir -p -- " + Games.quote(artDir) + " && cp -f -- " + Games.quote(srcPath) + " " + Games.quote(dest),
                  (code, out, err) => {
            if (code === 0)
                setFieldFor(gameId, "soundFile", "file://" + dest)
            else
                say(i18n("Could not copy the sound: %1", err.trim()), true)
        })
    }

    // Probar un sonido; con Loader, por si falta Qt Multimedia.
    Loader {
        id: previewer
        source: "Voice.qml"
    }
    function previewSound(url) {
        if (!previewer.item || !url)
            return
        previewer.item.source = url
        previewer.item.play()
    }

    // Busca el arte de Steam en su caché local (portada vertical y logo) y lo copia.
    function fetchSteamArt(gameId, steamId) {
        if (!/^\d{1,12}$/.test(steamId))
            return
        const dir = steamCache + "/" + steamId
        shell.run("find " + Games.quote(dir) + " -maxdepth 2 -type f \\( -name library_600x900.jpg -o -name library_capsule.jpg -o -name logo.png \\)",
                  (code, out, err) => {
            const lines = out.split("\n").filter(l => l !== "")
            const cover = lines.find(l => l.endsWith("/library_600x900.jpg")) || lines.find(l => l.endsWith("/library_capsule.jpg"))
            const logo = lines.find(l => l.endsWith("/logo.png"))
            if (cover)
                copyImage(cover, "cover", gameId)
            if (logo)
                copyImage(logo, "logo", gameId)
            if (!cover && !logo)
                say(i18n("Steam has no art saved for id %1 on this computer.", steamId), true)
        })
    }

    // Lee Name= y Exec= de un .desktop para rellenar el nombre y el id de Steam.
    // "placeholder": nombre provisional que se puede sustituir por Name=.
    function readDesktop(path, gameId, placeholder) {
        shell.run("grep -E '^(Name|Exec)=' -- " + Games.quote(path), (code, out, err) => {
            let name = "", exec = ""
            for (const line of out.split("\n")) {
                if (!name && line.startsWith("Name="))
                    name = line.slice(5).trim()
                else if (!exec && line.startsWith("Exec="))
                    exec = line.slice(5).trim()
            }
            const g = games.find(x => x.id === gameId)
            if (!g)
                return
            if (name && (g.name === "" || g.name === i18n("New game") || g.name === placeholder))
                setFieldFor(gameId, "name", name)
            const m = /steam:\/\/rungameid\/(\d{1,12})/.exec(exec)
            if (m) {
                setFieldFor(gameId, "steamId", m[1])
                if (g.coverImage === "")
                    fetchSteamArt(gameId, m[1])
            }
        })
    }

    // Crea un juego por cada .desktop elegido (los que ya están se saltan).
    function addDesktops(urls) {
        const arr = games.slice()
        const have = {}
        for (const g of arr)
            if (g.launcher !== "")
                have[g.launcher] = true
        const added = []
        let skipped = 0, invalid = 0
        for (const u of urls) {
            const path = Games.urlToPath(u)
            const file = path.slice(path.lastIndexOf("/") + 1)
            if (Games.launcherKind(file) !== "desktop") {
                invalid++
                continue
            }
            if (have[file]) {
                skipped++
                continue
            }
            have[file] = true
            const g = {
                id: Games.newId(), name: file.slice(0, -8), launcher: file, steamId: "",
                spineImage: "", coverImage: "", logoImage: "", discImage: "", soundFile: "",
                color: Games.palette[arr.length % Games.palette.length]
            }
            arr.push(g)
            added.push({ id: g.id, path: path, placeholder: g.name })
        }
        if (added.length > 0) {
            games = arr
            for (const a of added)
                rows.append(rowOf(arr.find(g => g.id === a.id)))
            current = arr.length - 1
            commit()
            showRow(current)
            for (const a of added)
                readDesktop(a.path, a.id, a.placeholder)
        }
        let msg = i18np("Added %1 game.", "Added %1 games.", added.length)
        if (skipped > 0)
            msg += " " + i18np("%1 was already on the shelf.", "%1 were already on the shelf.", skipped)
        if (invalid > 0)
            msg += " " + i18np("%1 has a file name that is not allowed.", "%1 have a file name that is not allowed.", invalid)
        say(msg, invalid > 0)
    }

    FileDialog {
        id: manyDialog
        title: i18n("Choose your games' shortcuts")
        fileMode: FileDialog.OpenFiles
        nameFilters: [i18n("Shortcuts (*.desktop)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.ApplicationsLocation)
        onAccepted: page.addDesktops(selectedFiles)
    }

    FileDialog {
        id: imageDialog
        property string kind: "cover"
        title: i18n("Choose an image")
        nameFilters: [i18n("Images (*.png *.jpg *.jpeg *.webp)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: if (page.game) page.copyImage(Games.urlToPath(selectedFile), kind, page.game.id)
    }

    FileDialog {
        id: desktopDialog
        title: i18n("Choose the game's shortcut")
        nameFilters: [i18n("Shortcuts (*.desktop)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.ApplicationsLocation)
        onAccepted: {
            if (!page.game)
                return
            const path = Games.urlToPath(selectedFile)
            const name = path.slice(path.lastIndexOf("/") + 1)
            if (Games.launcherKind(name) !== "desktop") {
                page.say(i18n("That file name has characters that are not allowed."), true)
                return
            }
            page.setField("launcher", name)
            if (path.indexOf("/applications/") < 0)
                page.say(i18n("That file is not in an applications folder; it may not be found when launching."), true)
            else
                page.say("", false)
            page.readDesktop(path, page.game.id)
        }
    }

    FileDialog {
        id: wrapFileDialog
        title: i18n("Choose the full box art")
        nameFilters: [i18n("Images (*.png *.jpg *.jpeg *.webp)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: {
            if (!page.game)
                return
            const id = page.game.id
            const safeId = id.replace(/[^A-Za-z0-9_-]/g, "")
            const stamp = Date.now().toString(36)
            page.wrapGameId = id
            wrapDialog.spineDest = page.artDir + "/" + safeId + "-spine-" + stamp + ".png"
            wrapDialog.coverDest = page.artDir + "/" + safeId + "-cover-" + stamp + ".png"
            wrapDialog.source = selectedFile
            // La carpeta debe existir antes de guardar los recortes.
            shell.run("mkdir -p -- " + Games.quote(page.artDir), (code, out, err) => {
                if (code === 0)
                    wrapDialog.open()
                else
                    page.say(i18n("Could not create the folder %1: %2", page.artDir, err.trim()), true)
            })
        }
    }

    FileDialog {
        id: gameSoundDialog
        title: i18n("Choose the sound for this game")
        nameFilters: [i18n("Sounds (*.wav *.ogg *.oga *.opus *.mp3 *.flac)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.MusicLocation)
        onAccepted: if (page.game) page.copySound(Games.urlToPath(selectedFile), page.game.id)
    }

    FileDialog {
        id: discFileDialog
        title: i18n("Choose the disc image")
        nameFilters: [i18n("Images (*.png *.jpg *.jpeg *.webp)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: {
            if (!page.game)
                return
            const id = page.game.id
            const safeId = id.replace(/[^A-Za-z0-9_-]/g, "")
            page.wrapGameId = id
            discDialog.dest = page.artDir + "/" + safeId + "-disc-" + Date.now().toString(36) + ".png"
            discDialog.source = selectedFile
            shell.run("mkdir -p -- " + Games.quote(page.artDir), (code, out, err) => {
                if (code === 0)
                    discDialog.open()
                else
                    page.say(i18n("Could not create the folder %1: %2", page.artDir, err.trim()), true)
            })
        }
    }

    DiscImportDialog {
        id: discDialog
        onImported: (discUrl) => {
            page.setFieldFor(page.wrapGameId, "discImage", discUrl)
            page.say(i18n("Disc art created."), false)
        }
    }

    WrapImportDialog {
        id: wrapDialog
        onImported: (spineUrl, coverUrl) => {
            page.setFieldFor(page.wrapGameId, "spineImage", spineUrl)
            page.setFieldFor(page.wrapGameId, "coverImage", coverUrl)
            page.say(i18n("Spine and cover created."), false)
        }
    }

    // ---------- Exportar / importar la lista ----------
    // Un archivo JSON con la lista de juegos (sirve de copia de seguridad y
    // para pasar los juegos a otro widget). Las imágenes no van dentro: la
    // lista guarda dónde están (en ~/.local/share/…), así que en el mismo
    // equipo se conservan.

    property var pendingImport: []

    function exportList(path) {
        const data = JSON.stringify({ app: "NonDot GameLibrary", format: 1, exported: new Date().toISOString(), games: games }, null, 2)
        shell.run("printf '%s\\n' " + Games.quote(data) + " > " + Games.quote(path), (code, out, err) => {
            if (code === 0)
                say(i18np("List exported: %1 game to %2.", "List exported: %1 games to %2.", games.length, path), false)
            else
                say(i18n("Could not export the list: %1", err.trim()), true)
        })
    }

    function readImport(path) {
        shell.run("cat -- " + Games.quote(path), (code, out, err) => {
            if (code !== 0) {
                say(i18n("Could not read the file: %1", err.trim()), true)
                return
            }
            let data
            try {
                data = JSON.parse(out)
            } catch (e) {
                say(i18n("That file is not a valid game list."), true)
                return
            }
            const list = Array.isArray(data) ? data : (data && Array.isArray(data.games) ? data.games : null)
            if (!list) {
                say(i18n("That file is not a valid game list."), true)
                return
            }
            const r = Games.parse(JSON.stringify(list))
            if (r.games.length === 0) {
                say(i18n("The file has no games."), true)
                return
            }
            pendingImport = r.games
            if (games.length === 0)
                applyImport(true)
            else
                confirmImport.open()
        })
    }

    // replace: sustituir la lista; si no, añadir los que no estén ya
    // (mismo id o mismo lanzador).
    function applyImport(replace) {
        let arr
        let added = 0
        if (replace) {
            arr = pendingImport.slice()
            added = arr.length
        } else {
            arr = games.slice()
            const ids = {}, launchers = {}
            for (const g of arr) {
                ids[g.id] = true
                if (g.launcher !== "")
                    launchers[g.launcher] = true
            }
            for (const g of pendingImport) {
                if (ids[g.id] || (g.launcher !== "" && launchers[g.launcher]))
                    continue
                arr.push(g)
                added++
            }
        }
        games = arr
        rows.clear()
        for (const g of arr)
            rows.append(rowOf(g))
        current = arr.length > 0 ? 0 : -1
        commit()
        pendingImport = []
        say(i18np("Imported %1 game. Press Apply to save it.", "Imported %1 games. Press Apply to save them.", added), false)
    }

    FileDialog {
        id: exportDialog
        title: i18n("Export the game list")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [i18n("Game list (*.json)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        selectedFile: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) + "/nondot-gamelibrary.json"
        onAccepted: page.exportList(Games.urlToPath(selectedFile))
    }

    FileDialog {
        id: importDialog
        title: i18n("Import a game list")
        nameFilters: [i18n("Game list (*.json)")]
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        onAccepted: page.readImport(Games.urlToPath(selectedFile))
    }

    Kirigami.PromptDialog {
        id: confirmImport
        title: i18n("Import list")
        subtitle: i18np("The file has %1 game.", "The file has %1 games.", page.pendingImport.length)
                  + " " + i18np("Your current list has %1.", "Your current list has %1.", page.games.length)
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: i18n("Add to my list")
                icon.name: "list-add"
                onTriggered: {
                    page.applyImport(false)
                    confirmImport.close()
                }
            },
            Kirigami.Action {
                text: i18n("Replace my list")
                icon.name: "document-replace"
                onTriggered: {
                    page.applyImport(true)
                    confirmImport.close()
                }
            }
        ]
    }

    Kirigami.PromptDialog {
        id: confirmClean
        title: i18n("Clean up unused images")
        subtitle: i18np("%1 image (%2) will be deleted from the widget's folder, %3. Nothing from Steam, your downloads or the original images is touched.",
                        "%1 images (%2) will be deleted from the widget's folder, %3. Nothing from Steam, your downloads or the original images is touched.",
                        page.unused.length, (page.unusedBytes / 1048576).toFixed(1) + " MB", page.artDir)
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: page.cleanUnused()
    }

    Kirigami.PromptDialog {
        id: confirmRemove
        title: i18n("Remove game")
        subtitle: page.game ? i18n("Remove “%1” from the shelf? The game is not uninstalled.", page.game.name) : ""
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: page.removeCurrent()
    }

    // ---------- Interfaz ----------
    // A la izquierda la lista de juegos; a la derecha el editor del elegido,
    // en secciones. Las opciones generales están en sus propias páginas.

    // Una fila de imagen: nombre del archivo y botones con icono.
    // (Un componente en línea no ve los id de este archivo: recibe la página
    // y el selector de imágenes como propiedades.)
    component ImageRow: RowLayout {
        id: imageRow
        required property var pageRef
        required property var dialogRef
        property string kind
        property string emptyText: i18n("(fallback color)")
        property string importText: ""
        signal importClicked()
        readonly property string path: pageRef.game ? pageRef.game[kind + "Image"] : ""
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            Layout.maximumWidth: Kirigami.Units.gridUnit * 11
            text: imageRow.path !== "" ? imageRow.path.slice(imageRow.path.lastIndexOf("/") + 1) : imageRow.emptyText
            elide: Text.ElideMiddle
            opacity: imageRow.path !== "" ? 1 : 0.6
        }
        QQC2.ToolButton {
            icon.name: "insert-image"
            onClicked: {
                imageRow.dialogRef.kind = imageRow.kind
                imageRow.dialogRef.open()
            }
            QQC2.ToolTip.text: i18n("Pick an image")
            QQC2.ToolTip.visible: hovered
        }
        QQC2.ToolButton {
            visible: imageRow.importText !== ""
            icon.name: "transform-crop"
            onClicked: imageRow.importClicked()
            QQC2.ToolTip.text: imageRow.importText
            QQC2.ToolTip.visible: hovered
        }
        QQC2.ToolButton {
            icon.name: "edit-clear"
            enabled: imageRow.path !== ""
            onClicked: imageRow.pageRef.setField(imageRow.kind + "Image", "")
            QQC2.ToolTip.text: i18n("Remove the image")
            QQC2.ToolTip.visible: hovered
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            visible: page.loadError !== ""
            text: i18n("The saved list was damaged (%1). If you apply changes, a new list will be saved.", page.loadError)
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: page.statusIsError ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            visible: page.status !== ""
            text: page.status
            showCloseButton: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.gridUnit

            // ---------- Lista de juegos ----------
            ColumnLayout {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.smallSpacing

                // Barra de herramientas de la lista.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    QQC2.ToolButton {
                        id: addButton
                        icon.name: "list-add"
                        text: i18n("Add")
                        onClicked: addMenu.popup(addButton, 0, addButton.height)
                        QQC2.Menu {
                            id: addMenu
                            QQC2.MenuItem {
                                icon.name: "list-add"
                                text: i18n("An empty game")
                                onTriggered: page.addGame()
                            }
                            QQC2.MenuItem {
                                icon.name: "folder-open"
                                text: i18n("Several games from their shortcuts…")
                                onTriggered: manyDialog.open()
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    QQC2.ToolButton {
                        icon.name: "go-up"
                        enabled: page.current > 0
                        onClicked: page.move(-1)
                        QQC2.ToolTip.text: i18n("Move up (Alt + ↑)")
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: page.game !== null && page.current < page.games.length - 1
                        onClicked: page.move(1)
                        QQC2.ToolTip.text: i18n("Move down (Alt + ↓)")
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "list-remove"
                        enabled: page.game !== null
                        onClicked: confirmRemove.open()
                        QQC2.ToolTip.text: i18n("Remove from the shelf…")
                        QQC2.ToolTip.visible: hovered
                    }
                }

                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 26

                    ListView {
                        id: list
                        clip: true
                        model: rows
                        currentIndex: page.current
                        // La fila que se mueve se desliza entre las demás.
                        move: Transition {
                            NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic }
                        }
                        displaced: Transition {
                            NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutCubic }
                        }
                        add: Transition {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                        }
                        remove: Transition {
                            NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                        }

                        // Alt + flechas: mover el juego elegido.
                        Keys.onPressed: (ev) => {
                            if (ev.modifiers & Qt.AltModifier) {
                                if (ev.key === Qt.Key_Up) { page.move(-1); ev.accepted = true }
                                else if (ev.key === Qt.Key_Down) { page.move(1); ev.accepted = true }
                            }
                        }

                        delegate: QQC2.ItemDelegate {
                            id: rowItem
                            required property int index
                            required property string name
                            required property string launcher
                            required property string steamId
                            required property string coverImage
                            required property string color
                            width: ListView.view.width
                            highlighted: index === page.current
                            onClicked: {
                                page.current = index
                                list.forceActiveFocus()
                            }

                            contentItem: RowLayout {
                                spacing: Kirigami.Units.largeSpacing
                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 40
                                    radius: 3
                                    color: rowItem.color
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        source: coverImage
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize.height: 80
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    QQC2.Label {
                                        Layout.fillWidth: true
                                        text: name || i18n("(no name)")
                                        elide: Text.ElideRight
                                        font.bold: rowItem.highlighted
                                    }
                                    QQC2.Label {
                                        Layout.fillWidth: true
                                        text: Games.launcherKind(launcher) === "invalid" ? i18n("Invalid launcher")
                                            : steamId !== "" ? i18n("Steam · %1", steamId)
                                            : launcher !== "" ? launcher
                                            : i18n("No launcher")
                                        color: Games.launcherKind(launcher) === "invalid" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                                        elide: Text.ElideRight
                                        font: Kirigami.Theme.smallFont
                                        opacity: 0.7
                                    }
                                }
                            }
                        }
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                    text: i18np("%1 game", "%1 games", page.games.length)
                }

                QQC2.ToolButton {
                    id: listMenuButton
                    Layout.alignment: Qt.AlignLeft
                    icon.name: "document-save-as"
                    text: i18n("Export or import…")
                    font: Kirigami.Theme.smallFont
                    onClicked: listMenu.popup(listMenuButton, 0, listMenuButton.height)
                    QQC2.Menu {
                        id: listMenu
                        QQC2.MenuItem {
                            icon.name: "document-export"
                            text: i18n("Export list…")
                            enabled: page.games.length > 0
                            onTriggered: exportDialog.open()
                        }
                        QQC2.MenuItem {
                            icon.name: "document-import"
                            text: i18n("Import list…")
                            onTriggered: importDialog.open()
                        }
                    }
                }

                QQC2.ToolButton {
                    Layout.alignment: Qt.AlignLeft
                    icon.name: "edit-clear-history"
                    text: i18n("Clean up unused images…")
                    font: Kirigami.Theme.smallFont
                    onClicked: page.scanUnused()
                    QQC2.ToolTip.text: i18n("Deletes the copies no game of this widget uses anymore (for example, after importing several times). Only inside %1.", page.artDir)
                    QQC2.ToolTip.visible: hovered
                }
            }

            Kirigami.Separator {
                Layout.fillHeight: true
            }

            // ---------- Editor del juego elegido ----------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.largeSpacing
                enabled: page.game !== null

                Kirigami.PlaceholderMessage {
                    Layout.fillWidth: true
                    visible: page.game === null
                    text: i18n("No game selected")
                    explanation: i18n("Add a game or choose one from the list.")
                }

                // Vista previa: la caja y un control para girarla.
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: page.game !== null
                    spacing: Kirigami.Units.smallSpacing
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 154
                        GameCase {
                            id: previewCase
                            anchors.horizontalCenter: parent.horizontalCenter
                            t: turn.value
                            spineW: (page.game && page.game.spineImage !== "")
                                    ? Math.max(8, Math.round(150 * (naturalRatio > 0 ? naturalRatio : 0.077)))
                                    : 15
                            name: page.game ? page.game.name : ""
                            baseColor: page.game ? page.game.color : "#d71921"
                            spineImage: page.game ? page.game.spineImage : ""
                            coverImage: page.game ? page.game.coverImage : ""
                            logoImage: page.game ? page.game.logoImage : ""
                        }
                    }
                    QQC2.Slider {
                        id: turn
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 130
                        from: 0
                        to: 1
                        value: 0.5
                        QQC2.ToolTip.text: i18n("Turn the box: spine ↔ cover")
                        QQC2.ToolTip.visible: hovered
                    }
                }

                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    visible: page.game !== null

                    // ----- Juego -----
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Game")
                    }

                    QQC2.TextField {
                        Kirigami.FormData.label: i18n("Name:")
                        Layout.fillWidth: true
                        text: page.game ? page.game.name : ""
                        onTextEdited: page.setField("name", text)
                    }

                    RowLayout {
                        Kirigami.FormData.label: i18n("Launcher:")
                        Layout.fillWidth: true
                        QQC2.TextField {
                            Layout.fillWidth: true
                            placeholderText: i18n("game.desktop or steam://rungameid/123")
                            text: page.game ? page.game.launcher : ""
                            onTextEdited: page.setField("launcher", text.trim())
                        }
                        QQC2.ToolButton {
                            icon.name: "document-open"
                            onClicked: desktopDialog.open()
                            QQC2.ToolTip.text: i18n("Choose the shortcut (.desktop)")
                            QQC2.ToolTip.visible: hovered
                        }
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font: Kirigami.Theme.smallFont
                        readonly property string kind: page.game ? Games.launcherKind(page.game.launcher) : "empty"
                        color: kind === "invalid" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                        text: kind === "invalid" ? i18n("Invalid. Use the name of a .desktop file (no folders) or steam://rungameid/<number>.")
                            : kind === "empty" ? i18n("If there is a Steam id, the game opens through Steam even without a launcher.")
                            : i18n("Valid.")
                    }

                    QQC2.TextField {
                        Kirigami.FormData.label: i18n("Steam id:")
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                        placeholderText: i18n("optional")
                        validator: RegularExpressionValidator { regularExpression: /\d{0,12}/ }
                        text: page.game ? page.game.steamId : ""
                        onTextEdited: page.setField("steamId", text)
                    }

                    // ----- Arte de la caja -----
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Box art")
                    }

                    RowLayout {
                        Kirigami.FormData.label: i18n("Import:")
                        QQC2.Button {
                            icon.name: "transform-crop"
                            text: i18n("Full box…")
                            onClicked: wrapFileDialog.open()
                            QQC2.ToolTip.text: i18n("One image with back cover, spine and front cover (for example from steamgamecovers.com). Creates the spine and the cover.")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.Button {
                            icon.name: "download"
                            text: i18n("Steam art")
                            enabled: page.game !== null && page.game.steamId !== ""
                            onClicked: page.fetchSteamArt(page.game.id, page.game.steamId)
                            QQC2.ToolTip.text: i18n("The cover and logo Steam keeps on your computer for this game.")
                            QQC2.ToolTip.visible: hovered
                        }
                    }

                    ImageRow {
                        pageRef: page
                        dialogRef: imageDialog
                        Kirigami.FormData.label: i18n("Spine:")
                        kind: "spine"
                    }
                    ImageRow {
                        pageRef: page
                        dialogRef: imageDialog
                        Kirigami.FormData.label: i18n("Cover:")
                        kind: "cover"
                    }
                    ImageRow {
                        pageRef: page
                        dialogRef: imageDialog
                        Kirigami.FormData.label: i18n("Spine logo:")
                        kind: "logo"
                    }

                    // ----- Disco -----
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Disc")
                    }

                    ImageRow {
                        pageRef: page
                        dialogRef: imageDialog
                        Kirigami.FormData.label: i18n("Disc art:")
                        kind: "disc"
                        emptyText: i18n("(the cover is used)")
                        importText: i18n("Import disc: place a circle over the disc of a template (for example, the “Disc face” from steamgamecovers.com)")
                        onImportClicked: discFileDialog.open()
                    }

                    // Sonido del disco: suena al pulsar el juego (en lugar del
                    // sonido general de «Jugar»).
                    RowLayout {
                        Kirigami.FormData.label: i18n("Disc sound:")
                        spacing: Kirigami.Units.smallSpacing
                        readonly property string file: page.game ? page.game.soundFile || "" : ""
                        QQC2.Label {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                            Layout.maximumWidth: Kirigami.Units.gridUnit * 11
                            text: parent.file !== "" ? parent.file.slice(parent.file.lastIndexOf("/") + 1) : i18n("(the general “Play” sound)")
                            elide: Text.ElideMiddle
                            opacity: parent.file !== "" ? 1 : 0.6
                        }
                        QQC2.ToolButton {
                            icon.name: "media-playback-start"
                            enabled: parent.file !== ""
                            onClicked: page.previewSound(parent.file)
                            QQC2.ToolTip.text: i18n("Preview")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.ToolButton {
                            icon.name: "document-open"
                            onClicked: gameSoundDialog.open()
                            QQC2.ToolTip.text: i18n("Choose this disc's sound (for example, the game's theme). It plays when you select it and fades out when the animation ends.")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-clear"
                            enabled: parent.file !== ""
                            onClicked: page.setField("soundFile", "")
                            QQC2.ToolTip.text: i18n("Remove the sound")
                            QQC2.ToolTip.visible: hovered
                        }
                    }

                    // ----- Color -----
                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Fallback color")
                    }

                    RowLayout {
                        Kirigami.FormData.label: i18n("Color:")
                        spacing: Kirigami.Units.smallSpacing
                        KQuickControls.ColorButton {
                            showAlphaChannel: false
                            color: page.game ? page.game.color : "#d71921"
                            onAccepted: (c) => page.setField("color", c.toString().slice(0, 7))
                        }
                        Repeater {
                            model: Games.palette
                            Rectangle {
                                required property string modelData
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 10
                                color: modelData
                                border.width: page.game && page.game.color === modelData ? 2 : 1
                                border.color: page.game && page.game.color === modelData ? Kirigami.Theme.highlightColor : Qt.rgba(0, 0, 0, 0.3)
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.setField("color", parent.modelData)
                                }
                            }
                        }
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: i18n("Used on the spine and cover when there is no image.")
                    }

                    QQC2.BusyIndicator {
                        visible: page.pending > 0
                        running: visible
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                    }
                }
            }
        }
    }
}
