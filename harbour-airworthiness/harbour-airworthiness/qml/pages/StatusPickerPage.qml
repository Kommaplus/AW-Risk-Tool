import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: picker

    property string currentStatus
    signal statusPicked(string status)

    SilicaListView {
        anchors.fill: parent
        // The values in this model are the strings saved in the JSON data.
        // Only the labels are user-facing, so values must never be
        // translated or renamed: older saved hazards keep working.
        // Lifecycle order: open, mitigated, alarp, transferred, closed.
        model: [
            { value: "open",        label: qsTr("Open") },
            { value: "mitigated",   label: qsTr("Mitigated") },
            { value: "alarp",       label: qsTr("As Low As Reasonably Practicable (ALARP)") },
            { value: "transferred", label: qsTr("Transferred to Operational Risk") },
            { value: "closed",      label: qsTr("Closed") }
        ]
        header: PageHeader { title: qsTr("Status") }

        delegate: ListItem {
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: modelData.label
                color: modelData.value === picker.currentStatus
                       ? Theme.highlightColor : Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }
            onClicked: {
                picker.statusPicked(modelData.value)
                picker.accept()
            }
        }
    }
}
