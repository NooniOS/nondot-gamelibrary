/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - páginas del diálogo "Configurar…".
    Los archivos de las páginas están en contents/ui.
*/

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Games")
        icon: "applications-games"
        source: "configGames.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: i18n("When Playing")
        icon: "media-optical"
        source: "configPlay.qml"
    }
    ConfigCategory {
        name: i18n("Sounds")
        icon: "audio-volume-high"
        source: "configSounds.qml"
    }
    ConfigCategory {
        name: i18n("Controls")
        icon: "input-gaming"
        source: "configGamepad.qml"
    }
}
