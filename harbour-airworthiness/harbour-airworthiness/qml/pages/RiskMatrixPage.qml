import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

Page {
    id: page

    property int cellSize: Theme.fontSizeLarge + Theme.paddingMedium

    HazardStore { id: store }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("AWB-150 Risk Matrix")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Severity I–IV × Likelihood A–E. The Risk Assessment " +
                           "Code (e.g. IIE) determines the risk level: High, " +
                           "Serious, Medium or Low.")
            }

            // Header row: likelihood codes A-E
            Row {
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Item { width: page.cellSize; height: page.cellSize }
                Repeater {
                    model: 5
                    delegate: Item {
                        width: page.cellSize
                        height: page.cellSize
                        Label {
                            anchors.centerIn: parent
                            text: store.likelihoodCodeFor(index + 1)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }
                }
            }

            // Matrix rows: severity I (top) to IV (bottom)
            Repeater {
                model: 4

                delegate: Row {
                    id: matrixRow
                    spacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    property int severity: index + 1

                    Item {
                        width: page.cellSize
                        height: page.cellSize
                        Label {
                            anchors.centerIn: parent
                            text: store.severityCodeFor(matrixRow.severity)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }

                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            width: page.cellSize
                            height: page.cellSize
                            radius: 4
                            color: store.riskColorFor(matrixRow.severity, index + 1)
                            opacity: 0.85
                        }
                    }
                }
            }

            Row {
                spacing: Theme.paddingMedium
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: [{ name: qsTr("High"), color: "#e74c3c" },
                            { name: qsTr("Serious"), color: "#e67e22" },
                            { name: qsTr("Medium"), color: "#f1c40f" },
                            { name: qsTr("Low"), color: "#2ecc71" }]

                    delegate: Row {
                        spacing: Theme.paddingSmall
                        Rectangle {
                            width: Theme.fontSizeSmall
                            height: width
                            radius: width / 2
                            color: modelData.color
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: modelData.name
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.primaryColor
                        }
                    }
                }
            }
        }
    }
}
