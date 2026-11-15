import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: picker

    property string currentStatus
    signal statusPicked(string status)

    SilicaListView {
        anchors.fill: parent
        model: ["open", "mitigated", "closed"]
        header: PageHeader { title: qsTr("Status") }

        delegate: ListItem {
            Label {
                x: Theme.horizontalPageMargin
                text: modelData
                color: modelData === picker.currentStatus
                       ? Theme.highlightColor : Theme.primaryColor
                anchors.verticalCenter: parent.verticalCenter
            }
            onClicked: {
                picker.statusPicked(modelData)
                picker.accept()
            }
        }
    }
}
