import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

Page {
    id: page

    property int hazardId

    property variant hazard
    property int severity: 1
    property int likelihood: 1

    onStatusChanged: {
        if (status === PageStatus.Activating) {
            hazard = store.getHazard(hazardId)
            if (hazard && hazard.severity !== undefined) {
                severity = hazard.severity
                likelihood = hazard.likelihood
            }
        }
    }

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

            PageHeader {
                title: hazard && hazard.title ? hazard.title : qsTr("Hazard")
            }

            Row {
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                Rectangle {
                    width: Theme.fontSizeLarge * 3
                    height: width
                    radius: width / 2
                    color: store.riskColorFor(severity, likelihood)
                    Label {
                        anchors.centerIn: parent
                        text: store.riskCodeFor(severity, likelihood)
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.lightPrimaryColor
                    }
                }

                Column {
                    Label {
                        text: store.riskCategoryFor(severity, likelihood)
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.primaryColor
                    }
                    Label {
                        text: qsTr("HRI %1").arg(severity * likelihood)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                    }
                }
            }

            SectionHeader { text: qsTr("Description") }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                text: hazard && hazard.description
                      ? hazard.description : qsTr("No description")
            }

            SectionHeader { text: qsTr("Mitigation") }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                text: hazard && hazard.mitigation
                      ? hazard.mitigation : qsTr("No mitigation recorded")
            }

            SectionHeader { text: qsTr("Assessment (AWB-150)") }

            DetailItem {
                label: qsTr("Severity")
                value: store.severityNameFor(severity)
            }
            DetailItem {
                label: qsTr("Likelihood")
                value: store.likelihoodNameFor(likelihood)
            }
            DetailItem {
                label: qsTr("Risk level")
                value: store.riskCategoryFor(severity, likelihood)
            }

            SectionHeader { text: qsTr("Details") }

            DetailItem {
                label: qsTr("Aircraft")
                value: hazard ? hazard.aircraft : ""
            }
            DetailItem {
                label: qsTr("System")
                value: hazard ? hazard.system : ""
            }
            DetailItem {
                label: qsTr("Owner")
                value: hazard ? hazard.owner : ""
            }
            DetailItem {
                label: qsTr("Status")
                value: hazard ? hazard.status : ""
            }
            DetailItem {
                label: qsTr("Due")
                value: hazard && hazard.dueDate ? hazard.dueDate : qsTr("—")
            }
        }
    }
}
