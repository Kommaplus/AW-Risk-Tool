import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

// Risk matrix laid out exactly like AWB-150B Attachment 2, Table 4:
// rows = probability levels (A Frequent .. E Improbable, most likely at top),
// columns = severity categories (I Catastrophic .. IV Negligible),
// numeric RAC 1-20 in every cell (High 1-5, Serious 6-9, Medium 10-17, Low 18-20).
Page {
    id: page

    readonly property int labelWidth: Math.floor(page.width * 0.30)
    readonly property int cellSize: Math.floor((page.width - 2 * Theme.horizontalPageMargin - labelWidth - 8) / 4)

    HazardStore { id: store }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("AWB-150B Risk Matrix")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Rows are probability levels (A\u2013E), columns are " +
                           "severity categories (I\u2013IV), as in AWB-150B Table 4. " +
                           "The small number in each cell is the Risk Assessment " +
                           "Code (RAC 1\u201320); the bold number is how many open " +
                           "or mitigated hazards you have in that cell.")
            }

            // Severity column headers (I Catastrophic .. IV Negligible)
            Row {
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter

                Item { width: page.labelWidth; height: 1 }

                Repeater {
                    model: [ { name: qsTr("Catastrophic"), code: "I" },
                             { name: qsTr("Critical"), code: "II" },
                             { name: qsTr("Marginal"), code: "III" },
                             { name: qsTr("Negligible"), code: "IV" } ]

                    delegate: Item {
                        width: page.cellSize
                        height: Math.max(page.cellSize, 2 * Theme.fontSizeTiny + 6)

                        Column {
                            anchors.centerIn: parent
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: page.cellSize - 2
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.secondaryColor
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "(" + modelData.code + ")"
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.secondaryHighlightColor
                            }
                        }
                    }
                }
            }

            // Matrix rows: probability A (top) .. E (bottom)
            Repeater {
                model: [ { name: qsTr("Frequent"), code: "A", prob: "10\u207B\u00B3 \u2264 P" },
                         { name: qsTr("Probable"), code: "B", prob: "10\u207B\u2074 \u2264 P < 10\u207B\u00B3" },
                         { name: qsTr("Occasional"), code: "C", prob: "10\u207B\u2075 \u2264 P < 10\u207B\u2074" },
                         { name: qsTr("Remote"), code: "D", prob: "10\u207B\u2076 \u2264 P < 10\u207B\u2075" },
                         { name: qsTr("Improbable"), code: "E", prob: "0 < P < 10\u207B\u2076" } ]

                delegate: Row {
                    id: matrixRow
                    property int likelihood: index + 1
                    spacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Row label: probability level and threshold
                    Item {
                        width: page.labelWidth
                        height: page.cellSize

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.paddingSmall
                            spacing: -Theme.paddingSmall / 2

                            Label {
                                text: modelData.code + " \u2014 " + modelData.name
                                font.pixelSize: Theme.fontSizeExtraSmall
                                font.bold: true
                                color: Theme.primaryColor
                            }
                            Label {
                                text: modelData.prob + " / FH"
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.secondaryColor
                            }
                        }
                    }

                    // Severity cells: I Catastrophic .. IV Negligible
                    Repeater {
                        model: 4

                        delegate: Rectangle {
                            width: page.cellSize
                            height: page.cellSize
                            radius: 4
                            color: store.riskColorFor(index + 1, matrixRow.likelihood)

                            Label {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    margins: Theme.paddingSmall / 2
                                }
                                text: store.racFor(index + 1, matrixRow.likelihood)
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.lightPrimaryColor
                                opacity: 0.7
                            }

                            Label {
                                anchors.centerIn: parent
                                text: store.countAt(index + 1, matrixRow.likelihood)
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                color: Theme.lightPrimaryColor
                                visible: text > 0
                            }
                        }
                    }
                }
            }

            // Legend with the AWB-150B RAC ranges
            Row {
                spacing: Theme.paddingMedium
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: [ { name: qsTr("High"), range: qsTr("RAC 1\u20135"), color: "#e74c3c" },
                             { name: qsTr("Serious"), range: qsTr("RAC 6\u20139"), color: "#e67e22" },
                             { name: qsTr("Medium"), range: qsTr("RAC 10\u201317"), color: "#f1c40f" },
                             { name: qsTr("Low"), range: qsTr("RAC 18\u201320"), color: "#2ecc71" } ]

                    delegate: Column {
                        spacing: 2

                        Rectangle {
                            width: Theme.fontSizeSmall
                            height: width
                            radius: width / 2
                            color: modelData.color
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Label {
                            text: modelData.name
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.primaryColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Label {
                            text: modelData.range
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.secondaryColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
                text: qsTr("P is the probability of the mishap per flying hour " +
                           "(or sortie). \u201CEliminated (F)\u201D means the hazard " +
                           "was removed; it carries no risk. Severity categories " +
                           "follow MIL-STD-882E: I Catastrophic, II Critical, " +
                           "III Marginal, IV Negligible.")
            }
        }
    }
}
