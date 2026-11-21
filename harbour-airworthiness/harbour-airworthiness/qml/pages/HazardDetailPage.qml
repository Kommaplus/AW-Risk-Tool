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
            // The page's store was created before the hazard may have been
            // edited elsewhere (e.g. via this page's Edit menu): re-read from
            // disk before showing the details.
            store.reload()
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

    PullDownMenu {
        MenuItem {
            text: qsTr("Edit")
            onDelayedClick: pageStack.push(Qt.resolvedUrl("EditHazardPage.qml"),
                                          { hazardId: page.hazardId })
        }
        MenuItem {
            text: qsTr("Delete")
            onDelayedClick: remorse.execute(qsTr("Deleting"))
        }
    }

    RemorsePopup {
        id: remorse
        onTriggered: {
            store.removeHazard(page.hazardId)
            pageStack.pop()
        }
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
                        text: qsTr("RAC %1").arg(store.racFor(severity, likelihood))
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                    }
                    Label {
                        visible: hazard && hazard.reviewDue
                        // Red marker: the recurring review is overdue.
                        text: qsTr("Review due")
                        font.pixelSize: Theme.fontSizeSmall
                        color: "#e74c3c"
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

            SectionHeader { text: qsTr("Risk acceptance (residual risk)") }

            DetailItem {
                label: qsTr("Accepted by")
                value: hazard && hazard.acceptedBy
                      ? hazard.acceptedBy : qsTr("Not accepted")
            }
            DetailItem {
                label: qsTr("Acceptance date")
                value: hazard && hazard.acceptedDate
                      ? Qt.formatDate(new Date(hazard.acceptedDate), "dd MMM yyyy")
                      : qsTr("—")
            }

            SectionHeader { text: qsTr("Risk review (re-evaluation)") }

            DetailItem {
                label: qsTr("Review interval")
                value: hazard && hazard.reviewInterval > 0
                      ? store.reviewIntervalLabelFor(hazard.reviewInterval)
                      : qsTr("—")
            }
            DetailItem {
                label: qsTr("Last reviewed")
                value: hazard && hazard.reviewedDate
                      ? Qt.formatDate(new Date(hazard.reviewedDate), "dd MMM yyyy")
                      : qsTr("Never")
            }
            DetailItem {
                label: qsTr("Next review")
                value: hazard && hazard.nextReview
                      ? Qt.formatDate(new Date(hazard.nextReview), "dd MMM yyyy")
                        + (hazard.reviewDue ? qsTr(" (overdue)") : "")
                      : qsTr("—")
            }

            SectionHeader { text: qsTr("Details") }

            DetailItem {
                label: qsTr("Aircraft")
                value: hazard ? hazard.aircraft : ""
            }
            DetailItem {
                label: qsTr("System (ATA)")
                value: hazard ? hazard.system : ""
            }
            DetailItem {
                // Shown directly under the system: which certification
                // baseline the hazard relates to.
                label: qsTr("Certification baseline")
                value: hazard && hazard.certBaseline
                      ? hazard.certBaseline : qsTr("Not specified")
            }
            DetailItem {
                label: qsTr("Criteria points")
                value: hazard && hazard.certCriteria
                      ? hazard.certCriteria : qsTr("Not specified")
            }
            DetailItem {
                label: qsTr("Owner")
                value: hazard ? hazard.owner : ""
            }
            DetailItem {
                label: qsTr("Status")
                value: hazard ? store.statusLabelFor(hazard.status) : ""
            }
            DetailItem {
                label: qsTr("Due")
                value: hazard && hazard.dueDate
                      ? Qt.formatDate(new Date(hazard.dueDate), "dd MMM yyyy")
                      : qsTr("—")
            }
        }
    }
}
