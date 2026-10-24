// SPDX-FileCopyrightText: 2026 NooniOS
// SPDX-License-Identifier: GPL-2.0-or-later
//
// NonDot GameLibrary - script de KWin que minimiza solo las ventanas de UN
// monitor (el del widget) y luego las devuelve.
//
// El widget hace una copia de esta plantilla con __OUTPUT__ (nombre del
// monitor, por ejemplo "DP-2") y __TAG__ (número del widget) sustituidos,
// la carga con org.kde.kwin.Scripting y la descarga al terminar. Mientras
// está cargada recuerda qué ventanas minimizó; para devolverlas, el widget
// "pulsa" uno de los atajos internos que registra (sin teclas):
//   NonDotGameLibraryRestore__TAG__ -> las devuelve y reactiva la ventana de antes
//   NonDotGameLibraryRelease__TAG__ -> las devuelve sin cambiar el foco (al jugar)
//   NonDotGameLibrarySteam__TAG__   -> desde ahora, las ventanas del cliente de
//                                      Steam se minimizan en cuanto aparecen (para
//                                      que se vea la animación del disco). Termina al
//                                      descargar el script.
// Con __HIDE__ = false no se minimiza nada al cargar (solo se vigila Steam).

const OUTPUT = "__OUTPUT__";
const TAG = "__TAG__";
const HIDE = __HIDE__;

const previous = workspace.activeWindow;
const hidden = [];

function onOutput(w) {
    return w.output && w.output.name === OUTPUT;
}

// Igual que el script "minimizeall" de KWin: solo ventanas del escritorio
// virtual y la actividad actuales.
function relevant(w) {
    return w.normalWindow && w.minimizable && !w.minimized && onOutput(w)
        && (!w.desktops.length || w.desktops.includes(workspace.currentDesktopForScreen(w.output)))
        && (!w.activities.length || w.activities.includes(workspace.currentActivity));
}

const toHide = HIDE ? workspace.windowList().filter(relevant) : [];
toHide.sort((a, b) => a.stackingOrder - b.stackingOrder);
for (const w of toHide) {
    w.minimized = true;
    hidden.push(w);
}

// El foco del teclado se queda en el escritorio de ese monitor.
const desk = workspace.windowList().find(w => w.desktopWindow && onOutput(w));
if (HIDE && desk)
    workspace.activeWindow = desk;

function restore(reactivate) {
    const alive = workspace.windowList();
    // En el mismo orden en que estaban: la de arriba vuelve la última.
    for (const w of hidden) {
        if (alive.includes(w))
            w.minimized = false;
    }
    hidden.length = 0;
    if (reactivate && previous && alive.includes(previous) && !previous.minimized)
        workspace.activeWindow = previous;
}

registerShortcut("NonDotGameLibraryRestore" + TAG, "NonDot GameLibrary: show the windows again", "", () => restore(true));
registerShortcut("NonDotGameLibraryRelease" + TAG, "NonDot GameLibrary: return the windows without changing focus", "", () => restore(false));

// ---------- Steam minimizado durante la animación ----------
// El cliente de Steam se llama "steam" (y sus ventanas internas,
// "steamwebhelper"). Los juegos se llaman "steam_app_<id>" o tienen su propio
// nombre: esos nunca se tocan.
function isSteamClient(w) {
    const c = String(w.resourceClass || "").toLowerCase();
    const n = String(w.resourceName || "").toLowerCase();
    if (c.startsWith("steam_app_"))
        return false;
    return c === "steam" || c === "steamwebhelper" || n === "steamwebhelper";
}

let watchSteam = false;

function tameSteam(w) {
    if (!watchSteam || !w || !(w.normalWindow || w.dialog) || !w.minimizable || w.minimized || !isSteamClient(w))
        return;
    w.minimized = true;
}

function followWindow(w) {
    // Si Steam vuelve a mostrar una ventana suya, se minimiza otra vez.
    w.minimizedChanged.connect(() => tameSteam(w));
}

for (const w of workspace.windowList())
    followWindow(w);
workspace.windowAdded.connect(w => { followWindow(w); tameSteam(w); });
workspace.windowActivated.connect(w => tameSteam(w));

registerShortcut("NonDotGameLibrarySteam" + TAG, "NonDot GameLibrary: keep Steam minimized", "", () => {
    watchSteam = true;
    for (const w of workspace.windowList())
        tameSteam(w);
});
