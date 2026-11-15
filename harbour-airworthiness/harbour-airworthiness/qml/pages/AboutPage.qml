import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("About")
            }

            SectionHeader { text: qsTr("Airworthiness Risk Management") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: qsTr("A hazard register for airworthiness risk management " +
                           "using the USAF AWB-150 risk assessment matrix. Record " +
                           "hazards, assess severity and likelihood, and track " +
                           "mitigations to acceptable levels.")
            }

            SectionHeader { text: qsTr("AWB-150 risk assessment") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: qsTr("Severity: I Catastrophic, II Critical, III Marginal, " +
                           "IV Negligible.\nLikelihood: A Frequent, B Probable, " +
                           "C Occasional, D Remote, E Improbable.\n" +
                           "The Risk Assessment Code (severity + likelihood, e.g. " +
                           "IIIE) maps to a risk level: High, Serious, Medium or Low.")
            }
        }
    }
}
