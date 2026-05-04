import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    property alias cfg_subreddits:       subredditsField.text
    property alias cfg_refreshInterval:  intervalSpinBox.value
    property alias cfg_fontSize:         fontSizeSpinBox.value
    property alias cfg_showMeta:         showMetaCheck.checked
    property alias cfg_fontFamily:       fontFamilyField.text

    Kirigami.FormLayout {
        anchors { left: parent.left; right: parent.right; top: parent.top }

        QQC2.TextField {
            id: subredditsField
            Kirigami.FormData.label: i18n("Subreddits (comma-separated):")
            placeholderText: "showerthoughts, legaladvice, ..."
        }

        QQC2.SpinBox {
            id: intervalSpinBox
            Kirigami.FormData.label: i18n("Show each thought for (seconds):")
            from: 10
            to: 3600
            stepSize: 10
        }

        QQC2.SpinBox {
            id: fontSizeSpinBox
            Kirigami.FormData.label: i18n("Font size (px):")
            from: 10
            to: 56
        }

        QQC2.CheckBox {
            id: showMetaCheck
            Kirigami.FormData.label: i18n("Show author & subreddit:")
            text: ""
        }

        QQC2.TextField {
            id: fontFamilyField
            Kirigami.FormData.label: i18n("Font family:")
            placeholderText: "Noto Serif"
        }
    }
}
