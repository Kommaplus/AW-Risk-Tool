import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

Page {
    id: page

    property bool showOnlyActive: true

    HazardStore {
        id: store
        // "active" is a virtual filter (open / mitigated / alarp);
        // an empty filter shows every hazard, including transferred.
        filterStatus: page.showOnlyActive ? "active" : ""
    }

    onStatusChanged: {
        // Each page keeps its own HazardStore instance, and the main page
        // outlives the edit pages: re-read the saved file whenever the
        // list becomes visible again, so newly added/edited hazards show up.
        if (status === PageStatus.Activating)
            store.reload()
    }

    SilicaListView {
        id: listView
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: qsTr("New hazard")
                onDelayedClick: pageStack.push(Qt.resolvedUrl("EditHazardPage.qml"))
            }
            MenuItem {
                text: page.showOnlyActive ? qsTr("Show all hazards")
                                          : qsTr("Show only active")
                onDelayedClick: page.showOnlyActive = !page.showOnlyActive
            }
            MenuItem {
                text: qsTr("Risk matrix")
                onDelayedClick: pageStack.push(Qt.resolvedUrl("RiskMatrixPage.qml"))
            }
            MenuItem {
                text: qsTr("About")
                onDelayedClick: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }

        header: PageHeader {
            title: qsTr("Airworthiness Risk")
        }

        ViewPlaceholder {
            enabled: listView.count === 0
            text: qsTr("No hazards")
            hintText: qsTr("Pull down to add one")
        }

        model: store

        delegate: ListItem {
            id: listItem
            contentHeight: Math.max(Theme.itemSizeMedium, column.height + Theme.paddingMedium)

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Edit")
                    onDelayedClick: pageStack.push(Qt.resolvedUrl("EditHazardPage.qml"),
                                                  { hazardId: model.id })
                }
                MenuItem {
                    // "Close" ends the hazard: the risk is eliminated or no
                    // longer relevant. Closed and transferred hazards reopen;
                    // open and mitigated hazards are closed by this action.
                    text: model.status === "closed" || model.status === "transferred"
                          ? qsTr("Reopen") : qsTr("Close")
                    onDelayedClick: store.updateHazard(model.id, {
                        status: model.status === "closed" || model.status === "transferred"
                                ? "open" : "closed"
                    })
                }
                MenuItem {
                    text: qsTr("Delete")
                    onDelayedClick: listItem.remorseAction(qsTr("Deleting"), function() {
                        store.removeHazard(model.id)
                    })
                }
            }

            Column {
                id: column
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingSmall
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Rectangle {
                        width: Theme.fontSizeMedium * 2.2
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: model.riskColor
                        Label {
                            anchors.centerIn: parent
                            // AWB-150 Risk Assessment Code, e.g. "IE"
                            text: model.severityCode + model.likelihoodCode
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.lightPrimaryColor
                        }
                    }

                    Label {
                        width: parent.width - Theme.fontSizeMedium * 2.2 - Theme.paddingSmall
                        text: model.title
                        color: listItem.highlighted ? Theme.highlightColor
                                                   : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                        truncationMode: TruncationMode.Fade
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Label {
                    width: parent.width
                    text: model.aircraft + (model.system ? " · " + model.system : "")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    visible: model.reviewDue
                    // Red marker: the recurring review is overdue.
                    text: qsTr("Review due")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: "#e74c3c"
                }
            }

            onClicked: pageStack.push(Qt.resolvedUrl("HazardDetailPage.qml"),
                                      { hazardId: model.id })
        }
    }
}
