import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

Page {
    id: page

    property string resultText: ""
    property bool resultOk: false

    HazardStore {
        id: store
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("Export hazards") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: qsTr("Exports the entire register (all hazards, regardless of any list filter) to the Documents folder of the phone, using today's date in the file name. Repeated exports on the same day overwrite the earlier file. CSV is semicolon-separated and opens directly in spreadsheet apps.")
            }

            Button {
                text: qsTr("Export as CSV")
                preferredWidth: Theme.buttonWidthMedium
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    var path = store.exportToCsv()
                    if (path !== "") {
                        page.resultOk = true
                        page.resultText = qsTr("Saved: %1").arg(path)
                    } else {
                        page.resultOk = false
                        page.resultText = qsTr("Export failed: check that the app has the Documents permission and that the Documents folder exists.")
                    }
                }
            }

            Button {
                text: qsTr("Export as JSON")
                preferredWidth: Theme.buttonWidthMedium
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    var path = store.exportToJson()
                    if (path !== "") {
                        page.resultOk = true
                        page.resultText = qsTr("Saved: %1").arg(path)
                    } else {
                        page.resultOk = false
                        page.resultText = qsTr("Export failed: check that the app has the Documents permission and that the Documents folder exists.")
                    }
                }
            }

            SectionHeader { text: qsTr("Result") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                visible: page.resultText !== ""
                text: page.resultText
                color: page.resultOk ? Theme.primaryColor : "#e74c3c"
            }
        }
    }
}
