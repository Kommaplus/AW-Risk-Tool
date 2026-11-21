import QtQuick 2.6
import Sailfish.Silica 1.0
import harbour.airworthiness 1.0

Dialog {
    id: dialog

    property int hazardId: 0
    property bool editing: hazardId > 0

    canAccept: titleField.text.trim().length > 0

    onAccepted: {
        var data = {
            aircraft: aircraftField.text.trim(),
            system: systemField.text.trim(),
            title: titleField.text.trim(),
            description: descriptionField.text,
            severity: severitySlider.value,
            likelihood: likelihoodSlider.value,
            mitigation: mitigationField.text,
            owner: ownerField.text.trim(),
            status: statusButton.statusValue,
            dueDate: dueDateField.dateText
        }
        if (editing)
            store.updateHazard(hazardId, data)
        else
            store.addHazard(data)
    }

    HazardStore {
        id: store
    }

      property bool fieldsLoaded: false

    onStatusChanged: {
        // Fyld felterne med hazardens gemte data KUN én gang, når redigeringen
        // åbnes. PageStatus.Activating udløses også når man vender tilbage fra
        // StatusPickerPage/DatePicker — og overskrev ellers brugerens nye
        // indtastninger med de gamle gemte værdier, så ændringer blev tabt.
        if (status === PageStatus.Activating && editing && !fieldsLoaded) {
            fieldsLoaded = true
            var h = store.getHazard(hazardId)
            aircraftField.text = h.aircraft || ""
            systemField.text = h.system || ""
            titleField.text = h.title || ""
            descriptionField.text = h.description || ""
            severitySlider.value = h.severity !== undefined ? h.severity : 2
            likelihoodSlider.value = h.likelihood !== undefined ? h.likelihood : 3
            mitigationField.text = h.mitigation || ""
            ownerField.text = h.owner || ""
            statusButton.statusValue = h.status || "open"
            dueDateField.dateText = h.dueDate || ""
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
                title: editing ? qsTr("Edit hazard") : qsTr("New hazard")
            }

            TextField {
                id: titleField
                width: parent.width
                placeholderText: qsTr("Hazard title *")
                label: qsTr("Title")
            }

            TextField {
                id: aircraftField
                width: parent.width
                placeholderText: qsTr("Aircraft registration (e.g. OH-ABC)")
                label: qsTr("Aircraft")
            }

            TextField {
                id: systemField
                width: parent.width
                placeholderText: qsTr("System / ATA chapter (e.g. 32 - Landing gear)")
                label: qsTr("System")
            }

            TextArea {
                id: descriptionField
                width: parent.width
                height: Math.max(Theme.itemSizeLarge, implicitHeight)
                placeholderText: qsTr("Describe the hazard")
                label: qsTr("Description")
            }

            SectionHeader { text: qsTr("Severity (AWB-150)") }

            Slider {
                id: severitySlider
                width: parent.width
                minimumValue: 1
                maximumValue: 4
                stepSize: 1
                value: 2
                label: store.severityNameFor(value)
            }

            SectionHeader { text: qsTr("Likelihood (AWB-150)") }

            Slider {
                id: likelihoodSlider
                width: parent.width
                minimumValue: 1
                maximumValue: 5
                stepSize: 1
                value: 3
                label: store.likelihoodNameFor(value)
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: qsTr("Risk Assessment Code: %1%2 — %3 (RAC %4)")
                    .arg(store.severityCodeFor(severitySlider.value))
                    .arg(store.likelihoodCodeFor(likelihoodSlider.value))
                    .arg(store.riskCategoryFor(severitySlider.value, likelihoodSlider.value))
                    .arg(store.racFor(severitySlider.value, likelihoodSlider.value))
                color: store.riskColorFor(severitySlider.value, likelihoodSlider.value)
                font.pixelSize: Theme.fontSizeMedium
            }

            TextArea {
                id: mitigationField
                width: parent.width
                height: Math.max(Theme.itemSizeLarge, implicitHeight)
                placeholderText: qsTr("Mitigation / corrective action")
                label: qsTr("Mitigation")
            }

            TextField {
                id: ownerField
                width: parent.width
                placeholderText: qsTr("Responsible person")
                label: qsTr("Owner")
            }

            ValueButton {
                id: statusButton
                property string statusValue: "open"

                width: parent.width
                label: qsTr("Status")
                value: statusValue

                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("StatusPickerPage.qml"),
                                                { currentStatus: statusValue })
                    picker.statusPicked.connect(function(status) {
                        statusButton.statusValue = status
                    })
                }
            }

            ValueButton {
                id: dueDateField
                property string dateText: ""   // stored in ISO format yyyy-MM-dd

                width: parent.width
                label: qsTr("Due date")
                value: dateText === ""
                       ? qsTr("Not set")
                       : Qt.formatDate(new Date(dateText), "dd MMM yyyy")
                onClicked: {
                    var initial = dateText !== "" ? new Date(dateText) : new Date()
                    var picker = pageStack.push(datePickerComponent, { date: initial })
                    picker.accepted.connect(function() {
                        // Store the date in ISO format so HazardStore can parse
                        // it back. Do NOT use picker.dateText — it is only a
                        // human-readable label (e.g. "Thu 15 Jan") and is not
                        // parseable as a date.
                        dueDateField.dateText = Qt.formatDate(picker.date, "yyyy-MM-dd")
                    })
                }

                Component {
                    id: datePickerComponent
                    DatePickerDialog {}
                }
            }
        }
    }
}
