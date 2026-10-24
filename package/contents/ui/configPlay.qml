/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - ajustes de lo que pasa al jugar.
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: page

    property bool cfg_launchAnimation
    property bool cfg_launchAnimationDefault
    property int cfg_launchSeconds
    property int cfg_launchSecondsDefault
    property bool cfg_keepSteamMinimized
    property bool cfg_keepSteamMinimizedDefault
    property bool cfg_testMode
    property bool cfg_testModeDefault

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Disc animation")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("When playing:")
            text: i18n("Open the box and spin the disc")
            checked: page.cfg_launchAnimation
            onToggled: page.cfg_launchAnimation = checked
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Duration:")
            enabled: page.cfg_launchAnimation
            QQC2.SpinBox {
                from: 1
                to: 30
                value: page.cfg_launchSeconds
                onValueModified: page.cfg_launchSeconds = value
            }
            QQC2.Label {
                text: i18np("second", "seconds", page.cfg_launchSeconds)
            }
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("A click, Esc or the gamepad's leave button cancels it. While it spins, the game is not launched again.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Steam")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Steam windows:")
            enabled: page.cfg_launchAnimation
            text: i18n("Keep Steam minimized while the disc spins")
            checked: page.cfg_keepSteamMinimized
            onToggled: page.cfg_keepSteamMinimized = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("If Steam opens a window (for example, to update the game), it is minimized so the whole animation can be seen. The game's window is not touched.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Testing")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Test mode:")
            text: i18n("Don't open the games")
            checked: page.cfg_testMode
            onToggled: page.cfg_testMode = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Everything works the same (the box, the disc, the sounds, the windows, the keyboard and the gamepad), but nothing opens when you play. While it is on, the widget shows “TEST MODE”.")
        }
    }
}
