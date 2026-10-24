/*
    SPDX-FileCopyrightText: 2026 NooniOS
    SPDX-License-Identifier: GPL-2.0-or-later

    NonDot GameLibrary - ajustes de apariencia: estilo, tamaño, lomo y barra.
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: page

    property int cfg_layoutMode
    property int cfg_layoutModeDefault
    property int cfg_boxHeight
    property int cfg_boxHeightDefault
    property int cfg_spineMode
    property int cfg_spineModeDefault
    property bool cfg_showScrubber
    property bool cfg_showScrubberDefault
    property bool cfg_compatMode
    property bool cfg_compatModeDefault

    // ¿Este Qt tiene lo necesario para la calidad completa? Se prueba a
    // cargar las dos piezas que piden Qt 6.8/6.9; si alguna falla, el widget
    // ya usa el modo compatibilidad solo.
    readonly property bool modernOk: shadowProbe.status === Loader.Ready && discProbe.status === Loader.Ready
    readonly property bool probed: shadowProbe.status !== Loader.Loading && discProbe.status !== Loader.Loading
    Loader { id: shadowProbe; source: "BoxShadow.qml"; visible: false }
    Loader { id: discProbe; source: "DiscLabel.qml"; visible: false }

    // Una opción con su explicación debajo.
    component Choice: ColumnLayout {
        id: choice
        property alias text: radio.text
        property string hint: ""
        property bool checked: false
        signal picked()
        spacing: 0
        QQC2.RadioButton {
            id: radio
            checked: choice.checked
            onToggled: if (checked) choice.picked()
        }
        QQC2.Label {
            Layout.leftMargin: radio.indicator.width + radio.spacing
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            visible: choice.hint !== ""
            text: choice.hint
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Style")
        }

        Choice {
            Kirigami.FormData.label: i18n("Look:")
            text: i18n("Shelf")
            hint: i18n("Spines on shelves; hover over one and the box slides out and turns.")
            checked: page.cfg_layoutMode === 0
            onPicked: page.cfg_layoutMode = 0
        }
        Choice {
            text: i18n("Jukebox")
            hint: i18n("Covers facing you; the selected one grows. If they don't fit, it becomes a carousel.")
            checked: page.cfg_layoutMode === 1
            onPicked: page.cfg_layoutMode = 1
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Boxes")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Size:")
            readonly property var values: [150, 200, 260]
            model: [i18n("Small"), i18n("Medium"), i18n("Large")]
            currentIndex: page.cfg_boxHeight >= 230 ? 2 : page.cfg_boxHeight >= 175 ? 1 : 0
            onActivated: (i) => page.cfg_boxHeight = values[i]
        }

        Choice {
            Kirigami.FormData.label: i18n("Spine:")
            text: i18n("Real proportions")
            hint: i18n("Each spine as wide as its image really is. Ideal for full box art.")
            checked: page.cfg_spineMode === 0
            onPicked: page.cfg_spineMode = 0
        }
        Choice {
            text: i18n("Thick")
            hint: i18n("Wide spines with the game's name or logo.")
            checked: page.cfg_spineMode === 1
            onPicked: page.cfg_spineMode = 1
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Scroll bar")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Bar:")
            text: i18n("Show the bar below the shelf")
            checked: page.cfg_showScrubber
            onToggled: page.cfg_showScrubber = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("One dot per game: slide the dot to browse them and release to play.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Compatibility")
        }

        Kirigami.InlineMessage {
            Kirigami.FormData.isSection: true
            Layout.fillWidth: true
            visible: page.probed && !page.modernOk
            type: Kirigami.MessageType.Information
            text: i18n("Your Qt version is older than 6.9: the widget is already using compatibility mode even if the box is unchecked.")
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Compatibility mode:")
            text: i18n("For Qt versions older than 6.9")
            checked: page.cfg_compatMode || (page.probed && !page.modernOk)
            enabled: page.modernOk
            onToggled: page.cfg_compatMode = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("What you lose: the soft shadows of the boxes (simpler layered shadows are used instead) and the crisp clipping of the disc art (a mask is used and the edge may look slightly less smooth). Everything else works the same.")
        }
    }
}
