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
            system: systemField.chapterValue,
            title: titleField.text.trim(),
            description: descriptionField.text,
            severity: severitySlider.value,
            likelihood: likelihoodSlider.value,
            mitigation: mitigationField.text,
            owner: ownerField.text.trim(),
            status: statusButton.statusValue,
            dueDate: dueDateField.dateText,
            acceptedBy: acceptedByField.text.trim(),
            acceptedDate: acceptedDateField.dateText,
            reviewInterval: reviewIntervalButton.intervalValue,
            reviewedDate: reviewedDateField.dateText,
            certBaseline: baselineButton.baselineValue,
            certCriteria: criteriaField.text.trim()
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
        // Fill the fields with the hazard's saved data ONLY once, when the
        // editor opens. PageStatus.Activating is also emitted when returning
        // from a picker/DatePicker — it would otherwise overwrite
        // the user's edits with the old saved values, losing changes.
        if (status === PageStatus.Activating && editing && !fieldsLoaded) {
            fieldsLoaded = true
            var h = store.getHazard(hazardId)
            aircraftField.text = h.aircraft || ""
            systemField.chapterValue = h.system || ""
            titleField.text = h.title || ""
            descriptionField.text = h.description || ""
            severitySlider.value = h.severity !== undefined ? h.severity : 2
            likelihoodSlider.value = h.likelihood !== undefined ? h.likelihood : 3
            mitigationField.text = h.mitigation || ""
            ownerField.text = h.owner || ""
            statusButton.statusValue = h.status || "open"
            dueDateField.dateText = h.dueDate || ""
            acceptedByField.text = h.acceptedBy || ""
            acceptedDateField.dateText = h.acceptedDate || ""
            reviewIntervalButton.intervalValue = h.reviewInterval !== undefined ? h.reviewInterval : 0
            reviewedDateField.dateText = h.reviewedDate || ""
            baselineButton.baselineValue = h.certBaseline || ""
            criteriaField.text = h.certCriteria || ""
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        ScrollDecorator {}

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

            ValueButton {
                id: systemField
                property string chapterValue: ""   // full ATA chapter string, stored as-is

                width: parent.width
                label: qsTr("System (ATA)")
                value: chapterValue === "" ? qsTr("Not set") : chapterValue
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("AtaChapterPickerPage.qml"),
                                                { currentChapter: chapterValue })
                    picker.chapterPicked.connect(function(chapter) {
                        systemField.chapterValue = chapter
                    })
                }
            }

            ValueButton {
                id: baselineButton
                property string baselineValue: ""   // stored baseline, e.g. "MIL-HDBK-516C"

                // Certification baseline directly under the system: which
                // requirements set the criteria points below refer to.
                width: parent.width
                label: qsTr("Certification baseline")
                value: baselineValue === "" ? qsTr("Not specified") : baselineValue
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("BaselinePickerPage.qml"),
                                                { currentBaseline: baselineValue })
                    picker.baselinePicked.connect(function(baseline) {
                        baselineButton.baselineValue = baseline
                    })
                }
            }

            TextField {
                id: criteriaField
                width: parent.width
                placeholderText: qsTr("e.g. 5.3.2.1, 5.3.1")
                label: qsTr("Criteria points")
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

            SectionHeader { text: qsTr("Risk acceptance (residual risk)") }

            TextField {
                id: acceptedByField
                width: parent.width
                placeholderText: qsTr("Name / role of the risk accepting authority")
                label: qsTr("Risk accepted by")
            }

            ValueButton {
                id: acceptedDateField
                property string dateText: ""   // stored in ISO format yyyy-MM-dd

                width: parent.width
                label: qsTr("Acceptance date")
                value: dateText === ""
                       ? qsTr("Not set")
                       : Qt.formatDate(new Date(dateText), "dd MMM yyyy")
                onClicked: {
                    var initial = dateText !== "" ? new Date(dateText) : new Date()
                    var picker = pageStack.push(acceptDatePickerComponent, { date: initial })
                    picker.accepted.connect(function() {
                        // Store the date in ISO format so HazardStore can
                        // parse it back (same pattern as the due date field).
                        acceptedDateField.dateText = Qt.formatDate(picker.date, "yyyy-MM-dd")
                    })
                }

                Component {
                    id: acceptDatePickerComponent
                    DatePickerDialog {}
                }
            }

            SectionHeader { text: qsTr("Risk review (re-evaluation)") }

            ValueButton {
                id: reviewIntervalButton
                property int intervalValue: 0   // months, 0 = off

                width: parent.width
                label: qsTr("Review interval")
                value: store.reviewIntervalLabelFor(intervalValue)
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("ReviewIntervalPickerPage.qml"),
                                                { currentInterval: intervalValue })
                    picker.intervalPicked.connect(function(months) {
                        reviewIntervalButton.intervalValue = months
                    })
                }
            }

            ValueButton {
                id: reviewedDateField
                property string dateText: ""   // stored in ISO format yyyy-MM-dd

                width: parent.width
                label: qsTr("Last reviewed")
                value: dateText === ""
                       ? qsTr("Not set")
                       : Qt.formatDate(new Date(dateText), "dd MMM yyyy")
                onClicked: {
                    var initial = dateText !== "" ? new Date(dateText) : new Date()
                    var picker = pageStack.push(reviewDatePickerComponent, { date: initial })
                    picker.accepted.connect(function() {
                        // Record when the risk was last re-evaluated; the
                        // next review is computed from this date.
                        reviewedDateField.dateText = Qt.formatDate(picker.date, "yyyy-MM-dd")
                    })
                }

                Component {
                    id: reviewDatePickerComponent
                    DatePickerDialog {}
                }
            }

            ValueButton {
                id: statusButton
                property string statusValue: "open"

                width: parent.width
                label: qsTr("Status")
                value: store.statusLabelFor(statusValue)

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
