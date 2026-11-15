import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

CoverBackground {
    id: cover

    HazardStore { id: coverStore }

    function refresh() {
        coverStore.reload()
        var open = coverStore.openCount()
        countLabel.text = open > 0
                ? qsTr("%1 open").arg(open)
                : qsTr("All clear")
        var hri = coverStore.highestRiskIndex()
        hriLabel.text = hri > 0 ? qsTr("Highest HRI: %1").arg(hri) : ""
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingSmall
        width: cover.width - 2 * Theme.paddingLarge

        Label {
            text: qsTr("AW Risk Tool")
            font.pixelSize: Theme.fontSizeMedium
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Label {
            id: countLabel
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Label {
            id: hriLabel
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: cover.refresh()
    }

    onCoverStatusChanged: cover.refresh()
}
