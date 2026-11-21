import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: picker

    property int currentInterval: -1
    signal intervalPicked(int months)

    SilicaListView {
        anchors.fill: parent
        // The values in this model are the numbers of months saved in the
        // JSON data. Only the labels are user-facing, so values must never
        // be translated or renamed: older saved hazards keep working.
        // 0 disables the recurring review.
        model: [
            { months: 0,  label: qsTr("Off (no recurring review)") },
            { months: 1,  label: qsTr("Every month") },
            { months: 3,  label: qsTr("Every 3 months") },
            { months: 6,  label: qsTr("Every 6 months") },
            { months: 12, label: qsTr("Every 12 months") },
            { months: 24, label: qsTr("Every 24 months") }
        ]
        header: PageHeader { title: qsTr("Review interval") }

        delegate: ListItem {
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: modelData.label
                color: modelData.months === picker.currentInterval
                       ? Theme.highlightColor : Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }
            onClicked: {
                picker.intervalPicked(modelData.months)
                picker.accept()
            }
        }
    }
}
